#!/bin/bash
set -euo pipefail

SERVICE="com.mando.staging.github"
ACCOUNT="$USER"

if [[ "$(/usr/bin/uname -s)" != "Darwin" ]]; then
  /bin/echo "This helper only runs on macOS." >&2
  exit 1
fi

/bin/echo "Paste a fine-grained GitHub token with read-only Contents access to MandoHQ/app."
/bin/echo "The token stays on this Mac and is stored in macOS Keychain."
printf "Token: "
IFS= read -r -s TOKEN
/bin/echo

if [[ -z "$TOKEN" ]]; then
  /bin/echo "No token entered." >&2
  exit 1
fi

/usr/bin/security add-generic-password \
  -U \
  -a "$ACCOUNT" \
  -s "$SERVICE" \
  -w "$TOKEN" >/dev/null

unset TOKEN
/bin/echo "Stored in Keychain service: $SERVICE"
