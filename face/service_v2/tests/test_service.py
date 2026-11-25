import base64,hashlib,hmac,json,socket,threading,time
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4
import cv2,numpy as np,pytest,httpx,uvicorn
from cryptography.fernet import Fernet
from face.service_v2.api import create_app
from face.service_v2.store import Store,Fault
from face.service_v2.tests.protocol_host import SyntheticEngine

@pytest.fixture
def service(tmp_path):
    store=Store(tmp_path/'gallery.sqlite',Fernet.generate_key().decode(),'insightface-buffalo_s',.5)
    control,capture,key=[uuid4().hex+uuid4().hex for _ in range(3)];clock=[2000000000]
    app=create_app(store,SyntheticEngine(),control,capture,key,.5,.05,lambda:clock[0])
    sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
    server=uvicorn.Server(uvicorn.Config(app,log_level='error',access_log=False));thread=threading.Thread(target=lambda:server.run(sockets=[sock]),daemon=True);thread.start()
    until=time.monotonic()+5
    while not server.started and time.monotonic()<until:time.sleep(.01)
    assert server.started
    with httpx.Client(base_url=f'http://127.0.0.1:{port}',headers={'X-Face-Token':control},timeout=6) as client:
        yield client,store,control,capture,key,clock
    server.should_exit=True;thread.join(5);sock.close();assert not thread.is_alive()

def binding(member=None,predecessor=None):
    profile=str(uuid4());return {'operation':str(uuid4()),'member':member or str(uuid4()),'profile':profile,'reference':'f02:'+profile,'predecessor':predecessor}
def image(n):return base64.b64encode(cv2.imencode('.png',np.full((8,8,3),n,dtype=np.uint8))[1]).decode()
def stage(c,b,n=1):
    r=c.post('/v2/operations',json=b);assert r.status_code==200;r=c.post('/v2/operations/'+b['operation']+'/samples',json={'frames':[image(n)]*5});assert r.status_code==200;return r.json()
def finalize(c,b,s):return c.post('/v2/operations/'+b['operation']+'/finalize',json={k:s[k] for k in ['member','profile','reference','generation']})
def scan(s,n=1,request=None,capture=None):
    c,_,_,token,_,_=s
    return c.post('/v2/captures',headers={'X-Face-Token':token},json={'request':request or str(uuid4()),'capture':capture or str(uuid4()),'frames':[image(n)]})
def proof(r):return json.loads(base64.urlsafe_b64decode(r.json()['payload']+'==='))

def test_no_auth_wrong_auth_and_separate_capture_authority(service):
    c,_,control,capture,_,_=service
    for token in ['',uuid4().hex]:
        response=c.get('/v2/health',headers={'X-Face-Token':token});assert response.status_code==401 and response.headers['cache-control']=='no-store'
    assert c.post('/v2/operations',headers={'X-Face-Token':capture},json=binding()).status_code==401
    assert c.post('/v2/captures',headers={'X-Face-Token':control},json={}).status_code==401
    assert c.get('/v2/health').headers['cache-control']=='no-store'

def test_staging_not_published_until_finalize_and_attestation_binding(service):
    c,store,_,_,key,clock=service;b=binding();s=stage(c,b)
    assert proof(scan(service))['outcome']=='REJECTED'
    assert finalize(c,b,s).json()['status']=='ACTIVE'
    r=scan(service);d=proof(r);assert d['profile']==b['profile'] and d['generation']==1
    assert d['liveness']=='NOT_PERFORMED' and d['admissionEnabled'] is False and d['provenance']=='SYNTHETIC_PROTOCOL'
    assert d['expiresAt']==clock[0]+10
    assert hmac.compare_digest(r.json()['signature'],hmac.new(key.encode(),r.json()['payload'].encode(),hashlib.sha256).hexdigest())
    assert c.get('/v2/captures/'+d['request']+'/'+d['capture']).json()==r.json()
    assert c.get('/v2/captures/'+str(uuid4())+'/'+d['capture']).status_code==404

