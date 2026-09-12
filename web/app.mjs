import { assess } from './status.mjs';
const $ = (id) => document.getElementById(id);
let report = null,
  error = null,
  active = null;
localStorage.removeItem('mando-device');
if (location.hash) history.replaceState(null, '', location.pathname);
function paint() {
  const result = error
    ? { tone: 'bad', title: 'Live check unavailable', detail: error }
    : report
      ? assess(report)
      : active
        ? {
            tone: 'neutral',
            title: 'Checking Chrome and GitHub…',
            detail: 'Waiting for the staging extension to reply.',
          }
        : assess(null);
  $('status').className = 'panel ' + result.tone;
  $('badge').textContent = { good: 'UP TO DATE', bad: 'NEEDS ATTENTION', neutral: 'CHECKING' }[
    result.tone
  ];
  $('title').textContent = result.title;
  $('detail').textContent = result.detail;
  $('checked').textContent = report
    ? 'Last checked ' + new Date(report.checkedAt).toLocaleTimeString()
    : active
      ? 'Checking now'
      : 'No live response';
  $('refresh').disabled = !!active;
  $('version').textContent = report?.runningVersion ? 'v' + report.runningVersion : '—';
  $('chrome').textContent = report?.chromeVersion || '—';
  const verified = report?.check === 'ok' && /^[a-f0-9]{40}$/.test(report.latestSha || '');
  $('match').textContent = verified
    ? report.runningSha === report.latestSha
      ? 'Matches ✓'
      : 'Different build'
    : 'Not verified';
  $('latest').textContent = verified
    ? 'Checked directly against GitHub'
    : 'Waiting for a successful GitHub check';
  $('runningSha').textContent = report?.runningSha || '—';
  $('latestSha').textContent = report?.latestSha || '—';
  $('chromeNote').textContent = 'Browser version · minimum supported: 116';
}
function refresh() {
  if (active) return;
  const nonce = crypto.randomUUID();
  active = {
    nonce,
    timer: setTimeout(() => {
      active = null;
      report = null;
      error = null;
      paint();
    }, 20000),
  };
  error = null;
  paint();
  window.postMessage({ type: 'MANDO_STATUS_REQUEST_V2', nonce }, location.origin);
}
window.addEventListener('message', (event) => {
  const value = event.data;
  if (
    event.source !== window ||
    event.origin !== location.origin ||
    value?.type !== 'MANDO_STATUS_RESPONSE_V2' ||
    value.nonce !== active?.nonce
  )
    return;
  clearTimeout(active.timer);
  active = null;
  report = value.report || null;
  error = value.error || null;
  paint();
});
$('refresh').onclick = refresh;
document.addEventListener('visibilitychange', () => {
  if (!document.hidden) refresh();
});
refresh();
setInterval(() => {
  if (!document.hidden) refresh();
}, 15000);
setInterval(paint, 1000);
