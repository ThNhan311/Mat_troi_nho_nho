"""F01 Core end-to-end: simulated identities, actual HTTP/JDBC database. No camera or Face model."""
from pathlib import Path
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from threading import Event
from time import monotonic, sleep
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

from face.prototype.auth_client import SingleFlightWorker
from face.prototype.types import AuthOutcome, AuthRequest, MockCapturePayload

repo = Path(__file__).resolve().parents[2]
private = Path(sys.argv[1]).resolve()
assert private.is_relative_to(Path(os.environ["LOCALAPPDATA"], "Temp").resolve())
assert os.environ.get("PGPASSWORD")
assert os.environ.get("FITCENTER_CORE_CHECKIN_TEST_ADAPTER_ENABLED") == "true"
base = "http://127.0.0.1:18085/api/v1"
resource = json.loads((private / "account-resource.json").read_text())
run = json.loads((private / "current-run.json").read_text())
config = json.loads((private / "checkin-demo-config.json").read_text())
props = {}
for line in (private / "demo-fixture.properties").read_text().splitlines():
    if "=" in line and not line.startswith("#"):
        key, value = line.split("=", 1)
        props[key] = re.sub(r"\\([:=!# ])", r"\1", value)
assert props["historyDatabase"] == run["history"]

def docker(*args, input=None):
    return subprocess.run(["docker", "--context", "desktop-linux", *args], input=input,
                          text=True, encoding="utf-8", capture_output=True, check=True).stdout.strip()

instance = json.loads(docker("inspect", resource["container"]))[0]
assert instance["Id"] == resource["containerId"]
assert instance["Config"]["Labels"]["fitcenter.task"] == "account-20261123"
assert next(x["Name"] for x in instance["Mounts"] if x["Destination"] == "/var/lib/postgresql/data") == "fitcenter_account_20261123_data"
assert instance["HostConfig"]["PortBindings"]["5432/tcp"] == [{"HostIp": "127.0.0.1", "HostPort": "15441"}]
assert instance["State"]["Running"]
assert re.fullmatch(r"fitcenter_account_[a-f0-9]{12}_history_test", run["history"])

def sql(query):
    return docker("exec", "-i", "-e", "PGPASSWORD", instance["Id"], "psql", "-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1", "-h", "127.0.0.1", "-U", "fitcenter_account_app", "-d", run["history"], input=query + "\n")

assert sql("SELECT current_database()||'|'||current_user||'|'||(rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)::text||'|'||(SELECT string_agg(version,',' ORDER BY installed_rank) FROM flyway_schema_history WHERE success) FROM pg_roles WHERE rolname=current_user") == run["history"] + "|fitcenter_account_app|false|1,2,3,4,5,6,8,9,10,11,12"

def literal(value):
    assert re.fullmatch(r"[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}", value)
    return "'" + value + "'::uuid"

registry = {"run": run["nonce"], "requests": [], "intentEmails": [], "created": [], "plans": [], "intents": []}
registry_file = private / "checkin-e2e-registry.json"
with registry_file.open("x", encoding="utf-8") as out:
    json.dump(registry, out)
result = {"at": datetime.now(timezone.utc).isoformat(), "base": "4af8bb8a51908cc46643fba009659c3903c1dba3", "identityMode": "SIMULATED_TEST", "http": [], "adapter": [], "db": [], "sourceHashes": {}, "failed": 0, "skipped": 0,
          "scenario": "ACTIVE accounts/facial references are synthetic fixtures, not actual activation/enrollment. Plan and counter Membership use real API; addon/SingleFlightWorker calls real Core; no camera/recognition/liveness."}

def save_registry():
    registry_file.write_text(json.dumps(registry, indent=2), encoding="utf-8")


def intent(label):
    assert label not in registry["intents"], "Do not blindly repeat a write"
    registry["intents"].append(label)
    save_registry()


def api(method, path, body=None, token=None, status=200, headers=None):
    all_headers = {"Content-Type": "application/json", **(headers or {})}
    if token:
        all_headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(base + path, data=json.dumps(body).encode() if body is not None else None,
                                     headers=all_headers, method=method)
    try:
        response = urllib.request.urlopen(request, timeout=15)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        code = response.status
        data = json.loads(response.read())
    assert code == status, "Unexpected HTTP status for " + method + " " + path
    result["http"].append({"method": method, "path": path, "status": code})
    return data


