#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
umask 022

readonly APP_NAME="Mando Chrome"
readonly REPOSITORY="MandoHQ/app"
readonly BRANCH="develop"
readonly ARTIFACT_PATH="extension/dist-staging.zip"
readonly CONTENTS_ENDPOINT="repos/${REPOSITORY}/contents/${ARTIFACT_PATH}?ref=${BRANCH}"
readonly EXTENSION_DIR="$HOME/Mando/StagingExtension"
readonly PREVIOUS_DIR="$HOME/Mando/StagingExtension.previous"
readonly TRANSACTION_BACKUP="$HOME/Mando/.StagingExtension.transaction-backup"
readonly BASE_DIR="$HOME/Mando"
readonly CACHE_DIR="$HOME/Library/Caches/MandoChrome"
readonly LOCK_DIR="$CACHE_DIR/update.lock"
readonly METADATA_FILENAME="mando-chrome-artifact.json"
readonly KEYCHAIN_SERVICE="com.mando.staging.github"
readonly EXPECTED_EXTENSION_NAME="Mando AI Docs - Staging"
readonly EXPECTED_MANIFEST_KEY="MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqn39itC3mZAW6/7I9rjunHk+14DSB6ossoq/t5tr75i+oMCI0gBNdzYXck0E4wydlFYql0FJRrbdXWUwsbyYbPzleIj9h1XztlDq5ZOLEXGdd2YP2l//AppCpUDfLkm2suV3C8hlhxq55+YFF7xxMm9ayHy0Mzl4gljJQOWizp0rOO+q4gLDc3KT2X14hWaQ7ZL78TkSzbEuaMCYc6WOGgddglIfcwrESyvU7y1RC3+rmCsJI1O2t4JFrzCvxhIGQGJZttVGCpBycMsED9Q4XGC058TcyUyd1RbWoLMrrLt3amWRybz2645mKEGtn1qxq7KqQZdz/34OTOkFfukp8wIDAQAB"
readonly STALE_MESSAGE="Mando Chrome has been updated. Close Chrome when convenient, then reopen it using Mando Chrome."
readonly AUTH_MESSAGE="Mando Chrome cannot read the private staging build. Sign in with GitHub CLI, or store a read-only token in macOS Keychain."
readonly VERIFY_MESSAGE="Mando Chrome could not verify the latest build. Existing extension files were left untouched."
readonly DOWNLOAD_MESSAGE="GitHub did not finish the staging download after several automatic retries. Existing extension files were left untouched. Close Chrome and try Mando Chrome again in a minute."
readonly CHROME_BUNDLE_ID="com.google.Chrome"
readonly MINIMUM_CHROME_MAJOR=116
readonly RESOURCE_DIR_LAUNCHER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WORK_ROOT=""
LOCK_HELD=0
GITHUB_MODE=""
GH_BIN=""
GITHUB_TOKEN=""

log() {
  /bin/echo "$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ') $*"
}

show_alert() {
  local title="$1"
  local message="$2"
  log "ALERT: $title: $message"
  if [[ "${MANDO_STAGING_NO_UI:-0}" == "1" || "${MANDO_STAGING_BACKGROUND:-0}" == "1" ]]; then
    return 0
  fi
  /usr/bin/osascript - "$title" "$message" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display alert (item 1 of argv) message (item 2 of argv) as critical buttons {"OK"} default button "OK"
end run
APPLESCRIPT
}

show_notification() {
  local message="$1"
  log "NOTIFICATION: $message"
  if [[ "${MANDO_STAGING_NO_UI:-0}" == "1" || "${MANDO_STAGING_BACKGROUND:-0}" == "1" ]]; then
    return 0
  fi
  /usr/bin/osascript - "$message" <<'APPLESCRIPT' >/dev/null 2>&1 || true
on run argv
  display notification (item 1 of argv) with title "Mando Chrome"
end run
APPLESCRIPT
}

