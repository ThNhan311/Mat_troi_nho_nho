"""Synthetic contracts against the pinned Face prototype. No model, frames, or real person."""
import importlib.util
import json
import os
from pathlib import Path
from threading import Event, Thread
from time import monotonic, sleep
from uuid import uuid4

import pytest
from face.prototype.auth_client import SingleFlightWorker
from face.prototype.config import PrototypeConfig
from face.prototype.controller import PrototypeController
from face.prototype.state_machine import State
from face.prototype.types import AuthOutcome, AuthRequest, Box, FaceCandidate, MockCapturePayload, Selection, SelectionStatus

spec = importlib.util.spec_from_file_location("f01_core_addon", Path(__file__).parents[1] / "core_client.py")
addon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(addon)
TOKEN = "synthetic_test_only_" + "x" * 32
CAPTURE = str(uuid4())
MEMBER = str(uuid4())
ATTENDANCE = str(uuid4())


@pytest.fixture(autouse=True)
def opt_in(monkeypatch):
    monkeypatch.setenv("FITCENTER_CORE_CHECKIN_TEST_ADAPTER_ENABLED", "true")


def request(kiosk="test-kiosk-a"):
    return AuthRequest(str(uuid4()), kiosk, MockCapturePayload())


def response(rid, **changes):
    body = {"requestId": rid, "recognized": True, "accessAllowed": True,
            "attendanceCreated": True, "memberId": MEMBER, "attendanceId": ATTENDANCE,
            "checkedAt": "2028-02-29T00:00:00Z", "checkedInAt": "2028-02-29T00:00:00Z",
            "reason": "CHECKED_IN", "replayed": False, "simulatedIdentity": True,
            "verificationMode": "SIMULATED_TEST"}
    body.update(changes)
    return 200, json.dumps(body).encode()


def client(transport):
    return addon.CoreCheckinClient("http://127.0.0.1:18085/api/v1", "test-kiosk-a", TOKEN, CAPTURE, transport=transport)


def wait_until(condition):
    deadline = monotonic() + 2
    while monotonic() < deadline:
        if condition():
            return
        sleep(.005)
    assert condition()


def test_default_opt_out(monkeypatch):
    monkeypatch.delenv("FITCENTER_CORE_CHECKIN_TEST_ADAPTER_ENABLED")
    with pytest.raises(ValueError):
        client(lambda *_: None)


@pytest.mark.parametrize("url", ["http://example.invalid/api/v1", "https://127.0.0.1:18085/api/v1", "http://127.0.0.1:18085/api/v1?x=1", "http://x:y@127.0.0.1:18085/api/v1"])
def test_only_explicit_loopback_rehearsal(url):
    with pytest.raises(ValueError):
        addon.CoreCheckinClient(url, "test-kiosk-a", TOKEN, CAPTURE)


def test_sends_opaque_capture_not_member_or_image_and_does_not_use_client_clock():
    calls = []
    def transport(payload, headers):
        data = json.loads(payload)
        calls.append(data)
        assert set(data) == {"requestId", "captureRef"}
        assert data["captureRef"] == CAPTURE
        assert headers["X-Kiosk-Id"] == "test-kiosk-a"
        assert headers["X-Kiosk-Token"] == TOKEN
        return response(data["requestId"])
    r = request()
    result = client(transport).authenticate(r, Event())
    assert result.outcome == AuthOutcome.SUCCESS and result.member_id == MEMBER
    assert len(calls) == 1


@pytest.mark.parametrize("change", [{"requestId": str(uuid4())}, {"simulatedIdentity": False}, {"verificationMode": "FACE_VERIFIED"}, {"recognized": False}, {"accessAllowed": 1}, {"checkedAt": "badZ"}, {"attendanceId": None}, {"memberId": "users-not-profile-id"}, {"reason": "LOCAL_GUESS"}, {"replayed": True}, {"reason": "DUPLICATE_WINDOW"}])
def test_malformed_200_never_becomes_success(change):
    r = request()
    assert client(lambda *_: response(r.request_id, **change)).authenticate(r, Event()).outcome == AuthOutcome.SERVICE_ERROR


