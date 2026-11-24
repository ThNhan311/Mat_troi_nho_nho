"""Private consented capture dataset. No personal identity, embeddings or automatic capture."""
import hashlib,json,os,re,subprocess
from contextlib import contextmanager
from datetime import datetime,timezone
from pathlib import Path
from uuid import UUID,uuid4
import cv2
import numpy as np

SCHEMA='F03B-1'
SUBJECT=re.compile(r'^p-[a-f0-9]{12}$')

def utc():return datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
def digest(raw):return hashlib.sha256(raw).hexdigest()
def load(path):return json.loads(Path(path).read_text(encoding='utf-8'))
def encoded(value):return (json.dumps(value,ensure_ascii=False,sort_keys=True,indent=2,allow_nan=False)+'\n').encode('utf-8')
def create_json(path,value):
    path=Path(path);created=False
    try:
        with path.open('xb') as f:created=True;f.write(encoded(value));f.flush();os.fsync(f.fileno())
    except BaseException:
        if created:path.unlink(missing_ok=True)
        raise
def atomic_json(path,value):
    path=Path(path);temporary=path.with_name('.'+str(uuid4())+'.tmp')
    created=False
    try:
        with temporary.open('xb') as f:created=True;f.write(encoded(value));f.flush();os.fsync(f.fileno())
        os.replace(temporary,path)
    finally:
        if created:temporary.unlink(missing_ok=True)

def outside_git(path):
    path=Path(path).resolve()
    repo=Path(__file__).resolve().parents[2]
    roots=[]
    result=subprocess.run(['git','-C',str(repo),'worktree','list','--porcelain'],capture_output=True,text=True,check=True)
    for line in result.stdout.splitlines():
        if line.startswith('worktree '):roots.append(Path(line[9:]).resolve())
    if any(path==r or r in path.parents for r in roots):raise ValueError('Dataset/output must be outside every repository worktree')
    if any((parent/'.git').exists() for parent in [path,*path.parents]):raise ValueError('Dataset/output cannot be inside another Git repository')
    return path

@contextmanager
def locked(root):
    lock=Path(root)/'.capture.lock'
    try:fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
    except FileExistsError:raise ValueError('Dataset busy or incomplete prior operation; inspect lock, never reset automatically') from None
    try:yield
    finally:os.close(fd);lock.unlink()

def pixel_digest(frame):
    if not isinstance(frame,np.ndarray) or frame.dtype!=np.uint8 or frame.ndim!=3 or frame.shape[2]!=3:raise ValueError('BGR uint8 frame required')
    return digest(str(tuple(frame.shape)).encode()+frame.tobytes())

def plan(root):
    root=outside_git(root);d=load(root/'plan.json')
    if d.get('schema')!=SCHEMA or d.get('liveness')!='NOT_PERFORMED' or d.get('admissionEnabled')is not False:raise ValueError('Unsupported study plan or admission claims')
    UUID(d['studyId'])
    subjects=d['participants']
    if not subjects or len({x['subject'] for x in subjects})!=len(subjects):raise ValueError('Invalid participants')
    for x in subjects:
        if not SUBJECT.fullmatch(x['subject']) or x['split'] not in ('calibration','evaluation') or type(x['known'])is not bool:raise ValueError('Invalid pseudonymous study assignment')
    return root,d

def initialize(root,version,calibration_known=2,calibration_unknown=1,evaluation_known=2,evaluation_unknown=1):
    root=outside_git(root)
    if not re.fullmatch(r'[a-zA-Z0-9_.-]{1,64}',version):raise ValueError('Opaque dataset version required')
    counts=[calibration_known,calibration_unknown,evaluation_known,evaluation_unknown]
    if any(type(n)is not int or n<1 for n in counts) or min(calibration_known,evaluation_known)<2:raise ValueError('Each split needs >=2 known and >=1 unknown for this 1:N protocol; this is not statistical sufficiency')
    if root.exists() and any(root.iterdir()):raise ValueError('Choose a new empty private study directory; do not overwrite')
    root.mkdir(parents=True,exist_ok=True)
    participants=[]
    for split,known,count in [('calibration',True,calibration_known),('calibration',False,calibration_unknown),('evaluation',True,evaluation_known),('evaluation',False,evaluation_unknown)]:
        for _ in range(count):participants.append({'subject':'p-'+uuid4().hex[:12],'split':split,'known':known})
    d={'schema':SCHEMA,'studyId':str(uuid4()),'datasetVersion':version,'createdAt':utc(),'participants':participants,'purpose':'LOCAL_FACE_EVALUATION_ONLY','liveness':'NOT_PERFORMED','admissionEnabled':False}
    create_json(root/'plan.json',d);(root/'sessions').mkdir();return d

def participant(root,subject,role):
    root,d=plan(root);rows=[x for x in d['participants'] if x['subject']==subject]
    if len(rows)!=1 or role not in ('gallery','probe'):raise ValueError('Subject/role not assigned in immutable study plan')
    person=rows[0]
    if not person['known'] and role!='probe':raise ValueError('Unknown identities are probe-only, never added to gallery')
    return root,d,person

