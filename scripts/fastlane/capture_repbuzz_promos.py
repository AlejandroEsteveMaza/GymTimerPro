#!/usr/bin/env python3
"""Capture native, localized simulator pixels without changing production sources."""
import argparse
import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import struct
import subprocess
import tempfile
import time

RUN_ID = "repbuzz-remaining-20261114T145150Z"
LOCALES = ("en", "de", "fr", "it", "pt-BR", "pt-PT", "nl",
           "sv", "da", "nb", "ja", "ko", "zh-Hans", "hi")
SCREENS = ("02_Timer", "11_RoutinesCatalog", "20_ProgressMonth",
           "12_RoutineEditor", "05_TrainingCompleted")
APPLE_LOCALES = dict(zip(LOCALES, ("en_US", "de_DE", "fr_FR", "it_IT",
    "pt_BR", "pt_PT", "nl_NL", "sv_SE", "da_DK", "nb_NO", "ja_JP", "ko_KR", "zh_CN", "hi_IN")))
APP = {"version": "1.3.1", "build": "4", "bundle_identifier": "alejandroestevemaza.GymTimerPro"}
DEVICE = {"name": "iPhone 17 Pro Max", "runtime": "iOS 26.2",
          "udid": "A52BEE18-A2DC-4642-8879-30632FC6B48E", "dimensions": [1320, 2868]}
PRODUCTION = ("GymTimerPro", "GymTimerProWidget", "Shared", "GymTimerPro.xcodeproj",
              "GymTimerProWidget-Info.plist")
MODEL_FILES = ("GymTimerPro/Routines/Routine.swift",
    "GymTimerPro/Routines/Classifications/RoutineClassification.swift",
    "GymTimerPro/Routines/RoutinesStore.swift",
    "GymTimerPro/Progress/Models/WorkoutCompletion.swift", "Shared/L10n.swift")


def utc():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def write_new(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(data)


def production_fingerprints(root):
    result = {}
    for name in PRODUCTION:
        base = Path(root) / name
        for path in sorted(base.rglob("*") if base.is_dir() else [base]):
            if not path.is_file() or path.name == ".DS_Store":
                continue
            if any(part in ("xcuserdata", "project.xcworkspace") for part in path.parts):
                continue
            result[path.relative_to(root).as_posix()] = sha256(path)
    return result


def png_dimensions(path):
    data = Path(path).read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"not PNG: {path}")
    return list(struct.unpack(">II", data[16:24]))


def validate_manifest(manifest, root, pilot=False):
    """No writes: reject incomplete, stale, misplaced or unverifiable originals."""
    if manifest.get("status") != ("pilot_passed" if pilot else "complete"):
        raise ValueError("partial capture manifest")
    if manifest.get("schema_version") != 1 or manifest.get("run_id") != RUN_ID:
        raise ValueError("schema/run mismatch")
    if manifest.get("app") != APP:
        raise ValueError("stale app version/build/bundle")
    if manifest.get("locales") != list(LOCALES) or manifest.get("screen_ids") != list(SCREENS):
        raise ValueError("locale/screen matrix mismatch")
    records = manifest.get("captures", [])
    expected = {(locale, screen) for locale in (("en",) if pilot else LOCALES) for screen in SCREENS}
    actual = [(r.get("locale"), r.get("screen_id")) for r in records]
    if len(actual) != len(expected) or set(actual) != expected:
        raise ValueError("incomplete or duplicate " + ("pilot" if pilot else "capture matrix"))
    if not manifest.get("source", {}).get("files_sha256"):
        raise ValueError("missing production source fingerprints")
    started = datetime.fromisoformat(manifest["run_started_at_utc"].replace("Z", "+00:00"))
    for record in records:
        locale, screen = record["locale"], record["screen_id"]
        expected_path = f"references/{RUN_ID}/raw/{locale}/{screen}.png"
        if record.get("source") != expected_path:
            raise ValueError("source path mismatch")
        path = Path(root) / expected_path
        if not path.is_file():
            raise ValueError(f"missing source: {expected_path}")
        if record.get("sha256") != sha256(path):
            raise ValueError(f"source hash mismatch: {expected_path}")
        if record.get("dimensions") != [1320, 2868] or png_dimensions(path) != [1320, 2868]:
            raise ValueError("source dimensions mismatch")
        if record.get("language") != locale or record.get("apple_locale") != APPLE_LOCALES[locale]:
            raise ValueError("capture language/locale mismatch")
        if record.get("premium") is not True:
            raise ValueError("Premium proof required")
        if not record.get("ui_proof"):
            raise ValueError("UI proof required")
        if record["ui_proof"].get("banner_absent") is not True:
            raise ValueError("capture banner absence must be asserted")
        when = datetime.fromisoformat(record["captured_at_utc"].replace("Z", "+00:00"))
        if when < started or when > datetime.now(timezone.utc):
            raise ValueError("stale/future capture timestamp")
    return len(records)


