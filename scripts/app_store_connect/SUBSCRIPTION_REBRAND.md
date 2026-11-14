# Rebrand existing subscriptions safely

Use `rebrand_subscription_localizations.py` for the RepBuzz rebrand, **not** the generic updater or `api_examples.sh`. The older tools can replace complete translations and create missing localizations.

## Safety boundary

- Fixed app: `alejandroestevemaza.GymTimerPro`.
- Fixed existing products: `premium_monthly`, `premium_yearly`.
- Default: authenticated GET requests and a before/after preview; no remote writes.
- Proposed text comes from **live Apple text**, replacing only `Gym Timer Pro`, `GymTimerPro`, and `GymTimer Pro` (case-insensitive, optional spaces). Monthly/yearly translations and other wording stay intact. HTTP(S) URLs are preserved verbatim. Other ambiguous brand spellings require manual review.
- The project JSON is a comparison source, not a replacement source. Both matching and differing translations are shown. Remote-only locales are included; project-only locales are reported as missing and never created. There is no fixed locale-count assumption.
- Only PATCH requests to `/v2/subscriptionLocalizations/{id}` can write, and only changed `name`/`description` attributes. No creation, deletion, pricing, durations, levels, product-ID updates, submission, or publication endpoints are supported.
- Both products need a unique `PREPARE_FOR_SUBMISSION` version to apply. Without one, preview is still read-only: it reads the latest identifiable version or the legacy localizations when no versions exist. Prepare an editable draft manually in App Store Connect and rerun preview; this tool does not create drafts. It never falls back to legacy writes.
- Apply is bound to the SHA256 of the reviewed plan. It rereads the app/product/version/localization inventory before any write and refuses remote or project drift. It checks draft state before each PATCH and rereads every locale afterward.
- Apple provides no cross-localization transaction here. Another editor can still race a request after its preflight read. Do not edit these texts concurrently. Errors may leave partial updates: no automatic retry or rollback; inspect Apple and generate a new plan.
- Plans contain metadata snapshots, not credentials; store them outside Git. The tool refuses to overwrite a plan or create it inside this repository. Nothing is automatically committed or uploaded by this tool.

## Configure authentication without exposing secrets

Reuse an existing authorized **team API key** if available; there is no need to create another just for this tool. Do not paste key contents into chat or Git.

1. In App Store Connect, open **Users and Access → Integrations → App Store Connect API → Team Keys**. Request API access if your organization has not enabled it. An appropriately authorized account must create the team key.
2. Use the least role that permits subscription management; **App Manager** is supported by Apple's subscription-management role guidance. Team keys can access all apps, so this script additionally restricts the Bundle ID and products. An endpoint-specific 403 still requires the account administrator to check permissions; do not automatically escalate privileges.
3. Download the `.p8` private key once and store it **outside the checkout**, for example in a private directory under `$HOME/.config/appstoreconnect/`. Restrict the directory to mode `700` and key to `600`. Do not copy it into this repository, even temporarily.
4. Set the existing variable names in your local shell, using your actual key metadata and path:

   ```bash
   export ASC_KEY_ID="YOUR_KEY_ID"
   export ASC_ISSUER_ID="YOUR_TEAM_ISSUER_ID"
   export ASC_PRIVATE_KEY_PATH="$HOME/.config/appstoreconnect/AuthKey_YOUR_KEY_ID.p8"
   ```

   These instructions use team-key JWT authentication; individual-key authentication is not implemented. Do not print JWTs or run `asc_token.py` into shared logs. Revoke a key if exposed.

5. Use Python 3.9+ and the existing signing dependencies. A virtual environment outside the repository avoids changing the app or committing tooling files:

   ```bash
   python3 -m venv "$HOME/.venvs/repbuzz-asc"
   "$HOME/.venvs/repbuzz-asc/bin/python" -m pip install pyjwt cryptography requests
   ```

   The tool reuses the existing JWT builder (ES256, `appstoreconnect-v1`, 19-minute lifetime); it never prints the token. Start a new invocation if it expires. Dependency installation is optional setup, not part of dry-run.

## Preview real Apple data — read-only

Running this command explicitly uses the configured API key for GET requests to the official Apple API. It is **not** an offline simulation. `--help` and the unit tests require no key and make no account requests.

```bash
umask 077
PLAN_DIR="$(mktemp -d)"
PYTHON="$HOME/.venvs/repbuzz-asc/bin/python"
"$PYTHON" scripts/app_store_connect/rebrand_subscription_localizations.py \
  --plan-output "$PLAN_DIR/repbuzz-plan.json"
```

Review every subscription/locale, name, description, project comparison, missing-locale notice, draft state, and the printed **Plan SHA256**. A preview exit code of `0` means the inventory was read, not that an editable draft exists or any update was applied. Any `BLOCKED` state must be resolved before apply.

For illustration only, the checked-in comparison file proposes these brand replacements:

| Product / locale | Previous name | Proposed name |
|---|---|---|
| `premium_monthly` / `es-ES` | GymTimer Pro Mensual | RepBuzz Mensual |
| `premium_yearly` / `es-ES` | GymTimer Pro Anual | RepBuzz Anual |
| `premium_monthly` / `en-US` | GymTimer Pro Monthly | RepBuzz Monthly |
| `premium_yearly` / `en-US` | GymTimer Pro Yearly | RepBuzz Yearly |

All 30 checked-in names have the old brand; their descriptions have no old-brand references, so the local proposal leaves all descriptions unchanged. This is **not** proof of the current account contents: the real preview is authoritative and may differ.

## Apply only after explicit approval of that preview

**The next command performs remote writes. Do not run it before reviewing and authorizing the exact plan.** Replace the placeholder with the full SHA256 printed above; do not generate approval automatically.

```bash
"$PYTHON" scripts/app_store_connect/rebrand_subscription_localizations.py \
  --apply-plan "$PLAN_DIR/repbuzz-plan.json" \
  --confirm PASTE_THE_REVIEWED_PLAN_SHA256_HERE
```

Success requires the final `Verified N localizations across both existing products` message and exit code `0`. An error exits `1`; CLI syntax errors exit `2`. Preserve the plan as a before-state record, inspect any partial result, and create a fresh preview before authorizing a retry. The final verification is read-only and covers unchanged as well as changed locales. You can also rerun the default preview afterward.

Apple approval/release of changed metadata is outside this workflow. Patching a draft does not complete any later review process.

## Offline regression tests

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s scripts/app_store_connect -p 'test_rebrand_subscription_localizations.py' -v
```

These tests use fake Apple responses, exercise the CLI, and never read credentials or contact Apple. They do not certify live permissions or availability.

## Apple API references

Verified against Apple's current public documentation on 2026-11-02:

- [Subscription version lifecycle and legacy migration](https://developer.apple.com/documentation/appstoreconnectapi/working-with-subscription-versions).
- [List versions](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptions-_id_-versions).
- [List version localizations](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-subscriptionversions-_id_-localizations).
- [Modify v2 localization](https://developer.apple.com/documentation/appstoreconnectapi/patch-v2-subscriptionlocalizations-_id_).
- [Exact PATCH attributes: `name` and `description`](https://developer.apple.com/documentation/appstoreconnectapi/subscriptionlocalizationv2updaterequest/data-data.dictionary/attributes-data.dictionary).
- [API keys and roles](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) and [subscription management roles](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions).
- [JWT authentication](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests).
