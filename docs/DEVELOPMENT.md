# Development

## Local checks

Use **Node.js 22** and macOS for the full test suite. Node is needed by contributors, not by teammates running the packaged launcher.

```bash
npm ci
npm run format:check
npm test
bash tests/test-package.sh
npm run build
npm run package
```

Use `npm run format` to apply the checked-in formatting rules.

The package is written to `work/Mando-Chrome-Team-Installer.zip`. Packaging starts from a new archive each time, validates it, then replaces the output. Private staging artifacts, credentials, logs, dependencies, and web deployment files are excluded.

## Code map

| Area                                              | Responsibility                                                                 |
| ------------------------------------------------- | ------------------------------------------------------------------------------ |
| `Mando Chrome.app/Contents/Resources/launcher.sh` | Resolve Chrome/GitHub, verify downloads, install transactionally, open Chrome. |
| `prepare-bridge.js`                               | Add the narrow live-status adapter to a verified candidate.                    |
| `bridge-content.js` / `bridge-worker.js`          | Dashboard request → running staging worker → live response.                    |
| `native-host.js` / `live-status.sh`               | Bounded native messaging and a fixed, read-only GitHub query.                  |
| `monitor.sh`                                      | Background updates only while Chrome is closed.                                |
| `web/`                                            | Plain HTML/CSS/JavaScript dashboard, with a separately tested status decision. |
| `scripts/`                                        | Build, packaging, and per-user installer configuration.                        |
| `tests/`                                          | Live protocol, error states, origin checks, update transactions, packaging.    |

There are no production JavaScript package dependencies. macOS built-in Bash, JavaScript for Automation, curl, and archive tools run the installed launcher.

## Live check

The dashboard communicates only with the current profile’s staging extension. The content script is limited to the exact dashboard origin. The worker validates the sender’s extension ID, origin, top-level frame, request type, and nonce.

The running worker reports its manifest version and an **upstream artifact SHA baked into its module**. It never substitutes an on-disk version marker for running identity. Its read-only native host queries the latest GitHub artifact through the user’s locally stored credential.

A result expires after 45 seconds. A missing response, failed GitHub request, invalid build ID, unsupported Chrome, or running/latest mismatch cannot produce green. The worker coalesces concurrent requests and reuses a result for at most five seconds.

The page checks every 15 seconds while visible. A live GitHub request has a 10-second network timeout; the bridge and page have bounded response deadlines.

## Safe installation

The updater verifies the upstream ZIP’s expected size, Git blob SHA, integrity, safe paths, absence of symlinks, Manifest V3, staging name, and stable key. Only then does it add the adapter to the isolated candidate.

The adapter adds nativeMessaging permission, a dashboard-only content script, and a distinct background entry point. Upstream source files are not rewritten; manifest additions and adapter files are explicit. This local adapter is not part of the upstream ZIP.

**Keep the entry point unique per artifact SHA and adapter revision.** Chrome can reuse an older MV3 worker registration when the URL is unchanged. Increment the adapter revision in both `prepare-bridge.js` and `launcher.sh` whenever the installed adapter changes; update its integration test too.

Files are replaced transactionally only while Chrome is closed, with a prior-version backup. Tests use isolated fixtures, never the user’s real extension directory.

## Releases

1. Update `package.json`, its lockfile, `BUILD_INFO.json`, and the app’s `Info.plist`.
2. Increment the adapter revision if required.
3. Run all checks above and verify the live page in Chrome.
4. Commit and push to `main`; confirm macOS CI and Vercel succeed.
5. Tag the same commit and publish a GitHub release with asset name **Mando-Chrome-Team-Installer.zip**.
6. Verify the public latest-release download. Do not replace a published release silently.

The installer signs and verifies a temporary app before replacing the installed app. Source bundles are unsigned; shipped installers do not contain stale source signatures.

## Hosting

The Vercel project is connected to this repository and uses `vercel.json`. The current dashboard needs **no server-side GitHub token, device token, database, or Blob store**. The retired `/api/status` route returns HTTP 410 so old clients cannot keep uploading reports.

For another domain, update the exact origin in both adapter files, `prepare-bridge.js`, and `Open Mando Status.command`, then release an installer with a new adapter revision. Preview deployments intentionally cannot access the production-origin bridge.

Read [SECURITY.md](../SECURITY.md) and Chrome’s [native messaging documentation](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging).
