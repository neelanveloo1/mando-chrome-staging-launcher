import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import vm from 'node:vm';
const resources = 'Mando Chrome.app/Contents/Resources/';
test('a completed request cannot cancel the next request on a late disconnect', () => {
  let requestListener;
  const ports = [],
    replies = [];
  const origin = 'https://mando-chrome-status.vercel.app';
  const window = {
    addEventListener: (name, fn) => (requestListener = fn),
    postMessage: (value) => replies.push(value),
  };
  window.top = window;
  const chrome = {
    runtime: {
      connect() {
        const port = {
          onMessage: { addListener: (fn) => (port.reply = fn) },
          onDisconnect: { addListener: (fn) => (port.closed = fn) },
          disconnect() {},
          postMessage() {},
        };
        ports.push(port);
        return port;
      },
    },
  };
  vm.runInNewContext(readFileSync(resources + 'bridge-content.js', 'utf8'), {
    window,
    location: { origin },
    chrome,
    setTimeout: () => 1,
    clearTimeout() {},
  });
  const first = '00000000-0000-0000-0000-000000000001',
    second = '00000000-0000-0000-0000-000000000002';
  const send = (nonce) =>
    requestListener({ source: window, origin, data: { type: 'MANDO_STATUS_REQUEST_V2', nonce } });
  send(first);
  ports[0].reply({ nonce: first, report: { protocol: 2 } });
  send(second);
  ports[0].closed();
  assert.equal(replies.length, 1);
  ports[1].reply({ nonce: second, report: { protocol: 2 } });
  assert.equal(replies.length, 2);
  assert.equal(replies[1].nonce, second);
  assert.equal(replies[1].error, undefined);
});
test('live worker reports baked-in identity and restricts the caller', async () => {
  let connect,
    nativeCalls = 0;
  const sha = 'c'.repeat(40);
  const context = {
    URL,
    Date,
    navigator: {
      userAgentData: {
        getHighEntropyValues: async () => ({
          fullVersionList: [{ brand: 'Google Chrome', version: '152.0.7977.84' }],
        }),
      },
    },
    chrome: {
      runtime: {
        id: 'staging-id',
        getManifest: () => ({ version: '1.86.0' }),
        onConnect: { addListener: (fn) => (connect = fn) },
        sendNativeMessage: async (name, payload) => {
          nativeCalls++;
          assert.equal(name, 'work.mando.chrome.status');
          assert.deepEqual(JSON.parse(JSON.stringify(payload)), { action: 'status' });
          return { check: 'ok', latestSha: sha, checkedAt: new Date().toISOString() };
        },
      },
    },
  };
  vm.runInNewContext(
    readFileSync(resources + 'bridge-worker.js', 'utf8').replace('__MANDO_ARTIFACT_SHA__', sha),
    context,
  );
  let disconnected = false;
  connect({
    name: 'mando.health.v2',
    sender: { id: 'staging-id', frameId: 0, url: 'https://evil.example/' },
    disconnect: () => (disconnected = true),
  });
  assert.ok(disconnected);
  assert.equal(nativeCalls, 0);
  let message, reply;
  connect({
    name: 'mando.health.v2',
    sender: { id: 'staging-id', frameId: 0, url: 'https://mando-chrome-status.vercel.app/' },
    disconnect() {},
    onMessage: { addListener: (fn) => (message = fn) },
    postMessage: (value) => (reply = value),
  });
  await message({ action: 'status', nonce: '00000000-0000-0000-0000-000000000000' });
  assert.equal(reply.report.runningSha, sha);
  assert.equal(reply.report.runningVersion, '1.86.0');
  assert.equal(reply.report.chromeVersion, '152.0.7977.84');
  assert.equal(nativeCalls, 1);
});
test(
  'native host rejects unapproved actions and origins with valid framing',
  { skip: process.platform !== 'darwin' },
  () => {
    for (const [origin, action] of [
      ['chrome-extension://wrong/', 'status'],
      ['chrome-extension://gonaohmomchmmkmnnioldofcabibpicp/', 'execute'],
    ]) {
      const body = Buffer.from(JSON.stringify({ action })),
        header = Buffer.alloc(4);
      header.writeUInt32LE(body.length);
      const r = spawnSync('/bin/bash', [resources + 'native-host.sh', origin], {
        input: Buffer.concat([header, body]),
      });
      assert.equal(r.status, 0, r.stderr.toString());
      assert.equal(r.stdout.readUInt32LE(), r.stdout.length - 4);
      assert.equal(JSON.parse(r.stdout.subarray(4)).check, 'checker_error');
    }
  },
);
