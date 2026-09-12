ObjC.import('Foundation');
function run(argv) {
  const [root, resources, sha] = argv;
  if (!/^[a-f0-9]{40}$/.test(sha)) throw Error('Invalid artifact SHA');
  const read = (p) =>
    ObjC.unwrap($.NSString.stringWithContentsOfFileEncodingError(p, $.NSUTF8StringEncoding, null));
  const write = (p, s) => {
    if (!$(s).writeToFileAtomicallyEncodingError(p, true, $.NSUTF8StringEncoding, null))
      throw Error('Cannot write bridge');
  };
  const manifest = JSON.parse(read(root + '/manifest.json'));
  const worker = manifest.background && manifest.background.service_worker;
  if (
    manifest.background?.type !== 'module' ||
    !worker ||
    worker.includes('..') ||
    worker.includes('/') ||
    !/^[-\w.]+\.js$/.test(worker)
  )
    throw Error('Unsupported staging worker');
  write(
    root + '/mando-health-worker.js',
    read(resources + '/bridge-worker.js').replace('__MANDO_ARTIFACT_SHA__', sha),
  );
  write(root + '/mando-health-content.js', read(resources + '/bridge-content.js'));
  // New URL per build avoids reusing Chrome's cached MV3 worker registration.
  const entry = 'mando-health-entry-' + sha + '-v4.js';
  write(root + '/' + entry, "import './mando-health-worker.js';\nimport './" + worker + "';\n");
  manifest.background.service_worker = entry;
  manifest.permissions = Array.from(new Set([...(manifest.permissions || []), 'nativeMessaging']));
  manifest.content_scripts = (manifest.content_scripts || []).filter(
    (c) => !c.js?.includes('mando-health-content.js'),
  );
  manifest.content_scripts.push({
    matches: ['https://mando-chrome-status.vercel.app/*'],
    js: ['mando-health-content.js'],
    run_at: 'document_start',
  });
  write(root + '/manifest.json', JSON.stringify(manifest, null, 2) + '\n');
  write(
    root + '/mando-health-bridge.json',
    JSON.stringify({ version: 4, artifactSha: sha }) + '\n',
  );
}
