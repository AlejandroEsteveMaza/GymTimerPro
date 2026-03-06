# App Store Connect localization updaters

This folder contains scripts to update:

- Subscription texts (`name` + `description`) for:
  - `premium_monthly`
  - `premium_yearly`
- App metadata localizations (`description`, `promotionalText`, `keywords`, `name`, `subtitle`, `supportUrl`, `marketingUrl`)


## Files

- `asc_token.py`: generate ASC JWT token from env vars.
- `update_subscription_localizations.py`: dry-run/apply updater.
- `subscription_texts.example.json`: translation payload example.
- `update_app_metadata_localizations.py`: app metadata localizations updater.
- `app_metadata_texts.gymtimerpro.json`: ready-to-run metadata payload.
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
