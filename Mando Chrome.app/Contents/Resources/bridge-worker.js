// Loaded into the staging worker after the original artifact is verified.
// Build identity is baked into this module, never read from replaceable disk data.
const origin = 'https://mando-chrome-status.vercel.app';
const runningSha = '__MANDO_ARTIFACT_SHA__';
const runningVersion = chrome.runtime.getManifest().version;
let pending;
let lastResult;
let lastChecked = 0;
async function status() {
  if (pending) return pending;
  if (lastResult && Date.now() - lastChecked < 5000) return lastResult;
  pending = (async () => {
    const local = await chrome.runtime.sendNativeMessage('work.mando.chrome.status', {action:'status'});
    const brands = await navigator.userAgentData?.getHighEntropyValues(['fullVersionList']);
    const chromeBrand = brands?.fullVersionList?.find(b => b.brand === 'Google Chrome');
    const chromeVersion = chromeBrand?.version || navigator.userAgent.match(/Chrome\/([\d.]+)/)?.[1] || null;
    lastResult = {protocol:2, runningSha, runningVersion, chromeVersion,
      check:local.check, latestSha:local.latestSha, checkedAt:local.checkedAt};
    lastChecked = Date.now();
    return lastResult;
  })();
  try { return await pending; } finally { pending = null; }
}
chrome.runtime.onConnect.addListener(port => {
  if (port.name !== 'mando.health.v2') return;
  let trusted = false;
  try { trusted = port.sender?.id === chrome.runtime.id && port.sender.frameId === 0 && new URL(port.sender.url).origin === origin; } catch {}
  if (!trusted) { port.disconnect(); return; }
  port.onMessage.addListener(async message => {
    if (message?.action !== 'status' || !/^[a-f0-9-]{36}$/.test(message.nonce)) return;
    let response;
    try { response = {nonce:message.nonce, report:await status()}; }
    catch { response = {nonce:message.nonce, error:'The local checker is unavailable. Install Mando Chrome 1.2.0, then quit and reopen Chrome.'}; }
    try { port.postMessage(response); } catch {}
  });
});
