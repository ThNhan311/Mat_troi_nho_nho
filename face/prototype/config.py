from dataclasses import dataclass, field, fields
import json
from math import isfinite
from pathlib import Path


@dataclass(frozen=True)
class ROI:
    """Normalized rectangle. A face is inside when its CENTER is inside."""

    x: float = 0.2
    y: float = 0.1
    width: float = 0.6
    height: float = 0.8

    def __post_init__(self):
        if not all(isfinite(v) for v in (self.x, self.y, self.width, self.height)) or not (
            0 <= self.x < 1 and 0 <= self.y < 1 and self.width > 0 and self.height > 0
            and self.x + self.width <= 1 and self.y + self.height <= 1
        ):
            raise ValueError("ROI must be a positive rectangle inside normalized frame [0, 1]")


@dataclass(frozen=True)
class PrototypeConfig:
    roi: ROI = field(default_factory=ROI)
    min_width_ratio: float = 0.15
    min_height_ratio: float = 0.15
    min_blur_variance: float = 60.0
    min_brightness: float = 45.0
    max_brightness: float = 220.0
    detection_hz: float = 8.0
    stable_seconds: float = 0.7
    stable_min_frames: int = 3
    stable_iou: float = 0.4
    max_detection_gap_seconds: float = 0.4
    auth_timeout_seconds: float = 7.0
    cooldown_seconds: float = 5.0
    leave_seconds: float = 0.4
    reconnect_seconds: float = 1.0
    kiosk_id: str = "fitcenter-local-mock"

    def __post_init__(self):
        for name in ("min_width_ratio", "min_height_ratio", "stable_iou"):
            if not 0 < getattr(self, name) <= 1:
                raise ValueError(f"{name} must be in (0, 1]")
        for name in ("detection_hz", "stable_seconds", "max_detection_gap_seconds", "auth_timeout_seconds", "cooldown_seconds", "leave_seconds", "reconnect_seconds"):
            value = getattr(self, name)
            if not isfinite(value) or value <= 0:
                raise ValueError(f"{name} must be finite and positive")
        if self.max_detection_gap_seconds <= 1 / self.detection_hz:
            raise ValueError("max_detection_gap_seconds must exceed detection interval")
        if type(self.stable_min_frames) is not int or self.stable_min_frames < 2:
            raise ValueError("stable_min_frames must be an integer >= 2")
        if not isfinite(self.min_blur_variance) or self.min_blur_variance < 0:
            raise ValueError("min_blur_variance must be finite and nonnegative")
        if not 0 <= self.min_brightness < self.max_brightness <= 255:
            raise ValueError("brightness thresholds must satisfy 0 <= min < max <= 255")
        if not self.kiosk_id:
            raise ValueError("kiosk_id is required")

    @classmethod
    def load(cls, path: str | Path) -> "PrototypeConfig":
        data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
        unknown = set(data) - {f.name for f in fields(cls)}
        if unknown:
            raise ValueError(f"Unknown config keys: {sorted(unknown)}")
        if "roi" in data:
            data["roi"] = ROI(**data["roi"])
        return cls(**data)
