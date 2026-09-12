#!/bin/bash
set -euo pipefail

APP="$HOME/Applications/Mando Chrome.app"
MONITOR_PLIST="$HOME/Library/LaunchAgents/work.mando.chrome.monitor.plist"
/bin/launchctl bootout "gui/$(/usr/bin/id -u)" "$MONITOR_PLIST" >/dev/null 2>&1 || true
/bin/rm -f "$MONITOR_PLIST" "$HOME/Applications/Open Mando Status.command"

/bin/rm -rf -- "$APP"
/bin/echo "Removed $APP"
/bin/echo "Extension files were intentionally left at $HOME/Mando/StagingExtension."
/bin/echo "Remove that directory manually only after removing the unpacked extension from Chrome."