def validate_pilot(manifest, root):
    return validate_manifest(manifest, root, pilot=True)


def capture_environment(initial_data_container, locale):
    """Pass only the stable simulator root; XCTest selects current bundle metadata."""
    if locale not in LOCALES:
        raise ValueError("Spanish and unsupported locales are not pending capture targets")
    return {"PROMO_LOCALE": locale,
            "PROMO_APP_CONTAINERS_ROOT": str(Path(initial_data_container).parent)}


def run(command, cwd, log=None):
    print("+ " + " ".join(map(str, command)), flush=True)
    if log:
        with Path(log).open("xb") as output:
            result = subprocess.run(list(map(str, command)), cwd=cwd, stdout=output,
                                    stderr=subprocess.STDOUT)
        if result.returncode:
            tail = Path(log).read_text(errors="replace").splitlines()[-45:]
            raise RuntimeError(f"exit {result.returncode}; log={log}\n" + "\n".join(tail))
        return ""
    return subprocess.check_output(list(map(str, command)), cwd=cwd, text=True).strip()


def strings(root, locale):
    text = (root / f"Shared/{locale}.lproj/Localizable.strings").read_text()
    return {key: bytes(value, "utf-8").decode("utf-8").replace(r"\"", '"').replace(r"\n", "\n")
            for key, value in re.findall(r'"([^"]+)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', text)}


def prepare(root, scratch):
    source = scratch / "source"
    source.mkdir()
    for name in (*PRODUCTION, "GymTimerProUITests"):
        src, dst = root / name, source / name
        if src.is_dir():
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns(
                ".DS_Store", "xcuserdata", "project.xcworkspace"))
        else:
            shutil.copyfile(src, dst)
    tests = source / "GymTimerProUITests"
    for name in MODEL_FILES:
        shutil.copyfile(root / name, tests / Path(name).name)
    shutil.copyfile(root / "GymTimerPro/GymTimerPro.storekit", tests / "GymTimerPro.storekit")
    fixture_path = root / "scripts/fastlane/fixtures/promo_samples.json"
    fixture = json.loads(fixture_path.read_text())
    for locale in LOCALES:
        fixture["locales"][locale]["chrome"] = strings(root, locale)
        fixture["locales"][locale]["apple_locale"] = APPLE_LOCALES[locale]
    (tests / "promo-runtime.json").write_text(json.dumps(fixture, ensure_ascii=False))
    return source


def test_targets(config):
    """Read Xcode's observed v2 format, retaining the earlier v1 format."""
    if "TestConfigurations" in config:
        return [target for group in config["TestConfigurations"]
                for target in group.get("TestTargets", [])
                if "TestBundlePath" in target]
    return [value for value in config.values()
            if isinstance(value, dict) and "TestBundlePath" in value]


def code_fingerprints(root):
    return {p: sha256(root / p) for p in (
        "GymTimerProUITests/RepBuzzPromoCaptureTests.swift",
        "scripts/fastlane/capture_repbuzz_promos.py",
        "scripts/fastlane/fixtures/promo_samples.json")}


