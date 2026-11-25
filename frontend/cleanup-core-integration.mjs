import {verifyAccountResource} from '../backend/scripts/rehearsal-resource.mjs';
// I-01 exact UUID cleanup for newly registered runs only. No broad DELETE/TRUNCATE/DROP.
import {readFile,writeFile,readdir} from 'node:fs/promises';import {execFileSync} from 'node:child_process';import {resolve,sep} from 'node:path';import assert from 'node:assert/strict';
const dir=resolve(process.argv[2]||'');assert(dir.startsWith(resolve(process.env.LOCALAPPDATA,'Temp')+sep));assert(process.env.PGPASSWORD);
const resource=JSON.parse(await readFile(resolve(dir,'account-resource.json'),'utf8'));
const docker=(...a)=>execFileSync('docker',['--context','desktop-linux',...a],{encoding:'utf8'}).trim();
assert.equal(JSON.parse(docker('context','inspect','desktop-linux'))[0].Endpoints.docker.Host,'npipe:////./pipe/dockerDesktopLinuxEngine');
const instance=JSON.parse(docker('inspect',resource.container))[0];verifyAccountResource(resource,instance);assert.equal(instance.Id,resource.containerId);assert.equal(instance.Config.Labels['fitcenter.task'],'account-20261123');assert.equal(instance.Mounts.find(x=>x.Destination==='/var/lib/postgresql/data').Name,resource.volume);assert.deepEqual(instance.HostConfig.PortBindings['5432/tcp'],[{HostIp:'127.0.0.1',HostPort:'15441'}]);assert(instance.State.Running);
const props=s=>Object.fromEntries(s.split(/\r?\n/).filter(s=>s.includes('=')&&!s.startsWith('#')).map(s=>{let i=s.indexOf('=');return[s.slice(0,i),s.slice(i+1).replace(/\\([:=!# ])/g,'$1')];}));
const literal=id=>{assert.match(id,/^[a-f0-9]{8}(-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i);return `'${id}'::uuid`;};const output={at:new Date().toISOString(),databases:[],failed:0};
const privateFiles=await readdir(dir),uiFiles=privateFiles.filter(p=>p==='core-ui-registry.json'||/^core-attempt\d+-registry\.json$/.test(p));
for(const run of resource.runs)for(const kind of ['empty','history']){
 const db=`fitcenter_account_${run.nonce}_${kind}_test`;assert.equal(run[kind],db);assert.match(run.nonce,/^[a-f0-9]{12}$/);
 const sql=q=>docker('exec','-e','PGPASSWORD',instance.Id,'psql','-X','-A','-t','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-U','fitcenter_account_app','-d',db,'-c',q);
 assert.equal(sql("SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text||'|'||(SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success) FROM pg_roles WHERE rolname=current_user"),db+'|fitcenter_account_app|false|1,2,3,4,5,6,8,9,10');
 const tables=JSON.parse(sql("SELECT json_agg(tablename ORDER BY tablename) FROM pg_tables WHERE schemaname='public' AND tablename<>'flyway_schema_history'")),owned=Object.fromEntries(tables.map(t=>{assert.match(t,/^[a-z_]+$/);return[t,new Set()];}));
 const add=(t,list)=>{assert(owned[t]);for(const id of list){literal(id);owned[t].add(id);}};const pk=t=>t.endsWith('_account_activation')?'user_id':'id';
 const ids=q=>JSON.parse(sql(`SELECT coalesce(json_agg(id),'[]') FROM (${q}) source`));
 if(kind==='history'){
  // Original runner registry, or sealed recovery registry when ephemeral sandbox files were lost.
  if(privateFiles.includes(`recovered-${run.nonce}.json`)){const recovered=JSON.parse(await readFile(resolve(dir,`recovered-${run.nonce}.json`),'utf8'));assert.equal(recovered.database,db);assert.equal(recovered.containerId,instance.Id);for(const[t,list]of Object.entries(recovered.ids))add(t,list);}
  try{const fixture=props(await readFile(resolve(dir,`run-${run.nonce}-fixture.properties`),'utf8'));assert.equal(fixture.historyDatabase,db);for(const[k,v]of Object.entries(fixture))if(k.startsWith('table.'))add(k.slice(6),v?v.split(','):[]);}catch(e){if(e.code!=='ENOENT')throw e;}
  try{for(const line of (await readFile(resolve(dir,`account-test-ids-${run.nonce}.tsv`),'utf8')).trim().split(/\r?\n/)){if(!line)continue;const[t,id]=line.split('\t');assert(['users','members','personal_trainers'].includes(t));add(t,[id]);}}catch(e){if(e.code!=='ENOENT')throw e;}
  try{const demo=props(await readFile(resolve(dir,'demo-fixture.properties'),'utf8'));if(demo.historyDatabase===db)for(const[k,v]of Object.entries(demo))if(k.startsWith('table.'))add(k.slice(6),v?v.split(','):[]);}catch(e){if(e.code!=='ENOENT')throw e;}
  // Integrated M03 tests record generated accounts/plans under this exact ledger.
  try{for(const line of (await readFile(resolve(dir,`m03-test-ids-${run.nonce}.tsv`),'utf8')).trim().split(/\r?\n/)){if(!line)continue;const[t,id]=line.split('\t');assert(['users','members','membership_plans'].includes(t));add(t,[id]);}}catch(e){if(e.code!=='ENOENT')throw e;}
  for(const file of uiFiles){const ui=JSON.parse(await readFile(resolve(dir,file),'utf8'));if(ui.run!==run.nonce)continue;
   for(const email of ui.intentEmails){assert.match(email,/^core-e2e-[a-f0-9-]{36}@example\.invalid$/);add('users',ids(`SELECT id FROM users WHERE email='${email}' AND role IN ('MEMBER','PT')`));}
   for(const a of ui.created){assert(['MEMBER','PT'].includes(a.role));add('users',[a.userId]);add(a.role==='PT'?'personal_trainers':'members',[a.profileId]);}
   if(ui.plan)add('membership_plans',[ui.plan.id]);if(ui.policy)add('booking_policy',[ui.policy.id]);
  }
  const users=[...owned.users];if(users.length)for(const t of ['members','personal_trainers'])add(t,ids(`SELECT id FROM ${t} WHERE user_id IN (${users.map(literal)})`));
  const members=[...owned.members];if(members.length)for(const t of ['memberships','payment_transactions','membership_initial_activations','bookings'])add(t,ids(`SELECT id FROM ${t} WHERE member_id IN (${members.map(literal)})`));
  const pts=[...owned.personal_trainers];if(pts.length)add('availability_slots',ids(`SELECT id FROM availability_slots WHERE pt_id IN (${pts.map(literal)})`));
  if(users.length)for(const t of ['member_account_activation','pt_account_activation'])add(t,ids(`SELECT user_id id FROM ${t} WHERE user_id IN (${users.map(literal)})`));
  const entities=[...owned.users,...owned.memberships];if(entities.length)add('audit_logs',ids(`SELECT id FROM audit_logs WHERE entity_id IN (${entities.map(literal)}) AND entity_type IN ('USER','MEMBERSHIP')`));
 }
 const file=resolve(dir,`cleanup-${run.nonce}-${kind}.json`);let registry;
 try{registry=JSON.parse(await readFile(file,'utf8'));assert.equal(registry.database,db);for(const[t,set]of Object.entries(owned))for(const id of set)assert(registry.ids[t].includes(id),'Ownership changed after cleanup registry sealed');}catch(e){if(e.code!=='ENOENT')throw e;registry={database:db,containerId:instance.Id,ids:Object.fromEntries(Object.entries(owned).map(([t,v])=>[t,[...v].sort()]))};await writeFile(file,JSON.stringify(registry,null,2),{flag:'wx'});}
 function snapshot(){const pairs=tables.map(t=>{let list=registry.ids[t];return `'${t}',(SELECT coalesce(json_agg(x),'[]') FROM (SELECT ${pk(t)} id,md5(to_jsonb(r)::text) hash FROM ${t} r ${list.length?'WHERE '+pk(t)+' NOT IN ('+list.map(literal)+')':''} ORDER BY ${pk(t)})x)`;});return JSON.parse(sql('SELECT json_build_object('+pairs.join(',')+')'));}

 const before=snapshot(),order=['audit_logs','membership_initial_activations','payment_transactions','bookings','availability_slots','memberships','membership_plans','booking_policy','member_account_activation','pt_account_activation','members','personal_trainers','users'];for(const[t,list]of Object.entries(registry.ids))if(list.length)assert(order.includes(t),'Unsupported cleanup dependency');
 let statements=['BEGIN;'];for(const t of order)for(const id of registry.ids[t]||[])statements.push(`DELETE FROM ${t} WHERE ${pk(t)}=${literal(id)};`);statements.push('COMMIT;');sql(statements.join('\n'));
 assert.deepEqual(snapshot(),before,'Nonfixture rows changed');const remaining=Object.entries(registry.ids).filter(([t,list])=>list.length).map(([t,list])=>`(SELECT count(*) FROM ${t} WHERE ${pk(t)} IN (${list.map(literal)}))`);if(remaining.length)assert.equal(sql('SELECT '+remaining.join('+')),'0');
 output.databases.push({name:db,registered:Object.values(registry.ids).reduce((s,x)=>s+x.length,0),checks:3,nonfixtureRowsPreserved:Object.values(before).reduce((s,x)=>s+x.length,0)});
}
await writeFile(resolve(dir,'core-cleanup-results.json'),JSON.stringify(output,null,2));console.log(JSON.stringify({databases:output.databases.length,checks:output.databases.reduce((s,x)=>s+x.checks,0),failed:0}));
