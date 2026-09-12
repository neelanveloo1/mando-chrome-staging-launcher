export function assess(r, now = Date.now()) {
  if (!r) return {tone:'neutral', title:'Connect your Mac', detail:'Install Mando Chrome, then open “Open Mando Status.command” to connect this page.'};
  const age = now - Date.parse(r.receivedAt);
  if (!Number.isFinite(age) || age > 300000 || age < -60000) return {tone:'neutral', title:'Mac offline · status unconfirmed', detail:'No recent report. Your Mac may be asleep or its monitor may be stopped.'};
  if (r.check !== 'ok') return {tone:'bad', title:'Check needs attention', detail:({auth_error:'GitHub access could not be verified. Sign in on your Mac with gh auth login.',github_error:'GitHub could not be reached. The installed files are preserved and the monitor will retry.',unsupported_chrome:'Update regular Google Chrome to version 116 or newer.',update_failed:'The update did not complete. Check the launcher log on your Mac.'})[r.check] || 'A check failed.'};
  if (!r.extensionVersion || !r.latestSha || r.latestSha !== r.installedSha) return {tone:'warn', title:'Update waiting', detail:r.chromeRunning?'The newest staging build is not confirmed on disk. Quit Chrome normally; the monitor will install it within two minutes, or open Mando Chrome for an immediate update.':'The newest staging build is not installed yet. The monitor will retry.'};
  if (!r.registered || r.disabled) return {tone:'warn', title:'Files current · Chrome setup needed', detail:r.disabled?'Chrome records this extension as disabled. Open chrome://extensions and review its permissions.':'Load ~/Mando/StagingExtension once in chrome://extensions → Developer mode → Load unpacked.'};
  // Saved service-worker registration versions can lag. They are informational,
  // not evidence that a verified on-disk staging update failed or is missing.
  return {tone:'good', title:'Latest staging build installed', detail:'Your installed staging build matches the latest GitHub SHA, and Chrome has the extension registered. This checks installation freshness—not live extension execution or backend health.'};
}
