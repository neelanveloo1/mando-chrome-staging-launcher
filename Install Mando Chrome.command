#!/bin/bash
set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
STATUS=0
"$ROOT/install-mando-chrome.sh" || STATUS=$?

/bin/echo
if [[ "$STATUS" == "0" ]]; then
  /bin/echo "Installation finished. Follow the numbered steps above."
else
  /bin/echo "Installation failed with status $STATUS. Nothing in Google Chrome was modified."
fi
/bin/echo "Press any key to close this window."
IFS= read -r -n 1 _
exit "$STATUS"
