// Only this allowlist of fields is sent to the dashboard. No profile names,
// browsing data, credentials, extension storage, or raw logs leave the Mac.
ObjC.import('Foundation');
function run(argv) {
  const home=ObjC.unwrap($.NSHomeDirectory());
  function json(path){try {const value=$.NSString.stringWithContentsOfFileEncodingError(path,$.NSUTF8StringEncoding,null);return JSON.parse(ObjC.unwrap(value));}catch(e){return {};}}
  const root=home+'/Mando/StagingExtension';
  const meta=json(root+'/mando-chrome-artifact.json'),manifest=json(root+'/manifest.json');
  const chromeRoot=home+'/Library/Application Support/Google/Chrome';
  const local=json(chromeRoot+'/Local State'),profile=local.profile&&local.profile.last_used||'Default';
  const safeProfile=/^(Default|Profile \d+)$/.test(profile)?profile:'Default';
  const prefs=json(chromeRoot+'/'+safeProfile+'/Preferences'),secure=json(chromeRoot+'/'+safeProfile+'/Secure Preferences');
  const id='gonaohmomchmmkmnnioldofcabibpicp';
  const entry=(secure.extensions&&secure.extensions.settings&&secure.extensions.settings[id])||(prefs.extensions&&prefs.extensions.settings&&prefs.extensions.settings[id]);
  const reasons=entry&&entry.disable_reasons;
  const disabled=!!entry&&(entry.state===0||(Array.isArray(reasons)?reasons.length>0:typeof reasons==='number'&&reasons!==0));
  return JSON.stringify({check:argv[0],latestSha:argv[1]||null,chromeVersion:argv[2]||null,chromeRunning:argv[3]==='1',launcherVersion:'1.1.0',installedSha:meta.artifact_sha||null,installedAt:meta.installed_at||null,extensionVersion:manifest.version||null,registered:!!entry&&entry.path===root,disabled:disabled,recordedVersion:entry&&entry.service_worker_registration_info&&entry.service_worker_registration_info.version||null});
}
