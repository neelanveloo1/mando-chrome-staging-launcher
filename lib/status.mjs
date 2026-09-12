import {createHash} from 'node:crypto';
export const hash = v => createHash('sha256').update(v).digest('hex');
export const isToken = v => typeof v === 'string' && /^[a-f0-9]{64}$/.test(v);
export function cleanReport(value, now = Date.now()) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid report');
  const sha = v => typeof v === 'string' && /^[a-f0-9]{40}$/.test(v) ? v : null;
  const version = v => typeof v === 'string' && /^\d+(\.\d+){0,3}$/.test(v) ? v : null;
  const states = ['ok','auth_error','github_error','unsupported_chrome','update_failed'];
  if (!states.includes(value.check)) throw new Error('Invalid check');
  return {receivedAt: new Date(now).toISOString(), check: value.check,
    installedSha: sha(value.installedSha), latestSha: sha(value.latestSha),
    extensionVersion: version(value.extensionVersion), chromeVersion: version(value.chromeVersion),
    launcherVersion: version(value.launcherVersion),
    chromeRunning: value.chromeRunning === true,
    registered: value.registered === true, disabled: value.disabled === true,
    recordedVersion: version(value.recordedVersion),
    installedAt: typeof value.installedAt === 'string' && Number.isFinite(Date.parse(value.installedAt)) ? new Date(value.installedAt).toISOString() : null};
}
