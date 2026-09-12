import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync,existsSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {spawnSync,execFileSync} from 'node:child_process';

test('real updater: defer while open, install on SHA change, skip current, reject corruption', {skip:process.platform!=='darwin'}, () => {
  const root=mkdtempSync(join(tmpdir(),'mando-updater-test-'));
  try {
    const launcher=resolve('Mando Chrome.app/Contents/Resources/launcher.sh');
    const key=readFileSync(launcher,'utf8').match(/readonly EXPECTED_MANIFEST_KEY="([^"]+)"/)[1];
    const home=join(root,'home'), fixture=join(root,'fixture'), ext=join(home,'Mando/StagingExtension');
    mkdirSync(fixture,{recursive:true});mkdirSync(ext,{recursive:true});
    const manifest={manifest_version:3,name:'Mando AI Docs - Staging',version:'9.9.9',key};
    writeFileSync(join(fixture,'manifest.json'),JSON.stringify(manifest));
    writeFileSync(join(ext,'manifest.json'),JSON.stringify({...manifest,version:'9.9.8'}));
    const marker=join(ext,'mando-chrome-artifact.json');
    writeFileSync(marker,JSON.stringify({artifact_sha:'a'.repeat(40)}));
    const zip=join(root,'fixture.zip');execFileSync('/usr/bin/zip',['-q',zip,'manifest.json'],{cwd:fixture});
    const sha=execFileSync('git',['hash-object',zip],{encoding:'utf8'}).trim();
    const metadata=join(root,'metadata.json');
    writeFileSync(metadata,JSON.stringify({sha,size:readFileSync(zip).length}));
    const wrapper=join(root,'run.sh');
    writeFileSync(wrapper,`source "$TEST_LAUNCHER"\nensure_supported_chrome(){ :; }\nconfigure_github_auth(){ :; }\nfetch_metadata(){ /bin/cp "$TEST_META" "$1"; }\nfetch_artifact(){ [[ "\${TEST_FORBID_DOWNLOAD:-0}" != "1" ]] || return 1; /bin/cp "$TEST_ZIP" "$1"; }\nmain\n`);
    const run=(running,extra={})=>spawnSync('/bin/bash',[wrapper],{encoding:'utf8',env:{...process.env,HOME:home,MANDO_STAGING_BACKGROUND:'1',MANDO_STAGING_TEST_CHROME_RUNNING:running,TEST_LAUNCHER:launcher,TEST_META:metadata,TEST_ZIP:zip,...extra}});
    let result=run('1');assert.equal(result.status,0,result.stdout+result.stderr);
    assert.equal(JSON.parse(readFileSync(marker)).artifact_sha,'a'.repeat(40));
    result=run('0');assert.equal(result.status,0,result.stdout+result.stderr);
    assert.equal(JSON.parse(readFileSync(marker)).artifact_sha,sha);
    assert.equal(JSON.parse(readFileSync(join(ext,'manifest.json'))).version,'9.9.9');
    assert.ok(existsSync(join(home,'Mando/StagingExtension.previous/manifest.json')));
    result=run('0',{TEST_FORBID_DOWNLOAD:'1'});assert.equal(result.status,0,result.stdout+result.stderr);
    writeFileSync(metadata,JSON.stringify({sha:'b'.repeat(40),size:readFileSync(zip).length}));
    result=run('0');assert.equal(result.status,1);
    assert.match(result.stdout,/Staging verification failed/);
    assert.equal(JSON.parse(readFileSync(marker)).artifact_sha,sha);
  } finally {rmSync(root,{recursive:true,force:true});}
});
