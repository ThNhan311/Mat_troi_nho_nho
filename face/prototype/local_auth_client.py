"""Local 1:N identification client. No liveness: a photo of an enrolled member can pass."""
from threading import Event, Lock
import numpy as np
from .embedder import Embedder
from .matcher import Matcher
from .types import AuthOutcome, AuthRequest, AuthResult


class LatestFrameBuffer:
    """The UI thread publishes frames; the auth worker reads copies."""

    def __init__(self):
        self._lock = Lock()
        self._frame: np.ndarray | None = None

    def put(self, frame: np.ndarray) -> None:
        with self._lock:
            self._frame = frame.copy()

    def get(self) -> np.ndarray | None:
        with self._lock:
            return self._frame


class LocalAuthClient:
    def __init__(self, embedder: Embedder, matcher: Matcher, frames: LatestFrameBuffer,
                 samples: int = 3, interval_seconds: float = 0.15):
        if samples < 1:
            raise ValueError("samples must be >= 1")
        self.embedder, self.matcher, self.frames = embedder, matcher, frames
        self.samples, self.interval_seconds = samples, interval_seconds

    def authenticate(self, request: AuthRequest, cancel: Event) -> AuthResult:
        vectors = []
        for i in range(self.samples):
            if cancel.is_set():
                return AuthResult(request.request_id, AuthOutcome.TIMEOUT)
            frame = self.frames.get()
            if frame is not None:
                vector = self.embedder.embed(frame)
                if vector is not None:
                    vectors.append(vector)
            if i + 1 < self.samples:
                cancel.wait(self.interval_seconds)
        if not vectors:
            return AuthResult(request.request_id, AuthOutcome.REJECTED)
        # Averaging unit vectors across frames reduces single-frame noise.
        mean = np.mean(np.stack(vectors), axis=0)
        result = self.matcher.match(mean)
        outcome = AuthOutcome.SUCCESS if result.member_id else AuthOutcome.REJECTED
        return AuthResult(request.request_id, outcome, result.member_id, result.score)
