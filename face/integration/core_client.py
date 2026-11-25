"""SIMULATED identity bridge for the existing SingleFlightWorker. No camera/biometric payloads.

Install alongside the pinned Face prototype; never place kiosk credentials in a Flutter/Web build.
"""
import http.client
import json
import os
import re
from datetime import datetime
from threading import Event, Lock
from urllib.parse import urlsplit
from uuid import UUID

from face.prototype.types import AuthOutcome, AuthRequest, AuthResult


def _uuid(value):
    if not isinstance(value, str) or str(UUID(value)) != value:
        raise ValueError("UUID required")
    return value


def _utc(value):
    if not isinstance(value, str) or not value.endswith("Z"):
        raise ValueError("UTC timestamp required")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


class CoreCheckinClient:
    """No retry, one operation at a time. A blocked transport retains its slot after local timeout."""

    def __init__(self, base_url, kiosk_id, token, capture_ref, timeout=5.0, *, transport=None):
        if os.environ.get("FITCENTER_CORE_CHECKIN_TEST_ADAPTER_ENABLED") != "true":
            raise ValueError("Simulated Core adapter is disabled")
        target = urlsplit(base_url)
        if (target.scheme != "http" or target.hostname not in ("127.0.0.1", "localhost")
                or not target.port or target.username or target.password or target.query or target.fragment
                or target.path.rstrip("/") != "/api/v1"):
            raise ValueError("Explicit loopback test backend required")
        if not re.fullmatch(r"[a-z0-9][a-z0-9_-]{0,49}", kiosk_id):
            raise ValueError("Registered kiosk ID required")
        if not re.fullmatch(r"[A-Za-z0-9_-]{43,128}", token) or not 0 < timeout <= 7:
            raise ValueError("Private kiosk credential and bounded timeout required")
        self.target, self.kiosk_id, self._token = target, kiosk_id, token
        self.capture_ref, self.timeout = _uuid(capture_ref), timeout
        self._transport = transport or self._http
        self._lock = Lock()

    def _http(self, payload, headers):
        connection = http.client.HTTPConnection(self.target.hostname, self.target.port, timeout=self.timeout)
        try:
            connection.request("POST", self.target.path.rstrip("/") + "/check-ins/face", body=payload, headers=headers)
            response = connection.getresponse()
            content = response.read(65537)
            if len(content) > 65536:
                raise ValueError("Oversized response")
            return response.status, content
        finally:
            connection.close()

    @staticmethod
    def _result(request, outcome, member=None):
        return AuthResult(request.request_id, outcome, member_id=member)

    def authenticate(self, request: AuthRequest, cancel: Event) -> AuthResult:
        if cancel.is_set():
            return self._result(request, AuthOutcome.TIMEOUT)
        if request.kiosk_id != self.kiosk_id or not self._lock.acquire(blocking=False):
            return self._result(request, AuthOutcome.SERVICE_ERROR)
        try:
            _uuid(request.request_id)
            payload = json.dumps({"requestId": request.request_id, "captureRef": self.capture_ref}).encode("utf-8")
            headers = {"Content-Type": "application/json", "Accept": "application/json",
                       "X-Kiosk-Id": self.kiosk_id, "X-Kiosk-Token": self._token}
            status, raw = self._transport(payload, headers)
            if cancel.is_set():
                return self._result(request, AuthOutcome.TIMEOUT)
            if status != 200:
                return self._result(request, AuthOutcome.SERVICE_ERROR)
            data = json.loads(raw)
            if (data.get("requestId") != request.request_id or data.get("simulatedIdentity") is not True
                    or data.get("verificationMode") != "SIMULATED_TEST"):
                raise ValueError("Unverified Core response")
            for field in ("recognized", "accessAllowed", "attendanceCreated", "replayed"):
                if type(data.get(field)) is not bool:
                    raise ValueError("Boolean contract required")
            _utc(data["checkedAt"])
            if data["attendanceCreated"] and (data["replayed"] or data.get("reason") != "CHECKED_IN"):
                raise ValueError("Inconsistent attendance creation flags")
            if data["accessAllowed"]:
                if not data["recognized"] or data.get("reason") not in ("CHECKED_IN", "DUPLICATE_WINDOW", "REQUEST_REPLAY"):
                    raise ValueError("Admission requires server eligibility")
                _uuid(data["memberId"])
                _uuid(data["attendanceId"])
                _utc(data["checkedInAt"])
                return self._result(request, AuthOutcome.SUCCESS, data["memberId"])
            if data["attendanceCreated"]:
                raise ValueError("Rejected admission cannot create attendance")
            return self._result(request, AuthOutcome.REJECTED)
        except (TimeoutError, http.client.RemoteDisconnected):
            return self._result(request, AuthOutcome.TIMEOUT)
        except Exception:
            # Do not print transport errors: they can contain private headers or capture references.
            return self._result(request, AuthOutcome.SERVICE_ERROR)
        finally:
            self._lock.release()
