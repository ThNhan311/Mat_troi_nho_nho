"""Load the pinned buffalo_s implementation without implicit downloads/cache mutation."""
from pathlib import Path
import hashlib
import importlib.metadata
import json
import numpy as np

REQUIRED=('det_500m.onnx','w600k_mbf.onnx')

def probe(root):
    root=Path(root).resolve();pack=root/'models'/'buffalo_s'
    report={'pack':'buffalo_s','root':str(root),'artifacts':{},'dependencies':{},'liveness':'NOT_PERFORMED'}
    for name in ['numpy','onnxruntime','insightface','opencv-contrib-python','fastapi','uvicorn','cryptography']:
        try:report['dependencies'][name]=importlib.metadata.version(name)
        except importlib.metadata.PackageNotFoundError:report['dependencies'][name]=None
    for name in REQUIRED:
        p=pack/name
        report['artifacts'][name]={'present':p.is_file(),'sha256':hashlib.sha256(p.read_bytes()).hexdigest() if p.is_file() else None}
    report['ready']=all(x['present'] for x in report['artifacts'].values()) and all(report['dependencies'].values())
    return report

class Runtime:
    model_name='insightface-buffalo_s'
    provenance='MODEL_INFERENCE_UNCALIBRATED'
    def __init__(self,root):
        report=probe(root)
        if not report['ready']:raise RuntimeError('Pinned buffalo_s dependencies/artifacts missing; run probe; no substitute/download')
        from insightface.app import FaceAnalysis
        # All artifacts preflighted; use caller-owned cache root, never the original cache.
        from face.prototype.embedder import InsightFaceEmbedder
        self.delegate=InsightFaceEmbedder.__new__(InsightFaceEmbedder)
        self.delegate._app=FaceAnalysis(name='buffalo_s',root=str(Path(root).resolve()),allowed_modules=['detection','recognition'],providers=['CPUExecutionProvider'])
        self.delegate._app.prepare(ctx_id=-1,det_size=(320,320))
    def embed(self,image):return self.delegate.embed(image)
