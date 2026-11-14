"""Fail-closed contract tests; synthetic PNG headers are never capture inputs."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

MODULE = Path(__file__).with_name("capture_repbuzz_promos.py")
spec = importlib.util.spec_from_file_location("capture", MODULE)
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)


class CaptureContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = {
            "schema_version": 1, "run_id": capture.RUN_ID,
            "app": dict(capture.APP), "device": capture.DEVICE,
            "locales": list(capture.LOCALES), "screen_ids": list(capture.SCREENS),
            "source": {"files_sha256": {"GymTimerPro/test.swift": "a" * 64}},
            "run_started_at_utc": "2026-11-14T13:56:52Z", "status": "complete",
            "captures": [],
        }
        for locale in capture.LOCALES:
            for screen in capture.SCREENS:
                source = f"references/{capture.RUN_ID}/raw/{locale}/{screen}.png"
                path = self.root / source
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13)
                                 + b"IHDR" + struct.pack(">II", 1320, 2868))
                self.manifest["captures"].append({
                    "locale": locale, "screen_id": screen, "source": source,
                    "sha256": capture.sha256(path), "dimensions": [1320, 2868],
                    "captured_at_utc": "2026-11-14T14:00:00Z",
                    "language": locale, "apple_locale": capture.APPLE_LOCALES[locale],
                    "premium": True, "ui_proof": {"assertions": ["native UI assertion"]},
                })
                self.manifest["captures"][-1]["ui_proof"]["banner_absent"] = True

    def check_rejected(self, mutate, message):
        mutate(self.manifest)
        before = {str(p): p.read_bytes() for p in self.root.rglob("*.png")}
        with self.assertRaisesRegex(ValueError, message):
            capture.validate_manifest(self.manifest, self.root)
        self.assertEqual(before, {str(p): p.read_bytes() for p in self.root.rglob("*.png")})

    def test_exact_ordered_matrix(self):
        self.assertEqual(70, capture.validate_manifest(self.manifest, self.root))
        self.assertEqual(("en", "de", "fr", "it", "pt-BR", "pt-PT", "nl",
                          "sv", "da", "nb", "ja", "ko", "zh-Hans", "hi"), capture.LOCALES)
        self.assertEqual(("02_Timer", "11_RoutinesCatalog", "20_ProgressMonth",
                          "12_RoutineEditor", "05_TrainingCompleted"), capture.SCREENS)

    def test_wrong_locale(self):
        self.check_rejected(lambda m: m["captures"][0].update(language="es"), "language")

    def test_missing_file(self):
        self.manifest["captures"][0]["source"] += ".missing"
        with self.assertRaisesRegex(ValueError, "source"):
            capture.validate_manifest(self.manifest, self.root)

    def test_hash_mismatch(self):
        self.check_rejected(lambda m: m["captures"][0].update(sha256="0" * 64), "hash")

    def test_stale_version(self):
        self.check_rejected(lambda m: m["app"].update(version="1.3.0"), "app")

    def test_partial_matrix(self):
        self.check_rejected(lambda m: m["captures"].pop(), "matrix")

    def test_partial_status(self):
        self.check_rejected(lambda m: m.update(status="partial"), "partial")

    def test_stale_timestamp(self):
        self.check_rejected(lambda m: m["captures"][0].update(
            captured_at_utc="2026-11-13T00:00:00Z"), "stale")

    def test_duplicate(self):
        self.check_rejected(lambda m: m["captures"].__setitem__(
            0, copy.deepcopy(m["captures"][1])), "matrix")

    def test_absolute_source(self):
        self.check_rejected(lambda m: m["captures"][0].update(source="/tmp/old.png"), "source")

    def test_premium_required(self):
        self.check_rejected(lambda m: m["captures"][0].update(premium=False), "Premium")

    def test_ui_proof_required(self):
        self.check_rejected(lambda m: m["captures"][0].update(ui_proof={}), "proof")

    def test_existing_source_never_overwritten(self):
        path = self.root / "existing.png"
        path.write_bytes(b"previous")
        with self.assertRaises(FileExistsError):
            capture.write_new(path, b"replacement")
        self.assertEqual(b"previous", path.read_bytes())

    def test_fingerprint_excludes_capture_code(self):
        (self.root / "GymTimerPro").mkdir()
        (self.root / "GymTimerPro/app.swift").write_text("production")
        (self.root / "GymTimerPro/.DS_Store").write_text("ignore")
        self.assertEqual({"GymTimerPro/app.swift": hashlib.sha256(b"production").hexdigest()},
                         capture.production_fingerprints(self.root))

    def test_xcode_version_two_targets(self):
        target = {"TestBundlePath": "__TESTHOST__/tests", "EnvironmentVariables": {}}
        self.assertEqual([target], capture.test_targets({
            "TestConfigurations": [{"TestTargets": [target]}]}))

    def test_xcode_version_one_targets_preserved(self):
        target = {"TestBundlePath": "__TESTHOST__/tests"}
        self.assertEqual([target], capture.test_targets({"UITests": target}))

    def test_no_spanish_capture(self):
        self.assertNotIn("es", capture.LOCALES)
        self.assertEqual("repbuzz-remaining-20261114T145150Z", capture.RUN_ID)

    def test_install_replacement_cannot_leave_stale_store_path(self):
        old = "/simulator/data/Containers/Data/Application/OLD-UUID"
        environment = capture.capture_environment(old, "en")
        self.assertNotIn("PROMO_STORE_PATH", environment)
        self.assertEqual("/simulator/data/Containers/Data/Application",
                         environment["PROMO_APP_CONTAINERS_ROOT"])
        self.assertNotIn("OLD-UUID", json.dumps(environment))

    def test_current_store_resolution_is_fail_closed(self):
        source = (MODULE.parents[2] / "GymTimerProUITests/RepBuzzPromoCaptureTests.swift").read_text()
        self.assertIn("MCMMetadataIdentifier", source)
        self.assertIn('matches.count == 1', source)
        self.assertIn("fileExists(atPath: store.path)", source)
        self.assertNotIn('environment["PROMO_STORE_PATH"]', source)

    def test_tip_dismissal_is_after_timer_action_and_required(self):
        source = (MODULE.parents[2] / "GymTimerProUITests/RepBuzzPromoCaptureTests.swift").read_text()
        timer_section = source.split("let timer = launch", 1)[1].split("timer.terminate()", 1)[0]
        self.assertLess(timer_section.index('["startRestButton"].tap()'),
                        timer_section.index("closeTip(timer, required: true)"))
        self.assertIn("waitForNonExistence(timeout:", source)
        self.assertNotIn('guard tip.exists else { return }', source)

    def test_visible_banner_proof_is_rejected(self):
        self.check_rejected(lambda m: m["captures"][0]["ui_proof"].update(banner_absent=False),
                            "banner")

    def test_reviewed_english_pilot_required_to_continue(self):
        pilot = copy.deepcopy(self.manifest)
        pilot["captures"] = pilot["captures"][:5]
        pilot["status"] = "pilot_passed"
        capture.validate_pilot(pilot, self.root)
        pilot["captures"].pop()
        with self.assertRaisesRegex(ValueError, "pilot"):
            capture.validate_pilot(pilot, self.root)

    def test_native_launch_has_no_shared_snapshot_cache_or_hidden_title_query(self):
        source = (MODULE.parents[2] / "GymTimerProUITests/RepBuzzPromoCaptureTests.swift").read_text()
        self.assertNotIn("setupSnapshot(app)", source)
        self.assertNotIn('timer.staticTexts[chrome["config.total_sets.title"]!]', source)
        self.assertIn("app.launchArguments = [", source)


if __name__ == "__main__":
    unittest.main()
