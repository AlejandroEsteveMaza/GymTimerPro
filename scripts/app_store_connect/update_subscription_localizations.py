#!/usr/bin/env python3
"""
Update App Store Connect subscription localization texts (name + description).

Targets:
- premium_monthly
- premium_yearly

The script:
1) Finds subscriptions by productId.
2) Lists existing localizations per subscription.
3) Updates existing locale rows with PATCH.
4) Creates missing locale rows with POST.

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
from dataclasses import dataclass
from typing import Any

import jwt
import requests

API_BASE = "https://api.appstoreconnect.apple.com"
DEFAULT_PRODUCT_IDS = ["premium_monthly", "premium_yearly"]


@dataclass(frozen=True)
class LocalizationInput:
    locale: str
    name: str
    description: str


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

    def request(self, method: str, path: str, *, params: dict[str, str] | None = None, body: dict[str, Any] | None = None) -> dict[str, Any]:
        response = self.session.request(method, f"{API_BASE}{path}", params=params, json=body, timeout=60)
        if response.status_code >= 400:
            try:
                payload = json.dumps(response.json(), indent=2, ensure_ascii=False)
            except Exception:
                payload = response.text
            raise RuntimeError(f"{method} {path} failed with {response.status_code}\n{payload}")

        if not response.text:
            return {}
        return response.json()

    def paginate(self, path: str, *, params: dict[str, str] | None = None) -> list[dict[str, Any]]:
        pages: list[dict[str, Any]] = []
        next_url = f"{API_BASE}{path}"
        first_page = True
        while next_url:
            response = self.session.get(next_url, params=params if first_page else None, timeout=60)
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


def get_subscription_group_ids(api: AppStoreConnectAPI, app_id: str) -> list[str]:
    pages = api.paginate(
        f"/v1/apps/{app_id}/relationships/subscriptionGroups",
        params={"limit": "200"},
    )
    group_ids: list[str] = []
    for page in pages:
        for item in page.get("data", []):
            group_ids.append(item["id"])
    return group_ids


def list_subscriptions_for_group(api: AppStoreConnectAPI, group_id: str) -> dict[str, dict[str, Any]]:
    params = {
        "fields[subscriptions]": "name,productId",
        "limit": "200",
    }
    pages = api.paginate(f"/v1/subscriptionGroups/{group_id}/subscriptions", params=params)

    by_product_id: dict[str, dict[str, Any]] = {}
    for page in pages:
        for item in page.get("data", []):
            attrs = item.get("attributes", {})
            product_id = attrs.get("productId")
            if not product_id:
                continue
            by_product_id[product_id] = item
    return by_product_id


def list_subscriptions_for_app(
    api: AppStoreConnectAPI,
    app_id: str,
    target_product_ids: list[str],
) -> dict[str, dict[str, Any]]:
    group_ids = get_subscription_group_ids(api, app_id)
    subscriptions: dict[str, dict[str, Any]] = {}

    for group_id in group_ids:
        grouped = list_subscriptions_for_group(api, group_id)
        for product_id, subscription in grouped.items():
            if product_id in target_product_ids:
                subscriptions[product_id] = subscription
    return subscriptions


def list_subscription_localizations(api: AppStoreConnectAPI, subscription_id: str) -> dict[str, dict[str, Any]]:
    params = {
        "fields[subscriptionLocalizations]": "locale,name,description",
        "limit": "200",
    }
    pages = api.paginate(f"/v1/subscriptions/{subscription_id}/subscriptionLocalizations", params=params)

    by_locale: dict[str, dict[str, Any]] = {}
    for page in pages:
        for item in page.get("data", []):
            attrs = item.get("attributes", {})
            locale = attrs.get("locale")
            if not locale:
                continue
            by_locale[locale] = item
    return by_locale


def patch_localization(api: AppStoreConnectAPI, localization_id: str, name: str, description: str) -> None:
    body = {
        "data": {
            "type": "subscriptionLocalizations",
            "id": localization_id,
            "attributes": {
                "name": name,
                "description": description,
            },
        }
    }
    api.request("PATCH", f"/v1/subscriptionLocalizations/{localization_id}", body=body)


def create_localization(api: AppStoreConnectAPI, subscription_id: str, payload: LocalizationInput) -> None:
    body = {
        "data": {
            "type": "subscriptionLocalizations",
            "attributes": {
                "locale": payload.locale,
                "name": payload.name,
                "description": payload.description,
            },
            "relationships": {
                "subscription": {
                    "data": {
                        "type": "subscriptions",
                        "id": subscription_id,
                    }
                }
            },
        }
    }
    api.request("POST", "/v1/subscriptionLocalizations", body=body)


def load_translations(path: str, max_description_length: int) -> dict[str, list[LocalizationInput]]:
    with open(path, "r", encoding="utf-8") as file:
        raw = json.load(file)

    result: dict[str, list[LocalizationInput]] = {}
    for product_id, locales in raw.items():
        if not isinstance(locales, dict):
            raise SystemExit(f"Invalid translation payload for {product_id}: expected object by locale")

        parsed_locales: list[LocalizationInput] = []
        for locale, content in locales.items():
            if not isinstance(content, dict):
                raise SystemExit(f"Invalid translation payload for {product_id}/{locale}: expected object")
            name = str(content.get("name", "")).strip()
            description = str(content.get("description", "")).strip()
            if not name or not description:
                raise SystemExit(f"Missing name or description for {product_id}/{locale}")
            if max_description_length > 0 and len(description) > max_description_length:
                raise SystemExit(
                    f"{product_id}/{locale}: description exceeds {max_description_length} characters"
                )

            parsed_locales.append(LocalizationInput(locale=locale, name=name, description=description))
        result[product_id] = parsed_locales
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Update App Store Connect subscription localization texts for premium_monthly and premium_yearly."
    )
    parser.add_argument(
        "--bundle-id",
        required=True,
        help="App bundle identifier (e.g. com.company.app).",
    )
    parser.add_argument(
        "--translations",
        required=True,
        help="Path to JSON with texts by productId and locale (see subscription_texts.example.json).",
    )
    parser.add_argument(
        "--product-ids",
        default=",".join(DEFAULT_PRODUCT_IDS),
        help="Comma-separated product IDs to process.",
    )
    parser.add_argument(
        "--max-description-length",
        type=int,
        default=55,
        help="Max description length, 0 to disable length validation.",
    )
    parser.add_argument(
        "--no-create-missing",
        action="store_true",
        help="Only patch existing localizations, do not create missing locales.",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually perform API changes. Without this flag, script runs in dry-run mode.",
    )
    args = parser.parse_args()

    product_ids = [item.strip() for item in args.product_ids.split(",") if item.strip()]
    if not product_ids:
        raise SystemExit("No product IDs provided.")

    translations = load_translations(args.translations, args.max_description_length)
    token = build_jwt()
    api = AppStoreConnectAPI(token)
    app_id = get_app_id(api, args.bundle_id)
    subscriptions = list_subscriptions_for_app(api, app_id, product_ids)
    missing_products = [pid for pid in product_ids if pid not in subscriptions]
    if missing_products:
        raise SystemExit(f"Subscriptions not found for product IDs: {', '.join(missing_products)}")

    actions: list[tuple[str, str, str, str, str, str]] = []
    # action tuple:
    # (method, product_id, locale, localization_or_subscription_id, name, description)
    for product_id in product_ids:
        subscription = subscriptions[product_id]
        subscription_id = subscription["id"]
        existing_localizations = list_subscription_localizations(api, subscription_id)

        expected_locales = translations.get(product_id)
        if not expected_locales:
            raise SystemExit(f"No translations found for {product_id} in input JSON.")

        print(
            f"{product_id}: subscriptionId={subscription_id}, "
            f"existingLocales={sorted(existing_localizations.keys())}"
        )

        for payload in expected_locales:
            existing = existing_localizations.get(payload.locale)
            if existing is not None:
                localization_id = existing["id"]
                actions.append(("PATCH", product_id, payload.locale, localization_id, payload.name, payload.description))
            elif not args.no_create_missing:
                actions.append(("POST", product_id, payload.locale, subscription_id, payload.name, payload.description))

    print("\nPlanned actions:")
    for method, product_id, locale, target_id, name, _ in actions:
        label = "localizationId" if method == "PATCH" else "subscriptionId"
        print(f"- {method} {product_id} {locale} ({label}={target_id}) name='{name}'")

    if not args.apply:
        print("\nDry-run only. Re-run with --apply to execute.")
        return

    for method, _, locale, target_id, name, description in actions:
        if method == "PATCH":
            patch_localization(api, target_id, name, description)
            print(f"Applied PATCH locale={locale} localizationId={target_id}")
        else:
            create_localization(
                api,
                target_id,
                LocalizationInput(locale=locale, name=name, description=description),
            )
            print(f"Applied POST locale={locale} subscriptionId={target_id}")

    print("\nDone.")


if __name__ == "__main__":
    main()
