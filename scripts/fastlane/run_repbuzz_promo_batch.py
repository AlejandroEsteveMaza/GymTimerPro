"""Combine 70 fresh localized promos with five unchanged approved Spanish PNGs. Offline only."""
import argparse
import contextlib
import copy
from datetime import datetime, timezone
import io
import json
from pathlib import Path
import re
import subprocess
import tempfile
import struct
import zlib

import promo_frameit as promo

LOCALES = ["en", "es", "de", "fr", "it", "pt-BR", "pt-PT", "nl", "sv",
           "da", "nb", "ja", "ko", "zh-Hans", "hi"]
PENDING_LOCALES = [locale for locale in LOCALES if locale != "es"]
SCREEN_IDS = ["02_Timer", "11_RoutinesCatalog", "20_ProgressMonth",
              "12_RoutineEditor", "05_TrainingCompleted"]
ASC = dict(zip(LOCALES, ["en-US", "es-ES", "de-DE", "fr-FR", "it", "pt-BR",
                        "pt-PT", "nl-NL", "sv", "da", "no", "ja", "ko", "zh-Hans", "hi"]))
NON_LATIN = {
    "ja": ("HiraginoSans-W6", "HiraginoSans-W3"),
    "ko": ("AppleSDGothicNeo-Bold", "AppleSDGothicNeo-Regular"),
    "zh-Hans": ("STHeitiSC-Medium", "STHeitiSC-Light"),
    "hi": ("KohinoorDevanagari-Semibold", "KohinoorDevanagari-Regular")
}
DESIGN = "fastlane/frameit/logic/repbuzz-es.json"
COPY = "fastlane/frameit/logic/repbuzz-locales.json"
APPROVED_ES = "fastlane/frameit/logic/approved-es.json"
APPROVED_ES_ROOT = "fastlane/frameit/results/repbuzz-es"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def approved_design(root):
    return read_json(root / DESIGN)


def contained(root, relative):
    path = Path(relative)
    if path.is_absolute() or ".." in path.parts:
        raise ValueError(f"Expected contained relative path: {relative}")
    resolved = (root / path).resolve()
    if root.resolve() not in resolved.parents:
        raise ValueError(f"Path escapes root: {relative}")
    return resolved


def load_copy(root):
    raw = read_json(root / COPY)
    if list(raw) != LOCALES:
        raise ValueError("Copy must contain the exact ordered locale matrix")
    result = {}
    for locale, pairs in raw.items():
        if len(pairs) != 5:
            raise ValueError(f"Five copy pairs required: {locale}")
        screens = []
        for screen_id, pair in zip(SCREEN_IDS, pairs):
            if len(pair) != 2 or any(not isinstance(t, str) or not t.strip()
                                     or "\ufffd" in t or "\x00" in t for t in pair):
                raise ValueError(f"Invalid UTF-8 copy: {locale}/{screen_id}")
            screens.append(dict(id=screen_id, title=pair[0], subtitle=pair[1]))
        result[locale] = screens
    expected = [{k: s[k] for k in ("id", "title", "subtitle")}
                for s in approved_design(root)["screens"]]
    if result["es"] != expected:
        raise ValueError("Approved Spanish copy must remain exact")
    return result


def validate_matrix(manifest, key):
    locales = PENDING_LOCALES if key == "captures" else LOCALES
    if manifest.get("locales") != locales or manifest.get("screen_ids") != SCREEN_IDS:
        raise ValueError("Exact ordered locales and screen IDs required")
    rows = manifest.get(key, [])
    expected = [(l, s) for l in locales for s in SCREEN_IDS]
    if [(r.get("locale"), r.get("screen_id")) for r in rows] != expected:
        raise ValueError(f"Exactly {len(expected)} ordered, distinct locale/screen mappings required: {key}")


def check_version(app, root):
    config = approved_design(root)
    expected = {"version": config["version"], "build": config["build"],
                "bundle_identifier": "alejandroestevemaza.GymTimerPro"}
    if app != expected:
        raise ValueError("Capture app version/build/bundle differs from approved current app")
    project = (root / "GymTimerPro.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    for key, value in [("MARKETING_VERSION", app["version"]),
                       ("CURRENT_PROJECT_VERSION", app["build"]),
                       ("PRODUCT_BUNDLE_IDENTIFIER", app["bundle_identifier"])]:
        values = set(re.findall(rf"(?<!\w){key}\s*=\s*([^;]+);", project))
        # Test targets may have suffixed bundle identifiers.
        if key == "PRODUCT_BUNDLE_IDENTIFIER":
            if value not in values:
                raise ValueError("Current bundle identifier changed")
        elif values != {value}:
            raise ValueError(f"Current app changed: {key}")


