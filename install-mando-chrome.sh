#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/Mando Chrome.app"
DEST_DIR="$HOME/Applications"
DEST_APP="$DEST_DIR/Mando Chrome.app"
ICON_SOURCE="$SOURCE_APP/Contents/Resources/MandoChrome.png"

if [[ "$(/usr/bin/uname -s)" != "Darwin" ]]; then
  /bin/echo "This installer only runs on macOS." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_APP" ]]; then
  /bin/echo "Mando Chrome.app is missing from the installer folder." >&2
  exit 1
fi

/bin/mkdir -p "$DEST_DIR"
TEMP_APP="$DEST_DIR/.Mando Chrome.app.install.$$"
ICONSET=""

cleanup() {
  local exit_code=$?
  trap - EXIT
  if [[ -n "$ICONSET" && -d "$ICONSET" ]]; then
    /bin/rm -rf -- "$ICONSET"
  fi
  if [[ -n "$TEMP_APP" && -d "$TEMP_APP" ]]; then
    /bin/rm -rf -- "$TEMP_APP"
  fi
  exit "$exit_code"
}
trap cleanup EXIT

/bin/rm -rf -- "$TEMP_APP"
/usr/bin/ditto "$SOURCE_APP" "$TEMP_APP"
/bin/chmod +x "$TEMP_APP/Contents/MacOS/mando-chrome" "$TEMP_APP/Contents/Resources/launcher.sh"

create_icns() {
  [[ -f "$ICON_SOURCE" ]] || return 0
  local iconbase
  iconbase=$(/usr/bin/mktemp -d "/tmp/MandoChrome.XXXXXX")
  ICONSET="${iconbase}.iconset"
  /bin/mv -- "$iconbase" "$ICONSET"

  /usr/bin/sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
  /usr/bin/sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  /usr/bin/sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
  /usr/bin/sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  /usr/bin/sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
  /usr/bin/sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  /usr/bin/sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
  /usr/bin/sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  /usr/bin/sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
  /usr/bin/sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

  /usr/bin/iconutil -c icns "$ICONSET" -o "$TEMP_APP/Contents/Resources/MandoChrome.icns"
  /bin/rm -rf -- "$ICONSET"
  ICONSET=""
}

create_icns

if [[ -x /usr/bin/codesign ]]; then
  /usr/bin/xattr -cr "$TEMP_APP"
  /usr/bin/codesign --force --deep --sign - "$TEMP_APP"
  /usr/bin/codesign --verify --deep --strict "$TEMP_APP"
fi

/bin/rm -rf -- "$DEST_APP"
/bin/mv -- "$TEMP_APP" "$DEST_APP"
TEMP_APP=""

/bin/echo
/bin/echo "Installed: $DEST_APP"
/bin/echo
/bin/echo "Authentication check:"
GH_BIN=""
for candidate in /opt/homebrew/bin/gh /usr/local/bin/gh /usr/bin/gh; do
  if [[ -x "$candidate" ]]; then
    GH_BIN="$candidate"
    break
  fi
done

if [[ -n "$GH_BIN" ]] && "$GH_BIN" auth token -h github.com >/dev/null 2>&1; then
  /bin/echo "GitHub CLI credentials are available to the launcher."
else
  /bin/echo "No authenticated GitHub CLI session was found."
  /bin/echo "Run: gh auth login -h github.com"
  /bin/echo "The launcher also supports a read-only token stored in Keychain service com.mando.staging.github."
fi

/bin/echo
/bin/echo "Next:"
/bin/echo "1. Close Chrome normally."
/bin/echo "2. Open $DEST_APP."
/bin/echo "3. In chrome://extensions, load unpacked from $HOME/Mando/StagingExtension once."
/bin/echo "4. Drag Mando Chrome from $DEST_DIR into the Dock."
/bin/echo
/usr/bin/open -R "$DEST_APP" >/dev/null 2>&1 || true
