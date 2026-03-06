#!/usr/bin/env python3
"""
Update App Store Connect app metadata localizations.

Fields supported:
- App Store Version Localization:
  - description
  - promotionalText
  - keywords
  - supportUrl
  - marketingUrl
- App Info Localization:
  - name

The script can run in dry-run mode (default) and apply mode (--apply).

Required environment variables:
- ASC_KEY_ID
- ASC_ISSUER_ID
- ASC_PRIVATE_KEY_PATH
"""

from __future__ import annotations

import argparse
import json
import os
import time
import unicodedata
from dataclasses import dataclass
from typing import Any

import jwt
import requests

API_BASE = "https://api.appstoreconnect.apple.com"
LOCALE_ALIASES = {
    # ASC app metadata expects "no" instead of "nb-NO".
    "nb-NO": "no",
}


@dataclass(frozen=True)
class AppLocaleInput:
    locale: str
    promotional_text: str
    description: str
    keywords: str
    app_name: str | None
    subtitle: str | None
    support_url: str | None
    marketing_url: str | None


def sanitize_text(value: str, *, single_line: bool) -> str:
    normalized = unicodedata.normalize("NFC", value)
    normalized = normalized.replace("\r\n", "\n").replace("\r", "\n")

    cleaned_chars: list[str] = []
    for char in normalized:
        category = unicodedata.category(char)
        if category.startswith("C"):
            if char in {"\n", "\t"} and not single_line:
                cleaned_chars.append(char)
            continue
        cleaned_chars.append(char)
    normalized = "".join(cleaned_chars)

    # Guard against isolated combining marks that can trigger ASC invalid character errors.
    without_orphan_combining: list[str] = []
    for char in normalized:
        if unicodedata.combining(char):
            if not without_orphan_combining:
                continue
            if unicodedata.category(without_orphan_combining[-1]).startswith("M"):
                continue
        without_orphan_combining.append(char)
    normalized = "".join(without_orphan_combining)

    if single_line:
        normalized = " ".join(normalized.split())

    return normalized.strip()


def sanitize_keywords(value: str) -> str:
    normalized = sanitize_text(value, single_line=True)
    parts = [part.strip() for part in normalized.split(",") if part.strip()]
    return ",".join(parts)


def normalize_locale(locale: str) -> str:
    normalized = sanitize_text(locale, single_line=True)
    return LOCALE_ALIASES.get(normalized, normalized)


def is_state_blocking_app_info_error(error: Exception) -> bool:
    message = str(error)
    return (
        "ENTITY_ERROR.ATTRIBUTE.INVALID.INVALID_STATE" in message
        or "ENTITY_ERROR.RELATIONSHIP.INVALID" in message
    )


def env_required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def build_jwt() -> str:
    key_id = env_required("ASC_KEY_ID")
    issuer_id = env_required("ASC_ISSUER_ID")
    private_key_path = env_required("ASC_PRIVATE_KEY_PATH")

    with open(private_key_path, "r", encoding="utf-8") as file:
        private_key = file.read()

    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + (19 * 60),
        "aud": "appstoreconnect-v1",
    }
    headers = {"kid": key_id, "typ": "JWT"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


class AppStoreConnectAPI:
    def __init__(self, token: str) -> None:
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Authorization": f"Bearer {token}",
                "Content-Type": "application/json",
                "Accept": "application/json",
            }
        )

    def request(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, str] | None = None,
        body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        url = f"{API_BASE}{path}"
        retries = 3
        for attempt in range(retries):
            response = self.session.request(method, url, params=params, json=body, timeout=60)
            if response.status_code in {429, 500, 502, 503, 504} and attempt < (retries - 1):
                retry_after = response.headers.get("Retry-After")
                sleep_seconds = int(retry_after) if (retry_after and retry_after.isdigit()) else (2 ** attempt)
                time.sleep(max(1, sleep_seconds))
                continue

            if response.status_code >= 400:
                try:
                    payload = json.dumps(response.json(), indent=2, ensure_ascii=False)
                except Exception:
                    payload = response.text
                raise RuntimeError(f"{method} {path} failed with {response.status_code}\n{payload}")

            if not response.text:
                return {}
            return response.json()

        raise RuntimeError(f"{method} {path} failed after retries")

    def paginate(self, path: str, *, params: dict[str, str] | None = None) -> list[dict[str, Any]]:
        pages: list[dict[str, Any]] = []
        next_url = f"{API_BASE}{path}"
        first_page = True
        while next_url:
            retries = 3
            response = None
            for attempt in range(retries):
                response = self.session.get(next_url, params=params if first_page else None, timeout=60)
                if response.status_code in {429, 500, 502, 503, 504} and attempt < (retries - 1):
                    retry_after = response.headers.get("Retry-After")
                    sleep_seconds = int(retry_after) if (retry_after and retry_after.isdigit()) else (2 ** attempt)
                    time.sleep(max(1, sleep_seconds))
                    continue
                break
            assert response is not None
            if response.status_code >= 400:
                try:
                    payload = json.dumps(response.json(), indent=2, ensure_ascii=False)
                except Exception:
                    payload = response.text
                raise RuntimeError(f"GET {next_url} failed with {response.status_code}\n{payload}")

            page = response.json()
            pages.append(page)
            next_url = page.get("links", {}).get("next")
            first_page = False
        return pages