def png_info(path, size, final=False):
    if promo.dimensions(path) != size:
        raise ValueError(f"Wrong PNG dimensions: {path}")
    # Force full decode, not just header inspection. Treat decoder warnings as errors.
    result = subprocess.run(
        ["magick", "-regard-warnings", str(path), "-format",
         "%m|%w|%h|%[colorspace]|%[channels]|%z", "info:"],
        capture_output=True, text=True, check=True)
    fields = result.stdout.strip().split("|")
    if fields[:3] != ["PNG", str(size[0]), str(size[1])]:
        raise ValueError(f"Invalid PNG: {path}")
    header = path.read_bytes()[:26]
    if fields[3] != "sRGB" or header[24] != 8 or header[25] not in (2, 6):
        raise ValueError(f"PNG must decode as 8-bit RGB/RGBA in sRGB: {path}")
    if final and (fields[3] != "sRGB" or header[24:26] != bytes([8, 2])):
        raise ValueError(f"Final PNG must be opaque 8-bit RGB/sRGB: {path}")
    return fields


def validate_capture(path, root):
    manifest = read_json(path)
    validate_matrix(manifest, "captures")
    if manifest.get("schema_version") != 1:
        raise ValueError("Unknown capture schema")
    run_id = manifest.get("run_id", "")
    if not re.fullmatch(r"repbuzz-remaining-\d{8}T\d{6}Z", run_id):
        raise ValueError("Invalid current capture run ID")
    if manifest.get("capture_policy", "pending_locales_only") != "pending_locales_only":
        raise ValueError("Only pending_locales_only capture policy is enabled")
    expected_path = root / "references" / run_id / "capture-manifest.json"
    if path.resolve() != expected_path.resolve():
        raise ValueError("Capture manifest must belong to its declared run")
    check_version(manifest["app"], root)
    fingerprints = manifest.get("source", {}).get("files_sha256", {})
    if not fingerprints:
        raise ValueError("Current production fingerprints required")
    for filename, expected in fingerprints.items():
        if Path(filename).name == ".DS_Store":
            continue
        if not (filename.startswith(("GymTimerPro/", "GymTimerProWidget/", "Shared/")) or
                filename in ("GymTimerPro.xcodeproj/project.pbxproj",
                             "GymTimerProWidget-Info.plist") or
                re.fullmatch(r"GymTimerPro\.xcodeproj/xcshareddata/xcschemes/[^/]+\.xcscheme",
                             filename)):
            raise ValueError(f"Non-production fingerprint: {filename}")
        if promo.digest(contained(root, filename)) != expected:
            raise ValueError(f"App changed since capture: {filename}")
    for row in manifest["captures"]:
        locale, screen_id = row["locale"], row["screen_id"]
        expected = f"references/{run_id}/raw/{locale}/{screen_id}.png"
        if row.get("source") != expected or row.get("dimensions") != [1320, 2868]:
            raise ValueError(f"Wrong source mapping: {locale}/{screen_id}")
        source = contained(root, expected)
        if promo.digest(source) != row.get("sha256"):
            raise ValueError(f"Stale source hash: {locale}/{screen_id}")
        png_info(source, [1320, 2868])
        proof = row.get("ui_proof")
        if row.get("premium") is not True or not isinstance(proof, (dict, list)) or not proof:
            raise ValueError(f"Actual Premium UI proof required: {locale}/{screen_id}")
        if row.get("language") != locale or not row.get("apple_locale"):
            raise ValueError(f"Wrong UI language: {locale}/{screen_id}")
        captured = datetime.fromisoformat(row["captured_at_utc"].replace("Z", "+00:00"))
        if captured.utcoffset() is None or captured.utcoffset().total_seconds() != 0:
            raise ValueError("Capture timestamp must be UTC")
    return manifest


