from pathlib import Path
from types import SimpleNamespace
import numpy as np
import pytest
from face.prototype.camera import SyntheticVideoSource
from face.prototype.detector import MediaPipeFaceDetector, MockFaceDetector, measure_candidates
from face.prototype.selector import EligibleFaceSelector
from face.prototype.types import Box, SelectionStatus


def test_measured_quality_rejects_dark_flat_region(config):
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    faces = measure_candidates(frame, [Box(230, 140, 180, 200)])
    assert faces[0].blur_variance == 0 and faces[0].brightness == 0
    assert not EligibleFaceSelector(config).select(640, 480, faces).eligible_faces


def test_synthetic_video_and_mock_detector(config):
    source = SyntheticVideoSource()
    ok, frame = source.read()
    faces = measure_candidates(frame, MockFaceDetector().detect(frame))
    assert ok
    assert faces[0].blur_variance > config.min_blur_variance
    assert config.min_brightness < faces[0].brightness < config.max_brightness
    assert EligibleFaceSelector(config).select(640, 480, faces).status == SelectionStatus.READY
    source.release()
    assert not source.isOpened()


def test_tasks_api_adapter_clips_boxes_and_closes(tmp_path, monkeypatch):
    from mediapipe.tasks.python import vision
    model = tmp_path / "fake.tflite"
    model.write_bytes(b"mock-adapter-test")
    calls = []

    class FakeTask:
        def detect(self, image):
            calls.append(image)
            return SimpleNamespace(detections=[SimpleNamespace(bounding_box=SimpleNamespace(origin_x=-10, origin_y=30, width=100, height=120))])

        def close(self):
            calls.append("closed")

    def create(options):
        assert options.running_mode == vision.RunningMode.IMAGE
        assert options.min_detection_confidence == .6
        return FakeTask()

    monkeypatch.setattr(vision.FaceDetector, "create_from_options", create)
    detector = MediaPipeFaceDetector(model)
    assert detector.detect(np.zeros((480, 640, 3), dtype=np.uint8)) == [Box(0, 30, 90, 120)]
    detector.close()
    assert calls[-1] == "closed"


def test_real_mediapipe_model_on_generated_frame():
    model = Path(__file__).parents[1] / "models" / "blaze_face_short_range.tflite"
    if not model.is_file():
        pytest.skip("Optional official model not downloaded; see README; no recognition accuracy claim")
    detector = MediaPipeFaceDetector(model)
    try:
        assert detector.detect(np.zeros((480, 640, 3), dtype=np.uint8)) == []
    finally:
        detector.close()