class Session:
    def __init__(self,root,subject,role,operator_ref,consent_ref,source):
        self.root,self.study,self.person=participant(root,subject,role)
        UUID(operator_ref);UUID(consent_ref)
        self.subject,self.role=subject,role
        self.operator,self.consent_ref=operator_ref,consent_ref
        self.source=source;self.document=None;self.folder=None
        if source.get('kind')!='WEBCAM' or source.get('savedOrientation')!='RAW_UNMIRRORED':raise ValueError('Explicit webcam/raw orientation provenance required')
    def confirm(self,phrase,independent=False):
        if phrase!='CONSENT '+self.subject:raise ValueError('Operator must explicitly confirm participant consent')
        if self.role=='probe' and self.person['known'] and not independent:raise ValueError('Known probe must be a separate visit/session, not a gallery-frame split')
        if self.document is not None:raise ValueError('Consent already recorded for this session')
        with locked(self.root):
            if (self.root/'dataset-lock.json').exists():raise ValueError('Study sealed; no capture or split edits allowed')
            for existing in (self.root/'sessions').glob('*/session.json'):
                previous=load(existing)
                if previous['consent']['recordRef']==self.consent_ref and previous['subject']!=self.subject:raise ValueError('Consent record is bound to another anonymous participant')
            session=str(uuid4());folder=self.root/'sessions'/session;folder.mkdir();(folder/'images').mkdir()
            self.document={'schema':SCHEMA,'studyId':self.study['studyId'],'planSha256':digest((self.root/'plan.json').read_bytes()),'sessionId':session,'subject':self.subject,'split':self.person['split'],'known':self.person['known'],'role':self.role,'startedAt':utc(),'source':self.source,'consent':{'accepted':True,'scope':'LOCAL_IMAGE_CAPTURE_AND_OFFLINE_FACE_EVALUATION','operatorRef':self.operator,'recordRef':self.consent_ref,'confirmedAt':utc()},'independentOfGalleryDeclared':bool(independent),'samples':[],'liveness':'NOT_PERFORMED','admissionEnabled':False}
            self.folder=folder;create_json(folder/'session.json',self.document)
        return session
    def save(self,frame,quality):
        if self.document is None:raise ValueError('Consent required before saving')
        if quality.get('ready')is not True:raise ValueError('Current frame quality/stability not ready')
        if self.folder.resolve().parent!=self.root/'sessions' or (self.folder/'images').resolve()!=(self.folder.resolve()/'images'):raise ValueError('Session directory redirected; refuse capture')
        raw_ok,raw=cv2.imencode('.png',frame)
        if not raw_ok:raise ValueError('Image encoding failed')
        image_bytes=raw.tobytes();sha,pixel=digest(image_bytes),pixel_digest(frame)
        with locked(self.root):
            if (self.root/'dataset-lock.json').exists():raise ValueError('Study sealed; no capture allowed')
            current=load(self.folder/'session.json')
            if current!=self.document:raise ValueError('Session changed externally; reopen/reconcile, never overwrite')
            for f in (self.root/'sessions').glob('*/session.json'):
                for sample in load(f)['samples']:
                    if sample['sha256']==sha or sample['pixelSha256']==pixel:raise ValueError('Duplicate image/pixels already captured; do not reuse gallery/probe images')
            name=str(uuid4())+'.png';target=self.folder/'images'/name
            sample={'id':str(uuid4()),'path':target.relative_to(self.root).as_posix(),'sha256':sha,'pixelSha256':pixel,'capturedAt':utc(),'width':int(frame.shape[1]),'height':int(frame.shape[0]),'quality':quality}
            updated={**current,'samples':[*current['samples'],sample]}
            created=False
            try:
                with target.open('xb') as f:created=True;f.write(image_bytes);f.flush();os.fsync(f.fileno())
                atomic_json(self.folder/'session.json',updated)
            except BaseException:
                if created:target.unlink(missing_ok=True)
                raise
            self.document=updated
        return sample

