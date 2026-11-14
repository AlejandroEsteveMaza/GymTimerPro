"""Strict, iPhone-only batch delivery using the existing screenshot uploader."""
from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import parse_qsl, urlparse

import upload_app_screenshots as legacy

REPO = Path(__file__).resolve().parents[2]
BUNDLE_ID = "alejandroestevemaza.GymTimerPro"
LOCALES = ["en", "es", "de", "fr", "it", "pt-BR", "pt-PT", "nl", "sv", "da",
           "nb", "ja", "ko", "zh-Hans", "hi"]
ASC_LOCALES = [legacy.normalize_locale(locale) for locale in LOCALES]
SCREEN_IDS = ["02_Timer", "11_RoutinesCatalog", "20_ProgressMonth",
              "12_RoutineEditor", "05_TrainingCompleted"]
DISPLAY_TYPE = "APP_IPHONE_67"
APP = {"version": "1.3.1", "build": "4", "bundle_identifier": BUNDLE_ID}
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
VISUAL_CHECKS = {"correct_screens", "correct_ui_locales", "text_not_clipped",
                 "no_overlap", "contrast", "font_and_encoding"}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_error(error):
    message = re.sub(r"https?://\S+", "[redacted URL]", str(error))
    return re.sub(r"Bearer\s+\S+", "Bearer [redacted]", message)[:1000]


