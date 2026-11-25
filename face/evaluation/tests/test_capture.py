from dataclasses import replace
from unittest.mock import patch
from uuid import uuid4
from pathlib import Path
import cv2,numpy as np,pytest
from face.evaluation.capture import ManualCapture,Guidance,render,verified_runtime
from face.evaluation.dataset import Session,initialize,load,outside_git
from face.prototype.config import PrototypeConfig
from face.prototype.types import Box
from .conftest import SOURCE,QUALITY,frame,session

@pytest.fixture
def unconfirmed(tmp_path):
    root=tmp_path/'dataset';d=initialize(root,'unit');s=Session(root,d['participants'][0]['subject'],'gallery',str(uuid4()),str(uuid4()),SOURCE);return s

def test_default_preview_never_writes_or_arms_without_consent(unconfirmed):
    c=ManualCapture(unconfirmed)
    for _ in range(3):
        with pytest.raises(ValueError):c.save(frame(1),QUALITY,1,1.1)
    with pytest.raises(ValueError):c.arm()
    with pytest.raises(ValueError):unconfirmed.confirm('yes')
    assert not list(unconfirmed.root.rglob('*.png')) and not list((unconfirmed.root/'sessions').iterdir())

def test_explicit_consent_arm_one_shot_and_saved_raw_orientation(unconfirmed):
    s=unconfirmed;s.confirm('CONSENT '+s.subject);c=ManualCapture(s);c.arm();image=frame(1)
    sample=c.save(image,QUALITY,1,1.1)
    assert not c.armed;assert np.array_equal(cv2.imread(str(s.root/sample['path'])),image)
    assert s.document['consent']['accepted'] and s.document['liveness']=='NOT_PERFORMED'
    with pytest.raises(ValueError):c.save(frame(1,1),QUALITY,2,2.1)
    c.arm();c.save(frame(1,1),QUALITY,2,2.1);assert len(s.document['samples'])==2
    c.close()
    with pytest.raises(ValueError):c.arm()

@pytest.mark.parametrize('age',[-.1,.401,2])
def test_stale_frames_rejected_and_disarmed(unconfirmed,age):
    s=unconfirmed;s.confirm('CONSENT '+s.subject);c=ManualCapture(s);c.arm()
    with pytest.raises(ValueError):c.save(frame(1),QUALITY,1,1+age)
    assert not c.armed and not list(s.root.rglob('*.png'))

@pytest.mark.parametrize('change',[{'ready':False},{'stable':False},{'faceCount':2},{'faceCount':0}])
def test_invalid_current_quality_does_not_store(unconfirmed,change):
    s=unconfirmed;s.confirm('CONSENT '+s.subject);c=ManualCapture(s);c.arm()
    with pytest.raises(ValueError):c.save(frame(1),{**QUALITY,**change},1,1.1)
    assert not list(s.root.rglob('*.png'))

def test_pause_reconnect_and_close_cannot_auto_resume_recording(unconfirmed):
    s=unconfirmed;s.confirm('CONSENT '+s.subject);c=ManualCapture(s);c.arm();c.pause()
    with pytest.raises(ValueError):c.save(frame(1),QUALITY,1,1.1)
    c.close();assert not c.armed

def test_quality_guidance_reuses_actual_measurements_roi_and_stability():
    c=PrototypeConfig();g=Guidance(c);image=frame(1);box=Box(20,20,60,60)
    for t in [0,.12,.24,.36,.48,.60,.72]:r=g.inspect(image,[box],t)
    assert r['ready'] and r['blurVariance']>60 and 45<=r['brightness']<=220
    assert not g.inspect(image,[box,Box(0,0,15,15)],.8)['ready']
    assert not g.inspect(np.zeros_like(image),[box],.9)['ready']
    assert not g.inspect(image,[Box(0,0,10,10)],1)['ready']
    assert not g.inspect(image,[],1.1)['ready']

def test_mirror_only_preview_keeps_original_array():
    image=frame(1);before=image.copy();c=PrototypeConfig();out=render(image,[],c,[])
    # Bottom row is outside ROI decoration; the source pixels are never changed.
    assert np.array_equal(image,before);assert np.array_equal(out[-1],before[-1,::-1])

def test_duplicate_across_sessions_and_manifest_rollback_preserve_other_samples(unconfirmed):
    s=unconfirmed;s.confirm('CONSENT '+s.subject);first=s.save(frame(1),QUALITY)
    person=s.study['participants'][0];other=session(s.root,person,'probe')
    with pytest.raises(ValueError,match='Duplicate'):other.save(frame(1),QUALITY)
    with patch('face.evaluation.dataset.atomic_json',side_effect=OSError('unit fault')):
        with pytest.raises(OSError):s.save(frame(1,2),QUALITY)
    assert len(load(s.folder/'session.json')['samples'])==1
    assert list((s.folder/'images').iterdir())==[s.root/first['path']]

