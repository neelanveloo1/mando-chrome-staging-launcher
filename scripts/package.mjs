import { mkdtemp, cp, mkdir, rename, rm } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { join, resolve, dirname } from 'node:path';

const output = resolve(process.argv[2] || 'work/Mando-Chrome-Team-Installer.zip');
await mkdir('work', { recursive: true });
await mkdir(dirname(output), { recursive: true });
const temporaryDirectory = await mkdtemp('work/package-');
const installerDirectory = join(temporaryDirectory, 'Mando-Chrome-Installer');
const packageFiles = [
  'Mando Chrome.app',
  'Install Mando Chrome.command',
  'Open Mando Status.command',
  'install-mando-chrome.sh',
  'store-github-token-in-keychain.sh',
  'uninstall-mando-chrome.sh',
  'README.md',
  'SECURITY.md',
  'BUILD_INFO.json',
  'docs',
];

try {
  await mkdir(installerDirectory);
  for (const file of packageFiles) {
    await cp(file, join(installerDirectory, file), { recursive: true });
  }
  for (const [folder, files] of [
    ['scripts', ['install-monitor.js', 'install-native-host.js']],
    ['tests', ['test-launcher.sh', 'test-package.sh']],
  ]) {
    await mkdir(join(installerDirectory, folder));
    for (const file of files) {
      await cp(join(folder, file), join(installerDirectory, folder, file));
    }
  }

  // Always build a fresh archive. Updating an existing ZIP preserves deleted files.
  const archive = resolve(temporaryDirectory, 'installer.zip');
  execFileSync('/usr/bin/zip', ['-qr', archive, 'Mando-Chrome-Installer'], {
    cwd: temporaryDirectory,
    env: { ...process.env, COPYFILE_DISABLE: '1' },
  });
  execFileSync('/usr/bin/unzip', ['-tq', archive]);
  await rename(archive, output);
  console.log(output);
} finally {
  await rm(temporaryDirectory, { recursive: true, force: true });
}
