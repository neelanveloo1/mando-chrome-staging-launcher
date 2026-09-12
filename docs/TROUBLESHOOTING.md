# Troubleshooting

## Dashboard says “Live check not connected”

1. Open the dashboard in **Google Chrome**, in the profile where staging is installed.
2. Make sure **Mando AI Docs - Staging** is enabled in `chrome://extensions`.
3. Install the latest launcher ZIP if you have an older version.
4. Quit Chrome with **⌘Q**, open **Mando Chrome** using the gold icon, then refresh the dashboard.

If Chrome displays an extension permissions warning, review and approve it if your organization allows it. Never edit Chrome’s profile files to bypass permissions.

## Dashboard says “Update needed”

Quit Chrome with **⌘Q** and open the gold Mando icon. It downloads and verifies the newest build before opening Chrome. Wait for the launcher to finish before starting Chrome yourself.

If you open ordinary Chrome directly, the launcher’s immediate update check does not run.

## Dashboard cannot check GitHub

Run:

```bash
gh auth status -h github.com
```

Your account needs access to `MandoHQ/app` and any required SSO authorization. If the account is correct but GitHub or your network is unavailable, the existing extension is preserved. Try **Check now** later.

The website does not need a GitHub login; the local checker uses your Mac’s existing credentials.

## My Chrome version is displayed — is it the latest Chrome?

The dashboard displays the version of **this running browser session** and checks the extension’s minimum supported Chrome version. It does not claim you have Google’s newest release.

Use Chrome’s **About Google Chrome** page to check Google’s own updater.

## Different profiles show different results

That is expected. Load the unpacked staging extension once in each profile that needs it. The dashboard checks the profile it is open in.

## Logs

- Launcher: `~/Library/Logs/MandoChrome/launcher.log`
- Background updater: `~/Library/Logs/MandoChrome/monitor.log`
- Extension folder: `~/Mando/StagingExtension`
- Previous verified build: `~/Mando/StagingExtension.previous`

Review logs for sensitive information before sharing them. Never share GitHub tokens or Chrome profile files.

## Uninstall

From the extracted installer folder:

```bash
./uninstall-mando-chrome.sh
```

This stops the background updater and removes the launcher, status shortcut, and native-host registration. Extension files, backups, logs, and your own GitHub credentials are preserved. Remove the extension separately in Chrome if you no longer want it.

Historical private cloud reports from 1.1.0 are not deleted by uninstall. They are no longer read or updated by the current dashboard.
