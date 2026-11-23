// Exact UUID cleanup for M03-owned rehearsal databases only. No broad DELETE/TRUNCATE/DROP.
import {readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve,sep} from 'node:path';
import assert from 'node:assert/strict';
const dir=resolve(process.argv[2]||'');assert(dir.startsWith(resolve(process.env.LOCALAPPDATA,'Temp')+sep));assert(process.env.PGPASSWORD);
const resource=JSON.parse(await readFile(resolve(dir,'membership-resource.json'),'utf8'));
const docker=(...a)=>execFileSync('docker',['--context','desktop-linux',...a],{encoding:'utf8'}).trim();
assert.equal(JSON.parse(docker('context','inspect','desktop-linux'))[0].Endpoints.docker.Host,'npipe:////./pipe/dockerDesktopLinuxEngine');
const instance=JSON.parse(docker('inspect',resource.container))[0];assert.equal(instance.Id,resource.containerId);assert.equal(instance.Config.Labels['fitcenter.task'],'membership-20261123');assert.equal(instance.Mounts.filter(x=>x.Destination==='/var/lib/postgresql/data')[0].Name,'fitcenter_membership_20261123_data');assert.deepEqual(instance.HostConfig.PortBindings['5432/tcp'],[{HostIp:'127.0.0.1',HostPort:'15440'}]);assert(instance.State.Running);
const props=s=>Object.fromEntries(s.split(/\r?\n/).filter(x=>x.includes('=')&&!x.startsWith('#')).map(x=>{let i=x.indexOf('=');return[x.slice(0,i),x.slice(i+1).replace(/\\([:=!# ])/g,'$1')];}));
const uuid=x=>{assert.match(x,/^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i);return `'${x}'::uuid`;};
const report={at:new Date().toISOString(),databases:[],failed:0};
for(const run of resource.runs){
 assert.match(run.nonce,/^[a-f0-9]{12}$/);
 for(const kind of ['empty','history']){
  const name=`fitcenter_membership_${run.nonce}_${kind}_test`;assert.equal(run[kind],name);
  function sql(q){return docker('exec','-e','PGPASSWORD',instance.Id,'psql','-X','-A','-t','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-U','fitcenter_membership_app','-d',name,'-c',q);}
  assert.equal(sql("SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text||'|'||(SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success) FROM pg_roles WHERE rolname=current_user"),name+'|fitcenter_membership_app|false|1,2,3,4,5,6,9');
  const tables=JSON.parse(sql("SELECT json_agg(tablename ORDER BY tablename) FROM pg_tables WHERE schemaname='public' AND tablename<>'flyway_schema_history'"));
  const owned=Object.fromEntries(tables.map(t=>{assert.match(t,/^[a-z_]+$/);return[t,new Set()];}));
  const add=(t,ids)=>{assert(owned[t]);for(const id of ids){uuid(id);owned[t].add(id);}};
  const ids=(q)=>JSON.parse(sql(`SELECT coalesce(json_agg(id),'[]') FROM (${q}) source`));
  if(kind==='history'){
   const base=props(await readFile(resolve(dir,`run-${run.nonce}-fixture.properties`),'utf8'));assert.equal(base.historyDatabase,name);
   for(const[k,v]of Object.entries(base))if(k.startsWith('table.'))add(k.slice(6),v?v.split(','):[]);
   try{for(const line of (await readFile(resolve(dir,`m03-test-ids-${run.nonce}.tsv`),'utf8')).trim().split(/\r?\n/)){if(!line)continue;const[t,id]=line.split('\t');assert(['users','members','membership_plans'].includes(t));add(t,[id]);}}catch(e){if(e.code!=='ENOENT')throw e;}
   // Recover UUIDs left by the earlier failed test cleanup, only this fresh task DB and exact synthetic namespaces.
   add('users',ids("SELECT id FROM users WHERE email ~ '^m03(-admin)?-[0-9a-f-]{36}@example.invalid$'"));
   add('membership_plans',ids("SELECT id FROM membership_plans WHERE name='Synthetic M03 plan'"));
   const current=JSON.parse(await readFile(resolve(dir,'current-run.json'),'utf8'));
   if(current.history===name){const ui=props(await readFile(resolve(dir,'ui-fixture.properties'),'utf8'));for(const a of ['memberActive','memberDisabled']){add('users',[ui[a+'.userId']]);add('members',[ui[a+'.profileId']]);}add('membership_plans',[ui.plan]);}
   const users=[...owned.users];if(users.length)add('members',ids(`SELECT id FROM members WHERE user_id IN (${users.map(uuid)})`));
   const members=[...owned.members];if(members.length)for(const t of ['memberships','payment_transactions','membership_initial_activations'])add(t,ids(`SELECT id FROM ${t} WHERE member_id IN (${members.map(uuid)})`));
   const entities=[...owned.users,...owned.memberships];if(entities.length)add('audit_logs',ids(`SELECT id FROM audit_logs WHERE entity_id IN (${entities.map(uuid)}) AND entity_type IN ('USER','MEMBERSHIP')`));
  }
  const registryFile=resolve(dir,`cleanup-${run.nonce}-${kind}.json`);
  let registry;try{registry=JSON.parse(await readFile(registryFile,'utf8'));assert.equal(registry.database,name);for(const[t,set]of Object.entries(owned))for(const id of set)assert(registry.ids[t].includes(id),'New unknown ownership after registry sealed');}catch(e){if(e.code!=='ENOENT')throw e;registry={database:name,containerId:instance.Id,ids:Object.fromEntries(Object.entries(owned).map(([t,v])=>[t,[...v].sort()]))};await writeFile(registryFile,JSON.stringify(registry,null,2),{flag:'wx'});}
  function snapshot(){return Object.fromEntries(tables.map(t=>{let list=registry.ids[t];return[t,JSON.parse(sql(`SELECT coalesce(json_agg(x),'[]') FROM (SELECT id,md5(to_jsonb(r)::text) hash FROM ${t} r ${list.length?'WHERE id NOT IN ('+list.map(uuid)+')':''} ORDER BY id)x`))];}));}
  const before=snapshot(),ordered=['audit_logs','membership_initial_activations','payment_transactions','bookings','availability_slots','memberships','membership_plans','members','personal_trainers','users'];
  for(const[t,list]of Object.entries(registry.ids))if(list.length)assert(ordered.includes(t),'No cleanup order for table');
  const statements=['BEGIN;'];for(const t of ordered)for(const id of registry.ids[t]||[])statements.push(`DELETE FROM ${t} WHERE id=${uuid(id)};`);statements.push('COMMIT;');sql(statements.join('\n'));
  assert.deepEqual(snapshot(),before,'Nonfixture rows changed');for(const[t,list]of Object.entries(registry.ids))if(list.length)assert.equal(sql(`SELECT count(*) FROM ${t} WHERE id IN (${list.map(uuid)})`),'0');
  report.databases.push({name,registered:Object.values(registry.ids).reduce((s,x)=>s+x.length,0),checks:3,remainingNonfixtureRows:Object.values(before).reduce((s,x)=>s+x.length,0)});
 }
}
await writeFile(resolve(dir,'m03-cleanup-results.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({databases:report.databases.length,checks:report.databases.reduce((s,x)=>s+x.checks,0),failed:0}));
