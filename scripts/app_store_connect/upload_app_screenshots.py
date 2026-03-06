#!/usr/bin/env python3
"""
Upload App Store screenshots per locale and display type.

Expected folder structure (defaults):
- fastlane/frameit/results/screenshots/<locale>/*.png
- fastlane/frameit/results/screenshots-ipad/<locale>/*.png

The script supports dry-run by default and apply mode with --apply.

Required environment variables:
- ASC_KEY_ID
- ASC_ISSUER_ID
- ASC_PRIVATE_KEY_PATH
"""

from __future__ import annotations

import argparse
import json
import os
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

try:
    import jwt  # type: ignore
except ImportError:  # pragma: no cover - runtime dependency check.
    jwt = None

try:
    import requests  # type: ignore
except ImportError:  # pragma: no cover - runtime dependency check.
    requests = None

API_BASE = "https://api.appstoreconnect.apple.com"
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg"}
IGNORED_FILENAMES = {".gitkeep", "screenshots.html"}
DEFAULT_IPHONE_ROOT = "fastlane/frameit/results/screenshots"
DEFAULT_IPAD_ROOT = "fastlane/frameit/results/screenshots-ipad"
DEFAULT_IPHONE_DISPLAY_TYPE = "APP_IPHONE_67"
DEFAULT_IPAD_DISPLAY_TYPE = "APP_IPAD_PRO_129"
DEFAULT_REPLACE_STRATEGY = "safe"

LOCALE_ALIASES = {
    "da": "da",
    "de": "de-DE",
    "en": "en-US",
    "en-us": "en-US",
    "es": "es-ES",
    "fr": "fr-FR",
    "hi": "hi",
    "it": "it",
    "ja": "ja",
    "ko": "ko",
    "nb": "no",
    "nb-no": "no",
    "nl": "nl-NL",
    "no": "no",
    "pt-br": "pt-BR",
    "pt-pt": "pt-PT",
    "sv": "sv",
    "zh-hans": "zh-Hans",
}

TERMINAL_UPLOAD_STATES = {"COMPLETE", "FAILED", "REJECTED"}


@dataclass(frozen=True)
class LocalScreenshotInput:
    source_locale_dir: str
    locale: str
    display_type: str
    files: list[Path]


def display_type_family(display_type: str) -> str:
    if display_type.startswith("APP_IPHONE_"):
        return "IPHONE"
    if display_type.startswith("APP_IPAD_"):
        return "IPAD"
    return "OTHER"


def resolve_display_type(
    requested_display_type: str,
    existing_sets_by_display_type: dict[str, dict[str, Any]],
    *,
    prefer_existing_display_type: bool,
) -> tuple[str, str | None]:
    if requested_display_type in existing_sets_by_display_type:
        return requested_display_type, None

    if not prefer_existing_display_type or not existing_sets_by_display_type:
        return requested_display_type, None

    requested_family = display_type_family(requested_display_type)
    same_family_types = [
        display_type
        for display_type in sorted(existing_sets_by_display_type.keys())
        if display_type_family(display_type) == requested_family
    ]

    if len(same_family_types) == 1:
        resolved = same_family_types[0]
        return resolved, (
            f"requested displayType={requested_display_type} not found; using existing displayType={resolved}"
        )

    if not same_family_types:
        available = ",".join(sorted(existing_sets_by_display_type.keys()))
        return requested_display_type, (
            f"requested displayType={requested_display_type} not found and no same-family existing set available ({available})"
        )

    available = ",".join(same_family_types)
    return requested_display_type, (
        f"requested displayType={requested_display_type} not found and multiple same-family sets available ({available})"
    )


