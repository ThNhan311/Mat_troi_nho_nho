// Rehearsal-only, no SQL execution. Published SQL and unknown shared histories stay untouched.
import {readFile} from 'node:fs/promises';import {execFileSync} from 'node:child_process';import {createHash} from 'node:crypto';import {dirname,resolve} from 'node:path';import {fileURLToPath} from 'node:url';import assert from 'node:assert/strict';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'../..'),m=JSON.parse(await readFile(resolve(repo,'database/checkin-integration-candidate.json'),'utf8'));
assert.deepEqual(m.candidate,[1,2,3,4,5,6,8,9,10,11,12]);assert.equal(m.releaseReady,false);assert.equal(execFileSync('git',['rev-parse','origin/feature/database-schema'],{cwd:repo,encoding:'utf8'}).trim(),m.databaseCommit,'Database ref changed; review before rehearsal');
const files=execFileSync('git',['ls-files','--cached','--others','--exclude-standard','database'],{cwd:repo,encoding:'utf8'}).trim().split(/\r?\n/).filter(p=>/\/V\d+__.*\.sql$/.test(p));assert.deepEqual(files.sort(),m.entries.map(e=>e.path).sort(),'Historical inventory (pin c3eb411); use core-readiness.ps1 for the current exact candidate. Unknown SQL is not accepted.');
for(const e of m.entries)assert.equal(createHash('sha256').update(await readFile(resolve(repo,e.path))).digest('hex'),e.sha256,e.path);
console.log('Checkin candidate verified: V1-V6,V8-V12; V7 quarantined, releaseReady=false');
