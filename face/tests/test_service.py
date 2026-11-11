from threading import Event, Thread
import cv2
import numpy as np
import pytest
from fastapi.testclient import TestClient
from face.prototype.embedder import MODEL_NAME
from face.prototype.gallery import EMBEDDING_DIM, Gallery, generate_key
from face.service.api import MAX_IMAGE_BYTES, create_app

KIOSK, ADMIN = "k" * 20, "a" * 20
ALICE, BOB, CAROL, NOBODY = 40, 120, 200, 0  # Solid-color "faces"; 0 means no face.


def photo(shade: int, noise: int = 0) -> bytes:
    image = np.full((64, 64, 3), shade, np.uint8)
    ok, jpeg = cv2.imencode(".jpg", image)
    assert ok
    return jpeg.tobytes()


class FakeEmbedder:
    model_name = MODEL_NAME

    def __init__(self):
        self.gate: Event | None = None
        self.entered = Event()

    def embed(self, frame):
        self.entered.set()
        if self.gate is not None:
            self.gate.wait(5)
        shade = int(round(float(frame.mean()) / 10.0)) * 10
        if shade == NOBODY:
            return None
        return np.random.default_rng(shade).standard_normal(EMBEDDING_DIM).astype(np.float32)


@pytest.fixture
def embedder(): return FakeEmbedder()


@pytest.fixture
def gallery_path(tmp_path): return str(tmp_path / "gallery.enc")


@pytest.fixture
def key(): return generate_key()


@pytest.fixture
def gallery(): return Gallery(MODEL_NAME)


@pytest.fixture
def client(embedder, gallery, gallery_path, key):
    return TestClient(create_app(embedder, gallery, gallery_path, key, KIOSK, ADMIN))


def files(*shades): return [("frames", (f"f{i}.jpg", photo(s), "image/jpeg")) for i, s in enumerate(shades)]


def enroll(client, member_id, shade, count=6, token=ADMIN):
    return client.post("/v1/enroll", data={"member_id": member_id}, files=files(*[shade] * count),
                       headers={"X-Admin-Token": token})


def identify(client, *shades, token=KIOSK, data=None):
    return client.post("/v1/identify", files=files(*shades), data=data or {}, headers={"X-Kiosk-Token": token})


def test_health_needs_no_token(client):
    assert client.get("/v1/health").json() == {"status": "ok", "members": 0, "model": MODEL_NAME}


def test_no_interactive_docs(client):
    assert all(client.get(path).status_code == 404 for path in ("/docs", "/redoc", "/openapi.json"))


@pytest.mark.parametrize("kiosk,admin", [("short", ADMIN), (KIOSK, "short"), (KIOSK, KIOSK)])
def test_create_app_refuses_weak_or_equal_tokens(embedder, gallery, gallery_path, key, kiosk, admin):
    with pytest.raises(ValueError):
        create_app(embedder, gallery, gallery_path, key, kiosk, admin)


def test_tokens_are_required_and_not_interchangeable(client):
    assert client.post("/v1/identify", files=files(ALICE)).status_code == 401
    assert identify(client, ALICE, token="wrong").status_code == 401
    assert identify(client, ALICE, token=ADMIN).status_code == 401
    assert enroll(client, "M1", ALICE, token=KIOSK).status_code == 401
    assert client.post("/v1/enroll", data={"member_id": "M1"}, files=files(*[ALICE] * 6)).status_code == 401
    assert client.delete("/v1/members/M1").status_code == 401
    assert client.delete("/v1/members/M1", headers={"X-Kiosk-Token": KIOSK}).status_code == 401


def test_enroll_then_identify_success(client, gallery_path, key):
    assert enroll(client, "M001", ALICE).json() == {"member_id": "M001", "samples_used": 6, "members": 1}
    enroll(client, "M002", BOB)
    body = identify(client, ALICE, ALICE, ALICE).json()
    assert body["outcome"] == "SUCCESS" and body["member_id"] == "M001" and body["liveness"] == "NOT_PERFORMED"
    assert body["score"] > 0.99 and body["request_id"]
    assert identify(client, BOB).json()["member_id"] == "M002"
    assert Gallery.load(gallery_path, key, MODEL_NAME).member_ids == ["M001", "M002"]  # Persisted.


def test_identify_stranger_and_no_face(client):
    enroll(client, "M001", ALICE)
    stranger = identify(client, CAROL).json()
    assert (stranger["outcome"], stranger["member_id"]) == ("REJECTED", None)
    none = identify(client, NOBODY, NOBODY).json()
    assert (none["outcome"], none["member_id"], none["score"]) == ("NO_FACE", None, None)
    assert identify(client, NOBODY, ALICE).json()["outcome"] == "SUCCESS"  # One usable frame is enough.


