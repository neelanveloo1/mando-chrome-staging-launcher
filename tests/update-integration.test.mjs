import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

test(
  'real updater: defer while open, install on SHA change, skip current, reject corruption',
  { skip: process.platform !== 'darwin' },
  () => {
    const root = mkdtempSync(join(tmpdir(), 'mando-updater-test-'));
    try {
      const launcher = resolve('Mando Chrome.app/Contents/Resources/launcher.sh');
      const key = readFileSync(launcher, 'utf8').match(
        /readonly EXPECTED_MANIFEST_KEY="([^"]+)"/,
      )[1];
      const home = join(root, 'home'),
        fixture = join(root, 'fixture'),
        ext = join(home, 'Mando/StagingExtension');
      mkdirSync(fixture, { recursive: true });
      mkdirSync(ext, { recursive: true });
      const manifest = {
        manifest_version: 3,
        name: 'Mando AI Docs - Staging',
        version: '9.9.9',
        key,
        background: { service_worker: 'worker.js', type: 'module' },
      };
      writeFileSync(join(fixture, 'worker.js'), '// fixture background worker\n');
      writeFileSync(join(fixture, 'manifest.json'), JSON.stringify(manifest));
      writeFileSync(join(ext, 'manifest.json'), JSON.stringify({ ...manifest, version: '9.9.8' }));
      const marker = join(ext, 'mando-chrome-artifact.json');
      writeFileSync(marker, JSON.stringify({ artifact_sha: 'a'.repeat(40) }));
      const zip = join(root, 'fixture.zip');
      execFileSync('/usr/bin/zip', ['-q', zip, 'manifest.json', 'worker.js'], { cwd: fixture });
      const sha = createHash('sha256').update(readFileSync(zip)).digest('hex');
      const metadata = join(root, 'metadata.json');
      // The shape of GET /repos/{owner}/{repo}/releases, newest first.
      const releases = (digest) => [
        {
          tag_name: 'ext/v9.9.10',
          name: 'Extension 9.9.10 (rollback)',
          draft: false,
          assets: [
            { name: 'dist-staging.zip', id: 1, size: 1, digest: 'sha256:' + 'f'.repeat(64) },
          ],
        },
        {
          tag_name: 'ext/v9.9.9',
          name: 'Extension 9.9.9 (develop)',
          draft: false,
          assets: [
            { name: 'SHA256SUMS', id: 2, size: 1, digest: 'sha256:' + 'e'.repeat(64) },
            { name: 'dist-staging.zip', id: 3, size: readFileSync(zip).length, digest },
          ],
        },
      ];
      writeFileSync(metadata, JSON.stringify(releases('sha256:' + sha)));
      const wrapper = join(root, 'run.sh');
      writeFileSync(
        wrapper,
        `source "$TEST_LAUNCHER"\nensure_supported_chrome(){ :; }\nconfigure_github_auth(){ :; }\nfetch_metadata(){ /bin/cp "$TEST_META" "$1"; }\nfetch_artifact(){ [[ "\${TEST_FORBID_DOWNLOAD:-0}" != "1" ]] || return 1; /bin/cp "$TEST_ZIP" "$1"; }\nmain\n`,
      );
      const run = (running, extra = {}) =>
        spawnSync('/bin/bash', [wrapper], {
          encoding: 'utf8',
          env: {
            ...process.env,
            HOME: home,
            MANDO_STAGING_BACKGROUND: '1',
            MANDO_STAGING_TEST_CHROME_RUNNING: running,
            TEST_LAUNCHER: launcher,
            TEST_META: metadata,
            TEST_ZIP: zip,
            ...extra,
          },
        });
      let result = run('1');
      assert.equal(result.status, 0, result.stdout + result.stderr);
      assert.equal(JSON.parse(readFileSync(marker)).artifact_sha, 'a'.repeat(40));
      result = run('0');
      assert.equal(result.status, 0, result.stdout + result.stderr);
      const installed = JSON.parse(readFileSync(marker));
      assert.equal(installed.artifact_sha, sha);
      assert.equal(installed.release_tag, 'ext/v9.9.9');
      assert.equal(installed.version, '9.9.9');
      assert.equal(JSON.parse(readFileSync(join(ext, 'manifest.json'))).version, '9.9.9');
      const installedManifest = JSON.parse(readFileSync(join(ext, 'manifest.json')));
      assert.equal(
        installedManifest.background.service_worker,
        'mando-health-entry-' + sha + '-v4.js',
      );
      assert.equal(readFileSync(join(ext, 'worker.js'), 'utf8'), '// fixture background worker\n');
      assert.ok(installedManifest.permissions.includes('nativeMessaging'));
      assert.ok(existsSync(join(home, 'Mando/StagingExtension.previous/manifest.json')));
      result = run('0', { TEST_FORBID_DOWNLOAD: '1' });
      assert.equal(result.status, 0, result.stdout + result.stderr);
      writeFileSync(metadata, JSON.stringify(releases('sha256:' + 'b'.repeat(64))));
      result = run('0');
      assert.equal(result.status, 1);
      assert.match(result.stdout, /Staging verification failed/);
      assert.equal(JSON.parse(readFileSync(marker)).artifact_sha, sha);
      writeFileSync(metadata, JSON.stringify(releases('sha256:' + sha).slice(0, 1)));
      result = run('0');
      assert.equal(result.status, 1);
      assert.match(result.stdout, /No staging release found/);
      assert.equal(JSON.parse(readFileSync(marker)).artifact_sha, sha);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
  },
);
