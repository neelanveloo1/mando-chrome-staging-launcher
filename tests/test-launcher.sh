#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LAUNCHER="$ROOT/Mando Chrome.app/Contents/Resources/launcher.sh"

/bin/bash -n "$LAUNCHER"
/bin/bash -n "$ROOT/install-mando-chrome.sh"
/bin/bash -n "$ROOT/store-github-token-in-keychain.sh"
/bin/bash -n "$ROOT/uninstall-mando-chrome.sh"
/bin/bash -n "$ROOT/Mando Chrome.app/Contents/Resources/monitor.sh"
/bin/bash -n "$ROOT/Open Mando Status.command"

if /usr/bin/grep -En '(^|[^[:alnum:]_])(kill|killall|pkill)([^[:alnum:]_]|$)' "$LAUNCHER"; then
  /bin/echo "Forbidden process-termination command found." >&2
  exit 1
fi

if /usr/bin/grep -F '/Applications/Google Chrome.app' "$LAUNCHER"; then
  /bin/echo "Launcher must use the Chrome bundle identifier, not modify or target the app path." >&2
  exit 1
fi

if /usr/bin/grep -Ei 'runtime\.reload|chrome://extensions|tell application[[:space:]]+"Google Chrome"[[:space:]]+to[[:space:]]+quit' "$LAUNCHER"; then
  /bin/echo "Forbidden Chrome reload, extensions-page automation, or quit command found." >&2
  exit 1
fi

for retry_flag in '--retry 4' '--retry-delay 2' '--retry-max-time 90' '--retry-all-errors'; do
  /usr/bin/grep -F -- "$retry_flag" "$LAUNCHER" >/dev/null
done

/usr/bin/grep -F 'readonly MINIMUM_CHROME_MAJOR=116' "$LAUNCHER" >/dev/null
/usr/bin/grep -F '/usr/bin/xattr -cr "$TEMP_APP"' "$ROOT/install-mando-chrome.sh" >/dev/null
/usr/bin/grep -F '/usr/bin/codesign --verify --deep --strict "$TEMP_APP"' "$ROOT/install-mando-chrome.sh" >/dev/null
if /usr/bin/grep -F 'codesign --force --deep --sign - "$DEST_APP"' "$ROOT/install-mando-chrome.sh"; then
  /bin/echo "Installer must verify the temporary app before replacing the installed app." >&2
  exit 1
fi

# Load helper functions without running main.
# macOS-specific commands are not invoked by these unit checks.
source "$LAUNCHER"

TMP_DIR="$(mktemp -d)"
trap '/bin/rm -rf "$TMP_DIR"' EXIT
printf 'mando-chrome-test' > "$TMP_DIR/blob"

# Authentication discovery must not depend on a successful GitHub API call.
# This fake CLI exposes a local credential while simulating an API outage.
cat > "$TMP_DIR/gh" <<'FAKE_GH'
#!/bin/bash
if [[ "$*" == "auth token -h github.com" ]]; then
  echo "test-token"
  exit 0
fi
if [[ "$1" == "api" ]]; then
  echo "simulated GitHub API outage" >&2
  exit 1
fi
exit 1
FAKE_GH
chmod +x "$TMP_DIR/gh"
MANDO_STAGING_GH_BIN="$TMP_DIR/gh"
GH_BIN=""
GITHUB_MODE=""
GITHUB_TOKEN=""
configure_github_auth
[[ "$GH_BIN" == "$TMP_DIR/gh" ]]
[[ "$GITHUB_MODE" == "token" ]]
[[ "$GITHUB_TOKEN" == "test-token" ]]

if [[ "$(uname -s)" == "Darwin" ]]; then
  EXPECTED="$(/usr/bin/shasum -a 256 "$TMP_DIR/blob" | /usr/bin/awk '{print $1}')"
  ACTUAL="$(compute_sha256 "$TMP_DIR/blob")"
  [[ "$ACTUAL" == "$EXPECTED" ]]
  [[ "$ACTUAL" =~ ^[0-9a-f]{64}$ ]]

  # Release selection: skip rollback builds, drafts, listing branches and a
  # develop release still missing its zip; take the newest complete develop one.
  GOOD_SHA="$(printf '%064d' 7)"
  cat > "$TMP_DIR/releases.json" <<RELEASES
