#!/usr/bin/env python3
"""Preview a brand-only rebrand; apply only an explicitly confirmed, unchanged plan."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

ORIGIN = "https://api.appstoreconnect.apple.com"
BUNDLE_ID = "alejandroestevemaza.GymTimerPro"
PRODUCTS = ("premium_monthly", "premium_yearly")
DEFAULT_TRANSLATIONS = Path(__file__).with_name("subscription_texts.example.json")
BRAND = re.compile(r"(?<![A-Za-z0-9])gym[ \t]*timer[ \t]*pro(?![A-Za-z0-9])", re.I)
URL = re.compile(r"(https?://[^\s]+)", re.I)
ID = r"[A-Za-z0-9_-]+"
READ_PATHS = re.compile(
    rf"/v1/(?:apps|apps/{ID}/relationships/subscriptionGroups|"
    rf"subscriptionGroups/{ID}/subscriptions|subscriptions/{ID}/versions|"
    rf"subscriptions/{ID}/subscriptionLocalizations|subscriptionVersions/{ID}(?:/localizations)?)"
)


def rebrand(text):
    if text is None:
        return None
    return "".join(part if URL.fullmatch(part) else BRAND.sub("RepBuzz", part)
                   for part in URL.split(text))


def digest(plan):
    return hashlib.sha256(json.dumps(plan, sort_keys=True, ensure_ascii=False,
                                    separators=(",", ":")).encode()).hexdigest()


def identifier(value):
    if not isinstance(value, str) or not re.fullmatch(ID, value):
        raise RuntimeError("Invalid resource identifier; no request sent.")
    return value


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise RuntimeError("Redirect refused; credentials were not forwarded.")


class API:
    """Deny-by-default transport; never retry writes or follow redirects."""

    def __init__(self, token, write=False):
        self.token, self.write = token, write
        self.opener = build_opener(NoRedirect())

    def request(self, method, path, body=None):
        url = path if path.startswith("https://") else ORIGIN + path
        parsed = urlsplit(url)
        if parsed.scheme != "https" or parsed.netloc != "api.appstoreconnect.apple.com" or parsed.fragment:
            raise RuntimeError("Non-Apple URL refused; no request sent.")
        if method == "GET":
            if body is not None or not (READ_PATHS.fullmatch(parsed.path) or
                                       re.fullmatch(rf"/v2/subscriptionLocalizations/{ID}", parsed.path)):
                raise RuntimeError("Read endpoint refused; no request sent.")
        elif method == "PATCH" and self.write:
            match = re.fullmatch(rf"/v2/subscriptionLocalizations/({ID})", parsed.path)
            data = body.get("data", {}) if isinstance(body, dict) else {}
            attrs = data.get("attributes", {})
            if (not match or parsed.query or set(body or {}) != {"data"}
                    or set(data) != {"id", "type", "attributes"}
                    or data["id"] != match.group(1) or data["type"] != "subscriptionLocalizations"
                    or not isinstance(attrs, dict) or not attrs
                    or not set(attrs) <= {"name", "description"}
                    or not all(isinstance(v, str) and v for v in attrs.values())):
                raise RuntimeError("Mutation target or attributes refused; no request sent.")
        else:
            raise RuntimeError("Write refused; only authorized v2 localization PATCH is supported.")
        request = Request(url, method=method, data=None if body is None else json.dumps(body).encode(),
                          headers={"Authorization": "Bearer " + self.token,
                                   "Accept": "application/json", "Content-Type": "application/json"})
        try:
            with self.opener.open(request, timeout=60) as response:
                return json.load(response)
        except HTTPError as error:
            raise RuntimeError(f"Apple returned HTTP {error.code}; no retry performed.") from None
        except (URLError, TimeoutError, OSError):
            raise RuntimeError("Network request failed; no retry performed.") from None

    def all(self, path):
        rows, visited = [], set()
        while path:
            if path in visited or len(visited) >= 100:
                raise RuntimeError("Invalid or excessive pagination; refusing partial inventory.")
            visited.add(path)
            page = self.request("GET", path)
            if not isinstance(page.get("data"), list):
                raise RuntimeError("Invalid collection response; refusing partial inventory.")
            rows.extend(page["data"])
            path = page.get("links", {}).get("next")
            if path is not None and not isinstance(path, str):
                raise RuntimeError("Invalid pagination link.")
        return rows


def translations(path):
    local = json.loads(path.read_text(encoding="utf-8"))
    if set(local) != set(PRODUCTS):
        raise RuntimeError("Translation file must contain exactly the two existing product IDs.")
    for locales in local.values():
        if not isinstance(locales, dict) or not locales:
            raise RuntimeError("Missing project locales.")
        for texts in locales.values():
            if not isinstance(texts, dict) or not all(isinstance(texts.get(k), str) and texts[k]
                                                     for k in ("name", "description")):
                raise RuntimeError("Invalid project name or description.")
    return local


def snapshot(api, local):
    apps = api.all("/v1/apps?" + urlencode({"filter[bundleId]": BUNDLE_ID}))
    if len(apps) != 1:
        raise RuntimeError("Expected exactly one app for the configured Bundle ID.")
    groups = api.all(f"/v1/apps/{identifier(apps[0]['id'])}/relationships/subscriptionGroups")
    found = {}
    for group in groups:
        for subscription in api.all(f"/v1/subscriptionGroups/{identifier(group['id'])}/subscriptions"):
            product = subscription["attributes"].get("productId")
            if product in PRODUCTS:
                if product in found:
                    raise RuntimeError("Duplicate product ID; refusing ambiguous subscription selection.")
                found[product] = subscription
    if set(found) != set(PRODUCTS):
        raise RuntimeError("Both existing products must be found in the selected app.")
    plan = {"schema": "repbuzz.subscription-rebrand/v1", "bundle_id": BUNDLE_ID, "products": {}}
    for product in PRODUCTS:
        subscription = found[product]
        sid = identifier(subscription["id"])
        versions = api.all(f"/v1/subscriptions/{sid}/versions")
        drafts = [v for v in versions if v["attributes"].get("state") == "PREPARE_FOR_SUBMISSION"]
        if len(drafts) > 1:
            raise RuntimeError(f"{product}: multiple editable drafts; select the intended draft manually.")
        chosen = drafts
        if not chosen and versions:
            numbers = [v["attributes"].get("version") for v in versions]
            if not all(isinstance(n, int) for n in numbers) or numbers.count(max(numbers)) != 1:
                raise RuntimeError(f"{product}: cannot identify latest read-only version.")
            chosen = [versions[numbers.index(max(numbers))]]
        vid = identifier(chosen[0]["id"]) if chosen else None
        path = (f"/v1/subscriptionVersions/{vid}/localizations" if vid
                else f"/v1/subscriptions/{sid}/subscriptionLocalizations")
        rows, locales, ids = [], set(), set()
        for resource in api.all(path):
            attrs = resource["attributes"]
            locale, lid = attrs.get("locale"), identifier(resource["id"])
            if not isinstance(locale, str) or not locale or locale in locales or lid in ids:
                raise RuntimeError(f"{product}: invalid or duplicate localization.")
            locales.add(locale)
            ids.add(lid)
            before = {k: attrs.get(k) for k in ("name", "description")}
            if (not isinstance(before["name"], str) or not before["name"]
                    or (before["description"] is not None and not isinstance(before["description"], str))):
                raise RuntimeError(f"{product}/{locale}: invalid remote text.")
            after = {k: rebrand(value) for k, value in before.items()}
            project = local[product].get(locale)
            rows.append({"id": lid, "locale": locale, "before": before, "after": after,
                         "project": project})
        if not rows:
            raise RuntimeError(f"{product}: no existing localizations; nothing will be created.")
        plan["products"][product] = {
            "subscription_id": sid, "subscription_attributes": subscription["attributes"],
            "version_id": vid, "version_state": chosen[0]["attributes"].get("state") if chosen else None,
            "localizations": sorted(rows, key=lambda row: row["locale"]),
            "missing_remote_locales": sorted(set(local[product]) - locales),
        }
    return plan


def preview(plan):
    for product, subscription in plan["products"].items():
        state = subscription["version_state"]
        print(f"\n{product}: version={subscription['version_id']} state={state}")
        if state != "PREPARE_FOR_SUBMISSION":
            print("BLOCKED for apply: no editable draft. Prepare a draft manually, then generate a new plan.")
        for row in subscription["localizations"]:
            print(f"  {row['locale']} ({row['id']}):")
            for field in ("name", "description"):
                print(f"    {field}: {json.dumps(row['before'][field], ensure_ascii=False)}"
                      f" -> {json.dumps(row['after'][field], ensure_ascii=False)}")
                project = row["project"].get(field) if row["project"] else None
                same = rebrand(project) == row["after"][field]
                print(f"      project: {json.dumps(project, ensure_ascii=False)}"
                      f" [{('MATCH' if same else 'DIFFERS; remote wording preserved')}]")
        for locale in subscription["missing_remote_locales"]:
            print(f"  {locale}: MISSING remotely; will not create a localization.")


def apply_plan(api, plan, local):
    if any(s["version_state"] != "PREPARE_FOR_SUBMISSION" for s in plan["products"].values()):
        raise RuntimeError("Both products require one editable draft; no writes performed.")
    if snapshot(api, local) != plan:
        raise RuntimeError("Remote/project data changed since preview; generate and authorize a new plan.")
    expected, count = copy.deepcopy(plan), 0
    for product, subscription in plan["products"].items():
        for index, row in enumerate(subscription["localizations"]):
            changed = {k: v for k, v in row["after"].items() if v != row["before"][k]}
            if changed:
                version = api.request("GET", f"/v1/subscriptionVersions/{subscription['version_id']}")
                if version["data"]["attributes"].get("state") != "PREPARE_FOR_SUBMISSION":
                    raise RuntimeError("Version is no longer editable; stopping further writes.")
                current = api.request("GET", f"/v2/subscriptionLocalizations/{row['id']}")["data"]
                attrs = current["attributes"]
                if (current["id"] != row["id"] or attrs.get("locale") != row["locale"]
                        or {k: attrs.get(k) for k in row["before"]} != row["before"]):
                    raise RuntimeError("Localization changed during apply; stopping further writes.")
                print(f"PATCH {product}/{row['locale']} (no automatic retry)")
                api.request("PATCH", f"/v2/subscriptionLocalizations/{row['id']}", {"data": {
                    "type": "subscriptionLocalizations", "id": row["id"], "attributes": changed}})
            expected["products"][product]["localizations"][index]["before"] = row["after"]
            count += 1
    if snapshot(api, local) != expected:
        raise RuntimeError("Post-write verification failed; do not assume all changes succeeded.")
    print(f"Verified {count} localizations across both existing products. Nothing submitted or published.")


def authenticated_api(write=False):
    # Reuse the existing signing helper without importing dependencies or reading keys for --help/tests.
    try:
        from update_subscription_localizations import build_jwt
        token = build_jwt()
    except (Exception, SystemExit):
        raise RuntimeError("Authentication setup failed. Check dependencies and the three ASC variables; "
                           "no key details are logged.") from None
    return API(token, write=write)


def main(argv=None, api_factory=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--translations", type=Path, default=DEFAULT_TRANSLATIONS,
                        help="Project text comparison file; never used to overwrite remote translations.")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--plan-output", type=Path, help="Save read-only preview outside the repository; never overwrite.")
    mode.add_argument("--apply-plan", type=Path, help="Apply a previously reviewed plan; requires --confirm SHA256.")
    parser.add_argument("--confirm", help="Exact SHA256 printed by preview; explicit authorization for that plan only.")
    args = parser.parse_args(argv)
    if args.confirm is not None and not args.apply_plan:
        parser.error("--confirm requires --apply-plan")
    applying = args.apply_plan is not None
    try:
        local = translations(args.translations)
        if applying:
            plan = json.loads(args.apply_plan.read_text(encoding="utf-8"))
            if args.confirm != digest(plan):
                raise RuntimeError("Missing or incorrect --confirm SHA256; no account access performed.")
            if plan.get("schema") != "repbuzz.subscription-rebrand/v1":
                raise RuntimeError("Unsupported plan schema.")
        if args.plan_output:
            repo = Path(__file__).resolve().parents[2]
            if args.plan_output.resolve().is_relative_to(repo) or args.plan_output.exists():
                raise RuntimeError("Plan output must be a new file outside the repository.")
        api = (api_factory or authenticated_api)(write=applying)
        if applying:
            apply_plan(api, plan, local)
        else:
            print("DRY RUN: authenticated GET requests only; no Apple writes.")
            plan = snapshot(api, local)
            preview(plan)
            print(f"\nPlan SHA256: {digest(plan)}")
            if args.plan_output:
                fd = os.open(args.plan_output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
                with os.fdopen(fd, "w", encoding="utf-8") as handle:
                    json.dump(plan, handle, ensure_ascii=False, indent=2)
                    handle.write("\n")
        return 0
    except (RuntimeError, ValueError, OSError, KeyError, TypeError, ImportError) as error:
        # Never include HTTP bodies, JWTs, environment values or private-key contents.
        print(f"Error: {error}" if isinstance(error, RuntimeError)
              else f"Error: invalid data, dependency or local file ({type(error).__name__}).", file=sys.stderr)
        if applying:
            print("Stopped. Writes may be partial; inspect remotely and generate a fresh preview before retrying.",
                  file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
