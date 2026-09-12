ObjC.import('Foundation');
function run(argv) {
  const home = ObjC.unwrap($.NSHomeDirectory());
  const manifest = {
    name: 'work.mando.chrome.status',
    description: 'Mando read-only staging build check',
    path: home + '/Applications/Mando Chrome.app/Contents/Resources/native-host.sh',
    type: 'stdio',
    allowed_origins: ['chrome-extension://gonaohmomchmmkmnnioldofcabibpicp/'],
  };
  if (
    !$(JSON.stringify(manifest, null, 2)).writeToFileAtomicallyEncodingError(
      argv[0],
      true,
      $.NSUTF8StringEncoding,
      null,
    )
  )
    throw Error('Cannot install native host');
}
