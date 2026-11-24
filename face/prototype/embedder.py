from typing import Protocol
import numpy as np

MODEL_NAME = "insightface-buffalo_s"


class Embedder(Protocol):
    model_name: str

    def embed(self, frame_bgr: np.ndarray) -> np.ndarray | None:
        """Unit-length 512-d embedding of the largest face, or None when no face."""
        ...


class InsightFaceEmbedder:
    """ArcFace embeddings via InsightFace on CPU. Pretrained weights are downloaded on first use.

    Check the InsightFace model license before any commercial deployment.
    """

    model_name = MODEL_NAME

    def __init__(self, pack: str = "buffalo_s", det_size: int = 320):
        from insightface.app import FaceAnalysis  # Heavy import: keep out of module load.
        self._app = FaceAnalysis(name=pack, allowed_modules=["detection", "recognition"], providers=["CPUExecutionProvider"])
        self._app.prepare(ctx_id=-1, det_size=(det_size, det_size))

    def embed(self, frame_bgr: np.ndarray) -> np.ndarray | None:
        faces = self._app.get(frame_bgr)
        if not faces:
            return None
        face = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
        return np.asarray(face.normed_embedding, dtype=np.float32)
