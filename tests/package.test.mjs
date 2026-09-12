import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

test(
  'rebuilding an installer cannot retain obsolete archive entries',
  { skip: process.platform !== 'darwin' },
  () => {
    const temporaryDirectory = mkdtempSync(join(tmpdir(), 'mando-package-test-'));
    try {
      const output = join(temporaryDirectory, 'installer.zip');
      writeFileSync(join(temporaryDirectory, 'obsolete.txt'), 'must not survive a rebuild');
      execFileSync('/usr/bin/zip', ['-q', output, 'obsolete.txt'], { cwd: temporaryDirectory });
      execFileSync(process.execPath, ['scripts/package.mjs', output]);
      const entries = execFileSync('/usr/bin/unzip', ['-Z1', output], { encoding: 'utf8' }).split(
        '\n',
      );
      assert.ok(!entries.includes('obsolete.txt'));
      assert.ok(entries.includes('Mando-Chrome-Installer/docs/TROUBLESHOOTING.md'));
      assert.ok(
        entries.includes(
          'Mando-Chrome-Installer/Mando Chrome.app/Contents/Resources/native-host.sh',
        ),
      );
      assert.ok(
        !entries.some((name) =>
          /node_modules|device-token|dist-staging\.zip|\/\.env|\/\.git\//.test(name),
        ),
      );
    } finally {
      rmSync(temporaryDirectory, { recursive: true, force: true });
    }
  },
);