def approved_png_info(path):
    """Check the hash-locked PNG stream without sending Spanish pixels to ImageMagick."""
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Approved Spanish file is not PNG: {path}")
    offset, compressed, header, ended = 8, bytearray(), None, False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError("Truncated approved Spanish PNG")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        crc = data[offset + 8 + length:offset + 12 + length]
        if len(crc) != 4 or zlib.crc32(kind + payload) & 0xffffffff != struct.unpack(">I", crc)[0]:
            raise ValueError("Corrupt approved Spanish PNG chunk")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", payload)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            ended = True
        offset += 12 + length
    if not ended or header != (1290, 2796, 8, 2, 0, 0, 0):
        raise ValueError("Approved Spanish PNG must be non-interlaced 1290x2796 opaque 8-bit RGB")
    scanlines = zlib.decompress(compressed)
    stride = 1290 * 3 + 1
    if len(scanlines) != stride * 2796 or any(scanlines[y * stride] > 4 for y in range(2796)):
        raise ValueError("Invalid approved Spanish PNG scanlines")


def validate_approved_es(root, approved_root=None):
    """Validate immutable Spanish authority, original raws and current production proof."""
    lock = read_json(root / APPROVED_ES)
    expected_root = contained(root, APPROVED_ES_ROOT)
    if approved_root is not None and approved_root.resolve() != expected_root:
        raise ValueError("Only the locked approved Spanish root is accepted")
    if lock.get("schema_version") != 1 or lock.get("root") != APPROVED_ES_ROOT:
        raise ValueError("Unknown approved Spanish lock")
    config = approved_design(root)
    check_version(lock["app"], root)
    for path, expected in [
        (root / DESIGN, lock["design_sha256"]),
        (expected_root / "manifest.json", lock["manifest_sha256"]),
        (root / config["capture_provenance"], lock["provenance_sha256"])
    ]:
        if promo.digest(path) != expected:
            raise ValueError(f"Approved Spanish authority changed: {path.name}")
    original = read_json(expected_root / "manifest.json")
    if (original["version"], original["build"], original["locale"]) != (
            lock["app"]["version"], lock["app"]["build"], "es"):
        raise ValueError("Approved Spanish manifest app mismatch")
    if [s["id"] for s in lock["screens"]] != SCREEN_IDS or len(original["screens"]) != 5:
        raise ValueError("Approved Spanish lock requires all five ordered screens")
    snapshot = {}
    for index, (row, design, screen) in enumerate(
            zip(lock["screens"], config["screens"], original["screens"]), 1):
        filename = f"{index:02d}_{row['id']}.png"
        if (row["path"] != filename or row["source"] != design["source"] or
                row["source_sha256"] != design["sha256"] or
                screen != dict(design, output=filename, output_sha256=row["sha256"])):
            raise ValueError("Approved Spanish mapping or copy changed")
        final = contained(expected_root, filename)
        if promo.digest(final) != row["sha256"]:
            raise ValueError(f"Approved Spanish output hash changed: {filename}")
        approved_png_info(final)
        snapshot[f"{APPROVED_ES_ROOT}/{filename}"] = row["sha256"]
        snapshot[row["source"]] = row["source_sha256"]
    # Existing validation owns raw hashes, version and all production fingerprints.
    # It performs no framing or text/image rendering.
    promo.validate(config, root)
    snapshot[DESIGN] = lock["design_sha256"]
    snapshot[f"{APPROVED_ES_ROOT}/manifest.json"] = lock["manifest_sha256"]
    snapshot[config["capture_provenance"]] = lock["provenance_sha256"]
    return dict(lock, lock_sha256=promo.digest(root / APPROVED_ES),
                assets_sha256=snapshot)


def approved_typography(approved):
    # Approval is the typography authority for reused pixels, not a new raster.
    return {role: dict(engine="approved_reuse", authority_sha256=approved["manifest_sha256"],
                       design_sha256=approved["design_sha256"], re_rendered=False)
            for role in ("title", "subtitle")}


def compile_text_helper(root, work):
    binary = work / "localized-text"
    promo.command("swiftc", "-module-cache-path", work / "swift-cache",
                  root / "scripts/fastlane/render_localized_text.swift", "-o", binary)
    return binary


def text_requests(root, work, locales=None):
    requests, keys = [], []
    style = approved_design(root)["style"]
    for locale, screens in load_copy(root).items():
        if locale not in (PENDING_LOCALES if locales is None else locales):
            continue
        for screen in screens:
            for role, width, height in [("title", 1150, 280), ("subtitle", 1160, 150)]:
                font = (NON_LATIN[locale][0 if role == "title" else 1] if locale in NON_LATIN
                        else "Arial-BoldMT" if role == "title" else "ArialMT")
                output = work / f"{locale}-{screen['id']}-{role}.png"
                request = dict(text=screen[role], font=font, size=style[role + "_size"],
                               minimum=80 if role == "title" else 36,
                               width=width, height=height,
                               color="#FFFFFF" if role == "title" else style["subtitle_color"])
                if locale in NON_LATIN:
                    request["output"] = str(output)
                requests.append(request)
                keys.append((locale, screen["id"], role))
    return keys, requests


