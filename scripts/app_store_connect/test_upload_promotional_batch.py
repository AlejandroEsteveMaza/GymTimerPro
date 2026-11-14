"""Offline tests: every Apple request is handled by FakeAPI."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import upload_promotional_batch as batch


class FakeAPI:
    def __init__(self):
        self.calls = []
        self.old_count = 1
        self.build = "4"
        self.state = "PREPARE_FOR_SUBMISSION"
        self.missing_locale = None
        self.fail_reservation = None
        self.serial = 0
        self.shots = {}
        self.order = {}

    def paginate(self, path, *, params=None):
        return [self.request("GET", path, params=params)]

    def request(self, method, path, *, params=None, body=None):
        self.calls.append((method, path))
        if method == "GET":
            if path == "/v1/apps":
                return {"data": [{"id": "app"}]}
            if path == "/v1/apps/app":
                return {"data": {"id": "app", "attributes": {"bundleId": batch.BUNDLE_ID}}}
            if path.endswith("/appStoreVersions"):
                return {"data": [{"id": "version", "attributes": {
                    "platform": "IOS", "versionString": "1.3.1", "appStoreState": self.state}}]}
            if path == "/v1/appStoreVersions/version":
                return {"data": {"id": "version", "attributes": {
                    "platform": "IOS", "versionString": "1.3.1", "appStoreState": self.state}}}
            if path.endswith("/build"):
                return {"data": {"id": "build", "attributes": {"version": self.build}}}
            if path.endswith("/appStoreVersionLocalizations"):
                return {"data": [{"id": "loc-" + locale, "attributes": {"locale": locale}}
                                 for locale in batch.ASC_LOCALES if locale != self.missing_locale]}
            if path.endswith("/appScreenshotSets"):
                locale = path.split("/")[-2].removeprefix("loc-")
                return {"data": [{"id": "set-" + locale,
                                  "attributes": {"screenshotDisplayType": batch.DISPLAY_TYPE}}]}
            if path.endswith("/relationships/appScreenshots"):
                set_id = path.split("/")[-3]
                return {"data": [{"type": "appScreenshots", "id": s} for s in self.order[set_id]]}
            if path.endswith("/appScreenshots"):
                set_id = path.split("/")[-2]
                if set_id not in self.shots:
                    self.shots[set_id] = [{
                        "id": f"{set_id}-old-{n}", "attributes": {
                            "fileName": f"old-{n}.png", "assetDeliveryState": {"state": "COMPLETE"}}}
                        for n in range(self.old_count)]
                    self.order[set_id] = [s["id"] for s in self.shots[set_id]]
                return {"data": list(self.shots[set_id])}
            if path.startswith("/v1/appScreenshots/"):
                shot_id = path.rsplit("/", 1)[1]
                return {"data": next(s for shots in self.shots.values() for s in shots if s["id"] == shot_id)}
        if method == "POST" and path == "/v1/appScreenshots":
            self.serial += 1
            if self.serial == self.fail_reservation:
                raise RuntimeError("Simulated uncertain reservation outcome")
            shot_id = f"new-{self.serial}"
            data = body["data"]
            set_id = data["relationships"]["appScreenshotSet"]["data"]["id"]
            shot = {"id": shot_id, "attributes": dict(data["attributes"],
                    assetDeliveryState={"state": "AWAITING_UPLOAD"})}
            self.shots[set_id].append(shot)
            self.order[set_id].append(shot_id)
            return {"data": {"id": shot_id, "attributes": {"uploadOperations": [{"fake": True}]}}}
        if method == "PATCH" and path.endswith("/relationships/appScreenshots"):
            self.order[path.split("/")[-3]] = [s["id"] for s in body["data"]]
            return {}
        if method == "PATCH":
            shot_id = path.rsplit("/", 1)[1]
            shot = next(s for shots in self.shots.values() for s in shots if s["id"] == shot_id)
            shot["attributes"].update(body["data"]["attributes"])
            shot["attributes"]["assetDeliveryState"] = {"state": "COMPLETE"}
            return {}
        if method == "DELETE":
            shot_id = path.rsplit("/", 1)[1]
            if self.serial != 75:
                raise AssertionError("Old screenshots deleted before all 75 uploads")
            for set_id, shots in self.shots.items():
                self.shots[set_id] = [s for s in shots if s["id"] != shot_id]
                self.order[set_id] = [s for s in self.order[set_id] if s != shot_id]
            return {}
        raise AssertionError((method, path))


class BatchUploadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.plan = self.root / "preflight.json"
        self.journal = self.root / "journal.json"
        self.api = FakeAPI()
        self.manifest = {"schema_version": 1, "status": "validated", "run_id": "current-run",
                         "app": {"version": "1.3.1", "build": "4", "bundle_identifier": batch.BUNDLE_ID},
                         "locales": batch.LOCALES, "screen_ids": batch.SCREEN_IDS, "images": []}
        for locale in batch.LOCALES:
            (self.root / locale).mkdir()
            for index, screen in enumerate(batch.SCREEN_IDS, 1):
                path = Path(locale) / f"{index:02d}_{screen}.png"
                (self.root / path).write_bytes(b"offline image bytes")
                self.manifest["images"].append({"locale": locale, "asc_locale": batch.legacy.normalize_locale(locale),
                    "screen_id": screen, "path": str(path), "sha256": batch.sha256(self.root / path)})
        (self.root / "batch-manifest.json").write_text(json.dumps(self.manifest))
        (self.root / "visual-validation.json").write_text(json.dumps({
            "run_id": "current-run", "reviewed_locales": batch.LOCALES,
            "batch_manifest_sha256": batch.sha256(self.root / "batch-manifest.json"),
            "checks": {name: True for name in batch.VISUAL_CHECKS}}))

    def invoke(self, *extra):
        output = io.StringIO()
        with patch.object(batch, "validate_local_batch", return_value=self.manifest), \
                patch.object(batch, "connect", return_value=self.api) as connection, \
                patch.object(batch, "upload_chunks"), contextlib.redirect_stdout(output):
            code = batch.main(["--batch-root", str(self.root), "--preflight-plan", str(self.plan),
                               "--journal", str(self.journal), *extra])
            self.connection_count = connection.call_count
        return code, output.getvalue()

    def test_scan_is_offline_and_reports_exact_75(self):
        code, output = self.invoke("--scan-only")
        self.assertEqual(code, 0, output)
        self.assertEqual(self.connection_count, 0)
        self.assertEqual(self.api.calls, [])
        self.assertIn("75", output)

    def test_preflight_get_only_all_locales_and_build(self):
        code, output = self.invoke()
        self.assertEqual(code, 0, output)
        self.assertTrue(self.plan.exists())
        self.assertTrue(all(method == "GET" for method, _ in self.api.calls))
        self.assertEqual(len(json.loads(self.plan.read_text())["sets"]), 15)

    def test_missing_locale_capacity_wrong_build_or_locked_version_never_mutates(self):
        for field, value in [("missing_locale", "ja"), ("old_count", 6),
                             ("build", "5"), ("state", "WAITING_FOR_REVIEW")]:
            with self.subTest(field=field):
                self.api = FakeAPI()
                setattr(self.api, field, value)
                code, output = self.invoke()
                self.assertNotEqual(code, 0, output)
                self.assertTrue(all(method == "GET" for method, _ in self.api.calls))
                self.assertFalse(self.plan.exists())

    def test_uncertain_reservation_preserves_every_old_image_and_records_progress(self):
        self.assertEqual(self.invoke()[0], 0)
        self.api.fail_reservation = 3
        code, output = self.invoke("--apply")
        self.assertNotEqual(code, 0, output)
        self.assertFalse(any(method == "DELETE" for method, _ in self.api.calls))
        self.assertEqual(json.loads(self.journal.read_text())["phase"], "blocked")
        self.assertEqual(self.api.serial, 3)

    def test_complete_batch_processed_before_deletion_and_final_order_verified(self):
        self.assertEqual(self.invoke()[0], 0)
        code, output = self.invoke("--apply")
        self.assertEqual(code, 0, output)
        journal = json.loads(self.journal.read_text())
        self.assertEqual(journal["phase"], "complete")
        self.assertEqual(len(journal["uploaded"]), 75)
        self.assertEqual(len(journal["deleted"]), 15)
        self.assertTrue(all(len(shots) == 5 for shots in self.api.shots.values()))

    def test_changed_plan_or_zero_wait_never_mutates(self):
        self.assertEqual(self.invoke()[0], 0)
        self.api.build = "5"
        self.assertNotEqual(self.invoke("--apply")[0], 0)
        self.assertFalse(any(method != "GET" for method, _ in self.api.calls))
        self.assertNotEqual(self.invoke("--apply", "--wait-seconds", "0")[0], 0)

    def test_changed_image_or_failed_visual_check_stops_before_credentials(self):
        first = self.root / self.manifest["images"][0]["path"]
        first.write_bytes(b"changed")
        self.assertNotEqual(self.invoke()[0], 0)
        self.assertEqual(self.connection_count, 0)

    def test_processing_failure_preserves_every_old_image(self):
        self.assertEqual(self.invoke()[0], 0)
        with patch.object(batch.legacy, "wait_until_processed", side_effect=RuntimeError("Processing failed")):
            code, output = self.invoke("--apply")
        self.assertNotEqual(code, 0, output)
        self.assertEqual(self.api.serial, 75)
        self.assertFalse(any(method == "DELETE" for method, _ in self.api.calls))


class TransportTests(unittest.TestCase):
    def test_write_scope_and_deletion_phase_are_enforced(self):
        api = batch.StrictAPI("offline-test-token")
        plan = {"sets": [{"localization_id": "locale", "set_id": "set", "old_ids": ["old"]}]}
        with patch.object(api.session, "request", side_effect=AssertionError("Network forbidden")):
            with self.assertRaises(ValueError):
                api.request("POST", "/v1/appScreenshots", body={})
            api.authorize(plan)
            with self.assertRaises(ValueError):
                api.request("DELETE", "/v1/appScreenshots/old")
            api.deletion_enabled = True
            with self.assertRaises(ValueError):
                api.request("DELETE", "/v1/appScreenshots/unrelated")
            with self.assertRaises(ValueError):
                api.request("GET", "//untrusted.example")
        self.assertFalse(api.session.trust_env)

    def test_mutations_are_not_retried_and_pagination_cannot_leak_credentials(self):
        api = batch.StrictAPI("offline-test-token")
        api.authorize({"sets": [{"localization_id": "locale", "set_id": "set", "old_ids": []}]})
        with patch.object(api.session, "request") as request:
            request.return_value.status_code = 503
            with self.assertRaises(RuntimeError):
                api.request("POST", "/v1/appScreenshots", body={"data": {
                    "relationships": {"appScreenshotSet": {"data": {"id": "set"}}}}})
            self.assertEqual(request.call_count, 1)
            self.assertFalse(request.call_args.kwargs["allow_redirects"])
            request.reset_mock()
            request.return_value.status_code = 200
            request.return_value.text = "json"
            request.return_value.json.return_value = {"data": [], "links": {"next": "https://untrusted.example/next"}}
            with self.assertRaises(ValueError):
                api.paginate("/v1/apps")
            self.assertEqual(request.call_count, 1)

    def test_upload_destinations_rejected_before_sending_bytes(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "test.png"
            path.write_bytes(b"test")
            with patch.object(batch.legacy.requests, "Session", side_effect=AssertionError("Network forbidden")):
                with self.assertRaises(ValueError):
                    batch.upload_chunks(path, [{"url": "https://untrusted.example/upload", "offset": 0, "length": 4}])
        self.assertNotIn("secret", batch.safe_error(RuntimeError("https://example.test/?secret=1 Bearer secret")))


if __name__ == "__main__":
    unittest.main()
