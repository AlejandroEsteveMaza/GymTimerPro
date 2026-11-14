"""Offline contract tests; fixtures are synthetic and never delivery inputs."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import struct
import zlib

import run_repbuzz_promo_batch as batch


def png_bytes(width, height, color=0):
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data +
                struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff))
    scanline = b"\0" + bytes([color, color, color]) * width
    return (b"\x89PNG\r\n\x1a\n" +
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)) +
            chunk(b"IDAT", zlib.compress(scanline * height)) + chunk(b"IEND", b""))


class BatchTests(unittest.TestCase):
    def test_copy_matrix_and_spanish_preservation(self):
        root = Path(__file__).resolve().parents[2]
        copies = batch.load_copy(root)
        self.assertEqual(list(copies), batch.LOCALES)
        approved = batch.approved_design(root)
        for locale, screens in copies.items():
            self.assertEqual([s["id"] for s in screens], batch.SCREEN_IDS)
            self.assertTrue(all(s["title"] and s["subtitle"] for s in screens))
        self.assertEqual(copies["es"], [
            {k: s[k] for k in ("id", "title", "subtitle")}
            for s in approved["screens"]])

    def test_missing_duplicate_unknown_locale_and_alias_fail(self):
        manifest = {"locales": batch.PENDING_LOCALES, "screen_ids": batch.SCREEN_IDS,
                    "captures": [{"locale": l, "screen_id": s}
                                 for l in batch.PENDING_LOCALES for s in batch.SCREEN_IDS]}
        batch.validate_matrix(manifest, "captures")
        for mutation in ("missing", "duplicate", "unknown", "alias", "order"):
            bad = copy.deepcopy(manifest)
            if mutation == "missing":
                bad["captures"].pop()
            elif mutation == "duplicate":
                bad["captures"][-1] = bad["captures"][0]
            elif mutation == "unknown":
                bad["captures"][0]["locale"] = "en-US"
            elif mutation == "alias":
                bad["captures"][0]["screen_id"] = "01_TIMER"
            else:
                bad["locales"] = list(reversed(batch.PENDING_LOCALES))
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                batch.validate_matrix(bad, "captures")

    def test_public_cli_rejection_is_atomic(self):
        with tempfile.TemporaryDirectory(prefix="repbuzz-contract-") as folder:
            root = Path(folder)
            capture = root / "capture.json"
            capture.write_text('{"schema_version":1,"locales":[],"captures":[]}')
            output = root / "new"
            result = subprocess.run(
                [sys.executable, "-B", batch.__file__, "--capture-manifest",
                 str(capture), "--results-root", str(output)],
                capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
            self.assertTrue(result.stderr.startswith("Batch validation failed:"))
            self.assertFalse(output.exists())
            self.assertEqual(capture.read_text(),
                             '{"schema_version":1,"locales":[],"captures":[]}')

    def test_existing_output_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            marker = root / "marker"
            marker.write_text("preserve")
            with self.assertRaisesRegex(ValueError, "already exists"):
                batch.generate(Path("missing"), root, root)
            self.assertEqual(marker.read_text(), "preserve")

    def fixture(self, root):
        project = Path(__file__).resolve().parents[2]
        for filename in (batch.DESIGN, batch.COPY):
            path = root / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes((project / filename).read_bytes())
        project_file = root / "GymTimerPro.xcodeproj/project.pbxproj"
        project_file.parent.mkdir()
        project_file.write_text("MARKETING_VERSION = 1.3.1;\nCURRENT_PROJECT_VERSION = 4;\n"
                                "PRODUCT_BUNDLE_IDENTIFIER = alejandroestevemaza.GymTimerPro;\n")
        icon = root / batch.approved_design(root)["icon"]
        icon.parent.mkdir(parents=True)
        icon.write_bytes(png_bytes(16, 16))
        run_id = "repbuzz-remaining-20261114T145150Z"
        captures = []
        raw = png_bytes(1320, 2868)
        for locale in batch.PENDING_LOCALES:
            for screen in batch.SCREEN_IDS:
                source = f"references/{run_id}/raw/{locale}/{screen}.png"
                path = root / source
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(raw)
                captures.append(dict(
                    locale=locale, screen_id=screen, source=source,
                    sha256=batch.promo.digest(path), dimensions=[1320, 2868],
                    language=locale, apple_locale=locale, premium=True,
                    ui_proof={"fixture": "Synthetic test only"},
                    captured_at_utc="2026-11-14T15:00:00Z"))
        manifest = dict(
            schema_version=1, run_id=run_id, app=dict(version="1.3.1", build="4",
                bundle_identifier="alejandroestevemaza.GymTimerPro"),
            device="Synthetic test only", locales=batch.PENDING_LOCALES, screen_ids=batch.SCREEN_IDS,
            capture_policy="pending_locales_only", run_started_at_utc="2026-11-14T14:51:50Z",
            source={"files_sha256": {"GymTimerPro.xcodeproj/project.pbxproj":
                                     batch.promo.digest(project_file)}},
            captures=captures)
        path = root / f"references/{run_id}/capture-manifest.json"
        path.write_text(json.dumps(manifest), encoding="utf-8")
        # Isolated synthetic Spanish authority, never the real approved images.
        design = batch.approved_design(root)
        original_root = root / "fastlane/frameit/results/repbuzz-es"
        original_root.mkdir(parents=True)
        approved_screens = []
        for index, screen in enumerate(design["screens"], 1):
            source = root / screen["source"]
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(raw)
            screen["sha256"] = batch.promo.digest(source)
            filename = f"{index:02d}_{screen['id']}.png"
            final = original_root / filename
            final.write_bytes(png_bytes(1290, 2796, color=37))
            approved_screens.append(dict(screen, output=filename,
                                         output_sha256=batch.promo.digest(final)))
        (root / batch.DESIGN).write_text(json.dumps(design), encoding="utf-8")
        original_manifest = original_root / "manifest.json"
        original_manifest.write_text(json.dumps(dict(
            version="1.3.1", build="4", locale="es", screens=approved_screens)))
        provenance = root / design["capture_provenance"]
        provenance.parent.mkdir(parents=True, exist_ok=True)
        provenance.write_text(json.dumps({"source": manifest["source"]}))
        lock = dict(schema_version=1, root="fastlane/frameit/results/repbuzz-es",
                    app=manifest["app"], manifest_sha256=batch.promo.digest(original_manifest),
                    design_sha256=batch.promo.digest(root / batch.DESIGN),
                    provenance_sha256=batch.promo.digest(provenance),
                    screens=[dict(id=s["id"], path=s["output"], sha256=s["output_sha256"],
                                  source=s["source"], source_sha256=s["sha256"])
                             for s in approved_screens])
        (root / "fastlane/frameit/logic/approved-es.json").write_text(json.dumps(lock))
        return path, manifest

    def test_stale_source_version_ui_proof_and_fingerprint_rejection(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path, manifest = self.fixture(root)
            mutations = {
                "stale source": lambda m: m["captures"][0].update(sha256="0" * 64),
                "version": lambda m: m["app"].update(version="0.0"),
                "language": lambda m: m["captures"][0].update(language="es"),
                "premium": lambda m: m["captures"][0].update(premium=False),
                "UI proof": lambda m: m["captures"][0].update(ui_proof=[]),
                "fingerprint": lambda m: m["source"]["files_sha256"].update(
                    {"GymTimerPro.xcodeproj/project.pbxproj": "0" * 64}),
                "run": lambda m: m.update(run_id="repbuzz-remaining-20261114T000000Z"),
                "fresh Spanish": lambda m: m["captures"][0].update(locale="es"),
                "missing pending": lambda m: m["captures"].pop(),
                "wrong policy": lambda m: m.update(capture_policy="all_locales")
            }
            before = batch.promo.digest(root / manifest["captures"][0]["source"])
            for name, mutate in mutations.items():
                bad = copy.deepcopy(manifest)
                mutate(bad)
                path.write_text(json.dumps(bad))
                with self.subTest(name=name), patch.object(batch, "png_info"), \
                        self.assertRaises(ValueError):
                    batch.validate_capture(path, root)
                self.assertEqual(batch.promo.digest(root / manifest["captures"][0]["source"]),
                                 before)

    def test_capture_production_components_and_hashes(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path, manifest = self.fixture(root)
            components = [
                "GymTimerProWidget/GymTimerProWidget.swift",
                "Shared/L10n.swift",
                "Shared/en.lproj/Localizable.strings",
                "GymTimerPro.xcodeproj/xcshareddata/xcschemes/GymTimerPro.xcscheme",
                "GymTimerProWidget-Info.plist",
            ]
            for name in components:
                file = root / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text("production fixture")
                manifest["source"]["files_sha256"][name] = batch.promo.digest(file)
            path.write_text(json.dumps(manifest))
            with patch.object(batch, "png_info"):
                self.assertEqual(batch.validate_capture(path, root), manifest)
                for name in components:
                    bad = copy.deepcopy(manifest)
                    bad["source"]["files_sha256"][name] = "0" * 64
                    path.write_text(json.dumps(bad))
                    with self.subTest(changed=name), self.assertRaisesRegex(ValueError, "App changed"):
                        batch.validate_capture(path, root)
                bad = copy.deepcopy(manifest)
                bad["source"]["files_sha256"]["scripts/not-production.py"] = "0" * 64
                path.write_text(json.dumps(bad))
                with self.assertRaisesRegex(ValueError, "Non-production fingerprint"):
                    batch.validate_capture(path, root)

    def test_complete_contract_round_trip_and_tampered_style_pixels(self):
        """Mock composition only; actual decoding and the 75-entry validator run."""
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path, capture = self.fixture(root)
            output = root / "results" / capture["run_id"]
            originals = root / "fastlane/frameit/results/repbuzz-es"
            original_bytes = {p.name: p.read_bytes() for p in originals.iterdir()}
            final_png = png_bytes(1290, 2796)
            proofs = {(locale, screen, role): {"fonts": ["fixture"], "missing_glyphs": 0}
                      for locale in batch.PENDING_LOCALES for screen in batch.SCREEN_IDS
                      for role in ("title", "subtitle")}
            def fake_render(root, capture, locale, output, proofs):
                self.assertNotEqual(locale, "es", "Spanish must never be rendered or recomposed")
                output.mkdir(parents=True)
                for i, screen in enumerate(batch.SCREEN_IDS, 1):
                    (output / f"{i:02d}_{screen}.png").write_bytes(final_png)
            with patch.object(batch, "typography_pilot", return_value=proofs), \
                    patch.object(batch, "render_locale", side_effect=fake_render):
                result = batch.generate(path, output, root)
                self.assertEqual(result["status"], "validated")
                self.assertEqual(len(result["images"]), 75)
                self.assertEqual(result["generated_count"], 70)
                self.assertEqual(result["reused_approved_count"], 5)
                for original in originals.glob("*.png"):
                    self.assertEqual(original.read_bytes(), (output / "es" / original.name).read_bytes())
                self.assertEqual(batch.validate_batch(output, root), result)
                pristine = copy.deepcopy(result)
                for kind in ("reuse", "copy"):
                    bad = copy.deepcopy(pristine)
                    if kind == "reuse":
                        bad["images"][0]["origin"] = "approved_reuse"
                    else:
                        bad["images"][5]["copy"]["title"] = "Tampered Spanish"
                    (output / "batch-manifest.json").write_text(json.dumps(bad))
                    with self.subTest(kind=kind), self.assertRaises(ValueError):
                        batch.validate_batch(output, root)
                (output / "batch-manifest.json").write_text(json.dumps(result))
                spanish_copy = output / result["images"][5]["path"]
                unchanged_copy = spanish_copy.read_bytes()
                spanish_copy.write_bytes(png_bytes(1290, 2796, color=99))
                bad = copy.deepcopy(result)
                bad["images"][5]["sha256"] = batch.promo.digest(spanish_copy)
                (output / "batch-manifest.json").write_text(json.dumps(bad))
                with self.assertRaisesRegex(ValueError, "Approved Spanish"):
                    batch.validate_batch(output, root)
                spanish_copy.write_bytes(unchanged_copy)
                (output / "batch-manifest.json").write_text(json.dumps(result))
                target = output / result["images"][0]["path"]
                target.write_bytes(png_bytes(1290, 2796, color=17))
                result["images"][0]["sha256"] = batch.promo.digest(target)
                (output / "batch-manifest.json").write_text(json.dumps(result))
                with self.assertRaisesRegex(ValueError, "composition/source pixels differ"):
                    batch.validate_batch(output, root)
            self.assertEqual({p.name: p.read_bytes() for p in originals.iterdir()}, original_bytes)

    def test_pending_label_selection_and_unchanged_hindi_shaping(self):
        root = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory(prefix="repbuzz-font-test-") as folder:
            keys, requests = batch.text_requests(root, Path(folder))
            self.assertEqual(len(requests), 140)
            self.assertNotIn("es", {k[0] for k in keys})
            proofs = batch.typography_pilot(root, Path(folder), locales=["hi"])
            self.assertEqual(len(proofs), 10)
            for (locale, screen, role), proof in proofs.items():
                with self.subTest(locale=locale, screen=screen, role=role):
                    self.assertEqual(proof["missing_glyphs"], 0)
                    self.assertTrue(proof["fonts"])
                    self.assertTrue(proof["positioned_glyphs"])
                    self.assertGreaterEqual(proof["point_size"], 80 if role == "title" else 36)
                    dimensions = batch.promo.dimensions(Path(proof["label_path"]))
                    self.assertLessEqual(dimensions[0], 1150 if role == "title" else 1160)
                    self.assertLessEqual(dimensions[1], 280 if role == "title" else 150)
            hindi = proofs[("hi", "02_Timer", "title")]
            self.assertEqual(hindi["engine"], "CoreText")
            self.assertIn("KohinoorDevanagari-Semibold", hindi["fonts"])
            self.assertLess(hindi["glyph_count"], len(hindi["text"]))
            for locale, fonts in [("hi", batch.NON_LATIN["hi"])]:
                for role, font in zip(("title", "subtitle"), fonts):
                    self.assertIn(font, proofs[(locale, "02_Timer", role)]["fonts"])
            # Exercise the actual shaping helper's rejection path as well.
            request, response = Path(folder) / "overflow.json", Path(folder) / "overflow-response.json"
            text = "प्रगति" * 100
            request.write_text(json.dumps([dict(
                text=text, font="KohinoorDevanagari-Semibold", size=142, minimum=80,
                width=10, height=10, color="#FFFFFF")]))
            result = subprocess.run([str(Path(folder) / "localized-text"), str(request), str(response)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, f"Text cannot fit at readable minimum: {text}\n")
            self.assertFalse(response.exists())

    def test_spanish_approval_lock_and_bad_hash_rejection(self):
        root = Path(__file__).resolve().parents[2]
        # Verify the committed authority without requiring ignored local exports.
        lock = json.loads((root / "fastlane/frameit/logic/approved-es.json").read_text())
        self.assertEqual(len(lock["screens"]), 5)
        self.assertEqual(lock["screens"][0]["sha256"],
                         "29fdc70eb5f7b9ae91912038d7cd7160a2a94245f45cd7228c9bb531c5b3c52d")
        with tempfile.TemporaryDirectory() as folder:
            isolated = Path(folder)
            self.fixture(isolated)
            with patch.object(batch.subprocess, "run", side_effect=AssertionError(
                    "Spanish validation must not invoke external image tools")):
                approved = batch.validate_approved_es(isolated)
            self.assertEqual(len(approved["screens"]), 5)
            original = isolated / "fastlane/frameit/results/repbuzz-es/01_02_Timer.png"
            original.write_bytes(png_bytes(1290, 2796, color=99))
            before = original.read_bytes()
            with patch.object(batch, "render_locale") as render, self.assertRaisesRegex(
                    ValueError, "Approved Spanish"):
                batch.validate_approved_es(isolated)
            render.assert_not_called()
            self.assertEqual(original.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
