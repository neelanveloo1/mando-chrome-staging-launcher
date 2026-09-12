export function assess(r, now = Date.now()) {
  if (!r)
    return {
      tone: 'bad',
      title: 'Live check not connected',
      detail:
        'Open this page in Google Chrome with Mando staging enabled. After installing Mando Chrome 1.2.0, quit Chrome and reopen it using the gold Mando icon.',
    };
  if (r.protocol !== 2 || !/^[a-f0-9]{40}$/.test(r.runningSha || '') || !r.runningVersion)
    return {
      tone: 'bad',
      title: 'No live extension response',
      detail: 'Reopen Chrome using Mando Chrome, then refresh this page.',
    };
  const age = now - Date.parse(r.checkedAt);
  if (!Number.isFinite(age) || age > 45000 || age < -60000)
    return {
      tone: 'bad',
      title: 'Check expired',
      detail: 'A fresh live check is needed. Check your connection and press Check now.',
    };
  if (r.check !== 'ok')
    return {
      tone: 'bad',
      title: 'Could not check GitHub',
      detail:
        r.check === 'auth_error'
          ? 'Sign in on your Mac with gh auth login. Your account needs access to MandoHQ/app.'
          : 'GitHub or the local checker did not respond successfully. Your existing extension is unchanged. Try Check now.',
    };
  if (!/^[a-f0-9]{40}$/.test(r.latestSha || ''))
    return {
      tone: 'bad',
      title: 'Latest build not verified',
      detail: 'GitHub did not return a valid build ID. Try Check now.',
    };
  if (
    !/^\d+(\.\d+){0,3}$/.test(r.chromeVersion || '') ||
    Number(r.chromeVersion.split('.')[0]) < 116
  )
    return {
      tone: 'bad',
      title: 'Chrome needs attention',
      detail:
        'This check requires Google Chrome 116 or newer. Update Chrome from About Google Chrome.',
    };
  if (r.runningSha !== r.latestSha)
    return {
      tone: 'bad',
      title: 'Update needed',
      detail:
        'Chrome is running an older staging build. Quit Chrome with ⌘Q, then click the gold Mando icon to update and reopen it.',
    };
  return {
    tone: 'good',
    title: 'You’re up to date',
    detail:
      'The staging extension running in this Chrome session matches the latest build on GitHub.',
  };
}