@pytest.mark.parametrize('field,value',[('member',None),('profile',None),('generation',2),('reference','f02:bad'),('generation',1.5)])
def test_finalize_wrong_binding_or_generation(service,field,value):
    c=service[0];b=binding();s=stage(c,b);d={k:s[k] for k in ['member','profile','reference','generation']};d[field]=value or str(uuid4())
    assert c.post('/v2/operations/'+b['operation']+'/finalize',json=d).status_code in (400,409)
    assert c.get('/v2/operations/'+b['operation']).json()['status']=='STAGED'

def test_prepare_retry_payload_conflict_sample_retry_and_finalize_retry(service):
    c=service[0];b=binding();s=stage(c,b);assert c.post('/v2/operations',json=b).json()['generation']==1
    changed={**b,'member':str(uuid4())};assert c.post('/v2/operations',json=changed).status_code==409
    assert c.post('/v2/operations/'+b['operation']+'/samples',json={'frames':[image(2)]*5}).status_code==409
    assert finalize(c,b,s).json()==finalize(c,b,s).json()

def test_predecessor_same_member_allowed_other_identity_duplicate_rejected(service):
    c=service[0];b=binding();s=stage(c,b);finalize(c,b,s)
    new=binding(b['member'],b['reference']);ss=stage(c,new);assert ss['generation']==2
    assert finalize(c,new,ss).status_code==200
    assert c.get('/v2/operations/'+b['operation']).json()['status']=='REPLACED'
    other=binding();c.post('/v2/operations',json=other)
    assert c.post('/v2/operations/'+other['operation']+'/samples',json={'frames':[image(1)]*5}).json()['error']['code']=='DUPLICATE_IDENTITY'
    assert proof(scan(service))['profile']==new['profile']

def test_wrong_predecessor_and_member_binding_rejected(service):
    c=service[0];b=binding();s=stage(c,b);finalize(c,b,s)
    assert c.post('/v2/operations',json=binding(b['member'])).status_code==409
    assert c.post('/v2/operations',json=binding(predecessor=b['reference'])).status_code==409

def test_abort_revoke_tombstone_blocks_late_prepare_and_finalize(service):
    c=service[0];b=binding();s=stage(c,b)
    for _ in range(2):assert c.post('/v2/references/abort',json={'reference':b['reference']}).status_code==200
    assert finalize(c,b,s).json()['error']['code']=='TOMBSTONED'
    later=binding();c.post('/v2/references/abort',json={'reference':later['reference']});assert c.post('/v2/operations',json=later).status_code==409
    assert proof(scan(service))['outcome']=='REJECTED'

def test_revoke_one_member_preserves_other_and_cached_result_stays_bound(service):
    c=service[0];a=binding();sa=stage(c,a,1);finalize(c,a,sa);b=binding();sb=stage(c,b,2);finalize(c,b,sb)
    req,cap=str(uuid4()),str(uuid4());old=scan(service,1,req,cap).json();c.post('/v2/references/abort',json={'reference':a['reference']})
    assert proof(scan(service,1))['outcome']=='REJECTED';assert proof(scan(service,2))['profile']==b['profile']
    assert scan(service,1,req,cap).json()==old
    assert scan(service,1,str(uuid4()),cap).status_code==409
    assert scan(service,2,req,cap).status_code==409

def test_durable_restart_and_no_plaintext_vectors(service,tmp_path):
    c,store,_,_,_,_=service;b=binding();s=stage(c,b);finalize(c,b,s)
    copy=Store(store.path,base64.urlsafe_b64encode(store.cipher._signing_key+store.cipher._encryption_key).decode(),store.model,.5)
    assert copy.status(b['operation'])['status']=='ACTIVE'
    with copy.transaction() as db:
        row=db.execute('SELECT vectors FROM operations').fetchone();assert b'[1.0' not in row['vectors'];assert row['vectors'].startswith(b'gAAAA')
    with pytest.raises(Fault,match='MODEL_MISMATCH'):Store(store.path,Fernet.generate_key().decode(),'other',.5)
    with pytest.raises(Fault,match='GALLERY_KEY_MISMATCH'):Store(store.path,Fernet.generate_key().decode(),store.model,.5)

