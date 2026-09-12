# Security

Do not include GitHub tokens, Keychain exports, Chrome profile data, staging
extension contents, or launcher logs in issues or pull requests.

The public launcher contains the private repository name and expected artifact
path, but GitHub authentication and repository authorization are still required
to read the artifact.

For a suspected credential exposure, revoke the affected GitHub token first and
then report the incident through Mando's internal security process.

## Dashboard trust boundary

GitHub credentials stay on each Mac. The cloud receives only the report fields
allowlisted in `lib/status.mjs`. Vercel's private Blob credential is server-only.
Reports are self-reported by the local monitor, not independent remote attestation.

The Mac creates a random 256-bit write token in a mode-600 file inside its
mode-700 Application Support directory. The read capability is SHA-256(write
token); its hash identifies the private Blob record. A read capability cannot
overwrite the corresponding device report. Treat either capability as private.
The shared landing page has no access to a device without its read capability.

The hosting account owner can access stored reports. The latest report replaces
the previous report; reports persist after uninstall until the hosting owner
removes them. Vercel may retain infrastructure request metadata under its policy.
"Forget this Mac" only clears this browser's saved link; it does not stop the
monitor, revoke links, or delete the server report. To stop reporting, uninstall.

This is an initial team-scale service: public device enrollment is unrestricted.
Use Vercel firewall/rate limits and cost alerts before exposing it broadly.
No claim is made that SHA equality proves live extension or backend functionality.
