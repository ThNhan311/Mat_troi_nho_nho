import json,hashlib
from pathlib import Path
import cv2,numpy as np,pytest
from face.service_v2.evaluate import manifest,evaluate,separate
from face.service_v2.tests.protocol_host import SyntheticEngine
from face.service_v2.runtime import probe,Runtime

def dataset(tmp_path):
    rows=[]
    for i,(role,subject,value) in enumerate([('gallery','a',1),('gallery','b',2),('probe','a',1),('probe','b',3),('probe','unknown-c',4)]):
        f=tmp_path/f'{i}.png';image=np.full((8+i,8,3),value,dtype=np.uint8);cv2.imwrite(str(f),image)
        rows.append({'id':str(i),'role':role,'subject':subject,'path':f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()})
    p=tmp_path/'manifest.json';p.write_text(json.dumps({'authorizedForEvaluation':True,'datasetVersion':'SYNTHETIC_UNIT_ONLY','samples':rows}),encoding='utf-8');return p

def test_one_to_many_metrics_unknown_rejection_and_pair_scores_separate(tmp_path):
    d,h,_=manifest(dataset(tmp_path));r=evaluate(d,SyntheticEngine(),.5,.05)
    assert r['identification']=={'knownProbes':2,'unknownProbes':1,'correctAccepted':1,'wrongIdentityAccepted':0,'knownRejected':1,'unknownAccepted':0,'ambiguous':0,'FNIR':.5,'FPIR':0.,'rank1IdentificationRate':.5}
    assert r['unknownRejectionRate']==1 and r['productionThresholdApproved'] is False
    assert len(r['genuineScores'])==2 and len(r['impostorScores'])==4
    assert r['scoreThresholdFalseRejectRate']==.5 and r['inferenceLatencyMs']['count']==5 and r['identificationLatencyMs']['count']==3
    assert r['provenance']=='SYNTHETIC_PROTOCOL'

@pytest.mark.parametrize('change',['unauthorized','checksum','duplicate','escape','subject'])
def test_bad_manifest_rejected(tmp_path,change):
    p=dataset(tmp_path);d=json.loads(p.read_text())
    if change=='unauthorized':d['authorizedForEvaluation']=False
    if change=='checksum':d['samples'][0]['sha256']='0'*64
    if change=='duplicate':d['samples'].append(d['samples'][0])
    if change=='escape':d['samples'][0]['path']='../outside.png'
    if change=='subject':d['samples'][0]['subject']=None
    p.write_text(json.dumps(d),encoding='utf-8')
    with pytest.raises((ValueError,FileNotFoundError)):manifest(p)

def test_calibration_evaluation_disjoint_by_subject_and_bytes(tmp_path):
    d,h,_=manifest(dataset(tmp_path));other={'samples':[{'subject':'different'}]}
    with pytest.raises(ValueError):separate(d,h,d,set())
    with pytest.raises(ValueError):separate(d,h,other,h)
    separate(d,h,other,{'other-hash'})

def test_ambiguous_match_counts_as_rejection_not_pair_accuracy(tmp_path):
    d,_,_=manifest(dataset(tmp_path));d['samples'][1]['_path']=d['samples'][0]['_path']
    r=evaluate(d,SyntheticEngine(),.5,.05)
    assert r['identification']['ambiguous']==1 and r['identification']['correctAccepted']==0
    assert r['identification']['FNIR']==1

def test_missing_model_fails_closed_without_downloading(tmp_path):
    before=list(tmp_path.rglob('*'));r=probe(tmp_path);assert not r['ready']
    assert set(r['artifacts'])=={'det_500m.onnx','w600k_mbf.onnx'}
    with pytest.raises(RuntimeError,match='missing'):Runtime(tmp_path)
    assert list(tmp_path.rglob('*'))==before
