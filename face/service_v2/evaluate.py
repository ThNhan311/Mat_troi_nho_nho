"""Private consented-dataset 1:N harness. No built-in images, no automatic production threshold."""
import argparse,hashlib,json,time
from pathlib import Path
import cv2
import numpy as np
from face.prototype.gallery import Gallery
from .runtime import Runtime,probe

def manifest(path):
    path=Path(path).resolve();d=json.loads(path.read_text(encoding='utf-8'))
    if d.get('authorizedForEvaluation') is not True or not d.get('datasetVersion'):raise ValueError('Explicit authorized versioned dataset required')
    if not isinstance(d.get('samples'),list) or not d['samples']:raise ValueError('Nonempty samples required')
    hashes=set();ids=set()
    for s in d['samples']:
        if s['role'] not in ('gallery','probe') or not isinstance(s['subject'],str) or not s['subject']:raise ValueError('Invalid sample metadata')
        f=(path.parent/s['path']).resolve(strict=True)
        if path.parent not in f.parents:raise ValueError('Dataset path escapes manifest root')
        digest=hashlib.sha256(f.read_bytes()).hexdigest()
        if digest!=s['sha256'] or digest in hashes or s['id'] in ids:raise ValueError('Duplicate samples or checksum mismatch')
        hashes.add(digest);ids.add(s['id']);s['_path']=f
    return d,hashes,hashlib.sha256(path.read_bytes()).hexdigest()

def rate(n,d):return None if not d else n/d

def evaluate(d,engine,threshold,margin):
    if not -1<threshold<1 or not 0<=margin<1:raise ValueError('Invalid explicit threshold/margin')
    gallery=Gallery(engine.model_name);group={};latencies=[];failures=[]
    def embed(s):
        image=cv2.imread(str(s['_path']))
        if image is None:raise ValueError('Undecodable dataset image')
        start=time.perf_counter();v=engine.embed(image);latencies.append((time.perf_counter()-start)*1000)
        if v is None:failures.append(s['id'])
        return v
    for s in d['samples']:
        if s['role']=='gallery':
            v=embed(s)
            if v is not None:group.setdefault(s['subject'],[]).append(v)
    if not group:raise ValueError('No usable gallery faces')
    for subject,v in group.items():gallery.add(subject,v)
    genuine=[];impostor=[];trials=[];identification_latencies=[];known=unknown=correct=wrong=rejected=fp=ambiguous=0
    for s in d['samples']:
        if s['role']!='probe':continue
        subject=s['subject'];is_known=subject in {x['subject'] for x in d['samples'] if x['role']=='gallery'}
        if is_known and subject not in group:raise ValueError('Known probe subject has no usable gallery')
        known+=int(is_known);unknown+=int(not is_known)
        started=time.perf_counter();v=embed(s);ranked=[] if v is None else gallery.search(v)
        identification_latencies.append((time.perf_counter()-started)*1000)
        for who,score in ranked:(genuine if who==subject else impostor).append(score)
        best=ranked[0][1] if ranked else None;gap=(best-ranked[1][1] if len(ranked)>1 else 1) if ranked else None
        accepted=bool(ranked and best>=threshold and gap>=margin)
        winner=ranked[0][0] if accepted else None
        correct+=int(is_known and winner==subject);wrong+=int(is_known and winner is not None and winner!=subject);rejected+=int(is_known and not accepted);fp+=int(not is_known and accepted)
        ambiguous+=int(bool(ranked and best>=threshold and gap<margin))
        trials.append({'sampleId':s['id'],'known':is_known,'bestScore':best,'margin':gap,'accepted':accepted,'correctIdentification':winner==subject if is_known else None,'rank1Correct':bool(ranked and ranked[0][0]==subject) if is_known else None})
    return {'model':engine.model_name,'provenance':engine.provenance,'preprocessing':'BGR; largest detected face; InsightFace SCRFD320; five-landmark alignment112; ArcFace512 L2; gallery max cosine per identity',
        'threshold':threshold,'margin':margin,'productionThresholdApproved':False,'gallerySize':len(gallery),'datasetVersion':d['datasetVersion'],
        'scoreUnit':'probe-to-gallery identity maximum cosine; not all image pairs','genuineScores':genuine,'impostorScores':impostor,'scoreThresholdFalseAcceptRate':rate(sum(x>=threshold for x in impostor),len(impostor)),
        'scoreThresholdFalseRejectRate':rate(sum(x<threshold for x in genuine),len(genuine)),
        'identification':{'knownProbes':known,'unknownProbes':unknown,'correctAccepted':correct,'wrongIdentityAccepted':wrong,'knownRejected':rejected,'unknownAccepted':fp,'ambiguous':ambiguous,'FNIR':rate(wrong+rejected,known),'FPIR':rate(fp,unknown),'rank1IdentificationRate':rate(sum(t['rank1Correct'] is True for t in trials),known)},
        'unknownRejectionRate':rate(unknown-fp,unknown),'failureToAcquireSampleIds':failures,
        'identificationLatencyMs':{'count':len(identification_latencies),'median':float(np.median(identification_latencies)) if identification_latencies else None,'p95':float(np.percentile(identification_latencies,95)) if identification_latencies else None},
        'inferenceLatencyMs':{'count':len(latencies),'median':float(np.median(latencies)) if latencies else None,'p95':float(np.percentile(latencies,95)) if latencies else None},'trials':trials,'liveness':'NOT_PERFORMED'}

def separate(evaluation, evaluation_hashes, calibration, calibration_hashes):
    subjects=lambda x:{s['subject'] for s in x['samples']}
    if evaluation_hashes & calibration_hashes or subjects(evaluation)&subjects(calibration):
        raise ValueError('Calibration/evaluation overlap by image hash or subject')

def main():
    a=argparse.ArgumentParser();a.add_argument('--phase',choices=['calibration','evaluation'],required=True);a.add_argument('--manifest',type=Path,required=True);a.add_argument('--calibration-manifest',type=Path);a.add_argument('--model-root',type=Path,required=True);a.add_argument('--threshold',type=float,required=True);a.add_argument('--margin',type=float,required=True);a.add_argument('--output',type=Path,required=True);v=a.parse_args()
    if v.phase=='evaluation':a.error('F03B: evaluation requires sealed sessions and frozen calibration; use python -m face.evaluation.study evaluate (no threshold override)')
    d,hashes,digest=manifest(v.manifest);calibration=None;calibration_version=None
    if v.phase=='evaluation':
        if not v.calibration_manifest:a.error('evaluation requires separate calibration manifest')
        c,ch,calibration=manifest(v.calibration_manifest)
        separate(d,hashes,c,ch);calibration_version=c['datasetVersion']
    result=evaluate(d,Runtime(v.model_root),v.threshold,v.margin);result.update({'phase':v.phase,'manifestSha256':digest,'calibrationManifestSha256':calibration,'calibrationDatasetVersion':calibration_version,'runtime':probe(v.model_root)})
    import os
    if (Path(os.environ['LOCALAPPDATA'])/'Temp').resolve() not in v.output.resolve().parents:raise ValueError('Write evaluation results to private Temp outside Git')
    # Never overwrite a prior evaluation result or write private dataset data into repository by default.
    with v.output.open('x',encoding='utf-8') as out:json.dump(result,out,indent=2)
if __name__=='__main__':main()
