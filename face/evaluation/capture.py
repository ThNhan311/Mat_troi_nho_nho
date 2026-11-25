"""Interactive local preview/manual still capture. Never starts recording automatically."""
import argparse,dataclasses,json,sys,time
from pathlib import Path
from uuid import UUID
import cv2,numpy as np
from face.prototype.camera import CameraCapture
from face.prototype.config import PrototypeConfig
from face.prototype.detector import measure_candidates
from face.prototype.selector import EligibleFaceSelector
from face.prototype.state_machine import StableFaceGate
from face.prototype.types import Box
from face.service_v2.runtime import Runtime,probe
from face.service_v2.artifacts import ARTIFACTS
from .dataset import Session,outside_git,utc


def verified_runtime(root):
    r=probe(root)
    if not r['ready'] or any(r['artifacts'][n]['sha256']!=sha for n,sha in ARTIFACTS.items()):raise ValueError('Pinned buffalo_s runtime/weights mismatch; no download or substitute')
    return Runtime(root),r

class Guidance:
    def __init__(self,config=None):
        self.config=config or PrototypeConfig();self.selector=EligibleFaceSelector(self.config);self.gate=StableFaceGate(self.config)
    def inspect(self,frame,boxes,now):
        faces=measure_candidates(frame,boxes);selection=self.selector.select(frame.shape[1],frame.shape[0],faces)
        stable=self.gate.update(selection,now) if len(faces)==1 else False
        if len(faces)!=1:self.gate.reset()
        ready=len(faces)==1 and len(selection.eligible_faces)==1 and stable
        hints=[]
        for _,reasons in selection.rejection_reasons:hints.extend(reasons)
        if len(faces)==0:hints.append('NO_FACE')
        elif len(faces)>1:hints.append('ONE_PARTICIPANT_ONLY')
        elif not stable:hints.append('HOLD_STILL')
        return {'ready':ready,'faceCount':len(faces),'stable':stable,'hints':hints,'blurVariance':faces[0].blur_variance if len(faces)==1 else None,'brightness':faces[0].brightness if len(faces)==1 else None}
    def invalidate(self):self.gate.reset()

class ManualCapture:
    def __init__(self,session,config=None):self.session=session;self.config=config or PrototypeConfig();self.armed=False;self.closed=False
    def arm(self):
        if self.closed or self.session.document is None:raise ValueError('Explicit consent required; cannot arm closed session')
        self.armed=True
    def pause(self):self.armed=False
    def close(self):self.pause();self.closed=True
    def save(self,frame,quality,captured_monotonic,now):
        if self.closed or not self.armed:raise ValueError('Manual capture not armed')
        # One-shot even on an error. Holding Space cannot create a burst; R is needed again.
        self.armed=False
        age=now-captured_monotonic
        if age<0 or age>self.config.max_detection_gap_seconds:raise ValueError('Frame stale; wait for fresh preview and re-arm')
        if quality.get('ready')is not True or quality.get('faceCount')!=1 or quality.get('stable')is not True:raise ValueError('Quality/ROI/stability not ready')
        return self.session.save(frame,{**quality,'ageMs':age*1000})

def boxes_from_runtime(engine,frame):
    bboxes,_=engine.delegate._app.det_model.detect(frame,max_num=0)
    height,width=frame.shape[:2];result=[]
    for row in bboxes:
        x,y=max(0.,float(row[0])),max(0.,float(row[1]));right,bottom=min(float(width),float(row[2])),min(float(height),float(row[3]))
        if right>x and bottom>y:result.append(Box(x,y,right-x,bottom-y))
    return result

def render(frame,boxes,config,lines):
    # Mirror the preview only. Draw normal text after flipping; saved BGR image stays raw.
    preview=cv2.flip(frame,1);h,w=preview.shape[:2];r=config.roi
    cv2.rectangle(preview,(int((1-r.x-r.width)*w),int(r.y*h)),(int((1-r.x)*w),int((r.y+r.height)*h)),(0,210,255),2)
    for b in boxes:cv2.rectangle(preview,(int(w-b.x-b.width),int(b.y)),(int(w-b.x),int(b.y+b.height)),(0,200,0),2)
    for i,line in enumerate(lines):cv2.putText(preview,line,(8,22+i*24),cv2.FONT_HERSHEY_SIMPLEX,.48,(240,240,240),1,cv2.LINE_AA)
    return preview

def camera_probe(index=0):
    cap=CameraCapture(index);result={'cameraIndex':index,'framesRead':0,'savedImages':0,'faceInference':False,'previewDisplayed':False,'backend':'DSHOW' if sys.platform=='win32' else 'DEFAULT','opencv':cv2.__version__};start=time.monotonic()
    try:
        for _ in range(3):
            frame=cap.read(time.monotonic())
            if frame is not None:result['framesRead']+=1;result['frameShape']=list(frame.shape)
            frame=None
        result['warning']=cap.warning
    finally:cap.close();result['released']=cap.closed and cap.source is None
    result['elapsedMs']=(time.monotonic()-start)*1000;return result

