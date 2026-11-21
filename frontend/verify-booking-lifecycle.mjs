import { readFile, writeFile } from 'node:fs/promises';
import { resolve, sep, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';
const manifestPath=resolve(process.argv[2]||'');
const repo=resolve(dirname(fileURLToPath(import.meta.url)),'..');
if(!manifestPath.startsWith(resolve(tmpdir())+sep)||manifestPath.startsWith(repo+sep))throw new Error('Private Temp manifest required');
const raw=await readFile(manifestPath,'utf8');
const manifest=Object.fromEntries(raw.split(/\r?\n/).filter(l=>l.includes('=')&&!l.startsWith('#')).map(l=>{const i=l.indexOf('=');return [l.slice(0,i),l.slice(i+1).replace(/\\:/g,':').replace(/\\=/g,'=')];}));
const base='http://127.0.0.1:18081/api/v1';let checks=0,requests=0;
function check(ok,label){if(!ok)throw new Error('Check failed: '+label);checks++;}
async function req(method,path,token,body){requests++;const response=await fetch(base+path,{method,headers:{...(token?{Authorization:'Bearer '+token}:{}),...(body?{'Content-Type':'application/json'}:{})},body:body?JSON.stringify(body):undefined,signal:AbortSignal.timeout(10000),cache:'no-store'});const data=response.status===204?null:await response.json();return {response,data};}
async function login(actor){const r=await req('POST','/auth/login',null,{email:manifest[actor+'.email'],password:manifest[actor+'.password']});check(r.response.status===200,actor+' login');return r.data.accessToken;}
const tokens={};for(const actor of ['memberA','memberB','ptA','ptB'])tokens[actor]=await login(actor);
const range='?'+new URLSearchParams({from:new Date(Date.now()-86400000).toISOString(),to:new Date(Date.now()+3*86400000).toISOString()});
const rows={};for(const actor of Object.keys(tokens)){const r=await req('GET',(actor.startsWith('pt')?'/pt/bookings':'/bookings/me')+range,tokens[actor]);check(r.response.status===200&&Array.isArray(r.data),actor+' calendar');rows[actor]=r.data;check(r.data.every(b=>b[actor.startsWith('pt')?'ptId':'memberId']===manifest[actor+'.profileId']),actor+' owner');}
function booking(name){return rows.memberA.find(b=>b.id===manifest['lifecycle.'+name+'.booking']);}
check(booking('memberCancel')?.status==='CANCELLED'&&booking('memberCancel').cancelledBy==='MEMBER','Member cancellation metadata');
const rebook=rows.memberB.find(b=>b.slotId===manifest['lifecycle.memberCancel.slot']);check(rebook?.status==='CONFIRMED'&&rebook.id!==booking('memberCancel').id,'different Member rebook same slot new booking ID');
check(booking('ptCancel')?.status==='CANCELLED'&&booking('ptCancel').cancelledBy==='PT'&&booking('ptCancel').cancelReason==='Demo PT unavailable','PT reason saved');
check(booking('ended')?.status==='COMPLETED'&&booking('ended').completedAt,'completion metadata');
check(booking('replacement')?.status==='CANCELLED'&&booking('replacement').slotId===manifest['lifecycle.replacement.slot'],'history FK retained');
const slots=await req('GET','/pt/slots'+range,tokens.ptA);check(slots.response.status===200,'own slots');
const slot=name=>slots.data.find(s=>s.id===manifest['lifecycle.'+name+'.slot']);
for(const name of ['ptCancel','replacement','delete','ended'])check(slot(name)?.status==='DISABLED',name+' slot DISABLED retained');
check(slot('memberCancel')?.status==='BOOKED','rebook BOOKED');
const available=await req('GET','/trainers/'+manifest['ptA.profileId']+'/slots'+range,tokens.memberB);
for(const name of ['ptCancel','replacement','delete','ended','memberCancel'])check(!available.data.some(s=>s.id===manifest['lifecycle.'+name+'.slot']),name+' absent available');
const replacement=available.data.find(s=>!Object.keys(manifest).some(k=>k.startsWith('lifecycle.')&&k.endsWith('.slot')&&manifest[k]===s.id));
check(replacement?.status==='AVAILABLE','replacement has a new UUID and is available');
const original=booking('replacement');check(replacement.startAt!==original.startAt,'replacement time changed, history time kept');
const old=booking('memberCancel');const repeated=await req('POST','/bookings/'+old.id+'/cancel',tokens.memberA);check(repeated.response.status===409&&repeated.data.error.code==='ERR_BOOKING_NOT_CONFIRMED','old cancellation cannot touch rebooking');
const after=await req('GET','/bookings/me'+range,tokens.memberB);check(after.data.some(b=>b.id===rebook.id&&b.status==='CONFIRMED'),'rebooking intact');
const blocked=await req('POST','/bookings',tokens.memberB,{ptId:manifest['ptA.profileId'],slotId:manifest['lifecycle.ptCancel.slot']});check(blocked.response.status===409&&blocked.data.error.code==='ERR_SLOT_NO_LONGER_AVAILABLE','DISABLED cannot rebook');
for(const [method,path,token,status] of [
 ['GET','/pt/bookings/'+manifest['lifecycle.current.booking']+'/service-eligibility',tokens.ptB,404],
 ['POST','/pt/bookings/'+manifest['lifecycle.ptCancel.booking']+'/cancel',tokens.ptB,404],
 ['DELETE','/pt/availability/'+replacement.id,tokens.memberA,403],
 ['GET','/pt/bookings/'+manifest['lifecycle.current.booking']+'/service-eligibility',null,401],
 ['POST','/bookings/'+rebook.id+'/cancel',tokens.memberA,404],
]){const r=await req(method,path,token,method==='POST'&&path.includes('/pt/')?{reason:'Forbidden test'}:undefined);check(r.response.status===status&&r.data.error.code,'role/owner/anonymous controlled '+status);}
const eligibility=await req('GET','/pt/bookings/'+manifest['lifecycle.current.booking']+'/service-eligibility',tokens.ptA);check(eligibility.response.status===200&&eligibility.response.headers.get('cache-control')==='no-store'&&eligibility.data.eligible&&eligibility.data.reasonCodes.length===0,'current eligibility true/no-store');
const future=await req('GET','/pt/bookings/'+rebook.id+'/service-eligibility',tokens.ptA);check(future.response.status===200&&!future.data.eligible&&future.data.reasonCodes.includes('SESSION_NOT_STARTED'),'future eligibility false HTTP200');
check(rows.ptA.some(b=>b.id===rebook.id)&&!rows.ptB.some(b=>b.id===rebook.id),'PT owner sees rebooking, other PT does not');
await writeFile(resolve(dirname(manifestPath),'lifecycle-http-results.json'),JSON.stringify({passed:checks,failed:0,skipped:0,requests,checkedAt:new Date().toISOString(),rebookId:rebook.id,replacementSlotId:replacement.id},null,2));
console.log('Lifecycle HTTP: '+checks+' checks passed, 0 failed, 0 skipped; '+requests+' requests; rebook='+rebook.id+' replacement='+replacement.id);
