"""All images below are generated checkerboards/no people, not camera/accuracy evidence."""
import json
from uuid import uuid4
import cv2,numpy as np,pytest
from face.evaluation.dataset import initialize,Session

SOURCE={'kind':'WEBCAM','savedOrientation':'RAW_UNMIRRORED','testProvenance':'GENERATED_NON_PERSON_UNIT_ONLY'}
QUALITY={'ready':True,'stable':True,'faceCount':1,'blurVariance':100.,'brightness':100.}

def frame(code,nonce=0):
    value=np.random.default_rng(code*100+nonce).integers(50,190,(100,100,3),dtype=np.uint8)
    value[0,0,:]=code;return value

def session(root,person,role):
    s=Session(root,person['subject'],role,str(uuid4()),str(uuid4()),SOURCE)
    s.confirm('CONSENT '+person['subject'],role=='probe');return s

class Engine:
    model_name='insightface-buffalo_s';provenance='SYNTHETIC_UNIT_ONLY'
    def __init__(self):self.calls=[]
    def embed(self,image):
        code=int(image[0,0,0]);self.calls.append(code);v=np.zeros(512,dtype=np.float32);v[code]=1;return v

@pytest.fixture
def metadata():return {'artifacts':{'synthetic-unit-only':{'sha256':'unit'}},'dependencies':{'unit':'1'}}

@pytest.fixture
def study(tmp_path):
    root=tmp_path/'private-study';d=initialize(root,'generated-unit-only')
    for i,person in enumerate(d['participants'],1):
        roles=['gallery','probe'] if person['known'] else ['probe']
        for j,role in enumerate(roles):session(root,person,role).save(frame(i,j),QUALITY)
    return root,d
