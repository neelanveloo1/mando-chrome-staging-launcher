ObjC.import('Foundation');
function run(argv) {
  const home = ObjC.unwrap($.NSHomeDirectory());
  const escape = (s) =>
    s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  const script = home + '/Applications/Mando Chrome.app/Contents/Resources/monitor.sh';
  const log = home + '/Library/Logs/MandoChrome/monitor.log';
  const xml =
    '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0"><dict><key>Label</key><string>work.mando.chrome.monitor</string><key>ProgramArguments</key><array><string>/bin/bash</string><string>' +
    escape(script) +
    '</string></array><key>StartInterval</key><integer>120</integer><key>RunAtLoad</key><true/><key>StandardOutPath</key><string>' +
    escape(log) +
    '</string><key>StandardErrorPath</key><string>' +
    escape(log) +
    '</string><key>ProcessType</key><string>Background</string></dict></plist>';
  if (!$(xml).writeToFileAtomicallyEncodingError(argv[0], true, $.NSUTF8StringEncoding, null))
    throw Error('Cannot write monitor configuration');
}
