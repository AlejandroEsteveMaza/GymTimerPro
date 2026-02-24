#!/usr/bin/env bash
set -euo pipefail

# Complete App Store Connect API examples for:
# - listing subscription localizations
# - modifying existing localization (PATCH)
# - creating missing localization (POST)
#
# Required env:
#   ASC_KEY_ID
#   ASC_ISSUER_ID
#   ASC_PRIVATE_KEY_PATH

ASC_TOKEN="$(python3 scripts/app_store_connect/asc_token.py)"

# Example 1: list subscriptions by productId.
curl -sS -G \
  -H "Authorization: Bearer ${ASC_TOKEN}" \
  -H "Accept: application/json" \
  --data-urlencode "filter[productId]=premium_monthly,premium_yearly" \
  --data-urlencode "fields[subscriptions]=name,productId" \
  --data-urlencode "limit=200" \
  "https://api.appstoreconnect.apple.com/v1/subscriptions"

# Fill this with a real subscription ID from the previous response.
SUBSCRIPTION_ID="REPLACE_WITH_SUBSCRIPTION_ID"

# Example 2: list localizations for one subscription.
curl -sS -G \
  -H "Authorization: Bearer ${ASC_TOKEN}" \
  -H "Accept: application/json" \
  --data-urlencode "fields[subscriptionLocalizations]=locale,name,description" \
  --data-urlencode "limit=200" \
  "https://api.appstoreconnect.apple.com/v1/subscriptions/${SUBSCRIPTION_ID}/subscriptionLocalizations"

# Fill this with a real localization ID to update existing text.
LOCALIZATION_ID="REPLACE_WITH_LOCALIZATION_ID"

# Example 3: modify existing localization (PATCH).
curl -sS -X PATCH \
  -H "Authorization: Bearer ${ASC_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "https://api.appstoreconnect.apple.com/v1/subscriptionLocalizations/${LOCALIZATION_ID}" \
  -d '{
    "data": {
      "type": "subscriptionLocalizations",
      "id": "'"${LOCALIZATION_ID}"'",
      "attributes": {
        "name": "GymTimer Pro Yearly",
        "description": "Full yearly access with best value."
      }
    }
  }'

# Example 4: create a new localization if it does not exist (POST).
curl -sS -X POST \
  -H "Authorization: Bearer ${ASC_TOKEN}" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  "https://api.appstoreconnect.apple.com/v1/subscriptionLocalizations" \
  -d '{
    "data": {
      "type": "subscriptionLocalizations",
      "attributes": {
        "locale": "fr-FR",
        "name": "GymTimer Pro Annuel",
        "description": "Acces annuel complet, meilleur rapport."
      },
      "relationships": {
        "subscription": {
          "data": {
            "type": "subscriptions",
            "id": "'"${SUBSCRIPTION_ID}"'"
          }
        }
      }
    }
  }'
