# Security

Do not include GitHub tokens, Keychain exports, Chrome profile data, staging
extension contents, or launcher logs in issues or pull requests.

The public launcher contains the private repository name and expected artifact
path, but GitHub authentication and repository authorization are still required
to read the artifact.

For a suspected credential exposure, revoke the affected GitHub token first and
then report the incident through Mando's internal security process.