cleanup() {
  local exit_code=$?
  trap - EXIT HUP INT TERM
  if [[ -n "$WORK_ROOT" && -d "$WORK_ROOT" ]]; then
    /bin/rm -rf -- "$WORK_ROOT"
  fi
  if [[ "$LOCK_HELD" == "1" && -d "$LOCK_DIR" ]]; then
    /bin/rm -rf -- "$LOCK_DIR"
  fi
  exit "$exit_code"
}
trap cleanup EXIT HUP INT TERM

fail() {
  local title="$1"
  local user_message="$2"
  local technical_message="${3:-$2}"
  log "ERROR: $technical_message"
  show_alert "$title" "$user_message"
  exit 1
}

acquire_lock() {
  /bin/mkdir -p "$CACHE_DIR"
  /bin/chmod 700 "$CACHE_DIR" 2>/dev/null || true

  if /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_HELD=1
    /bin/echo "$$" > "$LOCK_DIR/pid"
    return 0
  fi

  local now modified age
  now=$(/bin/date +%s)
  modified=$(/usr/bin/stat -f '%m' "$LOCK_DIR" 2>/dev/null || /bin/echo 0)
  age=$((now - modified))

  if (( age > 900 )); then
    log "Removing updater lock older than 15 minutes"
    /bin/rm -rf -- "$LOCK_DIR"
    if /bin/mkdir "$LOCK_DIR" 2>/dev/null; then
      LOCK_HELD=1
      /bin/echo "$$" > "$LOCK_DIR/pid"
      return 0
    fi
  fi

  show_alert "Mando Chrome is already running" "Another update check is already in progress."
  exit 0
}

is_chrome_running() {
  if [[ -n "${MANDO_STAGING_TEST_CHROME_RUNNING:-}" ]]; then
    [[ "$MANDO_STAGING_TEST_CHROME_RUNNING" == "1" ]]
    return
  fi

  local result
  result=$(/usr/bin/osascript -l JavaScript -e \
    'ObjC.import("AppKit"); $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.google.Chrome").count > 0' \
    2>/dev/null || /bin/echo "false")
  [[ "$result" == "true" ]]
}

