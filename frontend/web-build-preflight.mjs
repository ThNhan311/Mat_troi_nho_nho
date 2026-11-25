import {readFile,stat} from 'node:fs/promises';import {resolve} from 'node:path';
export const requiredLocalWebArtifacts=['index.html','flutter_bootstrap.js','main.dart.js','canvaskit/canvaskit.js','canvaskit/canvaskit.wasm','canvaskit/chromium/canvaskit.js','canvaskit/chromium/canvaskit.wasm'];
export async function verifyLocalWebBuild(root){
 for(const name of requiredLocalWebArtifacts){
  let info;try{info=await stat(resolve(root,name));}catch{throw new Error('Missing Web runtime asset '+name+'; restore/precache the pinned Flutter Web SDK and rebuild with --no-web-resources-cdn. Do not copy an old app build.');}
  if(!info.isFile()||info.size===0)throw new Error('Empty/invalid Web runtime asset '+name+'; restore the pinned SDK and rebuild.');
 }
 const bootstrap=await readFile(resolve(root,'flutter_bootstrap.js'),'utf8');
 if(!/"useLocalCanvasKit"\s*:\s*true/.test(bootstrap))throw new Error('Guarded demo requires local CanvasKit: rebuild with --no-web-resources-cdn');
 return requiredLocalWebArtifacts;
}
