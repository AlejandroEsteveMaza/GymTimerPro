"""Independent S2-S6 public-main and credential-boundary regression probes."""

import contextlib
import copy
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
from urllib.error import HTTPError, URLError

import rebrand_subscription_localizations as tool


class Inventory:
    def __init__(self):
        self.writes = []
        self.rows = {}
        self.data = {
            "/v1/apps?filter%5BbundleId%5D=" + tool.BUNDLE_ID: [{"id": "app"}],
            "/v1/apps/app/relationships/subscriptionGroups": [{"id": "unrelated"}, {"id": "target"}],
            "/v1/subscriptionGroups/unrelated/subscriptions": [],
            "/v1/subscriptionGroups/target/subscriptions": [],
        }
        for n, product in enumerate(tool.PRODUCTS):
            sid, vid, lid = "s" + str(n), "v" + str(n), "l" + str(n)
            self.data["/v1/subscriptionGroups/target/subscriptions"].append(
                {"id": sid, "attributes": {"productId": product, "price": "unchanged"}}
            )
            self.data[f"/v1/subscriptions/{sid}/versions"] = [
                {"id": "approved" + str(n), "attributes": {"state": "APPROVED", "version": 9}},
                {"id": vid, "attributes": {"state": "PREPARE_FOR_SUBMISSION", "version": 10}},
            ]
            self.rows[lid] = {"id": lid, "attributes": {
                "locale": "es-ES", "name": "Gym Timer Pro Mensual",
                "description": "Usa GymTimerPro; https://example.org/GymTimerPro?q=GymTimerPro",
            }}
            self.data[f"/v1/subscriptionVersions/{vid}/localizations"] = [self.rows[lid]]

    def all(self, path):
        return copy.deepcopy(self.data[path])

    def request(self, method, path, body=None):
        if method == "PATCH":
            self.writes.append((method, path, copy.deepcopy(body)))
            self.rows[path.rsplit("/", 1)[1]]["attributes"].update(body["data"]["attributes"])
            return {"data": {}}
        if path.startswith("/v2/"):
            return {"data": copy.deepcopy(self.rows[path.rsplit("/", 1)[1]])}
        return {"data": {"attributes": {"state": "PREPARE_FOR_SUBMISSION"}}}