def preview(args):
    if not sys.stdin.isatty():raise ValueError('Run from an interactive terminal; consent cannot be piped/auto-confirmed')
    UUID(args.operator_ref);UUID(args.consent_ref)
    engine,metadata=verified_runtime(args.model_root);config=PrototypeConfig();guidance=Guidance(config)
    source={'kind':'WEBCAM','cameraIndex':args.camera,'backend':'DSHOW' if sys.platform=='win32' else 'DEFAULT','savedOrientation':'RAW_UNMIRRORED','previewOrientation':'MIRRORED','detector':'SCRFD det_500m.onnx','modelArtifacts':metadata['artifacts'],'qualityGuidance':{k:v for k,v in dataclasses.asdict(config).items() if k in ('roi','min_width_ratio','min_height_ratio','min_blur_variance','min_brightness','max_brightness','stable_seconds','stable_min_frames','stable_iou','max_detection_gap_seconds')},'liveness':'NOT_PERFORMED'}
    session=Session(args.study,args.subject,args.role,args.operator_ref,args.consent_ref,source);manual=ManualCapture(session,config)
    camera=CameraCapture(args.camera);message='PREVIEW ONLY - NO IMAGES SAVED';window='FitCenter - local consented capture (NOT admission)'
    try:
        while True:
            frame=camera.read(time.monotonic());captured=time.monotonic();boxes=[];quality=None
            if frame is None:
                manual.pause();guidance.invalidate();canvas=np.zeros((480,640,3),dtype=np.uint8);lines=['Camera unavailable - capture paused','Q/Esc: quit; camera will reconnect']
            else:
                # No model processing before operator consent; raw preview is transient memory only.
                if session.document is not None:
                    boxes=boxes_from_runtime(engine,frame);quality=guidance.inspect(frame,boxes,time.monotonic())
                canvas=frame;lines=[message,'C: consent | R: arm ONE still | Space: save | P: pause | Q: quit',
                    'NOT RECORDING' if not manual.armed else 'ARMED - SPACE saves one image then DISARMS',
                    'Subject '+args.subject+' | '+args.role+' | '+session.person['split'],
                    'NOT_PERFORMED liveness - NO GYM ADMISSION']
                if quality is not None:lines.append('READY' if quality['ready'] else ', '.join(quality['hints']))
            cv2.imshow(window,render(canvas,boxes,config,lines));key=cv2.waitKey(20)&0xff
            if key in (27,ord('q')) or cv2.getWindowProperty(window,cv2.WND_PROP_VISIBLE)<1:break
            try:
                if key==ord('c') and session.document is None:
                    manual.pause()
                    print('Confirm the participant agreed to local image capture/offline evaluation, scope and private retention. No membership/admission is granted.')
                    phrase=input('Type CONSENT '+args.subject+' only after participant agreement: ').strip()
                    separate=False
                    if args.role=='probe' and session.person['known']:separate=input('A different visit/session from gallery (not frames from same video). Type INDEPENDENT: ').strip()=='INDEPENDENT'
                    session.confirm(phrase,separate);guidance.invalidate();message='Consent recorded; still NOT recording. R then Space per sample.'
                elif key==ord('r'):manual.arm();message='ARMED - check participant/ROI then Space once'
                elif key==ord('p'):manual.pause();message='PAUSED - NOT RECORDING'
                elif key==32:
                    if frame is None or quality is None:manual.pause();raise ValueError('Consent and fresh valid frame required')
                    manual.save(frame,quality,captured,time.monotonic());guidance.invalidate();message='Saved ONE image; DISARMED. Change pose; R then Space for next.'
            except ValueError as ex:message=str(ex);manual.pause()
            frame=None
    finally:manual.close();camera.close();cv2.destroyAllWindows()

def main():
    a=argparse.ArgumentParser(description='Local mirrored preview; explicit consent + R then Space per still. No video/auto-save, no admission.')
    a.add_argument('--probe-camera',action='store_true');a.add_argument('--camera',type=int,default=0)
    a.add_argument('--study',type=Path);a.add_argument('--subject');a.add_argument('--role',choices=['gallery','probe']);a.add_argument('--operator-ref');a.add_argument('--consent-ref');a.add_argument('--model-root',type=Path)
    args=a.parse_args()
    if args.camera<0:a.error('camera index must be nonnegative')
    if args.probe_camera:print(json.dumps(camera_probe(args.camera),indent=2));return
    if not all([args.study,args.subject,args.role,args.operator_ref,args.consent_ref,args.model_root]):a.error('study, subject, role, operator-ref, consent-ref, model-root required for manual preview')
    preview(args)
if __name__=='__main__':main()