def get_app_id(api: AppStoreConnectAPI, bundle_id: str) -> str:
    response = api.request(
        "GET",
        "/v1/apps",
        params={
            "filter[bundleId]": bundle_id,
            "limit": "1",
        },
    )
    apps = response.get("data", [])
    if not apps:
        raise SystemExit(f"No app found in App Store Connect for bundleId: {bundle_id}")
    return apps[0]["id"]


def get_app_info_id(api: AppStoreConnectAPI, app_id: str) -> str:
    pages = api.paginate(
        f"/v1/apps/{app_id}/appInfos",
        params={
            "limit": "50",
        },
    )
    for page in pages:
        for item in page.get("data", []):
            return item["id"]
    raise SystemExit("No iOS appInfo found for app.")


def get_target_app_store_version_id(
    api: AppStoreConnectAPI,
    app_id: str,
    version_string: str | None,
) -> str:
    pages = api.paginate(
        f"/v1/apps/{app_id}/appStoreVersions",
        params={
            "limit": "200",
        },
    )
    ios_versions: list[dict[str, Any]] = []
    for page in pages:
        for item in page.get("data", []):
            attrs = item.get("attributes", {})
            if attrs.get("platform") == "IOS":
                ios_versions.append(item)

    if not ios_versions:
        raise SystemExit("No iOS appStoreVersion found for app.")

    if version_string:
        for item in ios_versions:
            attrs = item.get("attributes", {})
            if attrs.get("versionString") == version_string:
                return item["id"]
        raise SystemExit(f"No iOS appStoreVersion found for versionString={version_string}")

    editable_states = {
        "PREPARE_FOR_SUBMISSION",
        "DEVELOPER_REJECTED",
        "REJECTED",
        "METADATA_REJECTED",
    }
    for item in ios_versions:
        state = item.get("attributes", {}).get("appStoreState")
        if state in editable_states:
            return item["id"]

    return ios_versions[0]["id"]


def list_version_localizations(api: AppStoreConnectAPI, app_store_version_id: str) -> dict[str, dict[str, Any]]:
    pages = api.paginate(
        f"/v1/appStoreVersions/{app_store_version_id}/appStoreVersionLocalizations",
        params={
            "fields[appStoreVersionLocalizations]": "locale,description,promotionalText,keywords,supportUrl,marketingUrl",
            "limit": "200",
        },
    )
    by_locale: dict[str, dict[str, Any]] = {}
    for page in pages:
        for item in page.get("data", []):
            locale = item.get("attributes", {}).get("locale")
            if locale:
                by_locale[locale] = item
    return by_locale


def list_app_info_localizations(api: AppStoreConnectAPI, app_info_id: str) -> dict[str, dict[str, Any]]:
    pages = api.paginate(
        f"/v1/appInfos/{app_info_id}/appInfoLocalizations",
        params={
            "fields[appInfoLocalizations]": "locale,name,subtitle",
            "limit": "200",
        },
    )
    by_locale: dict[str, dict[str, Any]] = {}
    for page in pages:
        for item in page.get("data", []):
            locale = item.get("attributes", {}).get("locale")
            if locale:
                by_locale[locale] = item
    return by_locale


def patch_version_localization(api: AppStoreConnectAPI, localization_id: str, payload: AppLocaleInput) -> None:
    attributes: dict[str, str] = {
        "description": payload.description,
        "promotionalText": payload.promotional_text,
        "keywords": payload.keywords,
    }
    if payload.support_url:
        attributes["supportUrl"] = payload.support_url
    if payload.marketing_url:
        attributes["marketingUrl"] = payload.marketing_url

    body = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "id": localization_id,
            "attributes": attributes,
        }
    }
    api.request("PATCH", f"/v1/appStoreVersionLocalizations/{localization_id}", body=body)