def test_identify_empty_gallery_rejects(client):
    assert identify(client, ALICE).json()["outcome"] == "REJECTED"


def test_request_id_echo_and_validation(client):
    assert identify(client, ALICE, data={"request_id": "req-1.a_b"}).json()["request_id"] == "req-1.a_b"
    for bad in ("bad id", "x" * 65, "a/b"):
        response = identify(client, ALICE, data={"request_id": bad})
        assert response.status_code == 400 and response.json()["error"] == "INVALID_REQUEST"


def test_identify_input_limits(client):
    assert client.post("/v1/identify", headers={"X-Kiosk-Token": KIOSK}).json()["error"] == "NO_FRAMES"
    assert identify(client, *[ALICE] * 6).json()["error"] == "TOO_MANY_FRAMES"
    garbage = [("frames", ("x.jpg", b"not an image", "image/jpeg"))]
    response = client.post("/v1/identify", files=garbage, headers={"X-Kiosk-Token": KIOSK})
    assert (response.status_code, response.json()["error"]) == (400, "INVALID_IMAGE")
    empty = [("frames", ("x.jpg", b"", "image/jpeg"))]
    assert client.post("/v1/identify", files=empty, headers={"X-Kiosk-Token": KIOSK}).status_code == 400
    huge = [("frames", ("x.jpg", b"\0" * (MAX_IMAGE_BYTES + 1), "image/jpeg"))]
    response = client.post("/v1/identify", files=huge, headers={"X-Kiosk-Token": KIOSK})
    assert (response.status_code, response.json()["error"]) == (413, "IMAGE_TOO_LARGE")


def test_enroll_validation(client):
    assert enroll(client, "M1", ALICE, count=4).json()["error"] == "TOO_FEW_FRAMES"
    assert enroll(client, "M1", ALICE, count=16).json()["error"] == "TOO_MANY_FRAMES"
    for bad in ("", "a b", "../x", "x" * 65):
        assert enroll(client, bad, ALICE).json()["error"] in ("INVALID_MEMBER_ID", "INVALID_REQUEST")
    assert client.post("/v1/enroll", files=files(*[ALICE] * 6), headers={"X-Admin-Token": ADMIN}).status_code == 400
    mixed = client.post("/v1/enroll", data={"member_id": "M1"}, files=files(ALICE, ALICE, NOBODY, NOBODY, NOBODY),
                        headers={"X-Admin-Token": ADMIN})
    assert (mixed.status_code, mixed.json()["error"]) == (400, "NO_FACE")
    assert client.get("/v1/health").json()["members"] == 0


def test_enroll_blocks_duplicate_identity_but_allows_reenroll(client):
    enroll(client, "M001", ALICE)
    duplicate = enroll(client, "M999", ALICE)
    assert (duplicate.status_code, duplicate.json()["error"]) == (409, "DUPLICATE_IDENTITY")
    assert client.get("/v1/health").json()["members"] == 1
    assert enroll(client, "M001", ALICE).status_code == 200  # Same member: replaces the profile.


def test_delete_member(client):
    enroll(client, "M001", ALICE)
    headers = {"X-Admin-Token": ADMIN}
    assert client.delete("/v1/members/M001", headers=headers).json() == {"member_id": "M001", "removed": True}
    assert client.delete("/v1/members/M001", headers=headers).json()["error"] == "NOT_FOUND"
    assert identify(client, ALICE).json()["outcome"] == "REJECTED"


def test_storage_failure_rolls_back(client, gallery, monkeypatch):
    enroll(client, "M001", ALICE)
    before = gallery.get("M001")

    def boom(*_): raise OSError("disk full")
    monkeypatch.setattr(gallery, "save", boom)
    failed = enroll(client, "M002", BOB)
    assert (failed.status_code, failed.json()["error"]) == (500, "STORAGE_ERROR")
    assert gallery.member_ids == ["M001"]
    assert enroll(client, "M001", ALICE).status_code == 500 and len(gallery.get("M001")) == len(before)
    assert client.delete("/v1/members/M001", headers={"X-Admin-Token": ADMIN}).status_code == 500
    assert gallery.member_ids == ["M001"]


def test_concurrent_operation_gets_busy(client, embedder):
    enroll(client, "M001", ALICE)
    embedder.gate, embedder.entered = Event(), Event()
    first = Thread(target=lambda: identify(client, ALICE))
    first.start()
    try:
        assert embedder.entered.wait(5)
        busy = identify(client, ALICE)
        assert (busy.status_code, busy.json()["error"]) == (503, "BUSY")
    finally:
        embedder.gate.set()
        first.join(5)
    assert identify(client, ALICE).json()["outcome"] == "SUCCESS"
