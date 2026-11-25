import { readFile, writeFile } from 'node:fs/promises';
import { resolve, sep, dirname } from 'node:path';
import { tmpdir } from 'node:os';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';

// API-only companion to the UI demo. Tokens never leave memory or appear in output.
const [action, path, expectedId] = process.argv.slice(2);
const manifestPath = resolve(path || '');
const repo = resolve(dirname(fileURLToPath(import.meta.url)), '..');
if (!manifestPath.startsWith(resolve(tmpdir()) + sep) || manifestPath.startsWith(repo + sep)) throw new Error('Use a private Temp manifest outside Git');
const raw = await readFile(manifestPath, 'utf8');
const manifest = Object.fromEntries(raw.split(/\r?\n/).filter(l => l.includes('=') && !l.startsWith('#')).map(l => {
  const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).replace(/\\:/g, ':').replace(/\\=/g, '=')];
}));
const base = 'http://127.0.0.1:18081/api/v1';
let checks = 0, requests = 0;
const check = (condition, label) => { if (!condition) throw new Error('Check failed: ' + label); checks++; };
async function request(method, path, token, body, headers = {}) {
  requests++;
  const response = await fetch(base + path, { method, headers: { ...headers,
    ...(token ? {Authorization: 'Bearer ' + token} : {}), ...(body ? {'Content-Type': 'application/json'} : {}) },
    body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(10000) });
  let data = null;
  if (response.headers.get('content-type')?.includes('application/json')) data = await response.json();
  return {response, data};
}
async function login(actor) {
  const {response, data} = await request('POST', '/auth/login', null,
    {email: manifest[actor + '.email'], password: manifest[actor + '.password']});
  check(response.status === 200 && typeof data.accessToken === 'string', actor + ' login');
  return data.accessToken;
}
const from = new Date(Date.now() - 86400000).toISOString();
const to = new Date(Date.now() + 32 * 86400000).toISOString();
const range = '?' + new URLSearchParams({from, to});
if (action === 'claim') {
  const token = await login('memberB');
  const {response, data} = await request('POST', '/bookings', token,
    {ptId: manifest['ptA.profileId'], slotId: expectedId});
  check(response.status === 201 && data.status === 'CONFIRMED' && data.slotId === expectedId &&
    data.memberId === manifest['memberB.profileId'], 'Member B claim 201/profile/slot');
  await writeFile(resolve(dirname(manifestPath), 'claim-result.json'),
    JSON.stringify({bookingId: data.id, slotId: data.slotId, memberId: data.memberId}, null, 2));
  console.log('HTTP claim: booking=' + data.id + ' slot=' + data.slotId + ' status=CONFIRMED');
} else if (action === 'verify') {
  const tokens = {};
  for (const actor of ['admin', 'memberA', 'memberB', 'ptA', 'ptB']) tokens[actor] = await login(actor);
  for (const origin of ['http://localhost:3000', 'http://localhost:3001']) {
    const {response} = await request('OPTIONS', '/bookings', null, null,
      {Origin: origin, 'Access-Control-Request-Method': 'POST', 'Access-Control-Request-Headers': 'authorization,content-type'});
    check(response.status === 200 && response.headers.get('access-control-allow-origin') === origin, 'CORS exact origin');
  }
  const blocked = await request('OPTIONS', '/bookings', null, null,
    {Origin: 'http://localhost:3999', 'Access-Control-Request-Method': 'POST'});
  check(blocked.response.status === 403, 'CORS unlisted origin refused');
  const anonymous = await request('GET', '/bookings/me' + range);
  check(anonymous.response.status === 401 && anonymous.data.error.code === 'ERR_UNAUTHORIZED', 'anonymous 401 envelope');
  const wrong = await request('POST', '/auth/login', null,
    {email: manifest['memberA.email'], password: randomUUID()});
  check(wrong.response.status === 401 && wrong.data.error.code === 'ERR_UNAUTHORIZED', 'wrong login 401');
  const forbidden = await request('GET', '/pt/slots' + range, tokens.memberA);
  check(forbidden.response.status === 403 && forbidden.data.error.code === 'ERR_FORBIDDEN', 'Member forbidden PT API');
  const trainers = await request('GET', '/trainers', tokens.memberA);
  check(trainers.response.status === 200 && Array.isArray(trainers.data) &&
    trainers.data.some(t => t.id === manifest['ptA.profileId']), 'PT profile catalog');
  const detail = await request('GET', '/trainers/' + manifest['ptA.profileId'], tokens.memberA);
  check(detail.response.status === 200 && detail.data.id === manifest['ptA.profileId'], 'PT profile detail');
  const rows = {};
  for (const actor of ['memberA', 'memberB', 'ptA', 'ptB']) {
    const path = actor.startsWith('pt') ? '/pt/bookings' : '/bookings/me';
    const result = await request('GET', path + range, tokens[actor]);
    check(result.response.status === 200 && Array.isArray(result.data), actor + ' booking array');
    rows[actor] = result.data;
    check(result.data.every(b => b[actor.startsWith('pt') ? 'ptId' : 'memberId'] === manifest[actor + '.profileId']), actor + ' profile ownership');
  }
  const own = rows.memberA.find(b => b.id === expectedId);
  check(own?.status === 'CONFIRMED' && own.ptId === manifest['ptA.profileId'], 'UI booking persisted CONFIRMED');
  check(rows.ptA.some(b => b.id === expectedId && b.startAt === own.startAt && b.endAt === own.endAt), 'same UUID/time Member/PT');
  check(!rows.memberB.some(b => b.id === expectedId) && !rows.ptB.some(b => b.id === expectedId), 'B identities cannot see A booking');
  const slots = await request('GET', '/trainers/' + manifest['ptA.profileId'] + '/slots' + range, tokens.memberA);
  check(slots.response.status === 200 && !slots.data.some(s => s.id === own.slotId), 'booked slot absent from available');
  const ptSlots = await request('GET', '/pt/slots' + range, tokens.ptA);
  check(ptSlots.response.status === 200 && ptSlots.data.some(s => s.id === own.slotId && s.status === 'BOOKED'), 'PT slot BOOKED');
  await writeFile(resolve(dirname(manifestPath), 'http-results.json'), JSON.stringify({
    checks, requests, expectedBooking: expectedId, memberCount: rows.memberA.length,
    otherMemberCount: rows.memberB.length, ptCount: rows.ptA.length, otherPtCount: rows.ptB.length,
    passed: checks, failed: 0, skipped: 0, checkedAt: new Date().toISOString()
  }, null, 2));
  console.log('HTTP verify: passed=' + checks + ' failed=0 skipped=0 requests=' + requests);
} else { throw new Error('Choose verify or claim'); }