def create_version_localization(api: AppStoreConnectAPI, app_store_version_id: str, payload: AppLocaleInput) -> None:
    attributes: dict[str, str] = {
        "locale": payload.locale,
        "description": payload.description,
        "promotionalText": payload.promotional_text,
        "keywords": payload.keywords,
    }
    if payload.support_url:
        attributes["supportUrl"] = payload.support_url
    if payload.marketing_url:
        attributes["marketingUrl"] = payload.marketing_url

    body = {
        "data": {
            "type": "appStoreVersionLocalizations",
            "attributes": attributes,
            "relationships": {
                "appStoreVersion": {
                    "data": {
                        "type": "appStoreVersions",
                        "id": app_store_version_id,
                    }
                }
            },
        }
    }
    api.request("POST", "/v1/appStoreVersionLocalizations", body=body)


def patch_app_info_localization(
    api: AppStoreConnectAPI,
    localization_id: str,
    app_name: str | None,
) -> None:
    attributes: dict[str, str] = {}
    if app_name:
        attributes["name"] = app_name
    if not attributes:
        return

    body = {
        "data": {
            "type": "appInfoLocalizations",
            "id": localization_id,
            "attributes": attributes,
        }
    }
    api.request("PATCH", f"/v1/appInfoLocalizations/{localization_id}", body=body)


def create_app_info_localization(
    api: AppStoreConnectAPI,
    app_info_id: str,
    locale: str,
    app_name: str | None,
) -> None:
    attributes: dict[str, str] = {"locale": locale}
    if app_name:
        attributes["name"] = app_name

    body = {
        "data": {
            "type": "appInfoLocalizations",
            "attributes": attributes,
            "relationships": {
                "appInfo": {
                    "data": {
                        "type": "appInfos",
                        "id": app_info_id,
                    }
                }
            },
        }
    }
    api.request("POST", "/v1/appInfoLocalizations", body=body)