def test_finalize_abort_race_never_resurrects(service):
    c,store,*_=service;b=binding();s=stage(c,b);barrier=threading.Barrier(2)
    def final():
        barrier.wait()
        try:store.finalize(b['operation'],s);return 'ACTIVE'
        except Fault as e:return e.code
    def abort():barrier.wait();return store.abort(b['reference'])
    with ThreadPoolExecutor(2) as pool:a=pool.submit(final);z=pool.submit(abort);a.result();z.result()
    assert store.status(b['operation'])['status']=='ABORTED'
    assert proof(scan(service))['outcome']=='REJECTED'

def test_duplicate_reservations_compete_before_backend_commit(service):
    c,store,*_=service;a,b=binding(),binding();c.post('/v2/operations',json=a);c.post('/v2/operations',json=b);barrier=threading.Barrier(2)
    vector=np.zeros(512,dtype=np.float32);vector[1]=1
    def reserve(x):
        barrier.wait()
        try:return store.stage(x['operation'],[vector]*3,'same-synthetic')['status']
        except Fault as e:return e.code
    with ThreadPoolExecutor(2) as pool:f=pool.submit(reserve,a);g=pool.submit(reserve,b);results=[f.result(),g.result()]
    assert sorted(results)==['DUPLICATE_IDENTITY','STAGED']
    winner=a if results[0]=='STAGED' else b
    assert finalize(c,winner,store.status(winner['operation'])).status_code==200


def test_failed_reenrollment_keeps_predecessor_and_rollback(service):
    c,store,*_=service;b=binding();s=stage(c,b,1);finalize(c,b,s);next_=binding(b['member'],b['reference']);stage(c,next_,1)
    # Transaction failure rolls back status and encrypted payload, no file compensation claim.
    with pytest.raises(RuntimeError):
        with store.transaction() as db:
            db.execute("UPDATE operations SET status='ABORTED' WHERE operation=?",(b['operation'],));raise RuntimeError('synthetic rollback')
    assert store.status(b['operation'])['status']=='ACTIVE'
    c.post('/v2/references/abort',json={'reference':next_['reference']});assert proof(scan(service))['profile']==b['profile']

@pytest.mark.parametrize('body',[{'member':'self-claim'}, {'frames':[]}, {'frames':['not-base64']}])
def test_strict_capture_and_image_input(service,body):
    c,_,_,token,_,_=service
    assert c.post('/v2/captures',headers={'X-Face-Token':token},json={'request':str(uuid4()),'capture':str(uuid4()),**body}).status_code==400

def test_pending_finalize_rejected_and_insufficient_samples(service):
    c=service[0];b=binding();s=c.post('/v2/operations',json=b).json()
    assert finalize(c,b,s).json()['error']['code']=='SAMPLE_NOT_READY'
    assert c.post('/v2/operations/'+b['operation']+'/samples',json={'frames':[image(1)]}).status_code==400


def test_heavy_capture_one_inflight_returns_busy_without_second_inference(service,monkeypatch):
    entered,release=threading.Event(),threading.Event();calls=[];original=SyntheticEngine.embed
    def blocked(self,image):
        calls.append(1);entered.set();assert release.wait(4);return original(self,image)
    monkeypatch.setattr(SyntheticEngine,'embed',blocked)
    with ThreadPoolExecutor(1) as pool:
        first=pool.submit(scan,service);assert entered.wait(3)
        try:assert scan(service).status_code==503;assert len(calls)==1
        finally:release.set()
        assert first.result().status_code==200

def test_abort_during_inference_prevents_late_stage_publication(service,monkeypatch):
    c=service[0];b=binding();c.post('/v2/operations',json=b)
    entered,release=threading.Event(),threading.Event();original=SyntheticEngine.embed
    def blocked(self,image):
        entered.set();assert release.wait(4);return original(self,image)
    monkeypatch.setattr(SyntheticEngine,'embed',blocked)
    with ThreadPoolExecutor(1) as pool:
        first=pool.submit(lambda:c.post('/v2/operations/'+b['operation']+'/samples',json={'frames':[image(1)]*5}));assert entered.wait(3)
        try:assert c.post('/v2/references/abort',json={'reference':b['reference']}).status_code==200
        finally:release.set()
        assert first.result().json()['error']['code']=='TOMBSTONED'
    assert c.get('/v2/operations/'+b['operation']).json()['status']=='ABORTED'
