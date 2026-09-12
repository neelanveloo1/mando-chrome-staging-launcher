# Mando Chrome Staging Launcher

Mando Chrome is a macOS launcher that keeps the private Mando staging Chrome
extension current before opening regular Google Chrome.

[Live status dashboard](https://mando-chrome-status.vercel.app) ·
[Download the Mac installer](https://github.com/neelanveloo1/mando-chrome-staging-launcher/releases/latest/download/Mando-Chrome-Team-Installer.zip)

Version 1.1.0 also installs a per-user background monitor. It checks GitHub every
two minutes while you are logged in and the Mac is awake, and installs new
staging builds when Chrome is closed. It never interrupts your browser session.

The launcher source is public, but the staging artifact is not. Every update
request still requires a GitHub account with read access to `MandoHQ/app`.
Publishing this launcher does not grant access to that repository or artifact.

## Requirements

- macOS 12 or newer
- Google Chrome 116 or newer
- GitHub CLI authenticated with an account that can read `MandoHQ/app`
- Permission to load an unpacked extension in Chrome

## Install

1. Download and extract the ZIP from the latest GitHub release.
2. Double-click `Install Mando Chrome.command`.
3. If macOS blocks the command because it was downloaded from the internet,
   Control-click it, choose **Open**, and confirm once.
4. Close Chrome normally.
5. Open `Mando Chrome` from `~/Applications`.
6. The first time only, open `chrome://extensions`, enable Developer mode,
   click **Load unpacked**, and select `~/Mando/StagingExtension`.
7. Drag Mando Chrome from `~/Applications` into the Dock if desired.
8. Open `~/Applications/Open Mando Status.command` to connect the dashboard to
   this Mac. Bookmark the page in that browser; the connection is remembered locally.

This does not silently install an extension into Chrome: **Load unpacked** is a
one-time action for each profile. Each teammate needs their own GitHub access.

## GitHub authentication

Authenticate GitHub CLI before opening Mando Chrome:

```bash
gh auth login -h github.com
gh auth status -h github.com
```

If `gh` is missing, install it from [GitHub CLI](https://cli.github.com), or use
`brew install gh` if you already have Homebrew. Authorize your organization's
SSO if GitHub requires it. Chrome itself must already be installed.

Finder-launched apps do not inherit Terminal's Homebrew `PATH`, so the launcher
looks for GitHub CLI at the standard absolute locations. It reads the existing
credential locally with `gh auth token` and sends it to the GitHub API through
standard input rather than exposing it in process arguments.

An optional fine-grained, read-only token can be stored in macOS Keychain with:

```bash
./store-github-token-in-keychain.sh
```

## Update behavior

On every launch, Mando Chrome:

1. Verifies regular Google Chrome is version 116 or newer.
2. Reads the current `extension/dist-staging.zip` metadata from the `develop`
   branch of `MandoHQ/app`.
3. Compares GitHub's blob SHA with the locally installed artifact SHA.
4. When Chrome is closed and the SHA differs, downloads and validates the ZIP.
5. Installs it transactionally while retaining the previous version.
6. Opens regular Google Chrome without flags or a separate profile.

The launcher never changes extension files while Chrome is running. If an
update is required, **quit Chrome normally with Command-Q** (closing its windows
may leave it running). The monitor will install the update on the next check;
open Mando Chrome for an immediate check and relaunch. No Chrome restart is forced.

The launcher updates the extension, not itself. Install a new launcher release
to receive future launcher/monitor changes. Chrome continues using its own normal
updates; no Chrome version is pinned or modified.

The download is checked for expected size, Git blob SHA, ZIP integrity, unsafe
paths, symbolic links, Manifest V3, the staging extension name, and its stable
public key before installation.

## Live status

The website receives a small report from your Mac. A website alone cannot inspect
your local Chrome installation or authenticate to Mando's private repository.

- Green: recent successful GitHub check, matching artifact SHAs, and the staging
  extension is registered in Chrome's last-used saved profile.
- Amber: an update is waiting or Chrome setup is required. A lagging saved
  service-worker version alone does not mean the installed build is out of date.
- Red: GitHub authentication, network, compatibility, update, or status service error.
- Offline/unconfirmed: no new report for more than five minutes, including sleep.

This verifies downloaded-build freshness and saved registration, **not** live
extension execution, recording, permissions, or Mando backend health. Saved
Chrome settings can lag; confirm the live version in `chrome://extensions`.

Each Mac generates a private write token locally. The status command opens a
separate read-only capability link; anyone with that private link can view its
limited version/status report. The URL fragment is removed after the browser
stores it locally. Don't share the private link or device-token file.

Only versions, artifact SHAs, check result/timestamps, Chrome running state and
saved extension registration flags are sent to private Vercel Blob storage.
No GitHub tokens, Chrome profile names, tabs, cookies, extension storage or raw
logs are sent. See [SECURITY.md](SECURITY.md).

## Chrome profiles

Chrome retains the unpacked extension across ordinary browser updates and
restarts. Loading it once is still required for each new Chrome profile or new
Mac because the launcher does not modify Chrome profile data.

Company-managed Chrome policies can block Developer mode, unpacked extensions,
or requested extension permissions. An administrator must allow the extension
in that environment.

## Logs

Launcher activity is recorded at:

```text
~/Library/Logs/MandoChrome/launcher.log
~/Library/Logs/MandoChrome/monitor.log
```

Local latest report: `~/Library/Application Support/MandoChrome/status.json`.
Monitor configuration: `~/Library/LaunchAgents/work.mando.chrome.monitor.plist`.
For an immediate background check without opening Chrome:

```bash
launchctl kickstart gui/$(id -u)/work.mando.chrome.monitor
```

## Uninstall

Run:

```bash
./uninstall-mando-chrome.sh
```

The uninstaller stops/removes the monitor and removes the launcher and status
shortcut. It intentionally leaves downloaded extension files, prior-version
backup, logs and local status credentials untouched. It does not remove the
Chrome extension registration; remove that yourself in `chrome://extensions`.

## Security notes

- No GitHub credential is included in this repository or release.
- The launcher does not quit Chrome, modify Chrome itself, or edit browser data.
- The app is ad-hoc signed during installation. It is not Apple-notarized.
- Repository access remains enforced by GitHub on every staging update check.

## Development

Run the static package checks on macOS:

```bash
./tests/test-package.sh
npm ci
npm test
npm run build
node scripts/package.mjs
```

The package script produces `work/Mando-Chrome-Team-Installer.zip` containing only
the Mac installer (no staging artifact, credentials, node_modules or web service).

## Hosting your own dashboard on Vercel

Import this repository into Vercel, use Node 22 and the checked-in `vercel.json`.
Create a **private** Vercel Blob store and connect it to the project; Vercel adds
`BLOB_READ_WRITE_TOKEN` server-side. Never put a GitHub token on Vercel.
Change the status URL in `monitor.sh` and `Open Mando Status.command` before
packaging your own installer. The `/api/status` endpoint accepts small,
allowlisted reports and retains one current JSON report per device.

Configure Vercel spending alerts and abuse/rate-limit rules for your usage before
large-scale distribution. This initial deployment is a team utility, not an
authenticated multi-tenant monitoring service. Anyone can generate a new device
identity; existing private device reports remain capability-protected.