def login(actor):
    return api("POST", "/auth/login", {"email": props[actor + ".email"], "password": props[actor + ".password"]})["accessToken"]


def business():
    tables = json.loads(sql("SELECT json_agg(tablename ORDER BY tablename) FROM pg_tables WHERE schemaname='public' AND tablename NOT IN ('flyway_schema_history','attendance_records','checkin_requests')"))
    digest = {}
    for table in tables:
        assert re.fullmatch("[a-z_]+", table)
        rows = sql("SELECT coalesce(json_agg(x),'[]')::text FROM (SELECT md5(to_jsonb(t)::text) row_hash FROM " + table + " t ORDER BY to_jsonb(t)::text)x")
        digest[table] = hashlib.sha256(rows.encode()).hexdigest()
    return digest


spec = importlib.util.spec_from_file_location("f01_e2e_addon", repo / "face/integration/core_client.py")
addon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(addon)
keys = {k["id"]: k["token"] for k in config["kiosks"]}


def scan(actor, kiosk="test-kiosk-a", request_id=None, capture=None):
    rid = request_id or str(uuid4())
    if rid not in registry["requests"]:
        registry["requests"].append(rid)
        save_registry()
    client = addon.CoreCheckinClient(base, kiosk, keys[kiosk], capture or props[actor + ".captureRef"])
    worker = SingleFlightWorker(client)
    try:
        req = AuthRequest(rid, kiosk, MockCapturePayload())
        assert worker.submit(req)
        assert not worker.submit(AuthRequest(str(uuid4()), kiosk, MockCapturePayload()))
        until = monotonic() + 10
        while worker.busy and monotonic() < until:
            sleep(.01)
        assert not worker.busy
        responses = worker.drain()
        assert len(responses) == 1
        result["adapter"].append({"requestId": rid, "outcome": responses[0].outcome.value, "mode": "SIMULATED_TEST"})
        return rid, responses[0]
    finally:
        worker.shutdown()


