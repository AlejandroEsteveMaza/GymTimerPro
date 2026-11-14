import copy
import importlib.util
import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("promo", Path(__file__).with_name("promo_frameit.py"))


class PromoTests(unittest.TestCase):
    def setUp(self):
        self.module = importlib.util.module_from_spec(SPEC)
        SPEC.loader.exec_module(self.module)
        self.root = Path(__file__).resolve().parents[2]
        self.config = json.loads((self.root / "fastlane/frameit/logic/repbuzz-es.json").read_text())

    def test_explicit_five_screen_mapping_and_exact_copy(self):
        expected = [
            ("02_Timer", "Controla tus descansos", "Sigue cada serie con un temporizador claro, rápido y fácil de usar"),
            ("11_RoutinesCatalog", "Organiza tus rutinas", "Crea, clasifica y encuentra tus entrenamientos en segundos"),
            ("20_ProgressMonth", "Visualiza tu progreso", "Consulta tu actividad y sigue tu evolución"),
            ("12_RoutineEditor", "Personaliza tus rutinas", "Adapta cada entrenamiento a tus objetivos"),
            ("05_TrainingCompleted", "Cada entrenamiento cuenta", "Completa tus sesiones y registra tu esfuerzo"),
        ]
        self.assertEqual([(s["id"], s["title"].replace("\n", " "), s["subtitle"].replace("\n", " "))
                          for s in self.config["screens"]], expected)

    def test_rejects_wrong_screen_alias_before_rendering(self):
        self.config["screens"][0]["source"] = self.config["screens"][1]["source"]
        with self.assertRaisesRegex(ValueError, "screen identifier"):
            self.module.validate(self.config, self.root, check_sources=False)

    def test_rejects_duplicate_or_non_spanish_selection(self):
        invalid = copy.deepcopy(self.config)
        invalid["screens"][1]["id"] = invalid["screens"][0]["id"]
        with self.assertRaises(ValueError):
            self.module.validate(invalid, self.root, check_sources=False)
        invalid = copy.deepcopy(self.config)
        invalid["locale"] = "en"
        with self.assertRaisesRegex(ValueError, "Spanish"):
            self.module.validate(invalid, self.root, check_sources=False)

    def test_missing_sources_and_existing_outputs_fail_closed(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises((ValueError, FileNotFoundError)):
                self.module.validate(self.config, Path(folder))
            with self.assertRaisesRegex(ValueError, "already exists"):
                self.module.render(self.config, self.root, Path(folder))

    def test_changed_source_rejected_through_public_cli(self):
        invalid = copy.deepcopy(self.config)
        invalid["screens"][0]["sha256"] = "0" * 64
        with tempfile.TemporaryDirectory() as folder:
            config = Path(folder) / "invalid.json"
            config.write_text(json.dumps(invalid))
            result = subprocess.run([sys.executable, "-B", str(SPEC.origin),
                                     "--design-config", str(config), "--check-only"],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertIn("Unverified or changed source: 02_Timer", result.stderr)
            self.assertEqual(list(Path(folder).iterdir()), [config])

    def test_frameit_partial_failure_exports_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            cache = home / ".fastlane/frameit/latest"
            cache.mkdir(parents=True)
            for name in ["Apple iPhone 14 Pro Max Black.png", "offsets.json", "version.txt"]:
                (cache / name).write_text("1")
            output = home / "results"
            with patch.object(self.module, "validate"), patch.object(Path, "home", return_value=home), \
                    patch.object(self.module.shutil, "which", return_value="present"), \
                    patch.object(self.module, "command"):
                with self.assertRaisesRegex(ValueError, "nothing exported"):
                    self.module.render(self.config, self.root, output)
            self.assertFalse(output.exists())

    def test_publication_copy_failure_exports_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            cache = home / ".fastlane/frameit/latest"
            cache.mkdir(parents=True)
            for name in ["Apple iPhone 14 Pro Max Black.png", "offsets.json", "version.txt"]:
                (cache / name).write_text("1")
            output = home / "results"
            def fake_command(*args, **kwargs):
                if args[0] == "fastlane":
                    for screen in self.config["screens"]:
                        (kwargs["cwd"] / (screen["id"] + "_framed.png")).write_text("frame")
                else:
                    Path(args[-1]).write_text("test image")
            with patch.object(self.module, "validate"), \
                    patch.object(Path, "home", return_value=home), \
                    patch.object(self.module.shutil, "which", return_value="present"), \
                    patch.object(self.module, "command", side_effect=fake_command), \
                    patch.object(self.module, "dimensions", return_value=[1290, 2796]), \
                    patch.object(self.module.shutil, "copytree", side_effect=OSError("copy failed")):
                with self.assertRaisesRegex(OSError, "copy failed"):
                    self.module.render(self.config, self.root, output)
            self.assertFalse(output.exists())
            self.assertFalse(list(home.glob(".repbuzz-publish-*")))
            # The same legacy entry point still publishes its five-screen
            # manifest and exact success message when composition succeeds.
            stdout = io.StringIO()
            with patch.object(self.module, "validate"), \
                    patch.object(Path, "home", return_value=home), \
                    patch.object(self.module.shutil, "which", return_value="present"), \
                    patch.object(self.module, "command", side_effect=fake_command), \
                    patch.object(self.module, "dimensions", return_value=[1290, 2796]), \
                    contextlib.redirect_stdout(stdout):
                self.module.render(self.config, self.root, output)
            self.assertEqual(stdout.getvalue(),
                             f"Created five verified Spanish screenshots: {output}\n")
            manifest = json.loads((output / "manifest.json").read_text())
            self.assertEqual(manifest["locale"], "es")
            self.assertEqual(len(manifest["screens"]), 5)
            self.assertTrue(all("typography" not in row for row in manifest["screens"]))


if __name__ == "__main__":
    unittest.main()
