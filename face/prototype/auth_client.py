"""Mock transport only: no HTTP, images, embeddings, or AttendanceRecord writes."""
from math import isfinite
from queue import Empty, Queue
from threading import Event, Lock, Thread
from typing import Protocol
from .types import AuthOutcome, AuthRequest, AuthResult


class AuthClient(Protocol):
    def authenticate(self, request: AuthRequest, cancel: Event) -> AuthResult: ...


class MockAuthClient:
    def __init__(self, outcome: AuthOutcome = AuthOutcome.SUCCESS, delay_seconds: float = 0.5):
        if not isfinite(delay_seconds) or delay_seconds < 0:
            raise ValueError("Mock delay must be finite and nonnegative")
        self.outcome, self.delay_seconds = outcome, delay_seconds

    def authenticate(self, request: AuthRequest, cancel: Event) -> AuthResult:
        if self.outcome == AuthOutcome.TIMEOUT:
            cancel.wait()  # Simulate no server response until local cancellation.
        else:
            cancel.wait(self.delay_seconds)
        return AuthResult(request.request_id, self.outcome)


class SingleFlightWorker:
    """No request queue. A timed-out, uncooperative transport retains its slot.

    Python cannot kill a thread safely. A future real transport must implement
    deadlines/cancellation; cancellation never means it is safe to overlap it.
    """

    def __init__(self, client: AuthClient):
        self.client = client
        self.results: Queue[AuthResult] = Queue(maxsize=1)
        self._lock = Lock()
        self._thread: Thread | None = None
        self._cancel = Event()
        self._busy = False
        self._closed = False

    @property
    def busy(self) -> bool:
        with self._lock:
            return self._busy

    def submit(self, request: AuthRequest) -> bool:
        with self._lock:
            if self._closed or self._busy or not self.results.empty():
                return False
            self._busy = True
            self._cancel = Event()
            self._thread = Thread(target=self._run, args=(request, self._cancel), daemon=True, name="fitcenter-mock-auth")
            self._thread.start()
            return True

    def _run(self, request: AuthRequest, cancel: Event):
        try:
            result = self.client.authenticate(request, cancel)
        except Exception:
            # Do not print a future transport's secrets or payload in errors.
            result = AuthResult(request.request_id, AuthOutcome.SERVICE_ERROR)
        with self._lock:
            if not self._closed:
                self.results.put_nowait(result)
            self._busy = False

    def cancel(self):
        self._cancel.set()

    def drain(self) -> list[AuthResult]:
        try:
            return [self.results.get_nowait()]
        except Empty:
            return []

    def shutdown(self):
        with self._lock:
            self._closed = True
            self._cancel.set()
            thread = self._thread
        if thread is not None:
            thread.join(timeout=0.3)
        self.drain()
