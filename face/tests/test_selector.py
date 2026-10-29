from dataclasses import replace
import json
import pytest
from face.prototype.config import PrototypeConfig, ROI
from face.prototype.selector import EligibleFaceSelector
from face.prototype.types import Box, FaceCandidate, SelectionStatus


def test_T01_no_face(selector):
    result = selector.select(640, 480, [])
    assert result.status == SelectionStatus.NO_ELIGIBLE_FACE
    assert not result.eligible_faces


def test_T03_small_face(selector):
    result = selector.select(640, 480, [FaceCandidate(Box(300, 220, 30, 30), 200, 100)])
    assert not result.eligible_faces
    assert result.rejection_reasons == ((0, ("TOO_SMALL",)),)


def test_T04_large_front_small_background(selector, front):
    result = selector.select(640, 480, [front, FaceCandidate(Box(360, 150, 30, 30), 200, 100)])
    assert result.status == SelectionStatus.READY
    assert result.eligible_faces == (front,)
    assert result.faces_in_roi == 2


@pytest.mark.parametrize("blur,brightness,reason", [(0, 120, "BLUR_OR_UNKNOWN"), (150, 10, "BRIGHTNESS_OR_UNKNOWN"),
                                                (150, 250, "BRIGHTNESS_OR_UNKNOWN"), (None, 120, "BLUR_OR_UNKNOWN"),
                                                (150, float("nan"), "BRIGHTNESS_OR_UNKNOWN")])
def test_T06_bad_quality(selector, front, blur, brightness, reason):
    result = selector.select(640, 480, [replace(front, blur_variance=blur, brightness=brightness)])
    assert result.status == SelectionStatus.NO_ELIGIBLE_FACE
    assert reason in result.rejection_reasons[0][1]
    assert result.faces_in_roi == 1  # Quality loss must never re-arm a successful scan.


def test_T07_outside_roi(selector):
    result = selector.select(640, 480, [FaceCandidate(Box(0, 100, 100, 160), 100, 100)])
    assert not result.eligible_faces
    assert result.rejection_reasons == ((0, ("OUTSIDE_ROI",)),)
    assert result.faces_in_roi == 0


def test_T16_thresholds_loaded_from_json(tmp_path, front):
    assert ROI(.8, .8, .2, .2).width == .2  # A valid rectangle may touch frame edges.
    path = tmp_path / "settings.json"
    path.write_text(json.dumps({"min_width_ratio": 0.4, "stable_seconds": 1.0,
                                "roi": {"x": 0, "y": 0, "width": 1, "height": 1}}), encoding="utf-8")
    config = PrototypeConfig.load(path)
    assert config.stable_seconds == 1.0
    assert config.roi == ROI(0, 0, 1, 1)
    assert not EligibleFaceSelector(config).select(640, 480, [front]).eligible_faces
    assert EligibleFaceSelector(PrototypeConfig()).select(640, 480, [front]).eligible_faces


@pytest.mark.parametrize("change", [{"stable_seconds": -1}, {"detection_hz": 0}, {"auth_timeout_seconds": float("nan")},
                                    {"min_width_ratio": 2}, {"stable_min_frames": 1}, {"min_brightness": 250},
                                    {"max_detection_gap_seconds": 0.05}])
def test_invalid_config_rejected(change):
    with pytest.raises(ValueError):
        PrototypeConfig(**change)


@pytest.mark.parametrize("box", [Box(-1, 10, 100, 100), Box(10, 10, -1, 100), Box(float("nan"), 10, 100, 100)])
def test_invalid_box_rejected(selector, box):
    result = selector.select(640, 480, [FaceCandidate(box, 100, 100)])
    assert result.rejection_reasons == ((0, ("INVALID_BOX",)),)


def test_roi_uses_center_not_full_containment(config, front):
    selector = EligibleFaceSelector(replace(config, roi=ROI(0.4, 0.4, 0.2, 0.2)))
    assert selector.select(640, 480, [front]).status == SelectionStatus.READY
