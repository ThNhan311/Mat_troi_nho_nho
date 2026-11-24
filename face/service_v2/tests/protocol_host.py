"""Synthetic engine is test source only; production runtime never imports this host."""
import argparse,json,os,time
from pathlib import Path
import numpy as np
from face.service_v2.api import create_app
from face.service_v2.store import Store

class SyntheticEngine:
    model_name='insightface-buffalo_s'
    provenance='SYNTHETIC_PROTOCOL'
    def embed(self,image):
        v=np.zeros(512,dtype=np.float32);v[int(image[0,0,0])]=1;return v

def host(config):
    config=Path(config).resolve(strict=True)
    if (Path(os.environ['LOCALAPPDATA'])/'Temp').resolve() not in config.parents:raise ValueError('Private test config required')
    d=json.loads(config.read_text(encoding='utf-8'))
    if d.get('guard')!='F03A_SYNTHETIC_PROTOCOL_ONLY':raise ValueError('Explicit synthetic test guard required')
    store=Store(config.with_suffix('.sqlite'),d['galleryKey'],SyntheticEngine.model_name,.5)
    app=create_app(store,SyntheticEngine(),d['controlToken'],d['captureToken'],d['signingKey'],.5,.05)
    @app.middleware('http')
    async def faults(req,next_call):
        path=config.with_suffix('.fault.json');fault=json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}
        if fault.get('path')==req.url.path:
            if fault.get('pauseBefore'):
                config.with_suffix('.entered').write_text('entered',encoding='utf-8')
                until=time.monotonic()+8
                import asyncio
                while not config.with_suffix('.release').exists() and time.monotonic()<until:await asyncio.sleep(.02)
            if fault.get('delayBefore'):await __import__('asyncio').sleep(fault['delayBefore'])
        if fault.get('path')==req.url.path and fault.get('statusBefore'):
            from fastapi.responses import JSONResponse
            return JSONResponse({'error':{'code':'SYNTHETIC_FAULT'}},status_code=fault['statusBefore'])
        response=await next_call(req)
        if fault.get('path')==req.url.path:
            if fault.get('delayAfter'):await __import__('asyncio').sleep(fault['delayAfter'])
            if fault.get('replace'):
                raw=b''.join([chunk async for chunk in response.body_iterator]);value=json.loads(raw);value.update(fault['replace'])
                from fastapi.responses import JSONResponse
                return JSONResponse(value,status_code=response.status_code)
        return response
    return app

def main():
    a=argparse.ArgumentParser();a.add_argument('--config',required=True);v=a.parse_args();config=Path(v.config);d=json.loads(config.read_text(encoding='utf-8'))
    import uvicorn
    uvicorn.run(host(config),host='127.0.0.1',port=d['port'],access_log=False,log_level='error')
if __name__=='__main__':main()