def env_required(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def build_jwt() -> str:
    if jwt is None:
        raise SystemExit("Missing dependency: pyjwt. Install with `python3 -m pip install pyjwt cryptography requests`.")

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
        if requests is None:
            raise SystemExit("Missing dependency: requests. Install with `python3 -m pip install requests`.")
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
            response = self.session.request(method, url, params=params, json=body, timeout=90)
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
                response = self.session.get(next_url, params=params if first_page else None, timeout=90)
                if response.status_code in {429, 500, 502, 503, 504} and attempt < (retries - 1):
                    retry_after = response.headers.get("Retry-After")
                    sleep_seconds = int(retry_after) if (retry_after and retry_after.isdigit()) else (2 ** attempt)
                    time.sleep(max(1, sleep_seconds))
                    continue
                break

            if response is None:
                raise RuntimeError(f"GET {next_url} failed: no response")

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


def normalize_locale(folder_locale: str) -> str:
    key = folder_locale.strip().lower()
    if key in LOCALE_ALIASES:
        return LOCALE_ALIASES[key]
    return folder_locale.strip()


def natural_sort_key(path: Path) -> list[int | str]:
    chunks = re.split(r"(\d+)", path.name.lower())
    key: list[int | str] = []
    for chunk in chunks:
        if chunk.isdigit():
            key.append(int(chunk))
        else:
            key.append(chunk)
    return key


def discover_locale_files(root: Path, display_type: str, max_images_per_set: int) -> list[LocalScreenshotInput]:
    if not root.exists() or not root.is_dir():
        return []

    discovered: list[LocalScreenshotInput] = []

    for locale_dir in sorted(root.iterdir(), key=lambda item: item.name.lower()):
        if not locale_dir.is_dir():
            continue

        normalized_locale = normalize_locale(locale_dir.name)
        image_files = [
            file
            for file in locale_dir.iterdir()
            if file.is_file()
            and file.name not in IGNORED_FILENAMES
            and file.suffix.lower() in IMAGE_EXTENSIONS
        ]
        image_files.sort(key=natural_sort_key)

        if not image_files:
            continue

        if len(image_files) > max_images_per_set:
            raise SystemExit(
                f"{locale_dir}: found {len(image_files)} images, exceeds max {max_images_per_set} per screenshot set"
            )

        discovered.append(
            LocalScreenshotInput(
                source_locale_dir=locale_dir.name,
                locale=normalized_locale,
                display_type=display_type,
                files=image_files,
            )
        )

    return discovered


def deduplicate_inputs(items: list[LocalScreenshotInput]) -> tuple[list[LocalScreenshotInput], list[str]]:
    deduped: dict[tuple[str, str], LocalScreenshotInput] = {}
    warnings: list[str] = []

    for item in items:
        key = (item.locale, item.display_type)
        existing = deduped.get(key)
        if existing is None:
            deduped[key] = item
            continue

        existing_exact = existing.source_locale_dir.lower() == existing.locale.lower()
        new_exact = item.source_locale_dir.lower() == item.locale.lower()

        replacement = existing
        reason = "first entry kept"
        if new_exact and not existing_exact:
            replacement = item
            reason = "exact locale folder preferred"
        elif new_exact == existing_exact and len(item.files) > len(existing.files):
            replacement = item
            reason = "entry with more files preferred"

        deduped[key] = replacement
        warnings.append(
            f"duplicate locale/display '{item.locale}/{item.display_type}': "
            f"'{existing.source_locale_dir}' vs '{item.source_locale_dir}' -> {reason}"
        )

    result = sorted(
        deduped.values(),
        key=lambda element: (element.locale.lower(), element.display_type, element.source_locale_dir.lower()),
    )
    return result, warnings


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


def get_target_app_store_version_id(
    api: AppStoreConnectAPI,
    app_id: str,
    version_string: str | None,
) -> str:
    pages = api.paginate(
        f"/v1/apps/{app_id}/appStoreVersions",
        params={"limit": "200"},
    )
    ios_versions: list[dict[str, Any]] = []
    for page in pages:
        for item in page.get("data", []):
            attributes = item.get("attributes", {})
            if attributes.get("platform") == "IOS":
                ios_versions.append(item)

    if not ios_versions:
        raise SystemExit("No iOS appStoreVersion found for app")

    if version_string:
        for item in ios_versions:
            if item.get("attributes", {}).get("versionString") == version_string:
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
            "fields[appStoreVersionLocalizations]": "locale",
            "limit": "200",
        },
    )
    result: dict[str, dict[str, Any]] = {}
    for page in pages:
        for item in page.get("data", []):
            locale = item.get("attributes", {}).get("locale")
            if locale:
                result[locale] = item
    return result


