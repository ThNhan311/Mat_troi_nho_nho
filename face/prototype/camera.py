"""Capture resource lifecycle with injectable source for headless tests."""
from typing import Any, Callable, Protocol


class VideoSource(Protocol):
    def isOpened(self) -> bool: ...
    def read(self) -> tuple[bool, Any]: ...
    def release(self) -> None: ...


def open_webcam(index: int) -> VideoSource:
    import cv2
    import sys
    return cv2.VideoCapture(index, cv2.CAP_DSHOW) if sys.platform == "win32" else cv2.VideoCapture(index)


class CameraCapture:
    def __init__(self, index: int = 0, reconnect_seconds: float = 1.0, factory: Callable[[int], VideoSource] = open_webcam):
        self.index, self.reconnect_seconds, self.factory = index, reconnect_seconds, factory
        self.source: VideoSource | None = None
        self.next_retry = 0.0
        self.warning = "Camera not opened"
        self.closed = False

    def read(self, now: float):
        if self.closed:
            return None
        if self.source is None:
            if now < self.next_retry:
                return None
            try:
                self.source = self.factory(self.index)
                if not self.source.isOpened():
                    self._disconnect(now)
                    return None
            except Exception:
                self._disconnect(now)
                return None
        try:
            ok, frame = self.source.read()
            if not ok or frame is None:
                self._disconnect(now)
                return None
        except Exception:
            self._disconnect(now)
            return None
        self.warning = ""
        return frame

    def _release(self):
        if self.source is not None:
            source, self.source = self.source, None
            try:
                source.release()
            except Exception:
                self.warning = "Camera release failed"

    def _disconnect(self, now: float):
        self._release()
        self.next_retry = now + self.reconnect_seconds
        self.warning = "Camera disconnected/unavailable; reconnecting"

    def close(self):
        self.closed = True
        self._release()


class SyntheticVideoSource:
    """Generated checkerboard face REGION, not a face/recognition model."""

    def __init__(self):
        self.closed = False

    def isOpened(self) -> bool:
        return not self.closed

    def read(self):
        import numpy as np
        frame = np.full((480, 640, 3), 25, dtype=np.uint8)
        checker = ((np.indices((200, 180)).sum(axis=0) // 6) % 2 * 150 + 50).astype(np.uint8)
        frame[140:340, 230:410] = checker[:, :, None]
        return not self.closed, frame

    def release(self):
        self.closed = True
