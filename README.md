# Mando Chrome
[Open the live dashboard in Chrome](https://mando-chrome-status.vercel.app/) · [Download Mac installer](https://github.com/neelanveloo1/mando-chrome-staging-launcher/releases/latest/download/Mando-Chrome-Team-Installer.zip)

## Everyday use
1. Open Chrome using the **gold Mando icon** in your Dock.
2. Visit **https://mando-chrome-status.vercel.app/** in that Chrome profile.
3. **Green:** the running staging build matches GitHub and Chrome meets the minimum version.
4. **Red:** follow the short explanation. For an outdated build, quit Chrome with Command-Q and reopen using the gold icon.

The page shows the running extension version, whether its build SHA matches GitHub, and this browser's full Chrome version. It checks on page load, every 15 seconds while visible, and when you click **Check now**. No pairing link is needed.

Open the dashboard in **Google Chrome**, not another browser or an embedded app browser. It checks the current Chrome profile, not a different profile or another Mac. It verifies running-build identity and compatibility, not workflow recording or backend health.

## First-time setup
Requires macOS 12+, Google Chrome 116+, and your own read access to the private repository `MandoHQ/app`.

1. Download and extract the installer ZIP. Open **Install Mando Chrome.command**.
2. Install [GitHub CLI](https://cli.github.com) if needed (`brew install gh` with Homebrew), then run `gh auth login -h github.com`. Authorize organization SSO if required.
3. Quit Chrome normally and open **Mando Chrome** from your user Applications folder.
4. Once per profile, open `chrome://extensions`, enable Developer mode, choose **Load unpacked**, and select `~/Mando/StagingExtension`.
5. Drag Mando Chrome from `~/Applications` into your Dock.
6. Open the dashboard in Chrome. The included **Open Mando Status.command** opens it in Chrome for you.

If Chrome asks you to approve new permissions, review and approve them in its extensions page. Company policy may block unpacked extensions or native messaging; an administrator must allow them. The app is locally ad-hoc signed during installation, not Apple-notarized.

## Upgrading from 1.1.0
Install the **1.2.0** package, quit Chrome with Command-Q, then open Mando Chrome once. This installs the live-status adapter even if the staging ZIP's SHA has not changed. Refresh the dashboard. Old private status links and cloud device reports are no longer used.

## How the live check works
The launcher validates the private upstream ZIP's size, Git blob SHA, archive paths, manifest name, and stable extension key. Only then, in an isolated candidate directory, it adds a small status adapter. The original upstream files remain unchanged except for manifest additions. The adapter adds a dashboard-only content script, native-messaging permission, and a distinct background entry point per artifact SHA/adapter revision.

A message from the exact dashboard origin reaches the running staging service worker. That worker responds with its manifest version and **build SHA baked into its code**, not a marker read from disk. It also reports this session's Chrome version. A read-only native host checks the latest artifact SHA directly against GitHub using your local credentials. The returned status goes directly back to that browser page, not through cloud storage.

Distinct worker-entry URLs avoid reusing a stale Chrome MV3 background registration across builds. A missing response, failed GitHub check, incompatible Chrome, expired result, or mismatched SHA can never produce green.

The adapter is maintained by this launcher; it is not part of the upstream staging ZIP. We do not publish the private extension artifact. Source access to this launcher does not grant access to Mando's private repository.

## Updates and safety
- The launcher checks before opening Chrome. A per-user LaunchAgent also checks/updates every two minutes while Chrome is closed.
- Extension files are never replaced while Chrome is running. No background job quits Chrome.
- A verified candidate is installed transactionally, retaining the prior version.
- Chrome updates itself normally. The launcher checks the minimum supported version; it does not update, replace or pin Chrome.
- Staging updates automatically; install a new launcher release for launcher changes.
- A live check uses a 10-second GitHub request timeout and a five-second per-worker cache to avoid duplicate simultaneous requests.

## Logs and uninstall
Logs: `~/Library/Logs/MandoChrome/launcher.log` and `monitor.log`.
Run `./uninstall-mando-chrome.sh` to stop the LaunchAgent and remove the launcher, status shortcut and native-host registration. It leaves extension files, backups and logs in place. Remove the extension yourself in Chrome if desired.

The retired 1.1.0 service's historical reports may remain in private hosting storage; the new monitor no longer sends them and its old endpoint returns HTTP 410. Old local status credentials are unused.

## Development
On macOS:

```bash
npm ci
npm test
bash tests/test-package.sh
npm run build
node scripts/package.mjs
```

The package script produces `work/Mando-Chrome-Team-Installer.zip`. It excludes private staging contents, credentials, logs, node_modules, and the web deployment.

The public web frontend is hosted on Vercel. No GitHub or device credential is needed on the server for 1.2.0. A fork using another dashboard origin must update the origin in both adapter files, prepare-bridge.js, and Open Mando Status.command, then rebuild its installer. Native host access is restricted to the staging extension ID and a fixed read-only status command.

See [SECURITY.md](SECURITY.md) and Chrome's [native messaging documentation](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging).
