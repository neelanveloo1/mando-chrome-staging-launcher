import {assess} from './status.mjs';
const $ = id => document.getElementById(id);
let report, requestError, loading=false;
const hash = new URLSearchParams(location.hash.slice(1));
let key = hash.get('device') || localStorage.getItem('mando-device');
if (key && /^[a-f0-9]{64}$/.test(key)) { localStorage.setItem('mando-device', key); history.replaceState(null,'',location.pathname); } else key=null;
function paint(){
  const state=requestError?{tone:'bad',title:'Status unavailable',detail:requestError}:assess(report);
  $('status').className=`panel ${state.tone}`;$('title').textContent=state.title;$('detail').textContent=state.detail;
  $('badge').textContent=({good:'UP TO DATE',warn:'ACTION NEEDED',bad:'CHECK FAILED',neutral:report?'OFFLINE':'NOT CONNECTED'})[state.tone];
  $('checked').textContent=report?`Last report ${new Date(report.receivedAt).toLocaleTimeString()}`:'No report yet';
  $('version').textContent=report?.extensionVersion?`v${report.extensionVersion}`:'—';
  $('installedAt').textContent=report?.installedAt?`Installed ${new Date(report.installedAt).toLocaleString()}`:'Waiting for your Mac';
  $('chrome').textContent=report?.chromeVersion||'—';$('chromeState').textContent=report?(report.chromeRunning?'Chrome is open':'Chrome is closed'):'Regular Chrome · 116+ required';
  $('launcher').textContent=report?.launcherVersion?`v${report.launcherVersion}`:'—';
  $('installedSha').textContent=report?.installedSha||'Awaiting report';$('latestSha').textContent=report?.latestSha||'Not verified';
  $('runtime').textContent=report?.recordedVersion?`Chrome’s saved registration lists v${report.recordedVersion}. Saved settings can lag behind the running extension. This page verifies installed files, not recording or backend behavior.`:'Chrome registration is read from saved profile settings; this is not a live extension execution test.';
}
async function refresh(){if(!key||loading){paint();return;}loading=true;$('refresh').disabled=true;
try{const r=await fetch('/api/status',{headers:{Authorization:`Bearer ${key}`},cache:'no-store'});const data=await r.json();if(!r.ok)throw Error(data.error||'Status check failed');report=data;requestError=null;}catch(e){requestError=e.message;}finally{loading=false;$('refresh').disabled=false;paint();}}
$('refresh').onclick=refresh;$('disconnect').onclick=()=>{localStorage.removeItem('mando-device');key=null;report=null;requestError=null;paint();};
paint();refresh();setInterval(()=>{if(!document.hidden)refresh();},30000);setInterval(paint,10000);
