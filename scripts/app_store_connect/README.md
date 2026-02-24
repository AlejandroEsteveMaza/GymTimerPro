# App Store Connect subscription localization updater

This folder contains scripts to update subscription texts (`name` + `description`)
for all locales of:

- `premium_monthly`
- `premium_yearly`

## Files

- `asc_token.py`: generate ASC JWT token from env vars.
- `update_subscription_localizations.py`: dry-run/apply updater.
- `subscription_texts.example.json`: translation payload example.
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