def save_json(path, value):
    """Persist the recovery journal before sending any mutation."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                     prefix=".asc-journal-", delete=False) as stream:
        temporary = Path(stream.name)
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


class StrictAPI(legacy.AppStoreConnectAPI):
    """No ambient credentials, redirects, mutation retries or unscoped writes."""
    def __init__(self, token):
        super().__init__(token)
        self.session.trust_env = False
        self.writable = False
        self.deletion_enabled = False
        self.localizations, self.sets, self.old, self.new = set(), set(), set(), set()

    def authorize(self, plan):
        self.writable = True
        self.localizations = {row["localization_id"] for row in plan["sets"]}
        self.sets = {row["set_id"] for row in plan["sets"] if row["set_id"]}
        self.old = {shot for row in plan["sets"] for shot in row["old_ids"]}

    def request(self, method, path, *, params=None, body=None):
        if not re.fullmatch(r"/v1/[A-Za-z0-9/_-]+", path):
            raise ValueError("API path is outside the fixed Apple API origin")
        if method != "GET":
            allowed = False
            if self.writable and method == "POST" and path == "/v1/appScreenshotSets":
                data = body["data"]
                allowed = (data["attributes"] == {"screenshotDisplayType": DISPLAY_TYPE}
                           and data["relationships"]["appStoreVersionLocalization"]["data"]["id"]
                           in self.localizations)
            elif self.writable and method == "POST" and path == "/v1/appScreenshots":
                allowed = body["data"]["relationships"]["appScreenshotSet"]["data"]["id"] in self.sets
            elif self.writable and self.deletion_enabled and method == "DELETE":
                allowed = path in {f"/v1/appScreenshots/{item}" for item in self.old}
            elif self.writable and method == "PATCH":
                allowed = path in {f"/v1/appScreenshots/{item}" for item in self.new}
                if path.endswith("/relationships/appScreenshots"):
                    allowed = (self.deletion_enabled and path.split("/")[-3] in self.sets
                               and all(item["id"] in self.new for item in body["data"]))
            if not allowed:
                raise ValueError("Mutation outside the authorized iPhone screenshot plan")
        response = self.session.request(method, legacy.API_BASE + path, params=params,
                                        json=body, timeout=90, allow_redirects=False)
        if not 200 <= response.status_code < 300:
            raise RuntimeError(f"Apple {method} {path}: HTTP {response.status_code}; inspect before retrying")
        result = response.json() if response.text else {}
        if method == "POST":
            identifier = result.get("data", {}).get("id")
            if identifier:
                (self.sets if path == "/v1/appScreenshotSets" else self.new).add(identifier)
        return result

    def paginate(self, path, *, params=None):
        pages, seen = [], set()
        while path:
            marker = (path, json.dumps(params, sort_keys=True))
            if marker in seen or len(pages) >= 200:
                raise ValueError("Invalid Apple pagination")
            seen.add(marker)
            page = self.request("GET", path, params=params)
            pages.append(page)
            link = page.get("links", {}).get("next")
            if not link:
                break
            parsed = urlparse(link)
            if (parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com"
                    or parsed.username or parsed.fragment):
                raise ValueError("Pagination cannot leave App Store Connect")
            path, params = parsed.path, dict(parse_qsl(parsed.query))
        return pages


def connect():
    return StrictAPI(legacy.build_jwt())


def validate_local_batch(root, project_root):
    sys.path.insert(0, str(project_root / "scripts/fastlane"))
    validator = importlib.import_module("run_repbuzz_promo_batch")
    return validator.validate_batch(root, project_root)


def local_inputs(root, manifest):
    if (manifest["app"] != APP or manifest["locales"] != LOCALES
            or manifest["screen_ids"] != SCREEN_IDS or manifest["status"] != "validated"):
        raise ValueError("Batch does not match the authorized app, locales and screens")
    inputs = legacy.discover_locale_files(root, DISPLAY_TYPE, 5)
    if len(inputs) != 15 or {item.source_locale_dir for item in inputs} != set(LOCALES):
        raise ValueError("Exactly fifteen distinct locale folders are required")
    for item in inputs:
        images = [image for image in manifest["images"] if image["locale"] == item.source_locale_dir]
        expected = {root / image["path"] for image in images}
        if (len(item.files) != 5 or len(images) != 5 or set(item.files) != expected
                or {image["screen_id"] for image in images} != set(SCREEN_IDS)
                or any(image["asc_locale"] != item.locale for image in images)):
            raise ValueError(f"Incomplete or ambiguous screen mapping: {item.source_locale_dir}")
        for image in images:
            path = (root / image["path"]).resolve()
            if not path.is_relative_to(root.resolve()) or sha256(path) != image["sha256"]:
                raise ValueError("An upload file changed after batch validation")
    visual = json.loads((root / "visual-validation.json").read_text())
    if (visual.get("run_id") != manifest["run_id"]
            or visual.get("batch_manifest_sha256") != sha256(root / "batch-manifest.json")
            or set(visual.get("reviewed_locales", [])) != set(LOCALES)
            or set(visual.get("checks", {})) != VISUAL_CHECKS
            or not all(value is True for value in visual["checks"].values())):
        raise ValueError("Complete visual validation bound to this batch is required")
    return {item.source_locale_dir: item for item in inputs}


def target(api):
    app_id = legacy.get_app_id(api, BUNDLE_ID)
    app = api.request("GET", f"/v1/apps/{app_id}")["data"]
    if app["attributes"].get("bundleId") != BUNDLE_ID:
        raise ValueError("Wrong Apple application")
    version_id = legacy.get_target_app_store_version_id(api, app_id, APP["version"])
    attributes = api.request("GET", f"/v1/appStoreVersions/{version_id}")["data"]["attributes"]
    if (attributes.get("versionString") != APP["version"] or attributes.get("platform") != "IOS"
            or attributes.get("appStoreState") not in EDITABLE):
        raise ValueError("The requested iOS version is not editable")
    build = api.request("GET", f"/v1/appStoreVersions/{version_id}/build").get("data")
    if not build or build.get("attributes", {}).get("version") != APP["build"]:
        raise ValueError("The selected App Store version is not linked to build 4")
    return {"app_id": app_id, "version_id": version_id, "build_id": build["id"],
            "state": attributes["appStoreState"]}


def preflight(api, root, manifest, inputs):
    destination = target(api)
    localizations = legacy.list_version_localizations(api, destination["version_id"])
    rows, problems = [], []
    for locale in LOCALES:
        item = inputs[locale]
        localization = localizations.get(item.locale)
        if not localization:
            problems.append(f"Missing Apple locale: {item.locale}")
            continue
        screenshot_set = legacy.list_screenshot_sets(api, localization["id"]).get(DISPLAY_TYPE)
        shots = legacy.list_screenshots(api, screenshot_set["id"]) if screenshot_set else []
        if len(shots) + 5 > 10:
            problems.append(f"Safe capacity exceeded for {item.locale}: {len(shots)} existing + 5 new")
        if any(s["attributes"].get("assetDeliveryState", {}).get("state") != "COMPLETE" for s in shots):
            problems.append(f"Existing assets are not fully processed for {item.locale}")
        rows.append({"locale": locale, "asc_locale": item.locale, "localization_id": localization["id"],
                     "set_id": screenshot_set["id"] if screenshot_set else None,
                     "old_ids": sorted(s["id"] for s in shots),
                     "files": [str(p.relative_to(root)) for p in item.files]})
    if problems:
        raise ValueError("; ".join(problems))
    return {"schema_version": 1, "run_id": manifest["run_id"], "destination": destination,
            "app": APP, "display_type": DISPLAY_TYPE,
            "batch_manifest_sha256": sha256(root / "batch-manifest.json"), "sets": rows}


def upload_chunks(file_path, operations):
    size, ranges = file_path.stat().st_size, []
    for operation in operations:
        parsed = urlparse(operation["url"])
        host = parsed.hostname or ""
        if (parsed.scheme != "https" or parsed.username or parsed.port not in (None, 443)
                or not any(host.endswith("." + suffix) or host == suffix
                           for suffix in ["apple.com", "mzstatic.com", "icloud.com"])
                or operation.get("method", "PUT").upper() not in {"PUT", "POST"}):
            raise ValueError("Unexpected upload operation destination or method")
        offset, length = int(operation.get("offset", 0)), int(operation.get("length", size))
        if offset < 0 or length <= 0 or offset + length > size:
            raise ValueError("Invalid upload slice")
        ranges.append((offset, offset + length))
    cursor = 0
    for start, end in sorted(ranges):
        if start != cursor:
            raise ValueError("Upload operations must cover the file exactly once")
        cursor = end
    if cursor != size:
        raise ValueError("Incomplete upload operations")
    with legacy.requests.Session() as session, file_path.open("rb") as stream:
        session.trust_env = False
        for operation, (start, end) in zip(operations, ranges):
            stream.seek(start)
            headers = {header["name"]: header["value"] for header in operation.get("requestHeaders", [])}
            response = session.request(operation.get("method", "PUT"), operation["url"],
                                       data=stream.read(end - start), headers=headers,
                                       timeout=120, allow_redirects=False)
            if not 200 <= response.status_code < 300:
                raise RuntimeError(f"Screenshot byte upload failed: HTTP {response.status_code}")


def apply_plan(api, root, plan, journal_path, wait_seconds):
    if journal_path.exists():
        raise ValueError("Journal already exists; inspect the previous outcome instead of replaying")
    journal = {"schema_version": 1, "run_id": plan["run_id"], "plan": plan,
               "phase": "preflight_verified", "events": [], "uploaded": [], "deleted": []}

    def step(operation, action, **evidence):
        event = dict(evidence, operation=operation, status="pending")
        journal["events"].append(event)
        save_json(journal_path, journal)
        result = action()
        event["status"] = "confirmed"
        if isinstance(result, dict) and "id" in result:
            event["id"] = result["id"]
        elif isinstance(result, str):
            event["id"] = result
        save_json(journal_path, journal)
        return result

    if isinstance(api, StrictAPI):
        api.authorize(plan)
    save_json(journal_path, journal)
    try:
        sets = []
        for row in plan["sets"]:
            set_id = row["set_id"] or step("create_set", lambda: legacy.create_screenshot_set(
                api, row["localization_id"], DISPLAY_TYPE), locale=row["locale"])
            new_ids = []
            for relative in row["files"]:
                path = root / relative
                seed = step("reserve", lambda: legacy.create_screenshot_upload(api, set_id, path),
                            locale=row["locale"], file=path.name, set_id=set_id)
                shot_id = seed["id"]
                step("upload_bytes", lambda: upload_chunks(path, seed["operations"]), id=shot_id)
                checksum = hashlib.md5(path.read_bytes()).hexdigest()
                step("commit", lambda: api.request("PATCH", f"/v1/appScreenshots/{shot_id}", body={
                    "data": {"type": "appScreenshots", "id": shot_id,
                             "attributes": {"uploaded": True, "sourceFileChecksum": checksum}}}), id=shot_id)
                journal["uploaded"].append({"id": shot_id, "locale": row["locale"],
                                             "file": path.name, "sourceFileChecksum": checksum})
                new_ids.append(shot_id)
            sets.append(dict(row, set_id=set_id, new_ids=new_ids))
        legacy.wait_until_processed(api, [s["id"] for s in journal["uploaded"]], wait_seconds)
        journal["phase"] = "all_75_processed"
        save_json(journal_path, journal)
        if target(api) != plan["destination"]:
            raise ValueError("Apple version/build state changed while uploading; old screenshots preserved")
        for row in sets:
            actual = {s["id"] for s in legacy.list_screenshots(api, row["set_id"])}
            if actual != set(row["old_ids"] + row["new_ids"]):
                raise ValueError("Screenshot membership changed; old screenshots preserved")
        if isinstance(api, StrictAPI):
            api.deletion_enabled = True
        for row in sets:
            for old_id in row["old_ids"]:
                step("delete_old", lambda: legacy.delete_screenshot(api, old_id), id=old_id)
                journal["deleted"].append(old_id)
            step("order", lambda: api.request(
                "PATCH", f"/v1/appScreenshotSets/{row['set_id']}/relationships/appScreenshots",
                body={"data": [{"type": "appScreenshots", "id": item} for item in row["new_ids"]]}),
                locale=row["locale"])
            shots = legacy.list_screenshots(api, row["set_id"])
            if {s["id"] for s in shots} != set(row["new_ids"]):
                raise ValueError("Final screenshot membership did not match the five uploaded images")
            order = api.request("GET", f"/v1/appScreenshotSets/{row['set_id']}/relationships/appScreenshots")
            if [s["id"] for s in order["data"]] != row["new_ids"]:
                raise ValueError("Apple screenshot order verification failed")
            for item in journal["uploaded"]:
                if item["locale"] == row["locale"]:
                    attrs = api.request("GET", f"/v1/appScreenshots/{item['id']}")["data"]["attributes"]
                    if (attrs.get("sourceFileChecksum") != item["sourceFileChecksum"]
                            or attrs.get("fileName") != item["file"]
                            or attrs.get("assetDeliveryState", {}).get("state") != "COMPLETE"):
                        raise ValueError("Uploaded filename/checksum/processing verification failed")
        journal["phase"] = "complete"
        save_json(journal_path, journal)
        return journal
    except BaseException as error:
        journal["phase"] = "blocked"
        journal["error"] = safe_error(error)
        save_json(journal_path, journal)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--batch-root", type=Path, required=True)
    parser.add_argument("--project-root", type=Path, default=REPO)
    parser.add_argument("--preflight-plan", type=Path, required=True)
    parser.add_argument("--journal", type=Path)
    parser.add_argument("--wait-seconds", type=int, default=600)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--scan-only", action="store_true", help="Validate all 75 locally; no credentials or network")
    mode.add_argument("--apply", action="store_true", help="Revalidate saved GET-only plan, then replace screenshot sets")
    args = parser.parse_args(argv)
    try:
        if args.wait_seconds <= 0:
            raise ValueError("A positive processing timeout is mandatory")
        root = args.batch_root.resolve()
        manifest = validate_local_batch(root, args.project_root.resolve())
        inputs = local_inputs(root, manifest)
        if args.scan_only:
            print(json.dumps({"status": "validated", "locales": LOCALES, "png_count": 75}))
            return 0
        if args.apply and (not args.journal or not args.preflight_plan.is_file()):
            raise ValueError("Apply requires a saved preflight plan and a new recovery journal")
        api = connect()
        plan = preflight(api, root, manifest, inputs)
        if not args.apply:
            if args.preflight_plan.exists():
                raise ValueError("Preflight plan already exists; use a new path")
            save_json(args.preflight_plan, plan)
            print(json.dumps({"status": "preflight_passed", "png_count": 75, "plan": str(args.preflight_plan)}))
        else:
            if json.loads(args.preflight_plan.read_text()) != plan:
                raise ValueError("Saved preflight no longer matches; no mutation performed")
            result = apply_plan(api, root, plan, args.journal, args.wait_seconds)
            print(json.dumps({"status": result["phase"], "uploaded": len(result["uploaded"]),
                              "deleted": len(result["deleted"]), "journal": str(args.journal)}))
        return 0
    except (Exception, SystemExit) as error:
        print(json.dumps({"status": "blocked", "error": safe_error(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
