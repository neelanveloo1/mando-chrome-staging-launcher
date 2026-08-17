#!/bin/bash
set -euo pipefail

APP="$HOME/Applications/Mando Chrome.app"

/bin/rm -rf -- "$APP"
/bin/echo "Removed $APP"
/bin/echo "Extension files were intentionally left at $HOME/Mando/StagingExtension."
/bin/echo "Remove that directory manually only after removing the unpacked extension from Chrome."
