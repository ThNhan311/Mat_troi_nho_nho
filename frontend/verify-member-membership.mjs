// M-04: real Flutter Web + HTTP + guarded isolated PostgreSQL, not widget tests.
// PGPASSWORD process-only; node frontend/verify-member-membership.mjs <private fixture.properties> <playwright index.mjs> <run|cleanup>
import {readFile,writeFile,mkdir,readdir} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve,dirname,sep} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {randomUUID,createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const manifest=resolve(process.argv[2]||''),phase=process.argv[4]||'run';
assert(manifest.startsWith(resolve(process.env.LOCALAPPDATA,'Temp')+sep));assert(['run','cleanup'].includes(phase));assert(process.env.PGPASSWORD);
const f=Object.fromEntries((await readFile(manifest,'utf8')).split(/\r?\n/).filter(s=>s.includes('=')&&!s.startsWith('#')).map(s=>{const i=s.indexOf('=');return [s.slice(0,i),s.slice(i+1).replace(/\\([:=!# ])/g,'$1')];}));
assert.equal(f.seeded,'true');
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'..'),dir=dirname(manifest),registry=resolve(dir,'m04-registry.json'),out=resolve(dir,'m04-results.json');
const evidence=resolve(repo,'docs/backend-handover/evidence/member-membership');
const docker=(...a)=>execFileSync('docker',['--context','desktop-linux',...a],{encoding:'utf8'}).trim();
assert.equal(JSON.parse(docker('context','inspect','desktop-linux'))[0].Endpoints.docker.Host,'npipe:////./pipe/dockerDesktopLinuxEngine');
const instance=JSON.parse(docker('inspect','fitcenter-baseline-20261120-db'))[0];
assert.equal(instance.Id,'e4c5299f24d549bce3d962e539da61411889930ef33be71303c6bf1577d085e0');assert(instance.State.Running);assert.equal(instance.Config.Labels['fitcenter.task'],'baseline-20261120');
assert.deepEqual(instance.HostConfig.PortBindings['5432/tcp'],[{HostIp:'127.0.0.1',HostPort:'15437'}]);
const mounts=instance.Mounts.filter(m=>m.Destination==='/var/lib/postgresql/data');assert.equal(mounts.length,1);assert.equal(mounts[0].Type,'volume');assert.equal(mounts[0].Name,'fitcenter_baseline_20261120_data');
function sql(q){return docker('exec','-e','PGPASSWORD',instance.Id,'psql','-X','-A','-t','-v','ON_ERROR_STOP=1','-h','127.0.0.1','-U','fitcenter_baseline_app','-d','fitcenter_baseline_20261120_test','-c',q);}
assert.equal(sql("SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text||'|'||(SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success) FROM pg_roles WHERE rolname=current_user"),'fitcenter_baseline_20261120_test|fitcenter_baseline_app|false|1,2,3,4,5,6');
const uuid=x=>{assert.match(x,/^[0-9a-f-]{36}$/i);return `'${x}'::uuid`;};
const a=uuid(f.membershipA),b=uuid(f.membershipB),ma=uuid(f['memberA.profileId']),mb=uuid(f['memberB.profileId']),plan=uuid(f.plan);
const queryRows=q=>JSON.parse(sql(`SELECT coalesce(json_agg(t),'[]') FROM (${q})t`));
const rows=()=>queryRows('SELECT * FROM memberships ORDER BY id');
const snapshot=()=>JSON.parse(sql("SELECT json_build_object('users',(SELECT json_agg(u) FROM (SELECT id,role,status,updated_at FROM users ORDER BY id)u),'members',(SELECT json_agg(t) FROM (SELECT * FROM members ORDER BY id)t),'pts',(SELECT json_agg(t) FROM (SELECT * FROM personal_trainers ORDER BY id)t),'plans',(SELECT json_agg(t) FROM (SELECT * FROM membership_plans ORDER BY id)t),'payments',(SELECT json_agg(t) FROM (SELECT * FROM payment_transactions ORDER BY id)t),'bookings',(SELECT json_agg(t) FROM (SELECT * FROM bookings ORDER BY id)t),'slots',(SELECT json_agg(t) FROM (SELECT * FROM availability_slots ORDER BY id)t),'policy',(SELECT json_agg(t) FROM (SELECT * FROM booking_policy ORDER BY id)t))"));
function exactDelete(id,member){return `DELETE FROM memberships WHERE id=${id} AND member_id=${member} AND plan_id=${plan};`;}
if(phase==='cleanup'){
 const reg=JSON.parse(await readFile(registry,'utf8'));
 assert.deepEqual(snapshot(),reg.nonMembership,'No account/booking/payment/plan changes during read checks');
 for(const x of reg.extra)assert(!reg.memberships.some(m=>m.id===x));
 const fixtureIds=new Set([f.membershipA,f.membershipB,...reg.extra]);
 assert.deepEqual(rows().filter(m=>!fixtureIds.has(m.id)),reg.memberships.filter(m=>!fixtureIds.has(m.id)),'No membership changes outside fixture');
 // Exact registered UUIDs only. Restore original full rows by INSERT (no update trigger timestamp drift).
 const original=reg.memberships.filter(m=>[f.membershipA,f.membershipB].includes(m.id));assert.equal(original.length,2);
 const values=JSON.stringify(original).replaceAll("'","''");
 sql(`BEGIN; ${[exactDelete(a,ma),exactDelete(b,mb),...reg.extra.map(id=>exactDelete(uuid(id),ma))].join(' ')} INSERT INTO memberships SELECT * FROM json_populate_recordset(null::memberships,'${values}'::json); COMMIT;`);
 assert.deepEqual(rows(),reg.memberships);assert.deepEqual(snapshot(),reg.nonMembership);
 await writeFile(resolve(dir,'m04-cleanup.json'),JSON.stringify({at:new Date().toISOString(),dbChecks:4,failed:0,skipped:0,restored:true},null,2));
 console.log(JSON.stringify({phase,dbChecks:4,failed:0,skipped:0}));process.exit(0);
}
await mkdir(evidence,{recursive:true});
const reg={memberships:rows(),nonMembership:snapshot(),extra:[randomUUID(),randomUUID()]};
assert(reg.memberships.some(m=>m.id===f.membershipA&&m.member_id===f['memberA.profileId']&&m.plan_id===f.plan));
assert(reg.memberships.some(m=>m.id===f.membershipB&&m.member_id===f['memberB.profileId']&&m.plan_id===f.plan));
await writeFile(registry,JSON.stringify(reg,null,2),{flag:'wx'}); // Never overwrite an earlier run/cleanup authority.
const result={at:new Date().toISOString(),sourceBase:'0c31947b60bacbb7d7516556a7f2b44193ec86a8',ui:[],http:[],db:[],sourceHashes:{},seededScenarios:'All memberships/accounts are synthetic SQL fixture; UI performs reads only; no Member activation implemented.'};
async function files(dir){let out=[];for(const e of await readdir(resolve(repo,dir),{withFileTypes:true})){const p=dir+'/'+e.name;if(e.isDirectory())out.push(...await files(p));else if(p.endsWith('.dart'))out.push(p);}return out;}
for(const p of ['frontend/verify-member-membership.mjs','frontend/serve-booking-web.mjs','backend/scripts/BookingDemo.java','backend/scripts/booking-demo.ps1','frontend/fitcenter_member/pubspec.yaml','frontend/fitcenter_member/pubspec.lock',...await files('frontend/fitcenter_member/lib'),...await files('frontend/fitcenter_member/test')].sort())result.sourceHashes[p]=createHash('sha256').update(await readFile(resolve(repo,p))).digest('hex');
const persist=()=>writeFile(out,JSON.stringify(result,null,2));
const httpCheck=(ok,label)=>{assert(ok,label);result.http.push(label);};
const dbCheck=(ok,label)=>{assert(ok,label);result.db.push(label);};
const base='http://127.0.0.1:18081/api/v1';
async function token(actor){const r=await fetch(base+'/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:f[actor+'.email'],password:f[actor+'.password']})});assert.equal(r.status,200,'Fixture login');return (await r.json()).accessToken;}
async function mine(t){const r=await fetch(base+'/memberships/me',{headers:{Authorization:'Bearer '+t}});assert.equal(r.status,200);const body=await r.json();assert(Array.isArray(body));return body;}
const today=sql("SELECT (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date::text");assert.match(today,/^\d{4}-\d{2}-\d{2}$/);
const date=delta=>`('${today}'::date + ${delta})`;
function change(status,start=0,end=0){assert(['ACTIVE','SUSPENDED','EXPIRED','CANCELLED','PENDING_ACTIVATION'].includes(status));sql(`UPDATE memberships SET status='${status}',start_date=${start===null?'NULL':date(start)},expiry_date=${end===null?'NULL':date(end)} WHERE id=${a} AND member_id=${ma} AND plan_id=${plan}`);}
let browser;
try{
 const ta=await token('memberA'),tb=await token('memberB');
 const initialA=await mine(ta),initialB=await mine(tb);
 httpCheck(initialA.length===1&&initialA[0].id===f.membershipA&&initialB.length===1&&initialB[0].id===f.membershipB,'Owner isolation: users.id mapped to distinct Member profiles');
 const unauth=await fetch(base+'/memberships/me');httpCheck(unauth.status===401,'No token 401');
 for(const actor of ['ptA','admin']){const t=await token(actor),r=await fetch(base+'/memberships/me',{headers:{Authorization:'Bearer '+t}});httpCheck(r.status===403,actor+' denied 403');}
 const candidate=await fetch(base+'/memberships/me?memberId='+f['memberB.profileId'],{headers:{Authorization:'Bearer '+ta}});
 httpCheck(candidate.status===200&&(await candidate.json()).every(x=>x.id!==f.membershipB),'Client owner query cannot change principal ownership');
 for(const [stored,start,end,expected] of [['ACTIVE',0,0,'ACTIVE'],['ACTIVE',1,2,'PENDING_ACTIVATION'],['ACTIVE',-2,-1,'EXPIRED'],['PENDING_ACTIVATION',null,null,'PENDING_ACTIVATION'],['SUSPENDED',-1,1,'SUSPENDED'],['EXPIRED',-2,-1,'EXPIRED'],['CANCELLED',-2,-1,'CANCELLED']]){
  change(stored,start,end);const list=await mine(ta),m=list.find(m=>m.id===f.membershipA);
  const db=queryRows(`SELECT id,plan_id,start_date,expiry_date,status FROM memberships WHERE id=${a}`)[0];
  httpCheck(list.length===1&&m.status===expected&&m.startDate===db.start_date&&m.endDate===db.expiry_date&&m.planId===db.plan_id,'DATE VN '+stored+'/'+start+'/'+end+' -> '+expected);
  dbCheck(db.status===stored,'Stored status remains '+stored+'; GET does not persist effective status');
 }
 change('ACTIVE',0,0);
 sql(`BEGIN; ${exactDelete(b,mb)} ${reg.extra.map(id=>`INSERT INTO memberships(id,member_id,plan_id,start_date,expiry_date,status) VALUES(${uuid(id)},${ma},${plan},${date(-3)},${date(-2)},'CANCELLED');`).join(' ')} COMMIT;`);
 httpCheck((await mine(tb)).length===0,'No memberships returns empty array');
 const multiple=await mine(ta);httpCheck(multiple.length===3&&new Set(multiple.map(m=>m.id)).size===3&&multiple.every(m=>m.id!==f.membershipB),'Multiple memberships preserved; no implicit first/current');
 const {chromium}=await import(pathToFileURL(resolve(process.argv[3])).href);
 browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
 const context=await browser.newContext({viewport:{width:1024,height:768},timezoneId:'America/Los_Angeles'}),p=await context.newPage();
 const delay=()=>new Promise(r=>setTimeout(r,300));
 const check=(ok,label)=>{assert(ok,label);result.ui.push(label);};
 const click=async(role,name)=>{const el=p.getByRole(role,{name,exact:true});await el.waitFor({state:'attached'});await el.evaluate(e=>e.click());await delay();};
 async function fill(name,value){const el=p.getByRole('textbox',{name,exact:true});await el.click({force:true});await delay();await p.keyboard.press('Control+A');await p.keyboard.insertText(value);assert((await el.inputValue())===value,'Focused login field');}
 async function text(){return p.locator('flt-semantics-host').evaluate(e=>e.innerText+'\n'+[...e.querySelectorAll('*')].map(x=>[x.getAttribute('aria-label'),x.getAttribute('aria-valuetext'),x.value].filter(Boolean).join(' ')).join('\n'));}
 async function allText(){let collected='';await p.mouse.move(500,400);await p.mouse.wheel(0,-5000);await delay();for(let i=0;i<9;i++){collected+='\n'+await text();await p.mouse.wheel(0,450);await delay();}await p.mouse.wheel(0,-5000);await delay();return collected;}
 async function shot(name){await p.screenshot({path:resolve(evidence,name+'.png')});}
 async function login(actor){await p.goto('http://localhost:3000/');await p.getByRole('button',{name:'Enable accessibility'}).evaluate(e=>e.click());await delay();await fill('Email',f[actor+'.email']);await fill('Mật khẩu',f[actor+'.password']);const wait=p.waitForResponse(r=>r.url().endsWith('/auth/login'));await click('button','ĐĂNG NHẬP');check((await wait).status()===200,'UI login '+actor);}
 async function membership(){const wait=p.waitForResponse(r=>r.url().endsWith('/memberships/me'));await p.getByRole('tab',{name:/Gói hội viên/}).evaluate(e=>e.click());const r=await wait;check(r.status()===200,'Original Membership navigation -> GET200');await delay();return r.json();}
 await login('memberA');let list=await membership();check(list.length===3&&list.some(m=>m.id===f.membershipA),'UI reads all server UUIDs');
 let uiText=await allText();check(uiText.includes('Danh sách gói hội viên')&&uiText.includes('Đang hoạt động')&&uiText.includes('Đã hủy'),'Original screen list/status');
 check(uiText.includes(f.membershipA)&&uiText.includes('Chưa khả dụng'),'UI UUID and unavailable renewal');await shot('multiple-active-cancelled');
 for(const [stored,start,end,label] of [['PENDING_ACTIVATION',null,null,'Chờ kích hoạt'],['SUSPENDED',-1,1,'Tạm ngưng'],['ACTIVE',1,2,'Chờ kích hoạt'],['ACTIVE',-2,-1,'Đã hết hạn'],['ACTIVE',0,0,'Đang hoạt động']]){
  change(stored,start,end);const wait=p.waitForResponse(r=>r.url().endsWith('/memberships/me'));await click('button','Tải lại gói hội viên');const r=await wait;assert.equal(r.status(),200);list=await r.json();await delay();uiText=await allText();
  check(uiText.includes(label),'UI server status '+stored+'/'+start+'/'+end);if(start===null){check(uiText.includes('Chưa xác định'),'UI null calendar dates');await p.mouse.wheel(0,5000);await delay();await shot('pending-null-dates');await p.mouse.wheel(0,-5000);await delay();}
 }
 const expected=queryRows(`SELECT id,plan_id,start_date,expiry_date,status FROM memberships WHERE id=${a}`)[0];
 const dto=list.find(m=>m.id===expected.id);result.readback={uiResponse:dto,database:expected,calendarDayVietnam:today};dbCheck(dto?.planId===expected.plan_id&&dto?.startDate===expected.start_date&&dto?.endDate===expected.expiry_date&&dto?.status===expected.status,'UI response UUID/dates/status equal PostgreSQL row');
 await p.reload();await delay();await p.getByRole('button',{name:'Enable accessibility'}).evaluate(e=>e.click());await delay();check(await p.getByRole('button',{name:'ĐĂNG NHẬP',exact:true}).count()===1,'Reload drops memory session');
 await login('memberA');list=await membership();check(list.some(m=>m.id===expected.id&&m.startDate===expected.start_date&&m.endDate===expected.expiry_date&&m.status===expected.status),'Reload/login restores same UUID/date/status from server');await shot('relogin-persisted');
 // Logout through original Profile confirmation, then Member B must not see A rows.
 await p.getByRole('tab',{name:/Cá nhân/}).evaluate(e=>e.click());await delay();
 const logout=p.getByRole('button',{name:'Đăng xuất',exact:true});for(let i=0;i<12;i++){const box=await logout.boundingBox();if(box&&box.y>0&&box.y<700)break;await p.mouse.move(500,400);await p.mouse.wheel(0,350);await delay();}
 await logout.evaluate(e=>e.click());await delay();await p.getByRole('button',{name:'Đăng xuất',exact:true}).last().evaluate(e=>e.click());await delay();check(await p.getByRole('button',{name:'ĐĂNG NHẬP',exact:true}).count()===1,'Original logout confirmation clears routes');
 await login('memberB');list=await membership();uiText=await allText();check(list.length===0&&uiText.includes('Bạn chưa có gói hội viên.')&&!uiText.includes(f.membershipA),'UI Member B empty and no A membership after switch');await shot('member-b-empty');
 dbCheck(JSON.stringify(snapshot())===JSON.stringify(reg.nonMembership),'No Member/account/plan/payment/booking/slot/policy mutation');
 const fixtureIds=new Set([f.membershipA,f.membershipB,...reg.extra]);dbCheck(JSON.stringify(rows().filter(m=>!fixtureIds.has(m.id)))===JSON.stringify(reg.memberships.filter(m=>!fixtureIds.has(m.id))),'No membership mutation outside fixture UUIDs');
 result.finishedAt=new Date().toISOString();result.failed=0;result.skipped=0;await persist();
 console.log(JSON.stringify({uiChecks:result.ui.length,httpChecks:result.http.length,dbChecks:result.db.length,failed:0,skipped:0}));
}catch(e){result.failed=1;await persist();let message=String(e.message);for(const [k,v]of Object.entries(f))if((k.endsWith('.email')||k.endsWith('.password'))&&v)message=message.replaceAll(v,'[redacted]');console.error('M04 failed: '+message);process.exitCode=1;}
finally{if(browser)await browser.close();}
