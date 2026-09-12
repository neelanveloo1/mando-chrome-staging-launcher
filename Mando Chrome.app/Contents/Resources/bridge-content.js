(() => {
  const origin = 'https://mando-chrome-status.vercel.app';
  if (location.origin !== origin || window !== window.top) return;
  let busy = false;
  window.addEventListener('message', event => {
    const request = event.data;
    if (event.source !== window || event.origin !== origin || request?.type !== 'MANDO_STATUS_REQUEST_V2' || !/^[a-f0-9-]{36}$/.test(request.nonce) || busy) return;
    busy = true;
    let port, timer;
    const finish = result => {
      if (!busy) return;
      busy = false; clearTimeout(timer);
      window.postMessage({type:'MANDO_STATUS_RESPONSE_V2',nonce:request.nonce,...result},origin);
      try { port?.disconnect(); } catch {}
    };
    try {
      port = chrome.runtime.connect({name:'mando.health.v2'});
      port.onMessage.addListener(response => {if (response.nonce === request.nonce) finish(response);});
      port.onDisconnect.addListener(() => {void chrome.runtime.lastError; finish({error:'The staging extension stopped responding. Reopen Chrome using Mando Chrome.'});});
      timer = setTimeout(() => finish({error:'The live check timed out. Check your connection and try again.'}),18000);
      port.postMessage({action:'status',nonce:request.nonce});
    } catch { finish({error:'Refresh this page after reopening Chrome using Mando Chrome.'}); }
  });
})();
