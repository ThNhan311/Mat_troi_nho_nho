from dataclasses import dataclass
from enum import Enum
from math import isfinite


@dataclass(frozen=True)
class Box:
    """Pixel coordinates; x/y is the top-left corner."""

    x: float
    y: float
    width: float
    height: float

    @property
    def valid(self) -> bool:
        return all(isfinite(v) for v in (self.x, self.y, self.width, self.height)) and self.width > 0 and self.height > 0

    def iou(self, other: "Box") -> float:
        overlap = max(0.0, min(self.x + self.width, other.x + other.width) - max(self.x, other.x)) * max(
            0.0, min(self.y + self.height, other.y + other.height) - max(self.y, other.y)
        )
        return overlap / (self.width * self.height + other.width * other.height - overlap)


@dataclass(frozen=True)
class FaceCandidate:
    box: Box
    blur_variance: float | None
    brightness: float | None


class SelectionStatus(str, Enum):
    NO_ELIGIBLE_FACE = "NO_ELIGIBLE_FACE"
    READY = "READY"
    MULTIPLE_ELIGIBLE_FACES = "MULTIPLE_ELIGIBLE_FACES"


@dataclass(frozen=True)
class Selection:
    eligible_faces: tuple[FaceCandidate, ...]
    rejection_reasons: tuple[tuple[int, tuple[str, ...]], ...]
    status: SelectionStatus
    # Counts all detected faces inside ROI, even when quality/size fails.
    faces_in_roi: int


class AuthOutcome(str, Enum):
    SUCCESS = "SUCCESS"
    REJECTED = "REJECTED"
    TIMEOUT = "TIMEOUT"
    SERVICE_ERROR = "SERVICE_ERROR"


@dataclass(frozen=True)
class MockCapturePayload:
    """Metadata only. A single still is NOT a liveness capture protocol."""

    eligible_count: int = 1
    source: str = "mock-metadata-only"


@dataclass(frozen=True)
class AuthRequest:
    request_id: str
    kiosk_id: str
    payload: MockCapturePayload


@dataclass(frozen=True)
class AuthResult:
    request_id: str
    outcome: AuthOutcome
    member_id: str | None = None
    score: float | None = None