[
  {"tag_name": "ext/v1.93.120", "name": "Extension 1.93.120 (rollback)", "draft": false,
   "assets": [{"name": "dist-staging.zip", "id": 1, "size": 10, "digest": "sha256:$(printf '%064d' 1)"}]},
  {"tag_name": "ext/v1.93.119", "name": "Extension 1.93.119 (develop)", "draft": true,
   "assets": [{"name": "dist-staging.zip", "id": 2, "size": 10, "digest": "sha256:$(printf '%064d' 2)"}]},
  {"tag_name": "ext/v1.93.118", "name": "Extension 1.93.118 (main)", "draft": false,
   "assets": [{"name": "dist-staging.zip", "id": 3, "size": 10, "digest": "sha256:$(printf '%064d' 3)"}]},
  {"tag_name": "ext/v1.93.117", "name": "Extension 1.93.117 (develop)", "draft": false,
   "assets": [{"name": "SHA256SUMS", "id": 4, "size": 10, "digest": "sha256:$(printf '%064d' 4)"}]},
  {"tag_name": "v9.9.9", "name": "Launcher 9.9.9 (develop)", "draft": false,
   "assets": [{"name": "dist-staging.zip", "id": 5, "size": 10, "digest": "sha256:$(printf '%064d' 5)"}]},
  {"tag_name": "ext/v1.93.116", "name": "Extension 1.93.116 (develop)", "draft": false,
   "assets": [{"name": "dist-prod.zip", "id": 6, "size": 11, "digest": "sha256:$(printf '%064d' 6)"},
              {"name": "dist-staging.zip", "id": 7, "size": 2160505, "digest": "sha256:$GOOD_SHA"}]},
  {"tag_name": "ext/v1.93.115", "name": "Extension 1.93.115 (develop)", "draft": false,
   "assets": [{"name": "dist-staging.zip", "id": 8, "size": 10, "digest": "sha256:$(printf '%064d' 8)"}]}
]
RELEASES
  select_staging_release "$TMP_DIR/releases.json"
  [[ "$REMOTE_TAG" == "ext/v1.93.116" ]]
  [[ "$REMOTE_VERSION" == "1.93.116" ]]
  [[ "$REMOTE_ASSET_ID" == "7" ]]
  [[ "$REMOTE_SIZE" == "2160505" ]]
  [[ "$REMOTE_SHA" == "$GOOD_SHA" ]]

  # No usable release at all must fail rather than install anything.
  printf '[{"tag_name": "ext/v1.0.0", "name": "Extension 1.0.0 (main)", "draft": false, "assets": []}]' > "$TMP_DIR/none.json"
  ! select_staging_release "$TMP_DIR/none.json"
  [[ -z "$REMOTE_SHA" ]]

  # A digest that is not sha256 is not an identity.
  printf '[{"tag_name": "ext/v1.0.0", "name": "Extension 1.0.0 (develop)", "draft": false, "assets": [{"name": "dist-staging.zip", "id": 9, "size": 10, "digest": "md5:abc"}]}]' > "$TMP_DIR/bad.json"
  ! select_staging_release "$TMP_DIR/bad.json"
fi

validate_zip_entry 'dist-staging/manifest.json'
! validate_zip_entry '../manifest.json'
! validate_zip_entry '/absolute/manifest.json'
! validate_zip_entry 'folder\\manifest.json'

chrome_version_is_supported '116.0.5845.96'
chrome_version_is_supported '151.0.7922.138'
! chrome_version_is_supported '115.0.5790.170'
! chrome_version_is_supported 'not-a-version'

/bin/echo "Launcher static tests passed."
