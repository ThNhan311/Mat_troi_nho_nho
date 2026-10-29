"""MediaPipe Tasks 0.10.32 adapter; model is supplied explicitly by operator."""
from pathlib import Path
from typing import Protocol
from .types import Box, FaceCandidate


class FaceDetector(Protocol):
    def detect(self, frame) -> list[Box]: ...
    def close(self) -> None: ...


class MockFaceDetector:
    def __init__(self, boxes: list[Box] | None = None):
        self.boxes = boxes if boxes is not None else [Box(230, 140, 180, 200)]

    def detect(self, frame) -> list[Box]:
        return list(self.boxes)

    def close(self):
        pass


class MediaPipeFaceDetector:
    def __init__(self, model_path: str | Path, min_confidence: float = 0.6):
        import mediapipe as mp
        from mediapipe.tasks import python
        from mediapipe.tasks.python import vision
        path = Path(model_path)
        if not path.is_file():
            raise ValueError("MediaPipe model missing; supply --model path/to/blaze_face_short_range.tflite")
        self.mp = mp
        options = vision.FaceDetectorOptions(
            base_options=python.BaseOptions(model_asset_path=str(path.resolve())),
            running_mode=vision.RunningMode.IMAGE,
            min_detection_confidence=min_confidence,
        )
        self.detector = vision.FaceDetector.create_from_options(options)

    def detect(self, frame) -> list[Box]:
        import cv2
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        result = self.detector.detect(self.mp.Image(image_format=self.mp.ImageFormat.SRGB, data=rgb))
        height, width = frame.shape[:2]
        boxes = []
        for detection in result.detections:
            b = detection.bounding_box
            x, y = max(0, b.origin_x), max(0, b.origin_y)
            right, bottom = min(width, b.origin_x + b.width), min(height, b.origin_y + b.height)
            if right > x and bottom > y:
                boxes.append(Box(x, y, right - x, bottom - y))
        return boxes

    def close(self):
        self.detector.close()


def measure_candidates(frame, boxes: list[Box]) -> list[FaceCandidate]:
    """Actual grayscale mean and Laplacian variance; no synthetic quality score."""
    import cv2
    height, width = frame.shape[:2]
    faces = []
    for box in boxes:
        if not box.valid or box.x < 0 or box.y < 0 or box.x + box.width > width or box.y + box.height > height:
            faces.append(FaceCandidate(box, None, None))
            continue
        x, y = int(box.x), int(box.y)
        right, bottom = int(box.x + box.width), int(box.y + box.height)
        crop = frame[y:bottom, x:right]
        if crop.size == 0:
            faces.append(FaceCandidate(box, None, None))
            continue
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        faces.append(FaceCandidate(box, float(cv2.Laplacian(gray, cv2.CV_64F).var()), float(gray.mean())))
    return faces
