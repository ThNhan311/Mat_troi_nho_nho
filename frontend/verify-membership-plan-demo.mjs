// Isolated M-01 demo DB guard/audit/UUID cleanup. No successful API writes here.
// PGPASSWORD in process only; node frontend/verify-membership-plan-demo.mjs <manifest> <prepare|audit|cleanup>
import {readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve,dirname,sep} from 'node:path';
import assert from 'node:assert/strict';
const manifest=resolve(process.argv[2]||''),phase=process.argv[3];
assert(manifest.startsWith(resolve(process.env.LOCALAPPDATA,'Temp')+sep)); assert(['prepare','audit','cleanup'].includes(phase)); assert(process.env.PGPASSWORD);
const dir=dirname(manifest),beforePath=resolve(dir,'m01-db-before.json'),registryPath=resolve(dir,'m01-ui-results.json');
const docker=(...a)=>execFileSync('docker',['--context','desktop-linux',...a],{encoding:'utf8'}).trim();
const instance=JSON.parse(docker('inspect','fitcenter-baseline-20261120-db'))[0];
assert.equal(instance.Id,'e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0');assert(instance.State.Running);assert.equal(instance.Config.Labels['fitcenter.task'],'baseline-20261120');
const mounts=instance.Mounts.filter(m=>m.Destination==='/var/lib/postgresql/data');assert.equal(mounts.length,1);assert.equal(mounts[0].Type,'volume');assert.equal(mounts[0].Name,'fitcenter_baseline_20261120_data');assert.deepEqual(instance.HostConfig.PortBindings['5432/tcp'],[{HostIp:'127.0.0.1',HostPort:'15437'}]);
const endpoint=JSON.parse(docker('context','inspect','desktop-linux'))[0];assert.equal(endpoint.Endpoints.docker.Host,'npipe:////./pipe/dockerDesktopLinuxEngine');
function sql(q){return docker('exec','-e','PGPASSWORD',instance.Id,'psql','-X','-A','-t','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-U','fitcenter_baseline_app','-d','fitcenter_baseline_20261120_test','-c',q);}
assert.equal(sql("SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text||'|'||(SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success) FROM pg_roles WHERE rolname=current_user"),'fitcenter_baseline_20261120_test|fitcenter_baseline_app|false|1,2,3,4,5,6');
const snapshot=()=>JSON.parse(sql("SELECT json_build_object('users',(SELECT json_agg(u) FROM (SELECT id,role,status FROM users ORDER BY id)u),'members',(SELECT json_agg(t) FROM (SELECT * FROM members ORDER BY id)t),'pts',(SELECT json_agg(t) FROM (SELECT * FROM personal_trainers ORDER BY id)t),'memberships',(SELECT json_agg(t) FROM (SELECT * FROM memberships ORDER BY id)t),'payments',(SELECT json_agg(t) FROM (SELECT * FROM payment_transactions ORDER BY id)t),'bookings',(SELECT json_agg(t) FROM (SELECT * FROM bookings ORDER BY id)t),'slots',(SELECT json_agg(t) FROM (SELECT * FROM availability_slots ORDER BY id)t),'policy',(SELECT json_agg(t) FROM (SELECT * FROM booking_policy ORDER BY id)t))"));
if(phase==='prepare'){
 const before={nonPlan:snapshot(),plans:JSON.parse(sql('SELECT coalesce(json_agg(p),\'[]\') FROM (SELECT * FROM membership_plans ORDER BY id)p'))};
 await writeFile(beforePath,JSON.stringify(before,null,2),{flag:'wx'});console.log(JSON.stringify({phase,dbChecks:2,failed:0}));
}else{
 const before=JSON.parse(await readFile(beforePath,'utf8')),registry=JSON.parse(await readFile(registryPath,'utf8'));
 assert.deepEqual(snapshot(),before.nonPlan,'No Member/booking/payment/account mutation');assert(registry.created.length>0);
 let checks=1;
 for(const plan of registry.created){
  assert.match(plan.id,/^[0-9a-f-]{36}$/i);assert(!before.plans.some(p=>p.id===plan.id));
  assert.equal(plan.name,'Synthetic M01 UI plan');assert.equal(plan.description,'Synthetic M01 original Admin screen');assert.equal(plan.durationDays,37);assert.equal(plan.price,123456.78);
  const rows=JSON.parse(sql(`SELECT coalesce(json_agg(p),'[]') FROM (SELECT id,name,description,duration_days,price,status FROM membership_plans WHERE id='${plan.id}'::uuid)p`));
  if(phase==='cleanup'&&rows.length===0){checks++;continue;}
  assert.equal(rows.length,1);assert.deepEqual(rows[0],{id:plan.id,name:plan.name,description:plan.description,duration_days:37,price:123456.78,status:'ACTIVE'});checks++;
  if(phase==='cleanup'){
   // Guard ownership by exact response UUID + complete expected values, refuse referenced plans. FK is final protection.
   const q=`BEGIN; SELECT id FROM membership_plans WHERE id='${plan.id}'::uuid FOR UPDATE; DELETE FROM membership_plans WHERE id='${plan.id}'::uuid AND name='Synthetic M01 UI plan' AND description='Synthetic M01 original Admin screen' AND duration_days=37 AND price=123456.78 AND status='ACTIVE' AND NOT EXISTS(SELECT 1 FROM memberships WHERE plan_id='${plan.id}'::uuid) AND NOT EXISTS(SELECT 1 FROM payment_transactions WHERE plan_id='${plan.id}'::uuid); COMMIT;`;
   const out=sql(q);assert(out.includes('DELETE 1'));checks++;
  }
 }
 const ids=registry.created.map(p=>`'${p.id}'::uuid`).join(',');
 const remaining=JSON.parse(sql(`SELECT coalesce(json_agg(p),'[]') FROM (SELECT * FROM membership_plans ${phase==='audit'?`WHERE id NOT IN (${ids})`:''} ORDER BY id)p`));
 assert.deepEqual(remaining,before.plans,'No changes outside exact new plan UUIDs');checks++;
 const result={phase,dbChecks:checks,failed:0,skipped:0,createdIds:registry.created.map(p=>p.id),at:new Date().toISOString()};
 await writeFile(resolve(dir,'m01-db-'+phase+'.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}