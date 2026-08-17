#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

"$ROOT/tests/test-launcher.sh"
/usr/bin/plutil -lint "$ROOT/Mando Chrome.app/Contents/Info.plist"
/usr/bin/python3 -m json.tool "$ROOT/BUILD_INFO.json" >/dev/null

/bin/echo "All public package tests passed."
