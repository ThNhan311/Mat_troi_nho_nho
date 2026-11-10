from enum import Enum
from uuid import uuid4
from .config import PrototypeConfig
from .types import AuthOutcome, AuthRequest, AuthResult, Box, MockCapturePayload, Selection


class State(str, Enum):
    IDLE = "IDLE"
    READY = "READY"
    VERIFYING = "VERIFYING"
    COOLDOWN = "COOLDOWN"


class StableFaceGate:
    """Continuity is geometric, not identity tracking or recognition."""

    def __init__(self, config: PrototypeConfig):
        self.config = config
        self.reset()

    def reset(self):
        self.box: Box | None = None
        self.since: float | None = None
        self.last_seen: float | None = None
        self.frames = 0

    def update(self, selection: Selection, now: float) -> bool:
        if len(selection.eligible_faces) != 1:
            self.reset()
            return False
        box = selection.eligible_faces[0].box
        if (self.box is None or self.last_seen is None or
                now - self.last_seen > self.config.max_detection_gap_seconds or
                self.box.iou(box) < self.config.stable_iou):
            self.since, self.frames = now, 0
        self.box, self.last_seen = box, now
        self.frames += 1
        return self.frames >= self.config.stable_min_frames and now - self.since >= self.config.stable_seconds


class AuthStateMachine:
    """All calls belong to the UI/controller thread. Times are monotonic seconds."""

    def __init__(self, config: PrototypeConfig):
        self.config = config
        self.gate = StableFaceGate(config)
        self.state = State.IDLE
        self.active_request: AuthRequest | None = None
        self.deadline: float | None = None
        self.cooldown_until: float | None = None
        self.last_result: AuthResult | None = None
        self.needs_leave = False
        self.empty_since: float | None = None
        self.last_observation: float | None = None
        self.closed = False

    def tick(self, now: float):
        if self.closed:
            return
        if self.state == State.VERIFYING and now >= self.deadline:
            self._finish(AuthResult(self.active_request.request_id, AuthOutcome.TIMEOUT), now)
        if self.state == State.COOLDOWN and now >= self.cooldown_until and not self.needs_leave:
            self.state = State.IDLE
            self.gate.reset()
        if self.state == State.READY and now - self.gate.last_seen > self.config.max_detection_gap_seconds:
            self.invalidate_observation()

    def observe(self, selection: Selection, now: float):
        self.tick(now)
        if self.closed:
            return
        if self.needs_leave:
            if (self.last_observation is None or now - self.last_observation > self.config.max_detection_gap_seconds
                    or selection.faces_in_roi > 0):
                self.empty_since = None
            if selection.faces_in_roi == 0:
                if self.empty_since is None:
                    self.empty_since = now
                if now - self.empty_since >= self.config.leave_seconds:
                    self.needs_leave = False
                    self.empty_since = None
            self.last_observation = now
        if self.state in (State.VERIFYING, State.COOLDOWN):
            self.gate.reset()
            return
        self.state = State.READY if self.gate.update(selection, now) else State.IDLE

    def invalidate_observation(self):
        """Camera/detector failure is NOT evidence that a person left the ROI."""
        self.gate.reset()
        self.empty_since = self.last_observation = None
        if self.state == State.READY:
            self.state = State.IDLE

    def start_request(self, now: float) -> AuthRequest | None:
        self.tick(now)
        if self.closed or self.state != State.READY or self.needs_leave:
            return None
        request = AuthRequest(str(uuid4()), self.config.kiosk_id, MockCapturePayload())
        self.active_request = request
        self.deadline = now + self.config.auth_timeout_seconds
        self.state = State.VERIFYING
        self.gate.reset()
        return request

    def receive(self, result: AuthResult, now: float) -> bool:
        # At the deadline a timeout wins, even if a callback was already queued.
        self.tick(now)
        if self.closed or self.state != State.VERIFYING or result.request_id != self.active_request.request_id:
            return False
        self._finish(result, now)
        return True

    def _finish(self, result: AuthResult, now: float):
        self.last_result = result
        self.active_request = None
        self.deadline = None
        self.state = State.COOLDOWN
        self.cooldown_until = now + self.config.cooldown_seconds
        self.needs_leave = result.outcome == AuthOutcome.SUCCESS
        self.empty_since = self.last_observation = None
        self.gate.reset()

    def shutdown(self):
        self.closed = True
        self.active_request = None
        self.deadline = None
        self.invalidate_observation()
