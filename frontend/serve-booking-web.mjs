import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { dirname, resolve, sep, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

// Loopback-only static server for the three built demo apps; never serves the fixture folder.
const role = process.argv[2];
if (!['member', 'pt', 'ad'].includes(role)) throw new Error('Choose member, pt or ad');
const port = role === 'member' ? 3000 : role === 'pt' ? 3001 : 3002;
const root = resolve(dirname(fileURLToPath(import.meta.url)), 'fitcenter_' + role, 'build/web');
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript', '.json': 'application/json',
  '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.css': 'text/css', '.ttf': 'font/ttf' };
http.createServer(async (request, response) => {
  try {
    if (!['GET', 'HEAD'].includes(request.method)) { response.writeHead(405).end(); return; }
    const path = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let file = resolve(root, '.' + path);
    if (file !== root && !file.startsWith(root + sep)) { response.writeHead(403).end(); return; }
    if ((await stat(file)).isDirectory()) file = resolve(file, 'index.html');
    const body = await readFile(file);
    response.writeHead(200, { 'Content-Type': mime[extname(file)] || 'application/octet-stream',
      'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
    response.end(request.method === 'HEAD' ? undefined : body);
  } catch { response.writeHead(404).end('Not found'); }
}).listen(port, '127.0.0.1', () => console.log('Booking ' + role + ' web: http://localhost:' + port));
