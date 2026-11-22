// Real original Admin Web -> Backend -> separate PostgreSQL, not widget tests.
// node frontend/verify-membership-plan-ui.mjs <private fixture.properties> <playwright index.mjs>
import {readFile,writeFile,mkdir,readdir} from 'node:fs/promises';
import {resolve,dirname,sep} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const manifest=resolve(process.argv[2]||'');assert(manifest.startsWith(resolve(process.env.LOCALAPPDATA,'Temp')+sep));
const f=Object.fromEntries((await readFile(manifest,'utf8')).split(/\r?\n/).filter(s=>s.includes('=')&&!s.startsWith('#')).map(s=>{const i=s.indexOf('=');return [s.slice(0,i),s.slice(i+1).replace(/\\([:=!# ])/g,'$1')];}));
assert.equal(f.seeded,'true');
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'..'),dir=dirname(manifest),resultPath=resolve(dir,'m01-ui-results.json'),evidence=resolve(repo,'docs/backend-handover/evidence/m01-plan-create');await mkdir(evidence,{recursive:true});
async function files(dir){let out=[];for(const e of await readdir(resolve(repo,dir),{withFileTypes:true})){const p=dir+'/'+e.name;if(e.isDirectory())out.push(...await files(p));else if(p.endsWith('.dart'))out.push(p);}return out;}
const paths=['frontend/verify-membership-plan-ui.mjs','frontend/verify-membership-plan-demo.mjs','frontend/serve-booking-web.mjs','backend/scripts/booking-demo.ps1','frontend/fitcenter_ad/pubspec.yaml','frontend/fitcenter_ad/pubspec.lock',...await files('frontend/fitcenter_ad/lib'),...await files('frontend/fitcenter_ad/test')];
const result={at:new Date().toISOString(),intent:'one UI create; do not replay if outcome unclear',created:[],uiChecks:0,httpChecks:0,http:[],sourceHashes:{}};
for(const p of paths.sort())result.sourceHashes[p]=createHash('sha256').update(await readFile(resolve(repo,p))).digest('hex');
await writeFile(resultPath,JSON.stringify(result,null,2),{flag:'wx'});const persist=()=>writeFile(resultPath,JSON.stringify(result,null,2));
const {chromium}=await import(pathToFileURL(resolve(process.argv[3])).href),browser=await chromium.launch({headless:true,executablePath:process.env.CHROME_EXECUTABLE||'C:/Program Files/Google/Chrome/Application/chrome.exe'});
const context=await browser.newContext({viewport:{width:1024,height:768},timezoneId:'America/Los_Angeles'}),p=await context.newPage();
const delay=()=>new Promise(r=>setTimeout(r,250));const check=(ok,label)=>{assert(ok,label);result.uiChecks++;};
p.on('response',r=>{const u=new URL(r.url());if(u.port==='18081'&&!u.pathname.includes('/auth/'))result.http.push({method:r.request().method(),path:u.pathname,status:r.status()});});
async function click(role,name){const el=p.getByRole(role,{name,exact:true});await el.waitFor({state:'attached'});await el.evaluate(e=>e.click());await delay();}
async function scroll(el){for(let i=0;i<20;i++){if(await el.count()){const b=await el.first().boundingBox();if(b&&b.y>50&&b.y<710)return;}await p.mouse.move(500,400);await p.mouse.wheel(0,300);await delay();}throw Error('Cannot reach UI control');}
async function fill(name,value){const el=p.getByRole('textbox',{name,exact:true});await el.click({force:true});await delay();await p.keyboard.press('Control+A');await p.keyboard.insertText(value);await delay();assert.equal(await el.inputValue(),value,'Focused form field '+name);}
async function text(){return p.locator('flt-semantics-host').evaluate(e=>e.innerText+'\n'+[...e.querySelectorAll('*')].map(x=>[x.getAttribute('aria-label'),x.getAttribute('aria-valuetext'),x.value].filter(Boolean).join(' ')).join('\n'));}
async function shot(name){await p.screenshot({path:resolve(evidence,name+'.png')});}
async function login(){await p.goto('http://localhost:3002/');await p.getByRole('button',{name:'Enable accessibility'}).evaluate(e=>e.click());await delay();await fill('Email',f['admin.email']);await fill('Mật khẩu',f['admin.password']);const wait=p.waitForResponse(r=>r.url().endsWith('/auth/login'));await click('button','ĐĂNG NHẬP');check((await wait).status()===200,'Real Admin login');}
async function plans(){const menu=p.getByRole('button',{name:/Gói tập Xem gói/});await scroll(menu);const wait=p.waitForResponse(r=>r.url().endsWith('/membership-plans')&&r.request().method()==='GET');await menu.evaluate(e=>e.click());const r=await wait;check(r.status()===200,'Existing GET list');await delay();return r.json();}
try{
 await login();await plans();check((await text()).includes('Các gói hội viên'),'Original MembershipPage');await shot('active-list-before-create');
 await click('button','Thêm gói');await fill('Tên gói tập','Synthetic M01 UI plan');await fill('Giá (VNĐ)','123456.78');await fill('Thời hạn (ngày)','37');await fill('Mô tả (tùy chọn)','Synthetic M01 original Admin screen');
 assert.deepEqual(await p.getByRole('textbox').evaluateAll(els=>els.map(e=>e.value)),['Synthetic M01 UI plan','123456.78','37','Synthetic M01 original Admin screen']);await shot('create-form');
 const wait=p.waitForResponse(r=>r.url().endsWith('/admin/membership-plans')&&r.request().method()==='POST');result.writeAt=new Date().toISOString();await persist();await click('button','Lưu');const response=await wait,plan=await response.json();
 if(response.status()===201&&typeof plan.id==='string'){result.created.push(plan);await persist();}
 check(response.status()===201,'Only 201 success');assert.match(plan.id,/^[0-9a-f-]{36}$/i);check(plan.name==='Synthetic M01 UI plan'&&plan.durationDays===37&&plan.price===123456.78,'Exact request values and real UUID');
 await p.getByRole('button',{name:'L\u01b0u',exact:true}).waitFor({state:'detached'});check(true,'Create dialog closed after 201');await shot('created-plan');
 const logout=p.getByRole('button',{name:'Đăng xuất',exact:true});await logout.evaluate(e=>e.click());await delay();check(await p.getByRole('button',{name:'ĐĂNG NHẬP',exact:true}).count()===1,'Logout discards navigation');
 await login();let list=await plans();check(list.some(x=>x.id===plan.id&&x.price===123456.78&&x.durationDays===37),'Re-login server readback');
 await p.reload();await delay();await p.getByRole('button',{name:'Enable accessibility'}).evaluate(e=>e.click());check(await p.getByRole('button',{name:'ĐĂNG NHẬP',exact:true}).count()===1,'Reload requires login');
 await login();list=await plans();check(list.some(x=>x.id===plan.id&&x.price===123456.78&&x.durationDays===37),'Reload and login server persistence');
 await p.mouse.move(500,400);await p.mouse.wheel(0,500);await delay();await shot('persisted-plan');
 check(result.http.filter(x=>x.method==='POST'&&x.path.endsWith('/admin/membership-plans')).length===1,'Exactly one UI create POST');
 const base='http://127.0.0.1:18081/api/v1';const logged=await fetch(base+'/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:f['memberA.email'],password:f['memberA.password']})});assert.equal(logged.status,200);result.httpChecks++;
 const token=(await logged.json()).accessToken;
 const detail=await fetch(base+'/membership-plans/'+plan.id,{headers:{Authorization:'Bearer '+token}});assert.equal(detail.status,200);assert.deepEqual(await detail.json(),plan);result.httpChecks++;
 const memberList=await fetch(base+'/membership-plans',{headers:{Authorization:'Bearer '+token}});assert.equal(memberList.status,200);assert((await memberList.json()).some(x=>x.id===plan.id&&x.price===123456.78&&x.durationDays===37));result.httpChecks++;
 await click('button','Đăng xuất');check(await p.getByRole('button',{name:'ĐĂNG NHẬP',exact:true}).count()===1,'Final logout');
 result.finishedAt=new Date().toISOString();result.failed=0;result.skipped=0;await persist();console.log(JSON.stringify({uiChecks:result.uiChecks,httpChecks:result.httpChecks,failed:0,skipped:0,createdIds:result.created.map(x=>x.id)}));
}catch(e){result.failed=1;await persist();let message=String(e.message);for(const[k,v]of Object.entries(f))if((k.endsWith('.email')||k.endsWith('.password'))&&v)message=message.replaceAll(v,'[redacted]');console.error('M01 UI failed: '+message);process.exitCode=1;}finally{await browser.close();}