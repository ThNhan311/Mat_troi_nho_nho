from threading import Event
import pytest
from face.prototype.auth_client import MockAuthClient, SingleFlightWorker
from face.prototype.controller import PrototypeController
from face.prototype.state_machine import State
from face.prototype.types import AuthOutcome, AuthRequest, AuthResult, MockCapturePayload


def ready_controller(controller, single, start=0.0):
    for i in range(7):
        controller.update(start + i * .125, single)


def join_worker(worker):
    # Test synchronization only; the application never joins during preview.
    worker._thread.join(timeout=2)
    assert not worker.busy


@pytest.mark.parametrize("outcome", [AuthOutcome.SUCCESS, AuthOutcome.REJECTED, AuthOutcome.SERVICE_ERROR])
def test_T15_mock_outcomes_on_worker(config, single, outcome):
    worker = SingleFlightWorker(MockAuthClient(outcome, 0))
    controller = PrototypeController(config, worker)
    try:
        ready_controller(controller, single)
        join_worker(worker)
        controller.update(1)
        assert controller.machine.state == State.COOLDOWN
        assert controller.machine.last_result.outcome == outcome
        assert controller.requests_sent == 1
    finally:
        controller.shutdown()


def test_T09_preview_observations_continue_while_worker_blocked(config, single, empty):
    started, release = Event(), Event()

    class BlockingClient:
        def authenticate(self, request, cancel):
            started.set()
            assert release.wait(2)
            return AuthResult(request.request_id, AuthOutcome.SUCCESS)

    worker = SingleFlightWorker(BlockingClient())
    controller = PrototypeController(config, worker)
    try:
        ready_controller(controller, single)
        assert started.wait(1)
        for i in range(1, 25):
            controller.update(.75 + i * .125, single if i % 2 else empty)
        assert worker.busy
        assert controller.requests_sent == 1
        assert controller.machine.state == State.VERIFYING
        assert not worker.submit(AuthRequest("extra", "kiosk", MockCapturePayload()))
    finally:
        release.set()
        controller.shutdown()


def test_T10_timeout_keeps_slot_until_old_transport_exits(config, single):
    release = Event()

    class IgnoresCancel:
        def authenticate(self, request, cancel):
            assert release.wait(3)
            return AuthResult(request.request_id, AuthOutcome.SUCCESS)

    worker = SingleFlightWorker(IgnoresCancel())
    controller = PrototypeController(config, worker)
    try:
        ready_controller(controller, single)
        controller.update(7.75)
        assert controller.machine.last_result.outcome == AuthOutcome.TIMEOUT
        ready_controller(controller, single, 13)
        assert worker.busy
        assert controller.requests_sent == 1  # Cooldown ended, transport still owns slot.
        release.set()
        join_worker(worker)
        controller.update(13.8)  # Late SUCCESS cannot change the timeout outcome.
        assert controller.machine.last_result.outcome == AuthOutcome.TIMEOUT
        assert not controller.machine.needs_leave
    finally:
        release.set()
        controller.shutdown()


def test_T10_mock_timeout_cancellable(config, single):
    worker = SingleFlightWorker(MockAuthClient(AuthOutcome.TIMEOUT))
    controller = PrototypeController(config, worker)
    try:
        ready_controller(controller, single)
        controller.update(7.75)
        join_worker(worker)
        controller.update(8)
        assert controller.machine.last_result.outcome == AuthOutcome.TIMEOUT
        assert controller.machine.state == State.COOLDOWN
    finally:
        controller.shutdown()


def test_T15_worker_exception_recovers(config, single):
    class ExplodingClient:
        def authenticate(self, request, cancel):
            raise ConnectionError("simulated network failure")

    worker = SingleFlightWorker(ExplodingClient())
    controller = PrototypeController(config, worker)
    try:
        ready_controller(controller, single)
        join_worker(worker)
        controller.update(1)
        assert controller.machine.last_result.outcome == AuthOutcome.SERVICE_ERROR
        ready_controller(controller, single, 6)
        assert controller.requests_sent == 2
    finally:
        controller.shutdown()


def test_shutdown_ignores_worker_and_future_observations(config, single):
    worker = SingleFlightWorker(MockAuthClient(AuthOutcome.TIMEOUT))
    controller = PrototypeController(config, worker)
    ready_controller(controller, single)
    controller.shutdown()
    assert not worker.busy
    ready_controller(controller, single, 20)
    assert controller.requests_sent == 1
    assert controller.machine.last_result is None
    assert not worker.drain()