class IndependentGuards(unittest.TestCase):
    def invoke(self, api, args):
        out, err = io.StringIO(), io.StringIO()
        with patch.object(tool, "authenticated_api", side_effect=AssertionError("auth forbidden")), \
                patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = tool.main(args, api_factory=lambda **kw: api)
        return code, out.getvalue(), err.getvalue()

    def test_public_preview_authorization_drift_and_apply(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            project = root / "texts.json"
            project.write_text(json.dumps({p: {"fr-FR": {"name": "Different", "description": "Different"}}
                                           for p in tool.PRODUCTS}))
            plan = root / "plan.json"
            api = Inventory()
            options = ["--translations", str(project)]
            code, out, err = self.invoke(api, options + ["--plan-output", str(plan)])
            self.assertEqual((code, err), (0, ""))
            self.assertIn("DIFFERS; remote wording preserved", out)
            self.assertIn("fr-FR: MISSING remotely; will not create a localization.", out)
            self.assertEqual(plan.stat().st_mode & 0o777, 0o600)
            saved = json.loads(plan.read_text())
            approval = tool.digest(saved)
            def hashes():
                return [hashlib.sha256(p.read_bytes()).hexdigest() for p in (plan, project)]
            before = hashes()
            code, out, err = self.invoke(api, options + ["--apply-plan", str(plan)])
            self.assertEqual(code, 1)
            self.assertEqual(out, "")
            self.assertIn("no account access performed", err)
            self.assertEqual(hashes(), before)
            self.assertEqual(api.writes, [])
            api.rows["l0"]["attributes"]["description"] += "!"
            state = copy.deepcopy(api.data)
            code, _, err = self.invoke(api, options + ["--apply-plan", str(plan), "--confirm", approval])
            self.assertEqual(code, 1)
            self.assertIn("Remote/project data changed since preview", err)
            self.assertEqual(api.data, state)
            self.assertEqual(hashes(), before)
            self.assertEqual(api.writes, [])
            api.rows["l0"]["attributes"]["description"] = api.rows["l0"]["attributes"]["description"][:-1]
            code, out, err = self.invoke(api, options + ["--apply-plan", str(plan), "--confirm", approval])
            self.assertEqual((code, err), (0, ""))
            self.assertEqual(out, "PATCH premium_monthly/es-ES (no automatic retry)\n"
                                 "PATCH premium_yearly/es-ES (no automatic retry)\n"
                                 "Verified 2 localizations across both existing products. Nothing submitted or published.\n")
            for method, path, body in api.writes:
                self.assertEqual(method, "PATCH")
                self.assertTrue(path.startswith("/v2/subscriptionLocalizations/"))
                self.assertEqual(body["data"]["attributes"], {
                    "name": "RepBuzz Mensual",
                    "description": "Usa RepBuzz; https://example.org/GymTimerPro?q=GymTimerPro",
                })
            self.assertEqual(hashes(), before)

    def test_transport_exact_failures_and_no_secret(self):
        api = tool.API("SYNTHETIC_SECRET", write=True)
        errors = [
            (HTTPError(tool.ORIGIN, 403, "SYNTHETIC_SECRET", {}, io.BytesIO(b"SYNTHETIC_SECRET")),
             "Apple returned HTTP 403; no retry performed."),
            (URLError("SYNTHETIC_SECRET"), "Network request failed; no retry performed."),
        ]
        for error, expected in errors:
            with patch.object(api.opener, "open", side_effect=error) as send:
                with self.assertRaises(RuntimeError) as result:
                    api.request("GET", "/v1/apps")
                self.assertEqual(str(result.exception), expected)
                self.assertNotIn("SYNTHETIC_SECRET", str(result.exception))
                self.assertEqual(send.call_count, 1)
        with patch.object(api.opener, "open") as send:
            cases = [
                ("GET", "https://api.appstoreconnect.apple.com.evil/v1/apps", None),
                ("GET", "https://user:pass@api.appstoreconnect.apple.com/v1/apps", None),
                ("GET", "//evil/v1/apps", None),
                ("POST", "/v1/subscriptions", None),
                ("DELETE", "/v2/subscriptionLocalizations/l0", None),
                ("PATCH", "/v2/subscriptionLocalizations/l0?other=1", {"data": {
                    "id": "l0", "type": "subscriptionLocalizations", "attributes": {"name": "RepBuzz"}}}),
            ]
            for method, path, body in cases:
                with self.assertRaises(RuntimeError):
                    api.request(method, path, body)
            send.assert_not_called()
        for status in (301, 302, 303, 307, 308):
            with self.assertRaises(RuntimeError) as result:
                tool.NoRedirect().redirect_request(None, None, status, "SYNTHETIC_SECRET", {}, "https://evil/")
            self.assertEqual(str(result.exception), "Redirect refused; credentials were not forwarded.")

    def test_help_never_authenticates(self):
        with patch.object(tool, "authenticated_api", side_effect=AssertionError("auth forbidden")), \
                patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                tool.main(["--help"])
            self.assertEqual(result.exception.code, 0)

    def test_pagination_limits(self):
        api = tool.API("SYNTHETIC_SECRET")
        with patch.object(api, "request", side_effect=[
            {"data": [{"id": "a"}], "links": {"next": tool.ORIGIN + "/v1/apps?cursor=2"}},
            {"data": [{"id": "b"}], "links": {}},
        ]):
            self.assertEqual(api.all("/v1/apps"), [{"id": "a"}, {"id": "b"}])
        cases = [
            ({"data": None}, "Invalid collection response; refusing partial inventory."),
            ({"data": [], "links": {"next": 3}}, "Invalid pagination link."),
            ({"data": [], "links": {"next": "/v1/apps"}},
             "Invalid or excessive pagination; refusing partial inventory."),
        ]
        for page, text in cases:
            with patch.object(api, "request", return_value=page):
                with self.assertRaises(RuntimeError) as result:
                    api.all("/v1/apps")
                self.assertEqual(str(result.exception), text)


class ExplicitConfirmationOption(unittest.TestCase):
    def test_empty_confirmation_without_apply_is_syntax_error(self):
        factory = Mock(return_value=Inventory())
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                tool.main(["--confirm", ""], api_factory=factory)
        self.assertEqual(result.exception.code, 2)
        factory.assert_not_called()