def list_screenshot_sets(api: AppStoreConnectAPI, localization_id: str) -> dict[str, dict[str, Any]]:
    pages = api.paginate(
        f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets",
        params={
            "fields[appScreenshotSets]": "screenshotDisplayType",
            "limit": "200",
        },
    )
    result: dict[str, dict[str, Any]] = {}
    for page in pages:
        for item in page.get("data", []):
            display_type = item.get("attributes", {}).get("screenshotDisplayType")
            if display_type:
                result[display_type] = item
    return result


def create_screenshot_set(api: AppStoreConnectAPI, localization_id: str, display_type: str) -> str:
    body = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {
                "screenshotDisplayType": display_type,
            },
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": localization_id,
                    }
                }
            },
        }
    }
    response = api.request("POST", "/v1/appScreenshotSets", body=body)
    data = response.get("data")
    if not data:
        raise RuntimeError("Missing response data when creating appScreenshotSet")
    return data["id"]


def list_screenshots(api: AppStoreConnectAPI, screenshot_set_id: str) -> list[dict[str, Any]]:
    pages = api.paginate(
        f"/v1/appScreenshotSets/{screenshot_set_id}/appScreenshots",
        params={
            "fields[appScreenshots]": "fileName,assetDeliveryState",
            "limit": "200",
        },
    )

    screenshots: list[dict[str, Any]] = []
    for page in pages:
        screenshots.extend(page.get("data", []))
    return screenshots


def delete_screenshot(api: AppStoreConnectAPI, screenshot_id: str) -> None:
    api.request("DELETE", f"/v1/appScreenshots/{screenshot_id}")


def create_screenshot_upload(api: AppStoreConnectAPI, screenshot_set_id: str, file_path: Path) -> dict[str, Any]:
    body = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": file_path.name,
                "fileSize": file_path.stat().st_size,
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {
                        "type": "appScreenshotSets",
                        "id": screenshot_set_id,
                    }
                }
            },
        }
    }
    response = api.request("POST", "/v1/appScreenshots", body=body)
    data = response.get("data", {})
    screenshot_id = data.get("id")
    if not screenshot_id:
        raise RuntimeError(f"Missing screenshot id in upload creation response for {file_path}")

    attributes = data.get("attributes", {})
    operations = attributes.get("uploadOperations", [])
    if not operations:
        raise RuntimeError(f"Missing uploadOperations for screenshot {screenshot_id} ({file_path})")

    return {"id": screenshot_id, "operations": operations}


def upload_file_operations(file_path: Path, operations: list[dict[str, Any]]) -> None:
    if requests is None:
        raise SystemExit("Missing dependency: requests. Install with `python3 -m pip install requests`.")

    file_size = file_path.stat().st_size
    with file_path.open("rb") as file:
        for operation in operations:
            method = str(operation.get("method", "PUT")).upper()
            url = operation.get("url")
            if not url:
                raise RuntimeError(f"Missing upload URL in operation for {file_path}")

            offset = int(operation.get("offset", 0))
            length = int(operation.get("length", file_size - offset))

            file.seek(offset)
            payload = file.read(length)
            if len(payload) != length:
                raise RuntimeError(
                    f"Could not read expected upload slice for {file_path}: offset={offset} length={length}"
                )

            headers: dict[str, str] = {}
            for header in operation.get("requestHeaders", []):
                name = header.get("name")
                value = header.get("value")
                if name and value:
                    headers[name] = value

            response = requests.request(method, url, data=payload, headers=headers, timeout=120)
            if response.status_code >= 400:
                raise RuntimeError(
                    f"Upload operation failed for {file_path} with {response.status_code}: {response.text}"
                )


