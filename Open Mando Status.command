#!/bin/bash
set -euo pipefail
TOKEN_FILE="$HOME/Library/Application Support/MandoChrome/device-token"
if [[ ! -s "$TOKEN_FILE" ]]; then
  /bin/echo "Install Mando Chrome first, then wait two minutes for the status monitor."
  exit 1
fi
token="$(/bin/cat "$TOKEN_FILE")"
[[ "$token" =~ ^[a-f0-9]{64}$ ]] || exit 1
read_token="$(printf '%s' "$token" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
/usr/bin/open "https://mando-chrome-status.vercel.app/#device=$read_token"
