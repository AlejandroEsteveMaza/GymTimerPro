"""Offline public-CLI tests. No credentials or Apple account requests."""

import contextlib
import copy
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import rebrand_subscription_localizations as tool


def resource(identifier, **attributes):
    return {"id": identifier, "attributes": attributes}


class FakeAPI:
    def __init__(self, project):
        self.calls = []
        self.writes = []
        self.tables = {
            "/v1/apps?filter%5BbundleId%5D=" + tool.BUNDLE_ID: [resource("app")],
            "/v1/apps/app/relationships/subscriptionGroups": [resource("group")],
            "/v1/subscriptionGroups/group/subscriptions": [],
        }
        for index, product in enumerate(tool.PRODUCTS):
            sid, vid = "sub" + str(index), "version" + str(index)
            self.tables["/v1/subscriptionGroups/group/subscriptions"].append(
                resource(sid, productId=product, subscriptionPeriod="ONE_MONTH", groupLevel=1)
            )
            self.tables[f"/v1/subscriptions/{sid}/versions"] = [
                resource(vid, state="PREPARE_FOR_SUBMISSION", version=1)
            ]
            self.tables[f"/v1/subscriptionVersions/{vid}/localizations"] = [
                resource(f"loc{index}_{locale}", locale=locale, **texts)
                for locale, texts in project[product].items()
            ]

    def all(self, path):
        self.calls.append(("GET", path))
        return copy.deepcopy(self.tables[path])

    def request(self, method, path, body=None):
        self.calls.append((method, path))
        if method == "GET":
            identifier = path.rsplit("/", 1)[-1]
            return {"data": copy.deepcopy(next(
                r for rows in self.tables.values() for r in rows if r["id"] == identifier
            ))}
        identifier = path.rsplit("/", 1)[-1]
        self.writes.append(copy.deepcopy(body))
        for rows in self.tables.values():
            for row in rows:
                if row["id"] == identifier:
                    row["attributes"].update(body["data"]["attributes"])
                    return {"data": copy.deepcopy(row)}
        raise AssertionError(path)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.project = json.loads(tool.DEFAULT_TRANSLATIONS.read_text())
        self.translations = self.root / "translations.json"
        self.translations.write_text(json.dumps(self.project))
        self.plan = self.root / "plan.json"
        self.api = FakeAPI(self.project)
        self.options = ["--translations", str(self.translations)]

    def invoke(self, *options):
        output, error = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(error):
            code = tool.main(self.options + list(options), api_factory=lambda **kw: self.api)
        return code, output.getvalue(), error.getvalue()

    def save_plan(self):
        self.assertEqual(self.invoke("--plan-output", str(self.plan))[0], 0)
        return tool.digest(json.loads(self.plan.read_text()))

    def test_default_preview_covers_both_products_and_all_locales(self):
        code, output, error = self.invoke()
        self.assertEqual((code, error), (0, ""))
        self.assertIn("DRY RUN", output)
        for product in tool.PRODUCTS:
            self.assertIn(product, output)
            self.assertEqual(len(self.project[product]), 15)
        for locale in self.project[tool.PRODUCTS[0]]:
            self.assertIn(locale, output)
        self.assertIn("GymTimer Pro Mensual", output)
        self.assertIn("RepBuzz Mensual", output)
        self.assertIn("description:", output)
        self.assertIn("project:", output)
        self.assertTrue(all(method == "GET" for method, _ in self.api.calls))
        self.assertFalse(self.plan.exists())

    def test_live_translations_and_urls_are_preserved_not_overwritten_from_project(self):
        rows = self.api.tables["/v1/subscriptionVersions/version0/localizations"]
        rows[0]["attributes"]["description"] = (
            "Gym Timer Pro: custom text https://example.org/GymTimerPro-policy"
        )
        code, output, _ = self.invoke("--plan-output", str(self.plan))
        self.assertEqual(code, 0)
        data = json.loads(self.plan.read_text())
        row = data["products"][tool.PRODUCTS[0]]["localizations"][0]
        self.assertEqual(row["after"]["description"],
                         "RepBuzz: custom text https://example.org/GymTimerPro-policy")
        self.assertIn("DIFFERS", output)
        self.assertEqual(self.project, json.loads(self.translations.read_text()))

    def test_apply_updates_only_brand_fields_and_verifies_all_thirty_locales(self):
        approval = self.save_plan()
        self.api.calls.clear()
        code, output, error = self.invoke("--apply-plan", str(self.plan), "--confirm", approval)
        self.assertEqual((code, error), (0, ""))
        writes = [(m, p) for m, p in self.api.calls if m != "GET"]
        self.assertEqual(len(writes), 30)
        self.assertTrue(all(m == "PATCH" and p.startswith("/v2/subscriptionLocalizations/")
                            for m, p in writes))
        self.assertIn("Verified 30 localizations", output)
        self.assertTrue(all(set(body["data"]["attributes"]) == {"name"} for body in self.api.writes))
        self.assertEqual(self.project, json.loads(self.translations.read_text()))
        second = self.root / "after.json"
        self.assertEqual(self.invoke("--plan-output", str(second))[0], 0)
        self.api.calls.clear()
        self.assertEqual(self.invoke("--apply-plan", str(second), "--confirm",
                                     tool.digest(json.loads(second.read_text())))[0], 0)
        self.assertTrue(all(m == "GET" for m, _ in self.api.calls))

    def test_missing_confirmation_and_remote_drift_write_nothing(self):
        approval = self.save_plan()
        unchanged = self.plan.read_bytes()
        self.api.calls.clear()
        self.assertEqual(self.invoke("--apply-plan", str(self.plan))[0], 1)
        self.assertFalse(self.api.calls)
        self.api.tables["/v1/subscriptionVersions/version1/localizations"][0]["attributes"]["name"] += "!"
        self.assertEqual(self.invoke("--apply-plan", str(self.plan), "--confirm", approval)[0], 1)
        self.assertTrue(all(m == "GET" for m, _ in self.api.calls))
        self.assertEqual(self.plan.read_bytes(), unchanged)

    def test_noneditable_version_can_be_previewed_but_not_applied(self):
        self.api.tables["/v1/subscriptions/sub0/versions"][0]["attributes"]["state"] = "APPROVED"
        approval = self.save_plan()
        self.api.calls.clear()
        code, _, error = self.invoke("--apply-plan", str(self.plan), "--confirm", approval)
        self.assertEqual(code, 1)
        self.assertIn("editable", error)
        self.assertTrue(all(m == "GET" for m, _ in self.api.calls))

    def test_missing_locales_are_reported_and_never_created(self):
        self.api.tables["/v1/subscriptionVersions/version0/localizations"].pop()
        approval = self.save_plan()
        self.assertIn("MISSING remotely", self.invoke()[1])
        code, output, _ = self.invoke("--apply-plan", str(self.plan), "--confirm", approval)
        self.assertEqual(code, 0)
        self.assertIn("Verified 29 localizations", output)
        self.assertFalse(any(m in ("POST", "DELETE") for m, _ in self.api.calls))

    def test_failed_postwrite_verification_is_not_success(self):
        approval = self.save_plan()
        original = self.api.request
        def ignore_patch(method, path, body=None):
            if method == "PATCH":
                self.api.calls.append((method, path))
                return {"data": {}}
            return original(method, path, body)
        self.api.request = ignore_patch
        code, output, error = self.invoke("--apply-plan", str(self.plan), "--confirm", approval)
        self.assertEqual(code, 1)
        self.assertNotIn("Verified", output)
        self.assertIn("verification", error)

    def test_legacy_localizations_are_readonly_and_extra_remote_locales_are_included(self):
        self.api.tables["/v1/subscriptions/sub0/versions"] = []
        rows = self.api.tables["/v1/subscriptionVersions/version0/localizations"]
        self.api.tables["/v1/subscriptions/sub0/subscriptionLocalizations"] = rows
        rows.append(resource("extra", locale="en-GB", name="GymTimerPro Monthly", description=None))
        approval = self.save_plan()
        code, output, error = self.invoke("--apply-plan", str(self.plan), "--confirm", approval)
        self.assertEqual(code, 1)
        self.assertIn("editable", error)
        self.assertIn("en-GB", self.invoke()[1])
        self.assertTrue(all(m == "GET" for m, _ in self.api.calls))

    def test_duplicate_products_or_locales_abort_without_writes(self):
        for path in ("/v1/subscriptionGroups/group/subscriptions",
                     "/v1/subscriptionVersions/version0/localizations"):
            with self.subTest(path=path):
                rows = self.api.tables[path]
                rows.append(copy.deepcopy(rows[0]))
                self.assertEqual(self.invoke()[0], 1)
                self.assertTrue(all(m == "GET" for m, _ in self.api.calls))
                rows.pop()

    def test_drift_during_apply_stops_before_overwriting_the_changed_locale(self):
        approval = self.save_plan()
        original = self.api.request
        def concurrent_change(method, path, body=None):
            if method == "GET" and path == "/v2/subscriptionLocalizations/loc0_da":
                self.api.tables["/v1/subscriptionVersions/version0/localizations"][0]["attributes"]["description"] = "Updated remotely"
            return original(method, path, body)
        self.api.request = concurrent_change
        self.assertEqual(self.invoke("--apply-plan", str(self.plan), "--confirm", approval)[0], 1)
        self.assertFalse(self.api.writes)

    def test_changed_or_overwritten_plan_is_rejected_without_account_access(self):
        approval = self.save_plan()
        self.api.calls.clear()
        before = self.plan.read_bytes()
        self.assertEqual(self.invoke("--plan-output", str(self.plan))[0], 1)
        self.assertEqual(self.plan.read_bytes(), before)
        data = json.loads(before)
        data["bundle_id"] = "other.app"
        self.plan.write_text(json.dumps(data))
        self.assertEqual(self.invoke("--apply-plan", str(self.plan), "--confirm", approval)[0], 1)
        self.assertFalse(self.api.calls)


