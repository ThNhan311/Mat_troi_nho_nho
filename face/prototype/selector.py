from math import isfinite
from .config import PrototypeConfig
from .types import FaceCandidate, Selection, SelectionStatus


class EligibleFaceSelector:
    def __init__(self, config: PrototypeConfig):
        self.config = config

    def select(self, frame_width: int, frame_height: int, faces: list[FaceCandidate]) -> Selection:
        if frame_width <= 0 or frame_height <= 0:
            raise ValueError("Frame dimensions must be positive")
        eligible, rejected = [], []
        in_roi_count = 0
        c, roi = self.config, self.config.roi
        for index, face in enumerate(faces):
            b, reasons = face.box, []
            if not b.valid or b.x < 0 or b.y < 0 or b.x + b.width > frame_width or b.y + b.height > frame_height:
                rejected.append((index, ("INVALID_BOX",)))
                continue
            cx, cy = (b.x + b.width / 2) / frame_width, (b.y + b.height / 2) / frame_height
            inside = roi.x <= cx <= roi.x + roi.width and roi.y <= cy <= roi.y + roi.height
            in_roi_count += int(inside)
            if b.width / frame_width < c.min_width_ratio or b.height / frame_height < c.min_height_ratio:
                reasons.append("TOO_SMALL")
            if face.blur_variance is None or not isfinite(face.blur_variance) or face.blur_variance < c.min_blur_variance:
                reasons.append("BLUR_OR_UNKNOWN")
            if face.brightness is None or not isfinite(face.brightness) or not c.min_brightness <= face.brightness <= c.max_brightness:
                reasons.append("BRIGHTNESS_OR_UNKNOWN")
            if not inside:
                reasons.append("OUTSIDE_ROI")
            if reasons:
                rejected.append((index, tuple(reasons)))
            else:
                eligible.append(face)
        status = (SelectionStatus.NO_ELIGIBLE_FACE if not eligible else
                  SelectionStatus.READY if len(eligible) == 1 else SelectionStatus.MULTIPLE_ELIGIBLE_FACES)
        return Selection(tuple(eligible), tuple(rejected), status, in_roi_count)