def parse_payload(path: str) -> list[AppLocaleInput]:
    with open(path, "r", encoding="utf-8") as file:
        raw = json.load(file)

    if not isinstance(raw, dict):
        raise SystemExit("Invalid JSON payload: expected top-level object.")

    by_locale = raw.get("localizations", raw)
    if not isinstance(by_locale, dict):
        raise SystemExit("Invalid JSON payload: expected localizations object.")

    parsed: list[AppLocaleInput] = []
    for raw_locale, content in by_locale.items():
        if not isinstance(content, dict):
            raise SystemExit(f"Invalid payload for locale {raw_locale}: expected object.")

        locale = normalize_locale(raw_locale)

        promotional_text = sanitize_text(str(content.get("promotionalText", "")), single_line=True)
        description = sanitize_text(str(content.get("description", "")), single_line=False)
        keywords = sanitize_keywords(str(content.get("keywords", "")))
        app_name = sanitize_text(str(content.get("name", "")), single_line=True) or None
        subtitle = sanitize_text(str(content.get("subtitle", "")), single_line=True) or None
        support_url = sanitize_text(str(content.get("supportUrl", "")), single_line=True) or None
        marketing_url = sanitize_text(str(content.get("marketingUrl", "")), single_line=True) or None

        if not promotional_text:
            raise SystemExit(f"Missing promotionalText for locale {raw_locale}")
        if not description:
            raise SystemExit(f"Missing description for locale {raw_locale}")
        if not keywords:
            raise SystemExit(f"Missing keywords for locale {raw_locale}")

        if len(promotional_text) > 170:
            raise SystemExit(f"{raw_locale}: promotionalText exceeds 170 characters")
        if len(keywords) > 100:
            raise SystemExit(f"{raw_locale}: keywords exceeds 100 characters")
        if subtitle and len(subtitle) > 30:
            raise SystemExit(f"{raw_locale}: subtitle exceeds 30 characters")

        parsed.append(
            AppLocaleInput(
                locale=locale,
                promotional_text=promotional_text,
                description=description,
                keywords=keywords,
                app_name=app_name,
                subtitle=subtitle,
                support_url=support_url,
                marketing_url=marketing_url,
            )
        )

    if not parsed:
        raise SystemExit("No locale payloads found.")

    dedup: dict[str, AppLocaleInput] = {}
    for item in parsed:
        dedup[item.locale] = item

    parsed = list(dedup.values())

    return parsed


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Update App Store Connect app metadata localizations "
            "(description/promotionalText/keywords/subtitle/name/supportUrl/marketingUrl)."
        )
    )
    parser.add_argument("--bundle-id", required=True, help="App bundle identifier (e.g. com.company.app).")
    parser.add_argument(
        "--translations",
        required=True,
        help="Path to JSON with texts by locale (see app_metadata_texts.example.json).",
    )
    parser.add_argument(
        "--version-string",
        help="Optional target version string (e.g. 1.0). If omitted, script targets latest editable iOS version.",
    )
    parser.add_argument(
        "--no-create-missing",
        action="store_true",
        help="Only patch existing localizations, do not create missing locales.",
    )
    parser.add_argument(
        "--skip-support-url",
        action="store_true",
        help="Do not patch/create supportUrl/marketingUrl in appStoreVersionLocalizations.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually perform API changes. Without this flag, script runs in dry-run mode.",
    )
    args = parser.parse_args()

    payloads = parse_payload(args.translations)

    token = build_jwt()
    api = AppStoreConnectAPI(token)
    app_id = get_app_id(api, args.bundle_id)
    app_info_id = get_app_info_id(api, app_id)
    app_store_version_id = get_target_app_store_version_id(api, app_id, args.version_string)

    existing_version = list_version_localizations(api, app_store_version_id)
    existing_info = list_app_info_localizations(api, app_info_id)

    print(
        f"appId={app_id} appInfoId={app_info_id} appStoreVersionId={app_store_version_id}\n"
        f"existingVersionLocales={sorted(existing_version.keys())}\n"
        f"existingAppInfoLocales={sorted(existing_info.keys())}"
    )

    version_actions: list[tuple[str, str, str]] = []
    info_actions: list[tuple[str, str, str]] = []

    for payload in payloads:
        version_item = existing_version.get(payload.locale)
        if version_item is not None:
            version_actions.append(("PATCH", payload.locale, version_item["id"]))
        elif not args.no_create_missing:
            version_actions.append(("POST", payload.locale, app_store_version_id))

        if not payload.app_name:
            continue

        info_item = existing_info.get(payload.locale)
        if info_item is not None:
            info_actions.append(("PATCH", payload.locale, info_item["id"]))
        elif not args.no_create_missing:
            info_actions.append(("POST", payload.locale, app_info_id))

    print("\nPlanned version-localization actions:")
    for method, locale, target in version_actions:
        target_label = "localizationId" if method == "PATCH" else "appStoreVersionId"
        print(f"- {method} locale={locale} ({target_label}={target})")

    print("\nPlanned app-info-localization actions (name):")
    for method, locale, target in info_actions:
        target_label = "localizationId" if method == "PATCH" else "appInfoId"
        print(f"- {method} locale={locale} ({target_label}={target})")

    if not args.apply:
        print("\nDry-run only. Re-run with --apply to execute.")
        return

    by_locale = {item.locale: item for item in payloads}
    failures: list[str] = []
    warnings: list[str] = []

    for method, locale, target in version_actions:
        payload = by_locale[locale]
        if args.skip_support_url:
            payload = AppLocaleInput(
                locale=payload.locale,
                promotional_text=payload.promotional_text,
                description=payload.description,
                keywords=payload.keywords,
                app_name=payload.app_name,
                subtitle=payload.subtitle,
                support_url=None,
                marketing_url=None,
            )
        try:
            if method == "PATCH":
                patch_version_localization(api, target, payload)
                print(f"Applied PATCH version localization locale={locale} id={target}")
            else:
                create_version_localization(api, target, payload)
                print(f"Applied POST version localization locale={locale} appStoreVersionId={target}")
        except Exception as error:  # Keep bulk update running and report all bad locales in one run.
            failures.append(f"version locale={locale} method={method}: {error}")
            print(f"FAILED version locale={locale} method={method}: {error}")

    for method, locale, target in info_actions:
        app_name = by_locale[locale].app_name
        if not app_name:
            continue
        try:
            if method == "PATCH":
                patch_app_info_localization(api, target, app_name)
                print(f"Applied PATCH app-info localization locale={locale} id={target}")
            else:
                create_app_info_localization(
                    api,
                    target,
                    locale,
                    app_name,
                )
                print(f"Applied POST app-info localization locale={locale} appInfoId={target}")
        except Exception as error:  # Keep bulk update running and report all bad locales in one run.
            if is_state_blocking_app_info_error(error):
                warning = (
                    f"app-info locale={locale} method={method} skipped: not editable in current ASC state "
                    f"(apply name manually in App Information when editable)"
                )
                warnings.append(warning)
                print(f"SKIPPED {warning}")
                continue
            failures.append(f"app-info locale={locale} method={method}: {error}")
            print(f"FAILED app-info locale={locale} method={method}: {error}")

    if warnings:
        print("\nCompleted with warnings:")
        for warning in warnings:
            print(f"- {warning}")

    if failures:
        print("\nCompleted with errors:")
        for failure in failures:
            print(f"- {failure}")
        raise SystemExit(1)

    print("\nDone.")


if __name__ == "__main__":
    main()
