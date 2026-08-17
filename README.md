# Mando Chrome Staging Launcher

Mando Chrome is a macOS launcher that keeps the private Mando staging Chrome
extension current before opening regular Google Chrome.

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

## GitHub authentication

Authenticate GitHub CLI before opening Mando Chrome:

```bash
gh auth login -h github.com
gh auth status -h github.com
```

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
update is required, close Chrome normally and open Mando Chrome again.

The download is checked for expected size, Git blob SHA, ZIP integrity, unsafe
paths, symbolic links, Manifest V3, the staging extension name, and its stable
public key before installation.

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
```

## Uninstall

Run:

```bash
./uninstall-mando-chrome.sh
```

The uninstaller removes only `~/Applications/Mando Chrome.app`. It intentionally
leaves the downloaded extension directory and prior-version backup untouched.

## Security notes

- No GitHub credential is included in this repository or release.
- The launcher does not quit Chrome, modify Chrome itself, or edit browser data.
- The app is ad-hoc signed during installation. It is not Apple-notarized.
- Repository access remains enforced by GitHub on every staging update check.

## Development

Run the static package checks on macOS:

```bash
./tests/test-package.sh
```