def capture_one(root, scratch, original_path, data, locale, label):
    original = plistlib.loads(original_path.read_bytes())
    targets = test_targets(original)
    if not targets:
        raise RuntimeError("unsupported xctestrun format (no target test specification)")
    for target in targets:
        target["TestLanguage"] = locale
        target["TestRegion"] = APPLE_LOCALES[locale].split("_")[-1]
        target.setdefault("EnvironmentVariables", {}).update(capture_environment(data, locale))
    configured = original_path.with_name(f"capture-{label}.xctestrun")
    write_new(configured, plistlib.dumps(original))
    result = scratch / f"{label}.xcresult"
    run(["xcodebuild", "test-without-building", "-xctestrun", configured,
         "-destination", f"platform=iOS Simulator,id={DEVICE['udid']}",
         "-only-testing:GymTimerProUITests/RepBuzzPromoCaptureTests/testCapturePromos",
         "-parallel-testing-enabled", "NO", "-resultBundlePath", result],
        scratch, scratch / f"{label}.log")
    attachments = scratch / f"{label}-attachments"
    run(["xcrun", "xcresulttool", "export", "attachments", "--path", result,
         "--output-path", attachments], scratch)
    exported = json.loads((attachments / "manifest.json").read_text())
    items = [item for test in exported for item in test.get("attachments", [])]
    records = []
    for screen in SCREENS:
        def find(suffix):
            matches = [i for i in items if i.get("suggestedHumanReadableName", "").startswith(screen + suffix)]
            if len(matches) != 1:
                raise RuntimeError(f"{locale}/{screen}: expected one {suffix} attachment; got {matches}")
            return attachments / matches[0]["exportedFileName"]
        png, proof_path = find("__native"), find("__proof")
        proof = json.loads(proof_path.read_text())
        if (proof["locale"] != locale or proof["screen_id"] != screen
                or proof.get("premium") is not True or proof.get("banner_absent") is not True):
            raise RuntimeError("native UI proof mismatch or visible banner")
        if png_dimensions(png) != [1320, 2868]:
            raise RuntimeError("native screenshot dimensions mismatch")
        relative = f"references/{RUN_ID}/raw/{locale}/{screen}.png"
        write_new(root / relative, png.read_bytes())
        records.append({
            "locale": locale, "screen_id": screen, "source": relative,
            "sha256": sha256(root / relative), "dimensions": [1320, 2868],
            "captured_at_utc": proof["captured_at_utc"], "language": locale,
            "apple_locale": APPLE_LOCALES[locale], "premium": True, "ui_proof": proof,
        })
    return records