def typography_pilot(root, work, locales=None):
    keys, requests = text_requests(root, work, locales)
    request, response = work / "text-requests.json", work / "text-response.json"
    request.write_text(json.dumps(requests, ensure_ascii=False), encoding="utf-8")
    promo.command(compile_text_helper(root, work), request, response)
    proofs = {}
    for key, entry, metrics in zip(keys, requests, read_json(response)):
        if metrics["missing_glyphs"] or not metrics["fonts"] or not metrics["positioned_glyphs"]:
            raise ValueError(f"Incomplete font coverage/shaping: {key}")
        output = work / ("-".join(key) + ".png")
        if key[0] not in NON_LATIN:
            role = key[2]
            style = approved_design(root)["style"]
            font = str(root / style["display_font" if role == "title" else "body_font"])
            promo.label(entry["text"], font, entry["size"], entry["color"],
                        f"{entry['width']}x{entry['height']}", output)
            width, height = promo.dimensions(output)
            # ImageMagick label scales the full text proportionally, preserving
            # the exact approved Latin raster path.
            intrinsic = subprocess.run(
                ["magick", "-background", "none", "-font", font, "-pointsize",
                 str(entry["size"]), "-interline-spacing", "-6", "label:" + entry["text"],
                 "-format", "%w|%h", "info:"],
                check=True, capture_output=True, text=True).stdout
            original_w, original_h = map(int, intrinsic.split("|"))
            effective = entry["size"] * min(width / original_w, height / original_h)
            if effective < entry["minimum"]:
                raise ValueError(f"Unreadable Latin text: {key} ({effective:.1f}px)")
            metrics.update(engine="ImageMagick/Arial; CoreText coverage",
                           point_size=effective, raster_dimensions=[width, height])
        # Hash decoded RGBA, never encoder timestamp/metadata chunks.
        metrics["label_pixels_sha256"] = pixel_digest(output, alpha=True)
        metrics["label_path"] = str(output)
        proofs[key] = metrics
    if len(proofs) != len(PENDING_LOCALES if locales is None else locales) * 10:
        raise ValueError("All pending copy labels must pass typography validation")
    return proofs


def proof_payload(proof):
    return {k: v for k, v in proof.items() if k != "label_path"}


def batch_config(root, capture, locale):
    config = copy.deepcopy(approved_design(root))
    config["locale"] = locale
    rows = [r for r in capture["captures"] if r["locale"] == locale]
    config["screens"] = [
        dict(c, source=row["source"], sha256=row["sha256"])
        for c, row in zip(load_copy(root)[locale], rows)]
    return config


def render_locale(root, capture, locale, output, proofs):
    if locale == "es":
        raise ValueError("Approved Spanish must never be rendered or recomposed")
    config = batch_config(root, capture, locale)
    def render_text(text, font, size, color, bounds, target):
        role = "title" if bounds == "1150x280" else "subtitle"
        screen = next(s for s in config["screens"] if s[role] == text)
        proof = proofs[(locale, screen["id"], role)]
        promo.shutil.copyfile(proof["label_path"], target)
        return proof_payload(proof)
    with contextlib.redirect_stdout(io.StringIO()):
        promo.render(config, root, output,
                     source_validator=lambda c, r: None, text_renderer=render_text)