def test_outside_git_rejects_current_and_other_known_worktree():
    repo=Path(__file__).resolve().parents[3]
    with pytest.raises(ValueError):outside_git(repo/'private-dataset')
    other=repo.with_name('Mat_troi_nho_nho')
    if other.exists():
        with pytest.raises(ValueError):outside_git(other/'private-dataset')

def test_no_new_or_replaced_weights_allowed(tmp_path):
    with patch('face.evaluation.capture.probe',return_value={'ready':True,'artifacts':{'det_500m.onnx':{'sha256':'changed'},'w600k_mbf.onnx':{'sha256':'changed'}}}):
        with pytest.raises(ValueError,match='weights mismatch'):verified_runtime(tmp_path)

def test_probe_requires_independent_session_and_unknown_cannot_gallery(tmp_path):
    root=tmp_path/'dataset';d=initialize(root,'unit');p=d['participants'][0]
    s=Session(root,p['subject'],'probe',str(uuid4()),str(uuid4()),SOURCE)
    with pytest.raises(ValueError,match='separate'):s.confirm('CONSENT '+p['subject'])
    unknown=next(x for x in d['participants'] if not x['known'])
    with pytest.raises(ValueError,match='probe-only'):Session(root,unknown['subject'],'gallery',str(uuid4()),str(uuid4()),SOURCE)


def test_uuid_file_collision_does_not_delete_existing_image(unconfirmed):
    from uuid import UUID
    s=unconfirmed;s.confirm('CONSENT '+s.subject);fixed=UUID('00000000-0000-0000-0000-000000000001');existing=s.folder/'images'/(str(fixed)+'.png');existing.write_bytes(b'existing private file')
    with patch('face.evaluation.dataset.uuid4',return_value=fixed):
        with pytest.raises(FileExistsError):s.save(frame(1),QUALITY)
    assert existing.read_bytes()==b'existing private file'

def test_consent_ref_cannot_be_rebound_to_another_participant(unconfirmed):
    s=unconfirmed;s.confirm('CONSENT '+s.subject);p=s.study['participants'][1]
    other=Session(s.root,p['subject'],'gallery',s.operator,s.consent_ref,SOURCE)
    with pytest.raises(ValueError,match='another anonymous'):other.confirm('CONSENT '+p['subject'])

def test_camera_probe_discards_frames_and_releases_without_storage():
    from face.evaluation.capture import camera_probe
    class Camera:
        def __init__(self,*_):self.closed=False;self.source=True;self.warning=''
        def read(self,_):return frame(1)
        def close(self):self.closed=True;self.source=None
    with patch('face.evaluation.capture.CameraCapture',Camera),patch('cv2.imwrite',side_effect=AssertionError('No persistence during probe')):
        result=camera_probe(0)
    assert result['framesRead']==3 and result['released'] and result['savedImages']==0 and result['faceInference'] is False

def test_preview_requires_operator_terminal_and_does_not_open_camera():
    from argparse import Namespace
    from face.evaluation.capture import preview
    with patch('sys.stdin.isatty',return_value=False),patch('face.evaluation.capture.CameraCapture') as camera:
        with pytest.raises(ValueError,match='interactive terminal'):preview(Namespace())
        camera.assert_not_called()


@pytest.mark.parametrize('confirm',[False,True])
def test_preview_loop_is_manual_and_releases_camera_without_real_people(tmp_path,confirm):
    from argparse import Namespace
    from face.evaluation.capture import preview
    from face.evaluation.dataset import load
    root=tmp_path/'study';d=initialize(root,'generated-unit-loop');subject=d['participants'][0]['subject'];instances=[]
    class Camera:
        def __init__(self,*_):self.closed=False;self.source=True;self.warning='';self.n=0;instances.append(self)
        def read(self,_):self.n+=1;return frame(1,self.n)
        def close(self):self.closed=True;self.source=None
    args=Namespace(operator_ref=str(uuid4()),consent_ref=str(uuid4()),model_root=tmp_path,study=root,subject=subject,role='gallery',camera=0)
    keys=[ord('c'),ord('r'),32,ord('r'),32,ord('q')] if confirm else [32,ord('r'),32,ord('q')]
    with patch('sys.stdin.isatty',return_value=True),patch('face.evaluation.capture.verified_runtime',return_value=(object(),{'artifacts':{}})),patch('face.evaluation.capture.CameraCapture',Camera),patch('face.evaluation.capture.boxes_from_runtime',return_value=[Box(20,20,60,60)]) as detector,patch('face.evaluation.capture.Guidance.inspect',return_value=QUALITY),patch('cv2.imshow'),patch('cv2.waitKey',side_effect=keys),patch('cv2.getWindowProperty',return_value=1),patch('cv2.destroyAllWindows'),patch('builtins.input',return_value='CONSENT '+subject):
        preview(args)
    assert instances[0].closed and instances[0].source is None
    images=list(root.rglob('*.png'));assert len(images)==(2 if confirm else 0)
    if confirm:
        metadata=load(next((root/'sessions').glob('*/session.json')))
        assert len(metadata['samples'])==2 and metadata['source']['previewOrientation']=='MIRRORED'
    else:detector.assert_not_called()