def execute_capture(root, pilot=None):
    """Build and pause after English, or reuse that reviewed pilot for the other 13."""
    start_clock = time.monotonic()
    fingerprints = production_fingerprints(root)
    out = root / "references" / RUN_ID
    if pilot:
        report = json.loads(pilot.read_text())
        validate_pilot(report, root)
        if fingerprints != report["source"]["files_sha256"]:
            raise ValueError("production changed since English pilot")
        if code_fingerprints(root) != report["capture_code_sha256"]:
            raise ValueError("capture code changed since English pilot")
        scratch = Path(report["scratch"])
        if not scratch.name.startswith("repbuzz-capture-") or not scratch.is_dir():
            raise ValueError("English pilot scratch unavailable")
        if set((out / "raw").glob("*/*.png")) != {
                root / item["source"] for item in report["captures"]}:
            raise ValueError("Unexpected originals present; refusing to retry or overwrite")
        report["english_pilot_visually_reviewed"] = True
        report["status"] = "partial"
    elif out.exists() and any((out / "raw").glob("*/*.png")):
        raise FileExistsError("Existing originals preserved; use validation, not recapture.")
    else:
        scratch = Path(tempfile.mkdtemp(prefix="repbuzz-capture-"))
        report = {
            "schema_version": 1, "run_id": RUN_ID, "app": APP, "device": DEVICE,
            "locales": list(LOCALES), "screen_ids": list(SCREENS),
            "capture_policy": "pending_locales_only",
            "source": {"files_sha256": fingerprints}, "captures": [],
            "run_started_at_utc": utc(), "status": "partial", "scratch": str(scratch),
            "capture_code_sha256": code_fingerprints(root), "attempted_locales": [],
        }
    print(f"SCRATCH={scratch}", flush=True)
    try:
        source = scratch / "source" if pilot else prepare(root, scratch)
        if production_fingerprints(source) != fingerprints:
            raise RuntimeError("isolated production source copy differs")
        run(["xcrun", "simctl", "ui", DEVICE["udid"], "appearance", "light"], scratch)
        run(["xcrun", "simctl", "status_bar", DEVICE["udid"], "override", "--time", "9:41",
             "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
             "--batteryState", "charged", "--batteryLevel", "100"], scratch)
        if not pilot:
            base = ["xcodebuild", "-project", "source/GymTimerPro.xcodeproj", "-scheme", "GymTimerPro",
                    "-destination", f"platform=iOS Simulator,id={DEVICE['udid']}",
                    "-derivedDataPath", str(scratch / "DerivedData"), "-parallel-testing-enabled", "NO",
                    "CODE_SIGNING_ALLOWED=NO",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG REPBUZZ_CAPTURE"]
            run(base + ["build-for-testing"], scratch, scratch / "build.log")
        product = scratch / "DerivedData/Build/Products/Debug-iphonesimulator/GymTimerPro.app"
        info = plistlib.loads((product / "Info.plist").read_bytes())
        observed = {"version": info["CFBundleShortVersionString"],
                    "build": info["CFBundleVersion"], "bundle_identifier": info["CFBundleIdentifier"]}
        if observed != APP:
            raise RuntimeError(f"built app mismatch: {observed}")
        report["built_app"] = observed
        if not pilot:
            run(["xcrun", "simctl", "install", DEVICE["udid"], product], scratch)
        data = run(["xcrun", "simctl", "get_app_container", DEVICE["udid"],
                    APP["bundle_identifier"], "data"], scratch)
        originals = [path for path in (scratch / "DerivedData/Build/Products").glob("*.xctestrun")
                     if not path.name.startswith("capture-")]
        if len(originals) != 1:
            raise RuntimeError("Expected exactly one original xctestrun")
        if not pilot:
            report["attempted_locales"].append("en")
            report["captures"].extend(capture_one(root, scratch, originals[0], data, "en", "pilot-en"))
            report["status"] = "pilot_passed"
            validate_pilot(report, root)
            report["pending"] = "Visually inspect all five English originals before continuing."
        else:
            report.pop("pending", None)
            for locale in LOCALES[1:]:
                report["attempted_locales"].append(locale)
                report["captures"].extend(capture_one(root, scratch, originals[0], data, locale, locale))
            report["status"] = "complete"
            validate_manifest(report, root)
    except Exception as error:
        report["status"] = "partial"
        report["failure"] = str(error)
        print(str(error), flush=True)
    finally:
        report["production_byte_identity_verified"] = production_fingerprints(root) == fingerprints
        if not report["production_byte_identity_verified"]:
            report["status"] = "partial"
            report["failure"] = "production fingerprints changed during execution"
        report["elapsed_seconds"] = round(report.get("elapsed_seconds", 0) + time.monotonic() - start_clock, 2)
        report["finished_at_utc"] = utc()
        report["successful_locales"] = [locale for locale in LOCALES if sum(
            item["locale"] == locale for item in report["captures"]) == 5]
        report["failed_or_pending_locales"] = [locale for locale in LOCALES
                                               if locale not in report["successful_locales"]]
        report["failed_locales"] = [locale for locale in report["attempted_locales"]
                                    if locale not in report["successful_locales"]]
        report["not_attempted_locales"] = [locale for locale in LOCALES
                                           if locale not in report["attempted_locales"]]
        name = {"complete": "capture-manifest.json", "pilot_passed": "pilot-en.json"}.get(
            report["status"], "capture-partial-report.json")
        # Reports are append-only too; an earlier failed attempt remains evidence.
        path = out / name
        if path.exists():
            path = out / f"capture-partial-{datetime.now(timezone.utc).strftime('%H%M%S')}.json"
        write_new(path, (json.dumps(report, ensure_ascii=False, indent=2) + "\n").encode())
        print(f"REPORT={path}\nSTATUS={report['status']} PNG_COUNT={len(report['captures'])}", flush=True)
    return 0 if report["status"] in ("complete", "pilot_passed") else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--execute", action="store_true", help="Build once and capture five English originals, then pause for inspection")
    parser.add_argument("--pilot-only", action="store_true", help="Explicit English-only pilot (also the default with --execute)")
    parser.add_argument("--continue-from-pilot", type=Path, help="Reuse the current English pilot/build and capture the other 13 pending locales")
    parser.add_argument("--confirm-pilot-reviewed", action="store_true", help="Confirm all five English originals passed visual inspection")
    parser.add_argument("--validate", type=Path, help="Validate an existing complete manifest without changing files")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.validate:
        print(f"Validated {validate_manifest(json.loads(args.validate.read_text()), root)} native originals")
        return 0
    if args.execute:
        return execute_capture(root)
    if args.continue_from_pilot:
        if not args.confirm_pilot_reviewed:
            parser.error("--continue-from-pilot requires --confirm-pilot-reviewed")
        return execute_capture(root, args.continue_from_pilot)
    parser.error("select --execute, --continue-from-pilot or --validate")


if __name__ == "__main__":
    raise SystemExit(main())