def generate(capture_path, output, root, approved_es_root=None):
    if output.exists():
        raise ValueError(f"Output already exists: {output}")
    capture = validate_capture(capture_path, root)
    approved = validate_approved_es(root, approved_es_root)
    if output.name != capture["run_id"]:
        raise ValueError("Results root must use the capture run ID")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".repbuzz-batch-", dir=output.parent) as folder:
        work = Path(folder)
        proofs = typography_pilot(root, work)
        staged = work / output.name
        staged.mkdir()
        images = []
        for locale in LOCALES:
            if locale == "es":
                (staged / "es").mkdir()
                for screen, entry in zip(load_copy(root)["es"], approved["screens"]):
                    relative = f"es/{entry['path']}"
                    source = f"{APPROVED_ES_ROOT}/{entry['path']}"
                    promo.shutil.copy2(contained(root, source), staged / relative)
                    images.append(dict(
                        locale="es", asc_locale=ASC["es"], screen_id=entry["id"],
                        path=relative, sha256=promo.digest(staged / relative),
                        dimensions=[1290, 2796], source=source, source_sha256=entry["sha256"],
                        copy={k: screen[k] for k in ("title", "subtitle")},
                        typography=approved_typography(approved), origin="approved_reuse"))
                continue
            config = batch_config(root, capture, locale)
            render_locale(root, capture, locale, staged / locale, proofs)
            for index, screen in enumerate(config["screens"], 1):
                relative = f"{locale}/{index:02d}_{screen['id']}.png"
                images.append(dict(
                    locale=locale, asc_locale=ASC[locale], screen_id=screen["id"],
                    origin="fresh_capture",
                    path=relative, sha256=promo.digest(staged / relative),
                    dimensions=[1290, 2796], source=screen["source"],
                    source_sha256=screen["sha256"],
                    copy={k: screen[k] for k in ("title", "subtitle")},
                    typography={role: proof_payload(proofs[(locale, screen["id"], role)])
                                for role in ("title", "subtitle")}))
        manifest = dict(schema_version=1, run_id=capture["run_id"], app=capture["app"],
                        locales=LOCALES, screen_ids=SCREEN_IDS,
                        capture_policy="pending_locales_only",
                        generated_count=70, reused_approved_count=5, approved_spanish=approved,
                        approved_design_sha256=promo.digest(root / DESIGN),
                        copy_sha256=promo.digest(root / COPY),
                        icon_sha256=promo.digest(root / approved_design(root)["icon"]),
                        capture_manifest=str(capture_path.resolve().relative_to(root.resolve())),
                        capture_manifest_sha256=promo.digest(capture_path),
                        design={k: approved_design(root)[k] for k in
                                ("canvas", "screen_size", "frame_device", "frame_color", "style")},
                        status="validated", validated_at_utc=datetime.now(timezone.utc).isoformat(),
                        images=images)
        (staged / "batch-manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
        validate_batch(staged, root)
        if validate_approved_es(root, approved_es_root) != approved:
            raise ValueError("Approved Spanish originals changed during generation")
        if output.exists():
            raise ValueError(f"Output already exists: {output}")
        staged.rename(output)
    return manifest


def validate_batch(output_root: Path, project_root: Path) -> dict:
    """Recompute local integrity and typography before any uploader may use a batch."""
    root = project_root.resolve()
    manifest = read_json(output_root / "batch-manifest.json")
    validate_matrix(manifest, "images")
    if manifest.get("schema_version") != 1 or manifest.get("status") != "validated":
        raise ValueError("Batch is not validated")
    if manifest["run_id"] != output_root.name:
        raise ValueError("Results directory does not belong to this run")
    capture_path = contained(root, manifest["capture_manifest"])
    capture = validate_capture(capture_path, root)
    approved = validate_approved_es(root)
    if (manifest.get("capture_policy") != "pending_locales_only" or
            manifest.get("generated_count") != 70 or manifest.get("reused_approved_count") != 5 or
            manifest.get("approved_spanish") != approved):
        raise ValueError("Mixed-origin batch approval/policy/counts changed")
    if capture["run_id"] != manifest["run_id"] or capture["app"] != manifest["app"]:
        raise ValueError("Batch/capture run or app mismatch")
    for field, path in [
        ("capture_manifest_sha256", capture_path),
        ("approved_design_sha256", root / DESIGN), ("copy_sha256", root / COPY),
        ("icon_sha256", root / approved_design(root)["icon"])
    ]:
        if manifest.get(field) != promo.digest(path):
            raise ValueError(f"Changed validation dependency: {field}")
    expected_design = {k: approved_design(root)[k] for k in
                       ("canvas", "screen_size", "frame_device", "frame_color", "style")}
    if manifest.get("design") != expected_design:
        raise ValueError("Approved geometry/style changed")
    expected_files = {r["path"] for r in manifest["images"]}
    if {str(p.relative_to(output_root)) for p in output_root.rglob("*.png")} != expected_files:
        raise ValueError("Missing, extra or old PNGs in batch")
    with tempfile.TemporaryDirectory(prefix="repbuzz-revalidate-") as folder:
        proofs = typography_pilot(root, Path(folder))
        sources = {(r["locale"], r["screen_id"]): r for r in capture["captures"]}
        for index, row in enumerate(manifest["images"]):
            locale, screen_id = row["locale"], row["screen_id"]
            expected_path = f"{locale}/{index % 5 + 1:02d}_{screen_id}.png"
            expected_copy = load_copy(root)[locale][index % 5]
            if row["path"] != expected_path or row["asc_locale"] != ASC[locale]:
                raise ValueError("Wrong output order, alias or ASC locale")
            if row["copy"] != {k: expected_copy[k] for k in ("title", "subtitle")}:
                raise ValueError("Localized copy changed")
            if row["dimensions"] != [1290, 2796]:
                raise ValueError("Wrong declared output dimensions")
            path = contained(output_root, row["path"])
            if promo.digest(path) != row["sha256"]:
                raise ValueError(f"Changed output hash: {row['path']}")
            if locale == "es":
                entry = approved["screens"][index % 5]
                expected_source = f"{APPROVED_ES_ROOT}/{entry['path']}"
                if (row.get("origin") != "approved_reuse" or row["source"] != expected_source or
                        row["source_sha256"] != entry["sha256"] or row["sha256"] != entry["sha256"] or
                        row["typography"] != approved_typography(approved)):
                    raise ValueError("Approved Spanish copy/provenance changed")
                approved_png_info(path)
                continue
            source = sources[(locale, screen_id)]
            if row.get("origin") != "fresh_capture":
                raise ValueError("Only Spanish may use approved reuse")
            if row["source"] != source["source"] or row["source_sha256"] != source["sha256"]:
                raise ValueError("Batch source proof changed")
            png_info(path, [1290, 2796], final=True)
            for role in ("title", "subtitle"):
                if row["typography"][role] != proof_payload(proofs[(locale, screen_id, role)]):
                    raise ValueError(f"Typography proof changed: {locale}/{screen_id}/{role}")
        # Do not trust a manifest's geometry claims or even its output hashes:
        # reproduce the approved composition from the verified current originals.
        # This also detects a self-consistent forged/edited manifest + PNG pair.
        for locale in PENDING_LOCALES:
            expected_root = Path(folder) / "recomposed" / locale
            render_locale(root, capture, locale, expected_root, proofs)
            for row in (r for r in manifest["images"] if r["locale"] == locale):
                expected = expected_root / Path(row["path"]).name
                if pixel_digest(expected) != pixel_digest(contained(output_root, row["path"])):
                    raise ValueError(f"Approved composition/source pixels differ: {row['path']}")
    # Check current sources again after lengthy decoding/recomposition.
    if read_json(capture_path) != capture:
        raise ValueError("Capture manifest changed during validation")
    validate_capture(capture_path, root)
    if validate_approved_es(root) != approved:
        raise ValueError("Approved Spanish originals changed during validation")
    return manifest


def pixel_digest(path, alpha=False):
    import hashlib
    result = subprocess.run(["magick", str(path), "-depth", "8",
                             "rgba:-" if alpha else "rgb:-"],
                            check=True, capture_output=True)
    return hashlib.sha256(result.stdout).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-manifest", type=Path, help="Fresh complete 70-capture pending-locale manifest")
    parser.add_argument("--approved-es-root", type=Path,
                        help="Locked Spanish finals root; defaults to fastlane/frameit/results/repbuzz-es")
    parser.add_argument("--results-root", type=Path, required=True,
                        help="New run-ID directory, or existing directory with --validate-only")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--validate-only", action="store_true",
                        help="Verify all 75; recompose only the 70 fresh images, never Spanish")
    parser.add_argument("--typography-only", action="store_true",
                        help="Create 140 pending-language copy labels, never Spanish or final screenshots")
    args = parser.parse_args()
    try:
        if args.validate_only and args.typography_only:
            raise ValueError("Select only one validation mode")
        if args.typography_only:
            if args.results_root.exists():
                raise ValueError("Typography output already exists")
            args.results_root.mkdir(parents=True)
            proofs = typography_pilot(args.project_root.resolve(), args.results_root.resolve())
            (args.results_root / "typography.json").write_text(json.dumps(
                {"|".join(k): proof_payload(v) for k, v in proofs.items()},
                ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"Validated 140 pending-language copy labels: {args.results_root}")
            return
        elif args.validate_only:
            validate_batch(args.results_root.resolve(), args.project_root.resolve())
        else:
            if not args.capture_manifest:
                raise ValueError("--capture-manifest is required for generation")
            generate(args.capture_manifest.resolve(), args.results_root.resolve(),
                     args.project_root.resolve(), args.approved_es_root)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(2, f"Batch validation failed: {error}\n")
    print(f"Validated 75 localized screenshots: {args.results_root}")


if __name__ == "__main__":
    main()
