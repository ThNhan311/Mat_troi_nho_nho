"""Actual model weights on generated non-person inputs. This is NOT identity accuracy or PAD."""
import argparse,base64,json,os,socket,threading,time
from pathlib import Path
from uuid import uuid4
import cv2,httpx,numpy as np,uvicorn
from cryptography.fernet import Fernet
from .runtime import Runtime,probe
from .store import Store
from .api import create_app

def main():
    a=argparse.ArgumentParser();a.add_argument('--model-root',type=Path,required=True);a.add_argument('--output',type=Path,required=True);v=a.parse_args()
    output=v.output.resolve();private=(Path(os.environ['LOCALAPPDATA'])/'Temp').resolve()
    if private not in output.parents:raise ValueError('Private output required')
    start=time.perf_counter();engine=Runtime(v.model_root);load=(time.perf_counter()-start)*1000
    samples=[]
    for i in range(3):
        frame=np.full((480,640,3),i*40,dtype=np.uint8);start=time.perf_counter();vector=engine.embed(frame)
        samples.append({'input':'generated uniform non-person BGR480x640','outcome':'NO_FACE' if vector is None else 'EMBEDDING','latencyMs':(time.perf_counter()-start)*1000})
    recognition=engine.delegate._app.models['recognition'];start=time.perf_counter();tensor=recognition.get_feat(np.zeros((112,112,3),dtype=np.uint8))
    embedding={'input':'generated non-person aligned112 tensor','shape':list(tensor.shape),'finite':bool(np.isfinite(tensor).all()),'nonzeroNorm':bool(np.linalg.norm(tensor)>0),'latencyMs':(time.perf_counter()-start)*1000}
    controls=[uuid4().hex+uuid4().hex for _ in range(3)]
    # All persisted state is synthetic and created with a unique namespace; no existing gallery is opened.
    store_path=output.parent/('model-smoke-'+str(uuid4())+'.sqlite');store=Store(store_path,Fernet.generate_key().decode(),engine.model_name,.5)
    app=create_app(store,engine,*controls,.5,.05)
    sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    server=uvicorn.Server(uvicorn.Config(app,log_level='error',access_log=False));thread=threading.Thread(target=lambda:server.run(sockets=[sock]),daemon=True);thread.start()
    try:
        until=time.monotonic()+8
        while not server.started and time.monotonic()<until:time.sleep(.01)
        if not server.started:raise RuntimeError('Model HTTP did not start')
        with httpx.Client(base_url=f'http://127.0.0.1:{port}',timeout=10) as client:
            health=client.get('/v2/health',headers={'X-Face-Token':controls[0]});assert health.status_code==200
            encoded=base64.b64encode(cv2.imencode('.png',np.zeros((480,640,3),dtype=np.uint8))[1]).decode()
            response=client.post('/v2/captures',headers={'X-Face-Token':controls[1]},json={'request':str(uuid4()),'capture':str(uuid4()),'frames':[encoded]});assert response.status_code==200
            proof=json.loads(base64.urlsafe_b64decode(response.json()['payload']+'==='));assert proof['outcome']=='NO_FACE' and proof['liveness']=='NOT_PERFORMED' and proof['admissionEnabled'] is False
        result={'runtime':probe(v.model_root),'loadMs':load,'components':{k:type(x).__name__ for k,x in engine.delegate._app.models.items()},'providers':{k:x.session.get_providers() for k,x in engine.delegate._app.models.items()},'detectorRuns':samples,'recognitionTensor':embedding,'HTTP':{'health':health.status_code,'capture':response.status_code,'outcome':proof['outcome'],'provenance':proof['provenance']},'accuracyEvaluated':False,'cameraTested':False,'liveness':'NOT_PERFORMED'}
        with output.open('x',encoding='utf-8') as out:json.dump(result,out,indent=2)
        print('Actual detector/recognition tensor and model HTTP smoke passed; accuracy/PAD/camera NOT tested')
    finally:
        server.should_exit=True;thread.join(5);sock.close()
        if thread.is_alive():raise RuntimeError('Model HTTP did not stop')
        # Exact file minted by this invocation, private synthetic state only.
        store_path.unlink()
if __name__=='__main__':main()
