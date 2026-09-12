#!/bin/bash
set -euo pipefail
RESOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RESOURCE_DIR/launcher.sh"
exec 3>&1
exec 1>&2
umask 077
/bin/mkdir -p "$CACHE_DIR"
WORK_ROOT=$(/usr/bin/mktemp -d "$CACHE_DIR/live.XXXXXX")
check=ok
sha=""
if ! configure_github_auth; then
  check=auth_error
elif ! {
  printf 'url = "https://api.github.com/%s"\n' "$CONTENTS_ENDPOINT"
  printf 'header = "Authorization: Bearer %s"\n' "$GITHUB_TOKEN"
  printf 'header = "Accept: application/vnd.github+json"\n'
} | /usr/bin/curl --config - --fail --silent --show-error --connect-timeout 3 --max-time 10 --proto '=https' --output "$WORK_ROOT/latest.json"; then
  check=github_error
else
  sha="$(plist_extract sha "$WORK_ROOT/latest.json" || true)"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { check=github_error; sha=""; }
fi
printf '{"check":"%s","latestSha":"%s","checkedAt":"%s"}\n' "$check" "$sha" "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" >&3
