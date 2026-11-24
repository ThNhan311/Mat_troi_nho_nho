import json,sys
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch
import pytest
from face.evaluation.dataset import initialize,plan,seal,validate_seal,load,atomic_json,digest,Session
from face.evaluation.study import calibrate,freeze,run_evaluation,main
from face.service_v2.evaluate import main as legacy_cli
from .conftest import Engine,frame,session,QUALITY,SOURCE


def test_seal_preserves_separate_subjects_sessions_known_and_unknown(study):
    root,d=study;lock=seal(root);validate_seal(root)
    cal=load(root/'calibration-manifest.json');ev=load(root/'evaluation-manifest.json')
    assert {s['subject'] for s in cal['samples']}.isdisjoint({s['subject'] for s in ev['samples']})
    assert {s['sha256'] for s in cal['samples']}.isdisjoint({s['sha256'] for s in ev['samples']})
    for person in d['participants']:
        rows=[s for s in cal['samples']+ev['samples'] if s['subject']==person['subject']]
        if person['known']:
            assert {s['role'] for s in rows}=={'gallery','probe'}
            assert len({s['sessionId'] for s in rows})==2
        else:assert {s['role'] for s in rows}=={'probe'}
    with pytest.raises(ValueError):seal(root)


def test_calibrate_reads_only_calibration_then_freeze_and_eval_fixed(study,metadata):
    root,d=study;seal(root);engine=Engine()
    name,report=calibrate(root,engine,metadata,.5,.05)
    assert set(engine.calls)=={1,2,3};assert report['phase']=='calibration'
    frozen=freeze(root,name);assert frozen['threshold']==report['threshold']
    engine.calls.clear();result=run_evaluation(root,engine,metadata)
    assert set(engine.calls)=={4,5,6};assert result['phase']=='evaluation'
    assert result['identification']['knownProbes']==2 and result['identification']['unknownProbes']==1
    assert result['threshold']==.5 and result['margin']==.05
    assert result['productionThresholdApproved'] is False and result['liveness']=='NOT_PERFORMED'
    before=(root/'evaluation-result.json').read_bytes()
    with pytest.raises(ValueError):run_evaluation(root,engine,metadata)
    with pytest.raises(ValueError):freeze(root,name)
    with pytest.raises(ValueError):calibrate(root,engine,metadata,.6,.1)
    assert (root/'evaluation-result.json').read_bytes()==before


@pytest.mark.parametrize('change',['threshold','margin','calibrationReportSha256','modelFingerprint','admissionEnabled','liveness'])
def test_frozen_settings_cannot_be_changed_for_eval(study,metadata,change):
    root,_=study;seal(root);name,_=calibrate(root,Engine(),metadata,.5,.05);freeze(root,name)
    p=root/'threshold-lock.json';f=load(p)
    f[change]={'threshold':.7,'margin':.3,'calibrationReportSha256':'bad','modelFingerprint':{},'admissionEnabled':True,'liveness':'PASSED'}[change];atomic_json(p,f)
    with pytest.raises(ValueError):run_evaluation(root,Engine(),metadata)
    assert not (root/'evaluation-result.json').exists()


def test_changed_calibration_report_or_model_is_rejected(study,metadata):
    root,_=study;seal(root);name,_=calibrate(root,Engine(),metadata,.5,.05);freeze(root,name)
    other=deepcopy(metadata);other['artifacts']['synthetic-unit-only']['sha256']='different'
    with pytest.raises(ValueError,match='model'):run_evaluation(root,Engine(),other)
    p=root/name;report=load(p);report['threshold']=.6;atomic_json(p,report)
    with pytest.raises(ValueError,match='source changed'):run_evaluation(root,Engine(),metadata)


@pytest.mark.parametrize('target',['image','session','manifest','plan'])
def test_sealed_dataset_changes_detected_not_repaired(study,target):
    root,_=study;seal(root)
    if target=='image':next(root.rglob('*.png')).write_bytes(b'changed')
    if target=='session':
        p=next((root/'sessions').glob('*/session.json'));v=load(p);v['consent']['accepted']=False;atomic_json(p,v)
    if target=='manifest':
        p=root/'evaluation-manifest.json';v=load(p);v['samples']=[];atomic_json(p,v)
    if target=='plan':
        p=root/'plan.json';v=load(p);v['participants'][0]['split']='evaluation';atomic_json(p,v)
    with pytest.raises(ValueError):validate_seal(root)


def test_missing_data_and_consent_not_faked_as_sufficient(tmp_path):
    root=tmp_path/'study';initialize(root,'unit')
    with pytest.raises(ValueError,match='Insufficient'):seal(root)
    assert not (root/'dataset-lock.json').exists()
    with pytest.raises(ValueError):initialize(root,'new-version')
    with pytest.raises(ValueError):initialize(tmp_path/'other','unit',calibration_known=1)


def test_duplicate_pixels_or_orphans_not_silently_included(study):
    root,_=study;p=next((root/'sessions').glob('*/session.json'));v=load(p);folder=p.parent/'images';(folder/'orphan.png').write_bytes(b'not referenced')
    with pytest.raises(ValueError,match='Orphan'):seal(root)


def test_sealed_study_rejects_further_manual_capture(study):
    root,d=study;seal(root)
    with pytest.raises(ValueError,match='sealed'):session(root,d['participants'][0],'gallery')


def test_data_modified_during_inference_cannot_produce_report(study,metadata):
    root,_=study;seal(root);image=next(root.rglob('*.png'));engine=Engine();original=engine.embed
    def mutate(frame):
        image.write_bytes(b'synthetic corruption during inference');return original(frame)
    engine.embed=mutate
    with pytest.raises(ValueError):calibrate(root,engine,metadata,.5,.05)
    assert not list(root.glob('calibration-????????-*.json'))


def test_freeze_rejects_other_study_report(study,metadata,tmp_path):
    root,_=study;seal(root);name,r=calibrate(root,Engine(),metadata,.5,.05);r['studyId']='different';atomic_json(root/name,r)
    with pytest.raises(ValueError):freeze(root,name)


def test_no_eval_threshold_override_in_either_cli():
    with patch.object(sys,'argv',['study','evaluate','--study','unused','--model-root','unused','--threshold','.9']):
        with pytest.raises(SystemExit):main()
    with patch.object(sys,'argv',['evaluate','--phase','evaluation','--manifest','unused','--model-root','unused','--threshold','.9','--margin','.1','--output','unused']):
        with pytest.raises(SystemExit):legacy_cli()


def test_nonfinite_calibration_candidate_rejected_before_model(study,metadata):
    root,_=study;seal(root)
    for threshold in [True,float('nan'),float('inf')]:
        with pytest.raises(ValueError):calibrate(root,Engine(),metadata,threshold,.05)


def test_seal_failure_cleans_only_files_it_created(study):
    import face.evaluation.dataset as module
    root,_=study;images={p:p.read_bytes() for p in root.rglob('*.png')};original=module.create_json
    def fail(path,value):
        if Path(path).name=='evaluation-manifest.json':raise OSError('unit seal failure')
        return original(path,value)
    with patch.object(module,'create_json',side_effect=fail):
        with pytest.raises(OSError):seal(root)
    assert not (root/'calibration-manifest.json').exists() and not (root/'dataset-lock.json').exists()
    assert all(p.read_bytes()==raw for p,raw in images.items())
    seal(root)
