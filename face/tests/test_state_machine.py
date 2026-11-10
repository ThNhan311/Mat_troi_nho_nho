from dataclasses import replace
import pytest
from face.prototype.state_machine import AuthStateMachine, State
from face.prototype.types import AuthOutcome, AuthResult, Box, SelectionStatus
from .conftest import make_ready


def test_T02_ready_only_after_stability(config, single):
    m = AuthStateMachine(config)
    for t in (0, .125, .25, .375, .5, .625):
        m.observe(single, t)
        assert m.state == State.IDLE
        assert m.start_request(t) is None
    m.observe(single, .75)
    assert m.state == State.READY
    assert m.start_request(.75) is not None
    assert m.state == State.VERIFYING


def test_T05_two_eligible_no_auth(config, selector, front):
    second = replace(front, box=Box(370, 140, 120, 200))
    selection = selector.select(640, 480, [front, second])
    assert selection.status == SelectionStatus.MULTIPLE_ELIGIBLE_FACES
    m = AuthStateMachine(config)
    for t in (0, .2, .4, .6, .8, 1.0):
        m.observe(selection, t)
        assert m.start_request(t) is None


def test_T08_flicker_no_auth(config, single, empty):
    m = AuthStateMachine(config)
    for i in range(30):
        m.observe(single if i % 3 else empty, i * .125)
        assert m.start_request(i * .125) is None


def test_T09_verifying_single_flight(config, single, selector, front):
    m = AuthStateMachine(config)
    t = make_ready(m, single)
    request = m.start_request(t)
    multiple = selector.select(640, 480, [front, front])
    for i in range(1, 20):
        m.observe(multiple if i % 2 else single, t + i * .125)
        assert m.state == State.VERIFYING
        assert m.start_request(t + i * .125) is None
        assert m.active_request == request


def test_T10_timeout_stale_ignored(config, single):
    m = AuthStateMachine(config)
    t = make_ready(m, single)
    request = m.start_request(t)
    m.tick(t + config.auth_timeout_seconds)
    assert m.state == State.COOLDOWN
    assert m.last_result.outcome == AuthOutcome.TIMEOUT
    assert not m.receive(AuthResult(request.request_id, AuthOutcome.SUCCESS), t + 8)
    assert m.last_result.outcome == AuthOutcome.TIMEOUT
    t2 = t + 13
    make_ready(m, single, t2)
    new = m.start_request(t2 + .75)
    assert new.request_id != request.request_id
    assert not m.receive(AuthResult(request.request_id, AuthOutcome.SUCCESS), t2 + .8)
    assert m.active_request == new


def test_T11_success_face_stays_no_repeat(config, single):
    m = AuthStateMachine(config)
    t = make_ready(m, single)
    request = m.start_request(t)
    assert m.receive(AuthResult(request.request_id, AuthOutcome.SUCCESS), 1)
    for i in range(1, 200):
        m.observe(single, 1 + i * .125)
        assert m.start_request(1 + i * .125) is None
    assert m.needs_leave


def test_T12_leaves_then_returns_can_auth(config, single, empty):
    m = AuthStateMachine(config)
    make_ready(m, single)
    request = m.start_request(.75)
    m.receive(AuthResult(request.request_id, AuthOutcome.SUCCESS), 1)
    for t in (1.125, 1.25, 1.375, 1.5, 1.625):
        m.observe(empty, t)
    assert not m.needs_leave
    m.tick(5.99)
    assert m.state == State.COOLDOWN
    make_ready(m, single, 6)
    new = m.start_request(6.75)
    assert new is not None and new.request_id != request.request_id


def test_T14_duplicate_callback_only_once(config, single):
    m = AuthStateMachine(config)
    make_ready(m, single)
    request = m.start_request(.75)
    result = AuthResult(request.request_id, AuthOutcome.SUCCESS)
    assert m.receive(result, 1)
    until = m.cooldown_until
    assert not m.receive(result, 2)
    assert m.cooldown_until == until


@pytest.mark.parametrize("outcome", [AuthOutcome.REJECTED, AuthOutcome.SERVICE_ERROR])
def test_T15_error_recovery(config, single, outcome):
    m = AuthStateMachine(config)
    make_ready(m, single)
    request = m.start_request(.75)
    assert m.receive(AuthResult(request.request_id, outcome), 1)
    assert m.state == State.COOLDOWN
    make_ready(m, single, 6)
    assert m.start_request(6.75) is not None


def test_T16_timing_from_config(config, single):
    m = AuthStateMachine(replace(config, stable_seconds=1.0, cooldown_seconds=2, auth_timeout_seconds=3))
    make_ready(m, single)
    assert m.state == State.IDLE
    m.observe(single, .875)
    m.observe(single, 1)
    request = m.start_request(1)
    assert request is not None
    m.tick(4)
    assert m.state == State.COOLDOWN
    m.tick(6)
    assert m.state == State.IDLE


def test_quality_loss_or_camera_disconnect_does_not_rearm(config, single, empty, selector, front):
    m = AuthStateMachine(config)
    make_ready(m, single)
    request = m.start_request(.75)
    m.receive(AuthResult(request.request_id, AuthOutcome.SUCCESS), 1)
    blurry = selector.select(640, 480, [replace(front, blur_variance=0)])
    for i in range(1, 20):
        m.observe(blurry, 1 + i * .125)
    assert m.needs_leave
    m.observe(empty, 4)
    m.invalidate_observation()
    m.observe(empty, 10)
    assert m.needs_leave  # A disconnected camera is not an empty ROI.


def test_gap_and_box_jump_reset_stability(config, single, selector, front):
    m = AuthStateMachine(config)
    m.observe(single, 0)
    m.observe(single, 1)
    assert m.state == State.IDLE
    make_ready(m, single, 2)
    moved = selector.select(640, 480, [replace(front, box=Box(350, 100, 130, 150))])
    m.observe(moved, 2.875)
    assert m.state == State.IDLE
    make_ready(m, single, 3)
    assert m.state == State.READY
    assert m.start_request(5) is None  # READY cannot survive stale observations.


def test_deadline_wins_race_and_shutdown_ignores_result(config, single):
    m = AuthStateMachine(config)
    make_ready(m, single)
    request = m.start_request(.75)
    assert not m.receive(AuthResult(request.request_id, AuthOutcome.SUCCESS), 7.75)
    assert m.last_result.outcome == AuthOutcome.TIMEOUT
    m.shutdown()
    assert not m.receive(AuthResult(request.request_id, AuthOutcome.SUCCESS), 8)
    assert m.start_request(20) is None