@pytest.mark.parametrize("reason", ["NO_MATCH", "UNKNOWN_IDENTITY", "MEMBERSHIP_INACTIVE", "ACCOUNT_INACTIVE", "PAID_COVERAGE_MISSING"])
def test_server_denial_not_http200_is_the_decision(reason):
    r = request()
    result = client(lambda *_: response(r.request_id, accessAllowed=False, attendanceCreated=False,
                                       attendanceId=None, checkedInAt=None, reason=reason)).authenticate(r, Event())
    assert result.outcome == AuthOutcome.REJECTED


def test_network_failure_does_not_retry():
    calls = []
    def transport(*_):
        calls.append(1)
        raise OSError("synthetic offline")
    assert client(transport).authenticate(request(), Event()).outcome == AuthOutcome.SERVICE_ERROR
    assert calls == [1]


def test_cancel_before_dispatch_and_late_response_are_discarded():
    cancelled = Event()
    cancelled.set()
    calls = []
    c = client(lambda *_: calls.append(1))
    assert c.authenticate(request(), cancelled).outcome == AuthOutcome.TIMEOUT
    assert not calls
    r = request()
    def transport(*_):
        cancelled.set()
        return response(r.request_id)
    cancelled.clear()
    assert client(transport).authenticate(r, cancelled).outcome == AuthOutcome.TIMEOUT


def test_adapter_itself_has_single_inflight_even_without_worker():
    entered, release = Event(), Event()
    r = request()
    calls = []
    def transport(*_):
        calls.append(1)
        entered.set()
        assert release.wait(2)
        return response(r.request_id)
    c = client(transport)
    result = []
    thread = Thread(target=lambda: result.append(c.authenticate(r, Event())))
    thread.start()
    assert entered.wait(1)
    assert c.authenticate(request(), Event()).outcome == AuthOutcome.SERVICE_ERROR
    release.set()
    thread.join(2)
    assert len(calls) == 1 and result[0].outcome == AuthOutcome.SUCCESS


def selection(present=True):
    faces = (FaceCandidate(Box(100, 100, 100, 100), 100, 100),) if present else ()
    return Selection(faces, (), SelectionStatus.READY if present else SelectionStatus.NO_ELIGIBLE_FACE, len(faces))


def start(controller):
    for t in (0, .3, .6, .9):
        controller.update(t, selection())


def test_existing_prototype_keeps_slot_after_timeout_until_transport_finishes_and_drops_late_result():
    entered, release = Event(), Event()
    def transport(payload, _):
        entered.set()
        assert release.wait(2)
        return response(json.loads(payload)["requestId"])
    worker = SingleFlightWorker(client(transport))
    controller = PrototypeController(PrototypeConfig(kiosk_id="test-kiosk-a"), worker)
    try:
        start(controller)
        assert entered.wait(1) and controller.machine.state == State.VERIFYING
        controller.update(8)
        assert controller.machine.last_result.outcome == AuthOutcome.TIMEOUT
        for t in (14, 14.3, 14.6, 14.9):
            controller.update(t, selection())
        assert worker.busy and controller.requests_sent == 1
        release.set()
        wait_until(lambda: not worker.busy)
        controller.update(15)
        assert controller.requests_sent == 1 and controller.machine.last_result.outcome == AuthOutcome.TIMEOUT
    finally:
        release.set()
        controller.shutdown()


def test_existing_prototype_five_second_cooldown_and_leave_gate_remain_intact():
    def transport(payload, _):
        return response(json.loads(payload)["requestId"])
    worker = SingleFlightWorker(client(transport))
    controller = PrototypeController(PrototypeConfig(kiosk_id="test-kiosk-a"), worker)
    try:
        start(controller)
        wait_until(lambda: not worker.busy)
        controller.update(1)
        assert controller.machine.state == State.COOLDOWN and controller.machine.cooldown_until == 6
        for t in (1.2, 1.5, 1.8):
            controller.update(t, selection(False))
        controller.update(5.999)
        assert controller.machine.state == State.COOLDOWN
        controller.update(6)
        assert controller.machine.state == State.IDLE and controller.requests_sent == 1
    finally:
        controller.shutdown()