phase = "bootstrap"
try:
    assert sql("SELECT count(*) FROM attendance_records") == "0"
    assert sql("SELECT count(*) FROM memberships") == "0"
    admin, member_a, member_b = login("admin"), login("memberA"), login("memberB")
    intent("create-plan")
    plan = api("POST", "/admin/membership-plans", {"name": "Synthetic F01 Core plan", "durationDays": 2, "price": 0}, admin, 201)
    registry["plans"].append(plan)
    save_registry()
    memberships = {}
    for actor in ("memberA", "memberB"):
        intent("counter-" + actor)
        key, receipt = str(uuid4()), "F01-E2E-" + str(uuid4())
        memberships[actor] = api("POST", "/admin/members/" + props[actor + ".memberId"] + "/activate-membership",
                                 {"planId": plan["id"], "amountCollected": 0, "receiptRef": receipt}, admin, 201,
                                 {"Idempotency-Key": key})
    before = business()
    result["db"].append("Plan and counter Memberships/payments created through actual API; account/facial references remain synthetic fixtures")
    phase = "first-checkin"
    first_id, first = scan("memberA")
    assert first.outcome == AuthOutcome.SUCCESS and first.member_id == props["memberA.memberId"]
    assert first.member_id != props["memberA.userId"]
    a = literal(props["memberA.memberId"])
    assert sql("SELECT count(*) FROM attendance_records WHERE member_id=" + a) == "1"
    attendance_id = sql("SELECT id::text FROM attendance_records WHERE member_id=" + a)
    assert sql("SELECT attendance_created::text||'|'||identity_mode FROM checkin_requests WHERE request_id=" + literal(first_id)) == "true|SIMULATED_TEST"
    result["db"].append("Real adapter HTTP creates exactly one Attendance with members.id and explicit simulated identity ledger")
    phase = "duplicate-replay"
    _, duplicate = scan("memberA", "test-kiosk-b")
    assert duplicate.outcome == AuthOutcome.SUCCESS
    assert sql("SELECT count(*) FROM attendance_records WHERE member_id=" + a) == "1"
    assert sql("SELECT count(*) FROM checkin_requests WHERE member_id=" + a + " AND decision='DUPLICATE_WINDOW' AND NOT attendance_created") == "1"
    ledger = sql("SELECT md5(to_jsonb(r)::text) FROM checkin_requests r WHERE request_id=" + literal(first_id))
    _, replay = scan("memberA", request_id=first_id)
    assert replay.outcome == AuthOutcome.SUCCESS
    assert sql("SELECT md5(to_jsonb(r)::text) FROM checkin_requests r WHERE request_id=" + literal(first_id)) == ledger
    assert sql("SELECT count(*) FROM attendance_records WHERE member_id=" + a) == "1"
    result["db"].append("Second kiosk rolling duplicate and exact replay create no extra Attendance or ledger metadata mutation")
    phase = "rejections"
    _, rejected = scan("memberA", capture=props["noMatch.captureRef"])
    assert rejected.outcome == AuthOutcome.REJECTED
    _, unknown = scan("memberA", capture=str(uuid4()))
    assert unknown.outcome == AuthOutcome.REJECTED
    for token in (None, member_a, admin):
        error = api("POST", "/check-ins/face", {"requestId": str(uuid4()), "captureRef": props["memberA.captureRef"]}, token, 401)
        assert error["error"]["code"] == "ERR_UNAUTHORIZED"
    conflict = api("POST", "/check-ins/face", {"requestId": first_id, "captureRef": props["memberB.captureRef"]}, status=409,
                   headers={"X-Kiosk-Id": "test-kiosk-a", "X-Kiosk-Token": keys["test-kiosk-a"]})
    assert conflict["error"]["code"] == "ERR_CHECKIN_REQUEST_REUSED"
    assert sql("SELECT count(*) FROM attendance_records") == "1"
    result["db"].append("No-match/unknown, public/user/admin claims and reused-ID different payload do not create Attendance")
    phase = "owner-history"
    _, other = scan("memberB", "test-kiosk-b")
    assert other.outcome == AuthOutcome.SUCCESS
    dates = "?" + urllib.parse.urlencode({"from": (datetime.now(timezone.utc) - timedelta(days=1)).isoformat(), "to": (datetime.now(timezone.utc) + timedelta(days=1)).isoformat()})
    history = api("GET", "/attendance/me" + dates + "&memberId=" + props["memberB.memberId"], token=member_a)
    assert len(history) == 1 and history[0]["id"] == attendance_id and history[0]["verificationMode"] == "SIMULATED_TEST"
    other_history = api("GET", "/attendance/me" + dates, token=member_b)
    assert len(other_history) == 1 and other_history[0]["id"] != attendance_id
    result["db"].append("History filters use principal members.id and cannot expose another Member even with client memberId query")
    member_a = login("memberA")
    reloaded = api("GET", "/attendance/me" + dates, token=member_a)
    assert reloaded == history
    result["db"].append("Fresh login reads the same persisted Attendance UUID/time/mode")
    assert business() == before
    result["db"].append("All User, facial profile, Membership, payment, receipt, activation and Booking rows unchanged by Core")
    result["readback"] = {"memberId": props["memberA.memberId"], "userId": props["memberA.userId"], "attendance": history[0],
                          "otherAttendanceId": other_history[0]["id"], "attendanceCount": 2}
    phase = "source-evidence"
    paths = subprocess.check_output(["git", "status", "--porcelain=v1", "-z", "--untracked-files=all"], cwd=repo).decode().split("\0")
    for entry in paths:
        if not entry:
            continue
        path = entry[3:]
        if path.startswith("docs/backend-handover/research/"):
            continue
        if Path(path).suffix in (".java", ".py", ".ps1", ".mjs", ".properties", ".sql", ".xml") or path in (".gitattributes", "database/checkin-integration-candidate.json"):
            result["sourceHashes"][path] = hashlib.sha256((repo / path).read_bytes()).hexdigest()
    result["finishedAt"] = datetime.now(timezone.utc).isoformat()
    (private / "checkin-e2e-results.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps({"simulatedIdentity": True, "adapterChecks": len(result["adapter"]), "httpChecks": len(result["http"]), "dbChecks": len(result["db"]), "failed": 0, "skipped": 0}))
except Exception as error:
    result["failed"] = 1
    result["failedPhase"] = phase
    (private / "checkin-e2e-results.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("F01 E2E failed at " + phase + ": " + type(error).__name__ + " [details kept private]")
    raise SystemExit(1)
