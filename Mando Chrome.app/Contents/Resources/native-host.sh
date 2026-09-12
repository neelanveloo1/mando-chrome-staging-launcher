#!/bin/bash
set -euo pipefail
RESOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/osascript -l JavaScript "$RESOURCE_DIR/native-host.js" "$RESOURCE_DIR" "$@"
