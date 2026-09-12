#!/bin/bash
set -euo pipefail
umask 077
RESOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RESOURCE_DIR/launcher.sh"
umask 077
STATUS_URL="https://mando-chrome-status.vercel.app"
STATUS_DIR="$HOME/Library/Application Support/MandoChrome"
TOKEN_FILE="$STATUS_DIR/device-token"
/bin/mkdir -p "$STATUS_DIR" "$CACHE_DIR" "$HOME/Library/Logs/MandoChrome"
/bin/chmod 700 "$STATUS_DIR"
if [[ ! -s "$TOKEN_FILE" ]]; then /usr/bin/openssl rand -hex 32 > "$TOKEN_FILE"; fi
/bin/chmod 600 "$TOKEN_FILE"
# LaunchAgent never overlaps its own jobs. WORK_ROOT is unique for manual tests.
WORK_ROOT=$(/usr/bin/mktemp -d "$CACHE_DIR/health.XXXXXX")
check="ok"
remote_sha=""
version="$(resolve_chrome_version || true)"
chrome_running=0
is_chrome_running && chrome_running=1
if ! chrome_version_is_supported "$version"; then
  check="unsupported_chrome"
elif ! configure_github_auth; then
  check="auth_error"
elif ! fetch_metadata "$WORK_ROOT/metadata.json"; then
  check="github_error"
else
  remote_sha="$(plist_extract sha "$WORK_ROOT/metadata.json" || true)"
  [[ "$remote_sha" =~ ^[0-9a-f]{40}$ ]] || check="github_error"
fi
if [[ "$check" == "ok" && "$(read_installed_sha || true)" != "$remote_sha" && "$chrome_running" == "0" ]]; then
  # The updater checks Chrome again before replacing any files. Background mode
  # never opens or quits Chrome and never raises a blocking dialog.
  if ! MANDO_STAGING_BACKGROUND=1 /bin/bash "$RESOURCE_DIR/launcher.sh" >> "$HOME/Library/Logs/MandoChrome/launcher.log" 2>&1; then
    check="update_failed"
  fi
fi
chrome_running=0
is_chrome_running && chrome_running=1
/usr/bin/osascript -l JavaScript "$RESOURCE_DIR/health.js" "$check" "$remote_sha" "$version" "$chrome_running" > "$WORK_ROOT/report.json"
/bin/cp "$WORK_ROOT/report.json" "$STATUS_DIR/status.json"
device_token="$(/bin/cat "$TOKEN_FILE")"
[[ "$device_token" =~ ^[a-f0-9]{64}$ ]] || exit 1
{
  printf 'url = "%s/api/status"\n' "$STATUS_URL"
  printf 'header = "Authorization: Bearer %s"\n' "$device_token"
  printf 'header = "Content-Type: application/json"\n'
} | /usr/bin/curl --config - --fail --silent --show-error --connect-timeout 10 --max-time 25 --proto '=https' --data-binary "@$WORK_ROOT/report.json" --output /dev/null
log "Status reported: $check; installed $(read_installed_sha || true); latest $remote_sha; Chrome running $chrome_running"
