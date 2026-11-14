"""Regression probes returned by the independent offline verifier."""
import json
import unittest

import test_upload_promotional_batch as fixtures


class IndependentSafetyTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.BatchUploadTests()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)

    def test_every_asset_is_read_before_first_old_delete(self):
        fixture = self.fixture
        self.assertEqual(fixture.invoke()[0], 0)
        original = fixture.api.request
        processed = set()

        def request(method, path, **kwargs):
            if method == "GET" and path.startswith("/v1/appScreenshots/new-"):
                processed.add(path)
            if method == "DELETE":
                self.assertEqual(len(processed), 75)
            return original(method, path, **kwargs)

        fixture.api.request = request
        self.assertEqual(fixture.invoke("--apply")[0], 0)
        journal = json.loads(fixture.journal.read_text())
        self.assertEqual(journal["phase"], "complete")
        self.assertEqual(len(journal["deleted"]), 15)

    def test_uncertain_late_reservation_remains_pending(self):
        fixture = self.fixture
        self.assertEqual(fixture.invoke()[0], 0)
        fixture.api.fail_reservation = 74
        self.assertEqual(fixture.invoke("--apply")[0], 1)
        journal = json.loads(fixture.journal.read_text())
        self.assertEqual(journal["phase"], "blocked")
        self.assertEqual(len(journal["uploaded"]), 73)
        self.assertEqual(journal["deleted"], [])
        self.assertEqual(journal["events"][-1]["operation"], "reserve")
        self.assertEqual(journal["events"][-1]["status"], "pending")
        self.assertFalse(any(method == "DELETE" for method, _ in fixture.api.calls))


if __name__ == "__main__":
    unittest.main()
