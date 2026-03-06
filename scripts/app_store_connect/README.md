# App Store Connect localization updaters

This folder contains scripts to update:

- Subscription texts (`name` + `description`) for:
  - `premium_monthly`
  - `premium_yearly`
- App metadata localizations (`description`, `promotionalText`, `keywords`, `name`, `subtitle`, `supportUrl`, `marketingUrl`)
- App Store screenshots per locale/display type (`appScreenshotSets` + `appScreenshots`)


## Files

- `asc_token.py`: generate ASC JWT token from env vars.
- `update_subscription_localizations.py`: dry-run/apply updater.
- `subscription_texts.example.json`: translation payload example.
- `update_app_metadata_localizations.py`: app metadata localizations updater.
- `app_metadata_texts.gymtimerpro.json`: ready-to-run metadata payload.
- `upload_app_screenshots.py`: uploads localized screenshots from frameit folders.
- `api_examples.sh`: complete `curl` examples for list + patch + post.

## Requirements

```bash
python3 -m pip install pyjwt cryptography requests
```

Environment variables:

```bash
export ASC_KEY_ID="YOUR_KEY_ID"
export ASC_ISSUER_ID="YOUR_ISSUER_ID"
export ASC_PRIVATE_KEY_PATH="/absolute/path/AuthKey_XXXXXX.p8"
```

## Run (dry-run first)

```bash
python3 scripts/app_store_connect/update_subscription_localizations.py \
  --bundle-id "com.yourcompany.yourapp" \
  --translations scripts/app_store_connect/subscription_texts.example.json
```

Apply real changes:

```bash
python3 scripts/app_store_connect/update_subscription_localizations.py \
  --bundle-id "com.yourcompany.yourapp" \
  --translations scripts/app_store_connect/subscription_texts.example.json \
  --apply
```

Optional:

```bash
# Disable description length check
python3 scripts/app_store_connect/update_subscription_localizations.py \
  --bundle-id "com.yourcompany.yourapp" \
  --translations scripts/app_store_connect/subscription_texts.example.json \
  --max-description-length 0 \
  --apply
```

## App metadata localizations (dry-run first)

```bash
python3 scripts/app_store_connect/update_app_metadata_localizations.py \
  --bundle-id "com.yourcompany.yourapp" \
  --translations scripts/app_store_connect/app_metadata_texts.gymtimerpro.json
```

Apply real changes:

```bash
python3 scripts/app_store_connect/update_app_metadata_localizations.py \
  --bundle-id "com.yourcompany.yourapp" \
  --translations scripts/app_store_connect/app_metadata_texts.gymtimerpro.json \
  --apply
```

Target a specific version string (recommended when preparing a release):

```bash
python3 scripts/app_store_connect/update_app_metadata_localizations.py \
  --bundle-id "com.yourcompany.yourapp" \
  --translations scripts/app_store_connect/app_metadata_texts.gymtimerpro.json \
  --version-string "1.0" \
  --apply
```

## App screenshots upload (dry-run first)

By default, the uploader scans:

- `fastlane/frameit/results/screenshots` -> `APP_IPHONE_67`
- `fastlane/frameit/results/screenshots-ipad` -> `APP_IPAD_PRO_129`

Each subfolder name is treated as locale (e.g. `es`, `en-US`, `pt-BR`) and all images inside it are uploaded in sorted order.

```bash
python3 scripts/app_store_connect/upload_app_screenshots.py \
  --bundle-id "com.yourcompany.yourapp"
```

Only validate local folder discovery (no ASC API calls):

```bash
python3 scripts/app_store_connect/upload_app_screenshots.py \
  --bundle-id "com.yourcompany.yourapp" \
  --scan-only
```

Apply real uploads:

```bash
python3 scripts/app_store_connect/upload_app_screenshots.py \
  --bundle-id "com.yourcompany.yourapp" \
  --version-string "1.0" \
  --apply
```

Safer replace mode (recommended): upload first, delete old only after processing succeeds.

```bash
python3 scripts/app_store_connect/upload_app_screenshots.py \
  --bundle-id "com.yourcompany.yourapp" \
  --version-string "1.0" \
  --replace-strategy safe \
  --apply
```

Useful options:

- `--skip-ipad` or `--skip-iphone`
- `--keep-existing` (do not delete existing ASC screenshots before upload)
- `--replace-strategy safe|eager` (`safe` is default)
- `--iphone-display-type` / `--ipad-display-type` (override ASC display type constants)
- `--prefer-existing-display-type` (reuse existing locale display type when possible)
