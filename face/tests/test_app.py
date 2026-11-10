from argparse import Namespace
import cv2
import pytest
from face.prototype import app


def args(**changes):
    values = dict(config=None, camera=0, model=None, synthetic=True, headless=False,
                  seconds=2, mock_outcome="SUCCESS", mock_delay=.5)
    values.update(changes)
    return Namespace(**values)


def test_preview_draws_roi_and_exits_on_q(monkeypatch):
    frames, closed = [], []
    monkeypatch.setattr(cv2, "imshow", lambda title, frame: frames.append(frame.copy()))
    monkeypatch.setattr(cv2, "waitKey", lambda _: ord("q"))
    monkeypatch.setattr(cv2, "destroyAllWindows", lambda: closed.append(True))
    result = app.run(args())
    assert len(frames) == 1 and result["frames"] == 1
    assert tuple(frames[0][48, 128]) == (255, 200, 0)  # Normalized ROI top-left.
    assert closed == [True]


def test_preview_window_close_releases_camera(monkeypatch):
    from face.prototype.camera import SyntheticVideoSource
    sources = []

    def factory():
        source = SyntheticVideoSource()
        sources.append(source)
        return source

    monkeypatch.setattr(app, "SyntheticVideoSource", factory)
    monkeypatch.setattr(cv2, "imshow", lambda *_: None)
    monkeypatch.setattr(cv2, "waitKey", lambda _: -1)
    monkeypatch.setattr(cv2, "getWindowProperty", lambda *_: 0)
    monkeypatch.setattr(cv2, "destroyAllWindows", lambda: None)
    app.run(args())
    assert sources[0].closed


def test_webcam_mirrors_image_with_aligned_detection_and_overlay(monkeypatch):
    import numpy as np
    from face.prototype.camera import CameraCapture
    from face.prototype.types import Box

    raw = np.zeros((480, 640, 3), dtype=np.uint8)
    raw[300:320, 40:60] = (10, 80, 200)
    shown, detected, released = [], [], []

    class Source:
        def isOpened(self):
            return True

        def read(self):
            return True, raw.copy()

        def release(self):
            released.append(True)

    class Detector:
        def detect(self, frame):
            detected.append(frame.copy())
            return [Box(580, 300, 20, 20)]

        def close(self):
            pass

    monkeypatch.setattr(app, "CameraCapture", lambda *_: CameraCapture(factory=lambda _: Source()))
    monkeypatch.setattr(app, "MediaPipeFaceDetector", lambda _: Detector())
    monkeypatch.setattr(cv2, "imshow", lambda title, frame: shown.append(frame.copy()))
    monkeypatch.setattr(cv2, "waitKey", lambda _: ord("q"))
    monkeypatch.setattr(cv2, "destroyAllWindows", lambda: None)
    app.run(args(synthetic=False, model="unused.tflite"))

    assert tuple(detected[0][310, 590]) == (10, 80, 200)
    assert tuple(detected[0][310, 50]) == (0, 0, 0)
    assert tuple(shown[0][310, 590]) == (10, 80, 200)
    assert tuple(shown[0][310, 580]) == (0, 100, 255)  # Rejected box follows mirrored image.
    assert released == [True]


def test_detector_failure_does_not_start_auth_and_closes(monkeypatch):
    closed = []

    class BrokenDetector:
        def detect(self, frame):
            raise RuntimeError("model error")

        def close(self):
            closed.append(True)

    monkeypatch.setattr(app, "MockFaceDetector", BrokenDetector)
    result = app.run(args(headless=True, seconds=.1))
    assert result["requests_sent"] == 0
    assert result["detections"] == 0
    assert closed == [True]


def test_startup_error_still_shuts_down_controller(monkeypatch):
    closed = []
    original = app.PrototypeController.shutdown

    def shutdown(self):
        original(self)
        closed.append(self.machine.closed)

    def fail():
        raise RuntimeError("detector initialization failed")

    monkeypatch.setattr(app.PrototypeController, "shutdown", shutdown)
    monkeypatch.setattr(app, "MockFaceDetector", fail)
    with pytest.raises(RuntimeError):
        app.run(args(headless=True))
    assert closed == [True]
