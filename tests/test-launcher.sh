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

if command -v git >/dev/null 2>&1; then
  EXPECTED="$(git hash-object "$TMP_DIR/blob")"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    ACTUAL="$(compute_git_blob_sha "$TMP_DIR/blob")"
    [[ "$ACTUAL" == "$EXPECTED" ]]
  fi
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