def inventory(root):
    root,d=plan(root);plan_sha=digest((root/'plan.json').read_bytes());rows=[];sessions={};hashes=set();pixels=set();sample_ids=set();people={x['subject']:x for x in d['participants']}
    for f in sorted((root/'sessions').glob('*/session.json')):
        s=load(f);UUID(s['sessionId'])
        if f.parent.name!=s['sessionId'] or s['studyId']!=d['studyId'] or s['planSha256']!=plan_sha:raise ValueError('Session/study/plan binding changed')
        person=people.get(s['subject'])
        if not person or type(s['known'])is not bool or s['split']!=person['split'] or s['known']!=person['known']:raise ValueError('Study assignment changed; never re-split to improve score')
        if s['role'] not in ('gallery','probe') or (not person['known'] and s['role']!='probe'):raise ValueError('Invalid gallery/probe identity assignment')
        if s.get('liveness')!='NOT_PERFORMED' or s.get('admissionEnabled')is not False:raise ValueError('Invalid session liveness/admission claims')
        consent=s.get('consent',{})
        if consent.get('accepted')is not True or consent.get('scope')!='LOCAL_IMAGE_CAPTURE_AND_OFFLINE_FACE_EVALUATION':raise ValueError('Missing evaluation consent')
        UUID(consent['operatorRef']);UUID(consent['recordRef'])
        if s['role']=='probe' and person['known'] and s.get('independentOfGalleryDeclared')is not True:raise ValueError('Probe independent session declaration missing')
        if s['source'].get('kind')!='WEBCAM' or s['source'].get('savedOrientation')!='RAW_UNMIRRORED':raise ValueError('Missing camera provenance')
        sessions[f.relative_to(root).as_posix()]=digest(f.read_bytes());referenced=set()
        for sample in s['samples']:
            image=(root/sample['path']).resolve(strict=True)
            if f.parent.resolve() not in image.parents or image.parent!=f.parent.resolve()/'images':raise ValueError('Sample escapes its session directory')
            raw=image.read_bytes();frame=cv2.imdecode(np.frombuffer(raw,np.uint8),cv2.IMREAD_COLOR)
            if frame is None or digest(raw)!=sample['sha256'] or pixel_digest(frame)!=sample['pixelSha256']:raise ValueError('Image checksum/pixels changed')
            if sample['sha256']in hashes or sample['pixelSha256']in pixels or sample['id']in sample_ids:raise ValueError('Duplicate image/pixels/sample ID')
            hashes.add(sample['sha256']);pixels.add(sample['pixelSha256']);sample_ids.add(sample['id']);referenced.add(image)
            rows.append({**sample,'subject':s['subject'],'role':s['role'],'split':s['split'],'sessionId':s['sessionId'],'sourceSession':f.relative_to(root).as_posix()})
        if {x.resolve() for x in (f.parent/'images').iterdir()}!=referenced:raise ValueError('Orphan image exists; inspect incomplete capture, never silently include/delete')
    for person in people.values():
        selected=[s for s in rows if s['subject']==person['subject']]
        expected={'gallery','probe'} if person['known'] else {'probe'}
        if {s['role'] for s in selected}!=expected:raise ValueError('Insufficient data: every planned known needs gallery/probe, every unknown needs probe')
        gallery_sessions={s['sessionId'] for s in selected if s['role']=='gallery'};probe_sessions={s['sessionId'] for s in selected if s['role']=='probe'}
        if gallery_sessions & probe_sessions:raise ValueError('Gallery and probe must come from separate sessions')
    return root,d,rows,sessions

def seal(root):
    root=outside_git(root)
    with locked(root):
        root,d,rows,sessions=inventory(root)
        names=['calibration-manifest.json','evaluation-manifest.json','dataset-lock.json']
        if any((root/n).exists() for n in names):raise ValueError('Sealed artifacts exist; no overwrite or split repair')
        created=[]
        try:
            manifests={}
            for split in ['calibration','evaluation']:
                document={'schema':SCHEMA,'studyId':d['studyId'],'datasetVersion':d['datasetVersion']+'-'+split,'authorizedForEvaluation':True,'samples':[{k:v for k,v in s.items() if k!='split'} for s in rows if s['split']==split],'liveness':'NOT_PERFORMED','admissionEnabled':False}
                f=root/(split+'-manifest.json');create_json(f,document);created.append(f);manifests[f.name]=digest(f.read_bytes())
            lock={'schema':SCHEMA,'studyId':d['studyId'],'sealedAt':utc(),'planSha256':digest((root/'plan.json').read_bytes()),'manifests':manifests,'sessions':sessions,'productionSufficiencyEstablished':False}
            create_json(root/'dataset-lock.json',lock);created.append(root/'dataset-lock.json')
        except BaseException:
            for f in created:f.unlink()
            raise
    return lock

def validate_seal(root):
    root,d,rows,sessions=inventory(root);lock=load(root/'dataset-lock.json')
    if lock.get('schema')!=SCHEMA or lock['studyId']!=d['studyId'] or lock['planSha256']!=digest((root/'plan.json').read_bytes()) or lock['sessions']!=sessions:raise ValueError('Frozen study/session inventory changed')
    if set(lock['manifests'])!={'calibration-manifest.json','evaluation-manifest.json'}:raise ValueError('Invalid sealed manifest set')
    for name,sha in lock['manifests'].items():
        if digest((root/name).read_bytes())!=sha:raise ValueError('Sealed manifest changed; do not resplit after calibration')
    # Reconcile exact sample content with the sealed manifests, not only their stored hashes.
    for split in ['calibration','evaluation']:
        expected=[{k:v for k,v in s.items() if k!='split'} for s in rows if s['split']==split]
        if load(root/(split+'-manifest.json'))['samples']!=expected:raise ValueError('Manifest does not describe captured source inventory')
    return root,d,lock
