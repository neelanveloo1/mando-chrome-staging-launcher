# Mando Chrome

**Open Chrome with the gold Mando icon. Open the dashboard to see whether your running staging extension is up to date.**

[Open dashboard in Chrome](https://mando-chrome-status.vercel.app/) · [Download Mac installer](https://github.com/neelanveloo1/mando-chrome-staging-launcher/releases/latest/download/Mando-Chrome-Team-Installer.zip)

## Daily use

1. Click **Mando Chrome** — the gold icon in your Dock.
2. Work in Chrome normally.
3. Open the [dashboard](https://mando-chrome-status.vercel.app/) in **that Chrome profile** whenever you want to check.

| Status                        | Meaning                                                                                                                         | What to do                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| **Green — You’re up to date** | The staging extension actually running in Chrome matches GitHub’s latest build, and Chrome meets the minimum supported version. | Nothing. Keep working.                                         |
| **Red — Update needed**       | Chrome is running an older staging build.                                                                                       | Quit Chrome with **⌘Q**, then click the gold Mando icon again. |
| **Red — Check unavailable**   | The extension, GitHub access, or local checker could not be verified.                                                           | Follow the message on the page, then click **Check now**.      |

The dashboard shows your **running extension version**, **GitHub match**, and **Chrome version**. It checks when opened, every **15 seconds while visible**, and when you click **Check now**. No login or private pairing link is needed on the website.

> Open it in **Google Chrome**, not Safari, Edge, or an embedded browser inside another app. It checks the extension in the profile displaying the page.

## First-time installation

You need **macOS 12+**, **Google Chrome 116+**, and a GitHub account with read access to **MandoHQ/app**. The public launcher does not grant access to Mando’s private staging build.

1. **Sign in to GitHub on your Mac.** Install [GitHub CLI](https://cli.github.com/) if needed. With Homebrew, use `brew install gh`. Then run:

   ```bash
   gh auth login -h github.com
   gh auth status -h github.com
   ```

   Authorize your organization’s SSO if GitHub requests it.

2. **Install the launcher.** [Download the ZIP](https://github.com/neelanveloo1/mando-chrome-staging-launcher/releases/latest/download/Mando-Chrome-Team-Installer.zip), unzip it, and double-click **Install Mando Chrome.command**.

3. **Quit Chrome with ⌘Q.** Then open **Mando Chrome** from your user Applications folder: `~/Applications`.

4. **Load staging once.** In Chrome, open `chrome://extensions`, enable **Developer mode**, click **Load unpacked**, and select `~/Mando/StagingExtension`.

5. **Add the gold icon to your Dock.** Drag **Mando Chrome** from `~/Applications` into the Dock. Then open the [dashboard](https://mando-chrome-status.vercel.app/) in Chrome.

That’s it. You do **not** repeat **Load unpacked** for normal staging updates.

If macOS blocks installation, the package is locally signed but **not Apple-notarized**. Follow your organization’s approved process for installing it; do not bypass company policy. Managed Chrome may require an administrator to allow unpacked extensions and native messaging.

## Already have an older launcher?

Install the latest ZIP over your existing launcher, quit Chrome with **⌘Q**, and open it using the gold icon once. Then refresh the dashboard.

Your extension data stays in place. Old private status links from version 1.1.0 are no longer needed.

## What updates automatically?

- **Staging:** checked before the launcher opens Chrome. It also updates in the background every two minutes **while Chrome is closed**.
- **Chrome:** uses Google’s normal updater. Mando does not replace Chrome or force a specific version.
- **The launcher itself:** install a new launcher ZIP when a launcher release is published.

The updater never quits Chrome or replaces extension files while Chrome is running. Closing a window is not always enough; use **⌘Q** when you want an update installed.

## What does green verify?

Green requires a fresh reply from the **running staging extension**, a successful GitHub check, matching build IDs, and a compatible Chrome version. It does **not** test recording features or Mando’s backend.

Your GitHub credentials stay on your Mac. The dashboard receives no browsing history, cookies, or GitHub token, and version 1.2+ does not upload device reports to cloud storage.

## Need help?

See the [troubleshooting guide](docs/TROUBLESHOOTING.md) for connection problems, permissions, logs, and uninstall instructions.

For contributors: [development and architecture](docs/DEVELOPMENT.md) · [security](SECURITY.md).
