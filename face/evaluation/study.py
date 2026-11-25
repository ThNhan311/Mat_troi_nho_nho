"""Session-separated dataset sealing and calibration-selected immutable evaluation settings."""
import argparse,hashlib,json,math
from pathlib import Path
from uuid import uuid4
from face.service_v2.evaluate import manifest,evaluate,separate
from .dataset import plan,initialize,validate_seal,seal,load,create_json,digest,utc,locked,outside_git


def fingerprint(engine,metadata):
    repo=Path(__file__).resolve().parents[2]
    source={f:digest((repo/f).read_bytes().replace(b'\r\n',b'\n')) for f in ['face/prototype/embedder.py','face/prototype/gallery.py','face/prototype/matcher.py','face/service_v2/runtime.py','face/service_v2/evaluate.py','face/evaluation/study.py','face/evaluation/dataset.py']}
    return {'model':engine.model_name,'provenance':engine.provenance,'artifacts':metadata['artifacts'],'dependencies':metadata['dependencies'],'preprocessingVersion':'F03A-buffalo_s-largest-BGR320-align112-512-L2-v1','sourceSha256':source}

def split_data(root):
    root,d,lock=validate_seal(root)
    c,ch,cs=manifest(root/'calibration-manifest.json');e,eh,es=manifest(root/'evaluation-manifest.json')
    separate(e,eh,c,ch)
    return root,d,lock,c,e,cs,es

def calibrate(root,engine,metadata,threshold,margin):
    if isinstance(threshold,bool) or isinstance(margin,bool) or not math.isfinite(threshold) or not math.isfinite(margin):raise ValueError('Finite explicit calibration candidate required')
    root,d,lock,c,_,cs,_=split_data(root)
    with locked(root):
        if (root/'threshold-lock.json').exists() or (root/'evaluation-result.json').exists():raise ValueError('Settings frozen; no new calibration candidate after freeze/evaluation')
        fp=fingerprint(engine,metadata);data_sha=digest((root/'dataset-lock.json').read_bytes())
        result=evaluate(c,engine,threshold,margin)
        split_data(root)
        if fingerprint(engine,metadata)!=fp or digest((root/'dataset-lock.json').read_bytes())!=data_sha:raise ValueError('Source/dataset changed during calibration')
        result.update({'schema':'F03B-1','phase':'calibration','studyId':d['studyId'],'manifestSha256':cs,'datasetLockSha256':digest((root/'dataset-lock.json').read_bytes()),'modelFingerprint':fingerprint(engine,metadata),'createdAt':utc(),'admissionEnabled':False})
        name='calibration-'+str(uuid4())+'.json';create_json(root/name,result)
    return name,result

def calibration_report(root,report):
    root,d,lock,c,_,cs,_=split_data(root);path=(root/report).resolve(strict=True)
    if path.parent!=root or not path.name.startswith('calibration-') or path.suffix!='.json':raise ValueError('Select a calibration report from this study')
    r=load(path)
    if r.get('schema')!='F03B-1' or r.get('phase')!='calibration' or r.get('studyId')!=d['studyId'] or r.get('datasetLockSha256')!=digest((root/'dataset-lock.json').read_bytes()) or r.get('manifestSha256')!=cs or r.get('productionThresholdApproved')is not False or r.get('admissionEnabled')is not False:raise ValueError('Calibration report does not match frozen study')
    if any(isinstance(r[k],bool) or not isinstance(r[k],(int,float)) or not math.isfinite(r[k]) for k in ['threshold','margin']) or not -1<r['threshold']<1 or not 0<=r['margin']<1:raise ValueError('Invalid candidate values')
    return root,d,path,r

def freeze(root,report):
    root,d,path,r=calibration_report(root,report)
    artifact={'schema':'F03B-1','studyId':d['studyId'],'calibrationReport':path.name,'calibrationReportSha256':digest(path.read_bytes()),'datasetLockSha256':r['datasetLockSha256'],'calibrationManifestSha256':r['manifestSha256'],'threshold':r['threshold'],'margin':r['margin'],'modelFingerprint':r['modelFingerprint'],'frozenAt':utc(),'productionThresholdApproved':False,'liveness':'NOT_PERFORMED','admissionEnabled':False}
    with locked(root):
        if (root/'evaluation-result.json').exists():raise ValueError('Evaluation already exists; no new threshold freeze')
        create_json(root/'threshold-lock.json',artifact)
    return artifact

