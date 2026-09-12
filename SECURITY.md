# Security

Never publish GitHub tokens, Keychain exports, Chrome profile data, private staging contents, or logs containing credentials.

## Live status trust boundary

GitHub authorization is enforced on every artifact fetch. Credentials stay on the Mac and are passed to curl via standard input, never to the dashboard or process arguments.

The status adapter is limited to https://mando-chrome-status.vercel.app. Its background listener checks the sender's extension ID, top-level frame, exact origin, request type, and nonce. It exposes no generic browser, shell, URL-fetch, filesystem or token API.

The native host accepts only the staging extension ID and a bounded, length-prefixed JSON message containing exactly {"action":"status"}. It runs one fixed local command that checks one fixed GitHub artifact. It returns check state, latest SHA, and timestamp only. It cannot install, execute user-supplied commands, or disclose credentials.

The running worker's original artifact SHA is baked into the adapter at install time after upstream ZIP verification. It cannot turn green merely because a newer file was downloaded while an old worker is running. The page expires checks after 45 seconds. The frontend and installed adapter remain trusted software; this is not tamper-resistant remote attestation or a test of Mando recording/backend behavior.

The locally added adapter includes nativeMessaging permission and a dashboard-only content script; the installer registers its read-only host. These additions are transparent in the installed manifest and public source. The upstream extension remains private.

## Data and retirement of 1.1.0 reports

Version 1.2.0 does not upload status reports to cloud storage or use device tokens. The hosting service serves the page and may keep ordinary request metadata. The retired status API returns HTTP 410. Historical 1.1.0 reports remain private until the hosting account owner removes them; uninstalling does not delete those historical reports.

The uninstaller removes native-host registration and the background updater, leaving extension data and backups for recovery. Credentials previously used for GitHub remain in the user's own GitHub CLI/Keychain.

Report security concerns through Mando's internal security process. Revoke an exposed GitHub token immediately.