class TransportTests(unittest.TestCase):
    def test_empty_confirmation_without_apply_is_rejected_before_authentication(self):
        factory = unittest.mock.Mock()
        with contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                tool.main(["--confirm", ""], api_factory=factory)
        self.assertEqual(result.exception.code, 2)
        factory.assert_not_called()

    def test_redirects_are_refused(self):
        with self.assertRaises(RuntimeError):
            tool.NoRedirect().redirect_request(None, None, 307, "redirect", {}, "https://example.org")

    def test_readonly_transport_rejects_writes_and_external_pagination(self):
        api = tool.API("not-a-real-token")
        with patch.object(api.opener, "open") as send:
            for method, path in [("POST", "/v1/subscriptions"),
                                 ("DELETE", "/v2/subscriptionLocalizations/123"),
                                 ("PATCH", "/v2/subscriptionLocalizations/123"),
                                 ("GET", "https://example.org/steal")]:
                with self.assertRaises(RuntimeError):
                    api.request(method, path)
            send.assert_not_called()

    def test_pagination_follows_all_pages_and_refuses_cycles(self):
        api = tool.API("not-a-real-token")
        path = "/v1/subscriptions/sub/versions"
        with patch.object(api, "request", side_effect=[
            {"data": [resource("one")], "links": {"next": tool.ORIGIN + path + "?cursor=2"}},
            {"data": [resource("two")], "links": {"next": None}},
        ]):
            self.assertEqual([r["id"] for r in api.all(path)], ["one", "two"])
        with patch.object(api, "request", return_value={"data": [], "links": {"next": path}}):
            with self.assertRaises(RuntimeError):
                api.all(path)

    def test_unapproved_mutation_targets_and_fields_are_rejected(self):
        api = tool.API("not-a-real-token", write=True)
        with patch.object(api.opener, "open") as send:
            for path, attributes in [("/v1/subscriptions/123", {"name": "RepBuzz"}),
                                     ("/v2/subscriptionLocalizations/123", {"price": "0"})]:
                with self.assertRaises(RuntimeError):
                    api.request("PATCH", path, {"data": {
                        "id": "123", "type": "subscriptionLocalizations", "attributes": attributes}})
            send.assert_not_called()


if __name__ == "__main__":
    unittest.main()