def run_evaluation(root,engine,metadata):
    root,d,lock,c,e,cs,es=split_data(root);frozen=load(root/'threshold-lock.json')
    root,_,path,cal=calibration_report(root,frozen['calibrationReport'])
    if frozen.get('schema')!='F03B-1' or frozen.get('studyId')!=d['studyId'] or frozen.get('calibrationReportSha256')!=digest(path.read_bytes()) or frozen.get('datasetLockSha256')!=digest((root/'dataset-lock.json').read_bytes()) or frozen.get('calibrationManifestSha256')!=cs:raise ValueError('Frozen calibration source changed')
    if any(frozen.get(k)!=cal.get(k) for k in ['threshold','margin','modelFingerprint']) or frozen['modelFingerprint']!=fingerprint(engine,metadata):raise ValueError('Threshold/margin/model/preprocessing changed after calibration')
    if frozen.get('productionThresholdApproved')is not False or frozen.get('admissionEnabled')is not False or frozen.get('liveness')!='NOT_PERFORMED':raise ValueError('Invalid admission/liveness claims')
    with locked(root):
        if (root/'evaluation-result.json').exists():raise ValueError('Evaluation already recorded; no overwrite, re-split or threshold tuning on evaluation')
        result=evaluate(e,engine,frozen['threshold'],frozen['margin'])
        split_data(root)
        if load(root/'threshold-lock.json')!=frozen or fingerprint(engine,metadata)!=frozen['modelFingerprint']:raise ValueError('Source/settings changed during evaluation')
        result.update({'schema':'F03B-1','phase':'evaluation','studyId':d['studyId'],'manifestSha256':es,'calibrationManifestSha256':cs,'calibrationDatasetVersion':c['datasetVersion'],'thresholdLockSha256':digest((root/'threshold-lock.json').read_bytes()),'datasetLockSha256':frozen['datasetLockSha256'],'modelFingerprint':fingerprint(engine,metadata),'createdAt':utc(),'admissionEnabled':False})
        create_json(root/'evaluation-result.json',result)
    return result

def main():
    a=argparse.ArgumentParser(description='Private study -> manual separate-session captures -> seal -> calibrate -> freeze -> evaluate. No admission.')
    sub=a.add_subparsers(dest='command',required=True)
    for name in ['init','inspect','seal','calibrate','freeze','evaluate']:
        s=sub.add_parser(name);s.add_argument('--study',type=Path,required=True)
        if name=='init':
            s.add_argument('--dataset-version',required=True)
            for flag,default in [('calibration-known',2),('calibration-unknown',1),('evaluation-known',2),('evaluation-unknown',1)]:s.add_argument('--'+flag,type=int,default=default)
        if name in ['calibrate','evaluate']:s.add_argument('--model-root',type=Path,required=True)
        if name=='calibrate':s.add_argument('--threshold',type=float,required=True);s.add_argument('--margin',type=float,required=True)
        if name=='freeze':s.add_argument('--calibration-report',required=True)
    v=a.parse_args()
    if v.command=='init':print(json.dumps(initialize(v.study,v.dataset_version,v.calibration_known,v.calibration_unknown,v.evaluation_known,v.evaluation_unknown),indent=2))
    elif v.command=='inspect':print(json.dumps(plan(v.study)[1],indent=2))
    elif v.command=='seal':print(json.dumps(seal(v.study),indent=2))
    elif v.command=='freeze':freeze(v.study,v.calibration_report);print('Calibration candidate frozen; not a production threshold approval')
    else:
        from .capture import verified_runtime
        engine,metadata=verified_runtime(v.model_root)
        if v.command=='calibrate':name,_=calibrate(v.study,engine,metadata,v.threshold,v.margin);print('Calibration report written: '+name)
        else:run_evaluation(v.study,engine,metadata);print('Evaluation written once with frozen calibration settings; liveness NOT_PERFORMED')
if __name__=='__main__':main()