def finalize_upload(api: AppStoreConnectAPI, screenshot_id: str) -> None:
    body = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {
                "uploaded": True,
            },
        }
    }
    api.request("PATCH", f"/v1/appScreenshots/{screenshot_id}", body=body)


def get_screenshot_state(api: AppStoreConnectAPI, screenshot_id: str) -> str:
    response = api.request(
        "GET",
        f"/v1/appScreenshots/{screenshot_id}",
        params={"fields[appScreenshots]": "assetDeliveryState"},
    )
    attributes = response.get("data", {}).get("attributes", {})
    state = attributes.get("assetDeliveryState", {}).get("state")
    if not state:
        return "UNKNOWN"
    return str(state)


def wait_until_processed(api: AppStoreConnectAPI, screenshot_ids: list[str], timeout_seconds: int) -> None:
    if not screenshot_ids or timeout_seconds <= 0:
        return

    pending = set(screenshot_ids)
    deadline = time.time() + timeout_seconds

    while pending and time.time() < deadline:
        finished_this_round: list[str] = []
        for screenshot_id in sorted(pending):
            state = get_screenshot_state(api, screenshot_id)
            if state in TERMINAL_UPLOAD_STATES:
                finished_this_round.append(screenshot_id)
                if state != "COMPLETE":
                    raise RuntimeError(f"Screenshot {screenshot_id} ended in state={state}")

        for screenshot_id in finished_this_round:
            pending.discard(screenshot_id)

        if pending:
            time.sleep(5)

    if pending:
        raise RuntimeError(
            "Timed out waiting for screenshot processing for ids=" + ",".join(sorted(pending))
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Upload localized App Store screenshots from frameit folders."
    )
    parser.add_argument("--bundle-id", required=True, help="App bundle identifier (e.g. com.company.app).")
    parser.add_argument(
        "--version-string",
        help="Optional target version string (e.g. 1.0). If omitted, script uses the latest editable iOS version.",
    )
    parser.add_argument(
        "--iphone-root",
        default=DEFAULT_IPHONE_ROOT,
        help=f"Folder with iPhone screenshots by locale (default: {DEFAULT_IPHONE_ROOT}).",
    )
    parser.add_argument(
        "--iphone-display-type",
        default=DEFAULT_IPHONE_DISPLAY_TYPE,
        help=f"ASC screenshotDisplayType for iPhone root (default: {DEFAULT_IPHONE_DISPLAY_TYPE}).",
    )
    parser.add_argument(
        "--ipad-root",
        default=DEFAULT_IPAD_ROOT,
        help=f"Folder with iPad screenshots by locale (default: {DEFAULT_IPAD_ROOT}).",
    )
    parser.add_argument(
        "--ipad-display-type",
        default=DEFAULT_IPAD_DISPLAY_TYPE,
        help=f"ASC screenshotDisplayType for iPad root (default: {DEFAULT_IPAD_DISPLAY_TYPE}).",
    )
    parser.add_argument(
        "--skip-ipad",
        action="store_true",
        help="Do not scan/upload iPad screenshots.",
    )
    parser.add_argument(
        "--skip-iphone",
        action="store_true",
        help="Do not scan/upload iPhone screenshots.",
    )
    parser.add_argument(
        "--keep-existing",
        action="store_true",
        help="Keep existing screenshots in ASC set and append new ones (default is to delete existing first).",
    )
    parser.add_argument(
        "--replace-strategy",
        choices=("safe", "eager"),
        default=DEFAULT_REPLACE_STRATEGY,
        help=(
            "How to replace existing screenshots when --keep-existing is not set: "
            "'safe' uploads new first then deletes old (safer), "
            "'eager' deletes old first then uploads new."
        ),
    )
    parser.add_argument(
        "--prefer-existing-display-type",
        action="store_true",
        help=(
            "If requested displayType is missing but locale has exactly one existing set, reuse that displayType."
        ),
    )
    parser.add_argument(
        "--max-images-per-set",
        type=int,
        default=10,
        help="Max number of screenshots per locale/display set (default: 10).",
    )
    parser.add_argument(
        "--scan-only",
        action="store_true",
        help="Only inspect local folders and print what would be uploaded. No ASC API calls.",
    )
    parser.add_argument(
        "--wait-seconds",
        type=int,
        default=300,
        help="Seconds to wait for ASC asset processing after upload (default: 300).",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually perform API changes. Without this flag, script runs in dry-run mode.",
    )
    args = parser.parse_args()

    screenshot_inputs: list[LocalScreenshotInput] = []

    if not args.skip_iphone:
        screenshot_inputs.extend(
            discover_locale_files(
                Path(args.iphone_root),
                args.iphone_display_type,
                args.max_images_per_set,
            )
        )

    if not args.skip_ipad:
        screenshot_inputs.extend(
            discover_locale_files(
                Path(args.ipad_root),
                args.ipad_display_type,
                args.max_images_per_set,
            )
        )

    if not screenshot_inputs:
        raise SystemExit("No screenshots found. Check folder paths or remove skip flags.")

    screenshot_inputs, dedupe_warnings = deduplicate_inputs(screenshot_inputs)

    if dedupe_warnings:
        print("Duplicate locale mappings detected:")
        for warning in dedupe_warnings:
            print(f"- {warning}")
        print("")

    print("Discovered screenshot payloads:")
    for item in screenshot_inputs:
        print(
            f"- locale={item.locale} sourceFolder={item.source_locale_dir} "
            f"displayType={item.display_type} files={len(item.files)}"
        )
        for file_path in item.files:
            print(f"    - {file_path}")

    if args.scan_only:
        print("\nScan-only complete.")
        return

    token = build_jwt()
    api = AppStoreConnectAPI(token)

    app_id = get_app_id(api, args.bundle_id)
    app_store_version_id = get_target_app_store_version_id(api, app_id, args.version_string)
    localizations = list_version_localizations(api, app_store_version_id)

    print(
        f"\nappId={app_id} appStoreVersionId={app_store_version_id} "
        f"existingLocales={sorted(localizations.keys())}"
    )

    planned_actions: list[str] = []
    planning_warnings: list[str] = []
    skipped_missing_locale: list[str] = []

    for item in screenshot_inputs:
        localization = localizations.get(item.locale)
        if localization is None:
            skipped_missing_locale.append(item.locale)
            continue

        localization_id = localization["id"]
        sets_by_display_type = list_screenshot_sets(api, localization_id)
        resolved_display_type, display_type_warning = resolve_display_type(
            item.display_type,
            sets_by_display_type,
            prefer_existing_display_type=args.prefer_existing_display_type,
        )
        if display_type_warning:
            planning_warnings.append(f"locale={item.locale}: {display_type_warning}")

        existing_set = sets_by_display_type.get(resolved_display_type)
        if existing_set is None:
            planned_actions.append(
                f"CREATE screenshot-set locale={item.locale} displayType={resolved_display_type}"
            )
        else:
            planned_actions.append(
                f"REUSE screenshot-set locale={item.locale} displayType={resolved_display_type} id={existing_set['id']}"
            )
            if not args.keep_existing:
                existing_screenshots = list_screenshots(api, existing_set["id"])
                existing_count = len(existing_screenshots)
                if args.replace_strategy == "safe":
                    projected_count = existing_count + len(item.files)
                    if projected_count > args.max_images_per_set:
                        raise SystemExit(
                            "Safe replace would exceed max screenshots in set: "
                            f"locale={item.locale} displayType={resolved_display_type} "
                            f"existing={existing_count} new={len(item.files)} max={args.max_images_per_set}. "
                            "Use --replace-strategy eager for delete-first behavior."
                        )
                    planned_actions.append(
                        f"SAFE-REPLACE locale={item.locale} displayType={resolved_display_type} "
                        f"(upload {len(item.files)} then delete {existing_count})"
                    )
                else:
                    planned_actions.append(
                        f"DELETE existing screenshots locale={item.locale} displayType={resolved_display_type} count={existing_count}"
                    )

        planned_actions.append(
            f"UPLOAD locale={item.locale} displayType={resolved_display_type} files={len(item.files)}"
        )

    print("\nPlanned ASC actions:")
    for action in planned_actions:
        print(f"- {action}")

    if skipped_missing_locale:
        unique = sorted(set(skipped_missing_locale))
        print("\nSkipped (missing appStoreVersion localization in ASC):")
        for locale in unique:
            print(f"- {locale}")

    if planning_warnings:
        print("\nWarnings:")
        for warning in planning_warnings:
            print(f"- {warning}")

    if not args.apply:
        print("\nDry-run only. Re-run with --apply to execute.")
        return

    uploaded_ids_pending_processing: list[str] = []

    for item in screenshot_inputs:
        localization = localizations.get(item.locale)
        if localization is None:
            continue

        localization_id = localization["id"]
        sets_by_display_type = list_screenshot_sets(api, localization_id)
        resolved_display_type, display_type_warning = resolve_display_type(
            item.display_type,
            sets_by_display_type,
            prefer_existing_display_type=args.prefer_existing_display_type,
        )
        if display_type_warning:
            print(f"WARN locale={item.locale}: {display_type_warning}")

        existing_set = sets_by_display_type.get(resolved_display_type)

        if existing_set is None:
            screenshot_set_id = create_screenshot_set(api, localization_id, resolved_display_type)
            print(
                f"Created screenshot set locale={item.locale} "
                f"displayType={resolved_display_type} id={screenshot_set_id}"
            )
        else:
            screenshot_set_id = existing_set["id"]
            print(
                f"Using screenshot set locale={item.locale} "
                f"displayType={resolved_display_type} id={screenshot_set_id}"
            )

        existing_screenshots = list_screenshots(api, screenshot_set_id)
        existing_screenshot_ids = [screenshot["id"] for screenshot in existing_screenshots]

        if not args.keep_existing and args.replace_strategy == "safe" and existing_screenshot_ids:
            projected_count = len(existing_screenshot_ids) + len(item.files)
            if projected_count > args.max_images_per_set:
                raise SystemExit(
                    "Safe replace would exceed max screenshots in set during apply: "
                    f"locale={item.locale} displayType={resolved_display_type} "
                    f"existing={len(existing_screenshot_ids)} new={len(item.files)} max={args.max_images_per_set}. "
                    "Use --replace-strategy eager for delete-first behavior."
                )

        if not args.keep_existing and args.replace_strategy == "eager" and existing_screenshot_ids:
            for screenshot_id in existing_screenshot_ids:
                delete_screenshot(api, screenshot_id)
                print(f"Deleted existing screenshot id={screenshot_id}")
            existing_screenshot_ids = []

        uploaded_this_item: list[str] = []

        for file_path in item.files:
            upload_seed = create_screenshot_upload(api, screenshot_set_id, file_path)
            screenshot_id = upload_seed["id"]
            upload_file_operations(file_path, upload_seed["operations"])
            finalize_upload(api, screenshot_id)
            uploaded_this_item.append(screenshot_id)
            print(f"Uploaded {file_path.name} -> screenshotId={screenshot_id}")

        if not args.keep_existing and args.replace_strategy == "safe" and existing_screenshot_ids:
            wait_until_processed(api, uploaded_this_item, args.wait_seconds)
            for screenshot_id in existing_screenshot_ids:
                delete_screenshot(api, screenshot_id)
                print(f"Deleted old screenshot after safe replace id={screenshot_id}")
        else:
            uploaded_ids_pending_processing.extend(uploaded_this_item)

    wait_until_processed(api, uploaded_ids_pending_processing, args.wait_seconds)
    print("\nCompleted screenshot upload flow.")


if __name__ == "__main__":
    main()