resolve_chrome_version() {
  local version
  version=$(/usr/bin/osascript -l JavaScript <<'JAVASCRIPT' 2>/dev/null || true
(function () {
  ObjC.import("AppKit");
  ObjC.import("Foundation");
  const appURL = $.NSWorkspace.sharedWorkspace.URLForApplicationWithBundleIdentifier("com.google.Chrome");
  if (!appURL) return "";
  const bundle = $.NSBundle.bundleWithURL(appURL);
  const value = bundle.objectForInfoDictionaryKey("CFBundleShortVersionString");
  return value ? ObjC.unwrap(value) : "";
})();
JAVASCRIPT
)
  [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || return 1
  /bin/echo "$version"
}

chrome_version_is_supported() {
  local version="$1"
  local major="${version%%.*}"
  [[ "$version" =~ ^[0-9]+(\.[0-9]+)*$ ]] || return 1
  (( 10#$major >= MINIMUM_CHROME_MAJOR ))
}

ensure_supported_chrome() {
  local version
  version="$(resolve_chrome_version || true)"
  if [[ -z "$version" ]]; then
    fail "Google Chrome was not found" "Install Google Chrome, then open Mando Chrome again."
  fi
  if ! chrome_version_is_supported "$version"; then
    fail "Google Chrome needs an update" "Mando Chrome requires Google Chrome 116 or later. Update Chrome from Chrome > About Google Chrome, then open Mando Chrome again." "Unsupported Google Chrome version $version; minimum is $MINIMUM_CHROME_MAJOR"
  fi
  log "Google Chrome version $version satisfies minimum $MINIMUM_CHROME_MAJOR"
}

open_chrome() {
  [[ "${MANDO_STAGING_BACKGROUND:-0}" == "1" ]] && return 0
  log "Opening Chrome by bundle identifier"
  if ! /usr/bin/open -b "$CHROME_BUNDLE_ID"; then
    fail "Google Chrome was not found" "Install Google Chrome, then open Mando Chrome again."
  fi
}

resolve_gh() {
  local candidate
  for candidate in \
    "${MANDO_STAGING_GH_BIN:-}" \
    "/opt/homebrew/bin/gh" \
    "/usr/local/bin/gh" \
    "/usr/bin/gh"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      /bin/echo "$candidate"
      return 0
    fi
  done
  return 1
}

configure_github_auth() {
  local cli_token=""
  GH_BIN="$(resolve_gh || true)"
  # Credential discovery must stay local. A live `gh api user` probe makes a
  # transient GitHub/API/network failure look like a missing login even when
  # Finder-launched apps can read the same Keychain credential as Terminal.
  if [[ -n "$GH_BIN" ]]; then
    cli_token="$("$GH_BIN" auth token -h github.com 2>/dev/null || true)"
  fi
  if [[ -n "$cli_token" ]]; then
    # Use the same curl path as the direct-Keychain fallback. gh 2.87.2 can
    # corrupt/fail on binary Contents API output with "transform: short source
    # buffer" even though metadata requests work. curl receives the raw bytes
    # without putting the credential in its process arguments.
    GITHUB_MODE="token"
    GITHUB_TOKEN="$cli_token"
    log "Using GitHub CLI credential from $GH_BIN"
    return 0
  fi

  if [[ -x /usr/bin/security ]]; then
    GITHUB_TOKEN=$(/usr/bin/security find-generic-password \
      -a "$USER" \
      -s "$KEYCHAIN_SERVICE" \
      -w 2>/dev/null || true)
  fi

  if [[ -n "$GITHUB_TOKEN" ]]; then
    GITHUB_MODE="token"
    log "Using GitHub token from macOS Keychain"
    return 0
  fi

  return 1
}

curl_github_to_file() {
  local accept_header="$1"
  local url="$2"
  local destination="$3"

  # Read the credential through stdin rather than exposing it in curl's process arguments.
  {
    printf 'url = "%s"\n' "$url"
    printf 'header = "Authorization: Bearer %s"\n' "$GITHUB_TOKEN"
    printf 'header = "Accept: %s"\n' "$accept_header"
    printf 'header = "X-GitHub-Api-Version: 2022-11-28"\n'
    printf 'header = "User-Agent: mando-chrome-launcher"\n'
  } | /usr/bin/curl \
    --config - \
    --fail \
    --location \
    --silent \
    --show-error \
    --connect-timeout 10 \
    --max-time 120 \
    --retry 4 \
    --retry-delay 2 \
    --retry-max-time 90 \
    --retry-all-errors \
    --proto '=https' \
    --tlsv1.2 \
    --output "$destination"
}

fetch_metadata() {
  local destination="$1"
  if [[ "$GITHUB_MODE" == "gh" ]]; then
    "$GH_BIN" api \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$CONTENTS_ENDPOINT" > "$destination"
  else
    curl_github_to_file \
      "application/vnd.github+json" \
      "https://api.github.com/${CONTENTS_ENDPOINT}" \
      "$destination"
  fi
}

fetch_artifact() {
  local destination="$1"
  if [[ "$GITHUB_MODE" == "gh" ]]; then
    "$GH_BIN" api \
      -H "Accept: application/vnd.github.raw+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$CONTENTS_ENDPOINT" > "$destination"
  else
    curl_github_to_file \
      "application/vnd.github.raw+json" \
      "https://api.github.com/${CONTENTS_ENDPOINT}" \
      "$destination"
  fi
}

plist_extract() {
  local key="$1"
  local file="$2"
  /usr/bin/plutil -extract "$key" raw -o - "$file" 2>/dev/null
}

file_size() {
  /usr/bin/stat -f '%z' "$1"
}

compute_git_blob_sha() {
  local file="$1"
  local size
  size="$(file_size "$file")"
  {
    printf 'blob %s\0' "$size"
    /bin/cat "$file"
  } | /usr/bin/shasum -a 1 | /usr/bin/awk '{print $1}'
}

bridge_is_current() {
  local marker="$EXTENSION_DIR/mando-health-bridge.json"
  [[ -f "$marker" ]] && [[ "$(plist_extract version "$marker" || true)" == "4" ]] && [[ "$(plist_extract artifactSha "$marker" || true)" == "$(read_installed_sha || true)" ]]
}

read_installed_sha() {
  local metadata="$EXTENSION_DIR/$METADATA_FILENAME"
  if [[ ! -f "$metadata" ]]; then
    return 1
  fi
  plist_extract "artifact_sha" "$metadata"
}

validate_zip_entry() {
  local entry="$1"
  local normalized="${entry%/}"

  [[ -n "$entry" ]] || return 0
  [[ "$entry" != /* ]] || return 1
  [[ "$entry" != *'\\'* ]] || return 1
  [[ "$entry" != *$'\r'* ]] || return 1
  [[ "$normalized" != *:* ]] || return 1

  case "/$normalized/" in
    *"/../"*) return 1 ;;
  esac

  return 0
}

validate_zip_paths() {
  local zip_file="$1"
  local entry
  while IFS= read -r entry; do
    if ! validate_zip_entry "$entry"; then
      log "Unsafe ZIP entry rejected: $entry"
      return 1
    fi
  done < <(/usr/bin/unzip -Z1 "$zip_file")
}

validate_manifest() {
  local root="$1"
  local manifest="$root/manifest.json"
  local manifest_version name key

  [[ -f "$manifest" ]] || return 1

  manifest_version="$(plist_extract "manifest_version" "$manifest" || true)"
  name="$(plist_extract "name" "$manifest" || true)"
  key="$(plist_extract "key" "$manifest" || true)"

  [[ "$manifest_version" == "3" ]] || return 1
  [[ "$name" == "$EXPECTED_EXTENSION_NAME" ]] || return 1
  [[ "$key" == "$EXPECTED_MANIFEST_KEY" ]] || return 1

  return 0
}

find_extension_root() {
  local extract_dir="$1"
  local item
  local -a top_entries=()

  if [[ -f "$extract_dir/manifest.json" ]]; then
    /bin/echo "$extract_dir"
    return 0
  fi

  while IFS= read -r -d '' item; do
    top_entries+=("$item")
  done < <(/usr/bin/find "$extract_dir" \
    -mindepth 1 \
    -maxdepth 1 \
    ! -name '__MACOSX' \
    ! -name '.DS_Store' \
    -print0)

  if [[ "${#top_entries[@]}" -ne 1 ]]; then
    return 1
  fi

  if [[ ! -d "${top_entries[0]}" || ! -f "${top_entries[0]}/manifest.json" ]]; then
    return 1
  fi

  /bin/echo "${top_entries[0]}"
}

write_artifact_metadata() {
  local root="$1"
  local artifact_sha="$2"
  local installed_at
  installed_at=$(/bin/date -u '+%Y-%m-%dT%H:%M:%SZ')

  /bin/cat > "$root/$METADATA_FILENAME" <<JSON
{
  "artifact_sha": "$artifact_sha",
  "installed_at": "$installed_at"
}
JSON
}

fail_update_and_open_chrome() {
  local title="$1"
  local user_message="$2"
  local technical_message="${3:-$2}"
  log "ERROR: $technical_message"
  show_alert "$title" "$user_message"
  open_chrome
  exit 1
}

recover_interrupted_install() {
  [[ -e "$TRANSACTION_BACKUP" ]] || return 0

  log "Recovering an interrupted staging extension transaction"
  if [[ ! -e "$EXTENSION_DIR" ]]; then
    /bin/mv -- "$TRANSACTION_BACKUP" "$EXTENSION_DIR"
    return 0
  fi

  local recovered_sha
  recovered_sha="$(read_installed_sha || true)"
  if validate_manifest "$EXTENSION_DIR" && [[ "$recovered_sha" =~ ^[0-9a-f]{40}$ ]]; then
    /bin/rm -rf -- "$PREVIOUS_DIR"
    /bin/mv -- "$TRANSACTION_BACKUP" "$PREVIOUS_DIR"
    return 0
  fi

  /bin/rm -rf -- "$EXTENSION_DIR"
  /bin/mv -- "$TRANSACTION_BACKUP" "$EXTENSION_DIR"
}

install_candidate_transactionally() {
  local candidate="$1"
  local artifact_sha="$2"
  local had_previous=0
  local installed_sha

  /bin/rm -rf -- "$TRANSACTION_BACKUP"

  if [[ -e "$EXTENSION_DIR" ]]; then
    /bin/mv -- "$EXTENSION_DIR" "$TRANSACTION_BACKUP"
    had_previous=1
  fi

  if ! /bin/mv -- "$candidate" "$EXTENSION_DIR"; then
    if [[ "$had_previous" == "1" && -e "$TRANSACTION_BACKUP" ]]; then
      /bin/mv -- "$TRANSACTION_BACKUP" "$EXTENSION_DIR" || true
    fi
    return 1
  fi

  installed_sha="$(read_installed_sha || true)"
  if ! validate_manifest "$EXTENSION_DIR" || [[ "$installed_sha" != "$artifact_sha" ]]; then
    /bin/rm -rf -- "$EXTENSION_DIR"
    if [[ "$had_previous" == "1" && -e "$TRANSACTION_BACKUP" ]]; then
      /bin/mv -- "$TRANSACTION_BACKUP" "$EXTENSION_DIR" || true
    fi
    return 1
  fi

  if [[ "$had_previous" == "1" && -e "$TRANSACTION_BACKUP" ]]; then
    /bin/rm -rf -- "$PREVIOUS_DIR"
    if ! /bin/mv -- "$TRANSACTION_BACKUP" "$PREVIOUS_DIR"; then
      log "Could not rotate last-known-good backup; leaving $TRANSACTION_BACKUP in place"
    fi
  fi

  /bin/chmod -R u+rwX,go+rX "$EXTENSION_DIR" 2>/dev/null || true
  return 0
}

main() {
  local metadata_file remote_sha remote_size installed_sha
  local chrome_was_running zip_file actual_size computed_sha extract_dir candidate

  [[ "$(/usr/bin/uname -s)" == "Darwin" ]] || fail "$APP_NAME" "This launcher only runs on macOS."

  ensure_supported_chrome

  /bin/mkdir -p "$BASE_DIR" "$CACHE_DIR"
  /bin/chmod 700 "$BASE_DIR" "$CACHE_DIR" 2>/dev/null || true
  acquire_lock

  chrome_was_running=0
  if is_chrome_running; then
    chrome_was_running=1
  fi

  if [[ -e "$TRANSACTION_BACKUP" ]]; then
    if [[ "$chrome_was_running" == "1" ]]; then
      show_alert "Mando Chrome recovery required" "A prior update was interrupted. Close Chrome normally, then reopen it using Mando Chrome. No extension files were changed while Chrome was running."
      open_chrome
      exit 0
    fi
    if ! recover_interrupted_install; then
      fail_update_and_open_chrome "Staging recovery failed" "$VERIFY_MESSAGE"
    fi
  fi

  if ! configure_github_auth; then
    show_alert "GitHub sign-in required" "$AUTH_MESSAGE"
    open_chrome
    exit 1
  fi

  WORK_ROOT=$(/usr/bin/mktemp -d "$BASE_DIR/.staging-update.XXXXXX")
  metadata_file="$WORK_ROOT/github-metadata.json"

  if ! fetch_metadata "$metadata_file"; then
    fail_update_and_open_chrome "Unable to check for a staging update" "$VERIFY_MESSAGE"
  fi

  remote_sha="$(plist_extract "sha" "$metadata_file" || true)"
  remote_size="$(plist_extract "size" "$metadata_file" || true)"

  if [[ ! "$remote_sha" =~ ^[0-9a-f]{40}$ ]] || [[ ! "$remote_size" =~ ^[0-9]+$ ]]; then
    fail_update_and_open_chrome "Invalid GitHub response" "$VERIFY_MESSAGE" "GitHub metadata did not contain a valid blob SHA and size"
  fi

  installed_sha="$(read_installed_sha || true)"
  chrome_was_running=0
  if is_chrome_running; then
    chrome_was_running=1
  fi

  log "Installed SHA: ${installed_sha:-none}; required SHA: $remote_sha; Chrome running: $chrome_was_running"

  if [[ "$installed_sha" == "$remote_sha" ]] && bridge_is_current; then
    open_chrome
    exit 0
  fi

  if [[ "$chrome_was_running" == "1" ]]; then
    show_alert "Mando Chrome update required" "$STALE_MESSAGE"
    open_chrome
    exit 0
  fi

  show_notification "Installing the latest staging extension"
  zip_file="$WORK_ROOT/dist-staging.zip"

  if ! fetch_artifact "$zip_file"; then
    fail_update_and_open_chrome "Update download failed" "$DOWNLOAD_MESSAGE"
  fi

  actual_size="$(file_size "$zip_file")"
  if [[ "$actual_size" != "$remote_size" ]]; then
    fail_update_and_open_chrome "Incomplete staging download" "$VERIFY_MESSAGE" "Expected $remote_size bytes, received $actual_size"
  fi

  computed_sha="$(compute_git_blob_sha "$zip_file")"
  if [[ "$computed_sha" != "$remote_sha" ]]; then
    fail_update_and_open_chrome "Staging verification failed" "$VERIFY_MESSAGE" "Expected Git blob SHA $remote_sha, computed $computed_sha"
  fi

  if ! /usr/bin/unzip -tq "$zip_file" >/dev/null; then
    fail_update_and_open_chrome "Invalid staging ZIP" "$VERIFY_MESSAGE"
  fi

  if ! validate_zip_paths "$zip_file"; then
    fail_update_and_open_chrome "Unsafe staging ZIP" "$VERIFY_MESSAGE"
  fi

  extract_dir="$WORK_ROOT/extracted"
  /bin/mkdir -p "$extract_dir"
  if ! /usr/bin/unzip -qq "$zip_file" -d "$extract_dir"; then
    fail_update_and_open_chrome "Staging extraction failed" "$VERIFY_MESSAGE"
  fi

  if [[ -n "$(/usr/bin/find "$extract_dir" -type l -print -quit)" ]]; then
    fail_update_and_open_chrome "Invalid staging contents" "$VERIFY_MESSAGE" "ZIP contained a symbolic link"
  fi

  candidate="$(find_extension_root "$extract_dir" || true)"
  if [[ -z "$candidate" ]] || ! validate_manifest "$candidate"; then
    fail_update_and_open_chrome "Wrong staging extension" "$VERIFY_MESSAGE" "ZIP did not contain exactly one valid Mando staging extension root"
  fi

  write_artifact_metadata "$candidate" "$remote_sha"

  # Add the adapter only to the verified candidate, never the running extension.
  if ! /usr/bin/osascript -l JavaScript "$RESOURCE_DIR_LAUNCHER/prepare-bridge.js" "$candidate" "$RESOURCE_DIR_LAUNCHER" "$remote_sha"; then
    fail_update_and_open_chrome "Live status setup failed" "$VERIFY_MESSAGE"
  fi

  if is_chrome_running; then
    show_alert "Mando Chrome update required" "$STALE_MESSAGE"
    open_chrome
    exit 0
  fi

  if ! install_candidate_transactionally "$candidate" "$remote_sha"; then
    fail_update_and_open_chrome "Staging installation failed" "$VERIFY_MESSAGE" "Transactional install failed and prior files were restored"
  fi

  log "Installed staging artifact $remote_sha"
  show_notification "Mando Chrome is current"
  open_chrome
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
