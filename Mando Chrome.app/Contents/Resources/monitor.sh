#!/bin/bash
set -euo pipefail
RESOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$RESOURCE_DIR/launcher.sh"
# Background updates only. No cloud device reports.
if is_chrome_running; then exit 0; fi
MANDO_STAGING_BACKGROUND=1 /bin/bash "$RESOURCE_DIR/launcher.sh"
