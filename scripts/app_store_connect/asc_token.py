#!/usr/bin/env python3
"""
Generate a short-lived App Store Connect JWT token.

Required environment variables:
- ASC_KEY_ID
- ASC_ISSUER_ID
- ASC_PRIVATE_KEY_PATH
"""

from __future__ import annotations

import os
import time

import jwt


def load_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def main() -> None:
    key_id = load_env("ASC_KEY_ID")
    issuer_id = load_env("ASC_ISSUER_ID")
    private_key_path = load_env("ASC_PRIVATE_KEY_PATH")

    with open(private_key_path, "r", encoding="utf-8") as file:
        private_key = file.read()

    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + (19 * 60),
        "aud": "appstoreconnect-v1",
    }
    headers = {"kid": key_id, "typ": "JWT"}

    token = jwt.encode(payload, private_key, algorithm="ES256", headers=headers)
    print(token)


if __name__ == "__main__":
    main()
