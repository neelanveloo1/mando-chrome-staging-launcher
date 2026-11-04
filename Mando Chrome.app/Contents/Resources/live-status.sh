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
  printf 'url = "https://api.github.com/%s"\n' "$RELEASES_ENDPOINT"
  printf 'header = "Authorization: Bearer %s"\n' "$GITHUB_TOKEN"
  printf 'header = "Accept: application/vnd.github+json"\n'
  printf 'header = "X-GitHub-Api-Version: 2022-11-28"\n'
} | /usr/bin/curl --config - --fail --silent --show-error --connect-timeout 3 --max-time 10 --proto '=https' --output "$WORK_ROOT/latest.json"; then
  check=github_error
elif select_staging_release "$WORK_ROOT/latest.json"; then
  sha="$REMOTE_SHA"
else
  check=github_error
fi
printf '{"check":"%s","latestSha":"%s","checkedAt":"%s"}\n' "$check" "$sha" "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')" >&3
