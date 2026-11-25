"""Authenticated loopback service; trusted capture uploads only. No public match claim input."""
import base64,hashlib,hmac,json,time
from threading import Lock
from uuid import UUID
import cv2
import numpy as np
from fastapi import FastAPI,Request
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool
from face.prototype.matcher import Matcher
from .store import Fault

def uuid(value):
    if not isinstance(value,str) or str(UUID(value))!=value: raise Fault('INVALID_UUID',400)
    return value

def create_app(store, engine, control_token, capture_token, signing_key, threshold, margin, clock=time.time):
    if min(len(control_token),len(capture_token),len(signing_key))<32 or control_token==capture_token: raise ValueError('Distinct private credentials required')
    app=FastAPI(docs_url=None,redoc_url=None,openapi_url=None)
    busy=Lock()
    def signed(body):
        payload=base64.urlsafe_b64encode(json.dumps(body,sort_keys=True,separators=(',',':')).encode()).decode().rstrip('=')
        return {'payload':payload,'signature':hmac.new(signing_key.encode(),payload.encode(),hashlib.sha256).hexdigest()}
    @app.exception_handler(Fault)
    async def fault(_,e): return JSONResponse({'error':{'code':e.code}},status_code=e.status,headers={'Cache-Control':'no-store'})
    @app.middleware('http')
    async def guard(req,call_next):
        # IPv4 loopback runner only, no wildcard listener or proxy-trusted remote headers.
        expected=capture_token if req.url.path.startswith('/v2/captures') and req.method=='POST' else control_token
        if not hmac.compare_digest(req.headers.get('X-Face-Token','').encode(),expected.encode()): return JSONResponse({'error':{'code':'UNAUTHORIZED'}},401,headers={'Cache-Control':'no-store'})
        try:length=int(req.headers.get('content-length','0'))
        except ValueError:return JSONResponse({'error':{'code':'INVALID_REQUEST'}},400,headers={'Cache-Control':'no-store'})
        if length>12*1024*1024:return JSONResponse({'error':{'code':'TOO_LARGE'}},413,headers={'Cache-Control':'no-store'})
        try: response=await call_next(req)
        except (ValueError,KeyError,TypeError): response=JSONResponse({'error':{'code':'INVALID_REQUEST'}},400)
        response.headers['Cache-Control']='no-store';return response
    async def data(req,keys):
        def pairs(items):
            d={}
            for k,v in items:
                if k in d: raise Fault('INVALID_REQUEST',400)
                d[k]=v
            return d
        raw=await req.body()
        if len(raw)>12*1024*1024: raise Fault('TOO_LARGE',413)
        try: d=json.loads(raw,object_pairs_hook=pairs)
        except (ValueError,UnicodeError): raise Fault('INVALID_REQUEST',400) from None
        if not isinstance(d,dict) or set(d)!=set(keys): raise Fault('INVALID_REQUEST',400)
        return d
    def vectors(images,minimum=1,maximum=5):
        if not isinstance(images,list) or not minimum<=len(images)<=maximum: raise Fault('INVALID_FRAMES',400)
        result=[]; raw_digest=hashlib.sha256()
        for encoded in images:
            raw=base64.b64decode(encoded,validate=True)
            if len(raw)>2*1024*1024: raise Fault('TOO_LARGE',413)
            raw_digest.update(len(raw).to_bytes(8,'big'));raw_digest.update(raw)
            image=cv2.imdecode(np.frombuffer(raw,np.uint8),cv2.IMREAD_COLOR)
            if image is None or max(image.shape[:2])>4096: raise Fault('INVALID_IMAGE',400)
            value=engine.embed(image)
            if value is not None: result.append(value)
        return result,raw_digest.hexdigest()
    def exclusive(work):
        if not busy.acquire(False): raise Fault('BUSY',503)
        try:return work()
        finally:busy.release()
    @app.get('/v2/health')
    def health():return {'model':engine.model_name,'provenance':engine.provenance,'liveness':'NOT_PERFORMED','admissionEnabled':False}
    @app.post('/v2/operations')
    async def prepare(req:Request):
        d=await data(req,['operation','member','profile','reference','predecessor'])
        for k in ['operation','member','profile']: uuid(d[k])
        if d['reference']!='f02:'+d['profile'] or (d['predecessor'] is not None and (not isinstance(d['predecessor'],str) or not d['predecessor'].startswith('f02:'))): raise Fault('INVALID_BINDING',400)
        if d['predecessor'] is not None:uuid(d['predecessor'][4:])
        return {**store.prepare(**d),'provenance':engine.provenance}
    @app.get('/v2/operations/{operation}')
    def status(operation:str):return {**store.status(uuid(operation)),'provenance':engine.provenance}
    @app.post('/v2/operations/{operation}/samples')
    async def samples(operation:str,req:Request):
        d=await data(req,['frames']); uuid(operation)
        def run():
            v,digest=vectors(d['frames'],5,15);return {**store.stage(operation,v,digest),'provenance':engine.provenance}
        return await run_in_threadpool(exclusive,run)
    @app.post('/v2/operations/{operation}/finalize')
    async def finalize(operation:str,req:Request):
        d=await data(req,['member','profile','reference','generation'])
        if type(d['generation']) is not int or d['generation']<1: raise Fault('INVALID_BINDING',400)
        return {**store.finalize(uuid(operation),d),'provenance':engine.provenance}
    @app.post('/v2/references/abort')
    async def abort(req:Request):
        d=await data(req,['reference'])
        if not isinstance(d['reference'],str) or not d['reference'].startswith('f02:'): raise Fault('INVALID_BINDING',400)
        uuid(d['reference'][4:]);return store.abort(d['reference'])
    @app.post('/v2/captures')
    async def capture(req:Request):
        d=await data(req,['request','capture','frames']);uuid(d['request']);uuid(d['capture'])
        def run():
            v,digest=vectors(d['frames'])
            def decide(gallery,vector):
                if vector is None:return 'NO_FACE',None,None,None
                match=Matcher(gallery,threshold,margin).match(vector)
                return ('MATCHED' if match.member_id else 'REJECTED'),match.member_id,match.score,match.margin
            result=store.recognize(np.mean(v,axis=0) if v else None,d['request'],d['capture'],digest,decide)
            if 'payload' in result:return result
            at=int(clock())
            result.update({'request':d['request'],'capture':d['capture'],'issuedAt':at,'expiresAt':at+10,'model':engine.model_name,'provenance':engine.provenance,'liveness':'NOT_PERFORMED','admissionEnabled':False})
            return store.save_capture(d['request'],d['capture'],digest,signed(result))
        return await run_in_threadpool(exclusive,run)
    @app.get('/v2/captures/{request}/{capture}')
    def attestation(request:str,capture:str):return store.capture(uuid(request),uuid(capture))
    return app
