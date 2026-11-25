// Frozen I-01 candidate. This never executes SQL or contacts a shared database.
import {readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {resolve,dirname} from 'node:path';import {fileURLToPath} from 'node:url';import assert from 'node:assert/strict';
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'../..'),lock=resolve(repo,'database/core-integration-candidate.json');
const git=(...args)=>execFileSync('git',args,{cwd:repo,maxBuffer:8*1024*1024});
const hash=b=>createHash('sha256').update(b).digest('hex');
function flyway(b){let crc=0xffffffff;for(const line of b.toString('utf8').replace(/^\uFEFF/,'').split(/\r\n|\n|\r/)){for(const c of Buffer.from(line)){crc^=c;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0);}}return (crc^0xffffffff)|0;}
const ref='origin/feature/database-schema',base='950311082d4cc5b2c5b85b1a3f8cd644246cd932';
const paths=git('ls-tree','-r','--name-only',base,'database').toString().trim().split('\n').filter(p=>/\/V(?:[1-6]|8|9|10)__.*\.sql$/.test(p)).sort((a,b)=>Number(a.match(/V(\d+)__/)[1])-Number(b.match(/V(\d+)__/)[1]));
assert.equal(paths.length,9);assert.equal(git('rev-parse',ref).toString().trim(),'558fb03fd5927ca9e04d17b54fd46e429fe62bb5','Database ref changed: review and regenerate inventory deliberately');
const describe=(path,b)=>({version:Number(path.match(/V(\d+)__/)[1]),path,sha256:hash(b),flywayChecksum:flyway(b)});
if(process.argv[2]==='--freeze'){
 const entries=[];for(const path of paths){const b=await readFile(resolve(repo,path));entries.push({...describe(path,b),gitBlobSha256:hash(git('show',base+':'+path)),dependsOn:entries.map(e=>e.version),classification:path.includes('/migrations/')?'canonical':'rehearsal'});}
 const v7='database/database/migrations/V7__membership_periods.sql';
 const refs=git('for-each-ref','--format=%(refname)','refs/remotes/origin').toString().trim().split('\n');const known=[];
 for(const r of refs){const commit=git('rev-parse',r).toString().trim();for(const path of git('ls-tree','-r','--name-only',r,'database').toString().trim().split('\n').filter(p=>/\/V\d+__.*\.sql$/.test(p)))known.push({ref:r,commit,...describe(path,git('show',r+':'+path))});}
 await writeFile(lock,JSON.stringify({format:1,base,databaseRef:ref,databaseCommit:git('rev-parse',ref).toString().trim(),candidate:[1,2,3,4,5,6,8,9,10],releaseReady:false,sharedDatabaseInventory:'UNKNOWN: no shared DB was contacted; V7 may already be applied elsewhere',entries,quarantined:[{...describe(v7,git('show',ref+':'+v7)),reason:'Drops payment period columns without backfill; incompatible with current M03 COUNTER records. Never execute in this candidate.'}],knownRemoteMigrations:known},null,2)+'\n',{flag:'wx'});
}else{
 assert.equal(process.argv[2],'--verify','Use --freeze once after review, or --verify before rehearsal');const m=JSON.parse(await readFile(lock,'utf8'));assert.equal(m.base,base);assert.deepEqual(m.candidate,[1,2,3,4,5,6,8,9,10]);assert.equal(m.releaseReady,false);assert.equal(m.entries.length,9);
 for(const e of m.entries){const b=await readFile(resolve(repo,e.path));assert.equal(hash(b),e.sha256,'SQL bytes changed: '+e.path);assert.equal(flyway(b),e.flywayChecksum);assert.equal(hash(git('show',base+':'+e.path)),e.gitBlobSha256);}
 const actual=git('ls-files','--cached','--others','--exclude-standard','database').toString().trim().split('\n').filter(p=>/\/V\d+__.*\.sql$/.test(p)).sort();assert.deepEqual(actual,m.entries.map(e=>e.path).sort(),'Historical I-01 inventory (pin d2774c9); use core-readiness.ps1 for the current exact candidate. Unknown SQL is not accepted.');
 for(const e of m.quarantined)assert.equal(hash(git('show',ref+':'+e.path)),e.sha256);
}
console.log('I-01 candidate verified: V1-V6,V8,V9,V10; V7 quarantined; releaseReady=false');