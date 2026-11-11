from threading import Event
import numpy as np
import pytest
from face.prototype.embedder import MODEL_NAME
from face.prototype.enroll import DuplicateIdentityError, register
from face.prototype.gallery import EMBEDDING_DIM, Gallery, generate_key, key_from_env
from face.prototype.local_auth_client import LatestFrameBuffer, LocalAuthClient
from face.prototype.matcher import Matcher
from face.prototype.types import AuthOutcome, AuthRequest, MockCapturePayload

rng = np.random.default_rng(7)


def person():
    return rng.standard_normal(EMBEDDING_DIM).astype(np.float32)


def noisy(vector, scale=0.15):
    return vector + scale * rng.standard_normal(EMBEDDING_DIM).astype(np.float32)


@pytest.fixture
def alice(): return person()


@pytest.fixture
def bob(): return person()


@pytest.fixture
def gallery(alice, bob):
    g = Gallery(MODEL_NAME)
    g.add("alice", [noisy(alice), noisy(alice)])
    g.add("bob", [noisy(bob)])
    return g


def test_gallery_search_ranks_the_right_member_first(gallery, alice):
    ranked = gallery.search(noisy(alice))
    assert ranked[0][0] == "alice" and ranked[0][1] > 0.9 and ranked[1][1] < 0.3


def test_gallery_rejects_bad_embeddings():
    g = Gallery(MODEL_NAME)
    for bad in (np.zeros(EMBEDDING_DIM), np.ones(10), np.full(EMBEDDING_DIM, np.nan)):
        with pytest.raises(ValueError):
            g.add("x", [bad])
    with pytest.raises(ValueError):
        g.add("", [person()])
    with pytest.raises(ValueError):
        g.add("x", [])


def test_add_replaces_profile_and_remove(gallery, alice, bob):
    gallery.add("alice", [bob])  # one active profile per member
    assert gallery.search(alice)[0][1] < 0.3 and len(gallery) == 2
    assert gallery.remove("alice") and not gallery.remove("alice") and gallery.member_ids == ["bob"]


def test_save_load_roundtrip_is_encrypted(gallery, alice, tmp_path):
    key, path = generate_key(), tmp_path / "g.enc"
    gallery.save(path, key)
    raw = path.read_bytes()
    assert b"alice" not in raw and b"PK" not in raw[:4]
    loaded = Gallery.load(path, key, MODEL_NAME)
    assert loaded.member_ids == ["alice", "bob"] and loaded.search(alice)[0][0] == "alice"


def test_load_refuses_wrong_key_wrong_model_and_corruption(gallery, tmp_path):
    key, path = generate_key(), tmp_path / "g.enc"
    gallery.save(path, key)
    with pytest.raises(ValueError, match="decrypted"):
        Gallery.load(path, generate_key(), MODEL_NAME)
    with pytest.raises(ValueError, match="re-enroll"):
        Gallery.load(path, key, "other-model")
    path.write_bytes(path.read_bytes()[:-5])
    with pytest.raises(ValueError, match="decrypted"):
        Gallery.load(path, key, MODEL_NAME)
    assert len(Gallery.load_or_new(tmp_path / "missing.enc", key, MODEL_NAME)) == 0


def test_key_from_env(monkeypatch):
    monkeypatch.delenv("FITCENTER_GALLERY_KEY", raising=False)
    with pytest.raises(ValueError, match="FITCENTER_GALLERY_KEY"):
        key_from_env()
    monkeypatch.setenv("FITCENTER_GALLERY_KEY", "not-a-key")
    with pytest.raises(ValueError, match="valid key"):
        key_from_env()
    key = generate_key()
    monkeypatch.setenv("FITCENTER_GALLERY_KEY", key)
    assert key_from_env() == key


def test_matcher_accepts_known_member(gallery, alice, bob):
    assert Matcher(gallery).match(noisy(alice)).member_id == "alice"
    assert Matcher(gallery).match(noisy(bob)).member_id == "bob"


def test_matcher_rejects_stranger_and_empty_gallery(gallery):
    result = Matcher(gallery).match(person())
    assert result.member_id is None and result.score < 0.5
    assert Matcher(Gallery(MODEL_NAME)).match(person()).member_id is None


def test_matcher_rejects_ambiguous_match(alice):
    g = Gallery(MODEL_NAME)
    g.add("a", [noisy(alice, .05)])
    g.add("b", [noisy(alice, .05)])  # near-identical twins: top-1 does not clearly beat top-2
    result = Matcher(g, threshold=0.5, margin=0.2).match(alice)
    assert result.member_id is None and result.score > 0.9 and result.margin < 0.2


def test_matcher_validates_parameters(gallery):
    for kwargs in ({"threshold": 1.0}, {"threshold": float("nan")}, {"margin": -0.1}, {"margin": 1.0}):
        with pytest.raises(ValueError):
            Matcher(gallery, **kwargs)


class FakeEmbedder:
    model_name = MODEL_NAME

    def __init__(self, vectors): self.vectors, self.calls = list(vectors), 0

    def embed(self, frame):
        self.calls += 1
        return self.vectors.pop(0) if self.vectors else None


def request():
    return AuthRequest("r1", "kiosk", MockCapturePayload())


def client(gallery, vectors, samples=3):
    buffer = LatestFrameBuffer()
    buffer.put(np.zeros((8, 8, 3), np.uint8))
    return LocalAuthClient(FakeEmbedder(vectors), Matcher(gallery), buffer, samples, interval_seconds=0)


def test_client_success_returns_member_and_score(gallery, alice):
    result = client(gallery, [noisy(alice) for _ in range(3)]).authenticate(request(), Event())
    assert (result.outcome, result.member_id, result.request_id) == (AuthOutcome.SUCCESS, "alice", "r1")
    assert result.score > 0.9


def test_client_rejects_stranger(gallery):
    result = client(gallery, [person() for _ in range(3)]).authenticate(request(), Event())
    assert result.outcome == AuthOutcome.REJECTED and result.member_id is None


def test_client_rejects_when_no_face_or_no_frame(gallery):
    assert client(gallery, []).authenticate(request(), Event()).outcome == AuthOutcome.REJECTED
    empty = LocalAuthClient(FakeEmbedder([person()]), Matcher(gallery), LatestFrameBuffer(), 1, 0)
    assert empty.authenticate(request(), Event()).outcome == AuthOutcome.REJECTED


def test_client_averages_samples_and_tolerates_missed_frames(gallery, alice):
    result = client(gallery, [noisy(alice), None, noisy(alice)]).authenticate(request(), Event())
    assert result.outcome == AuthOutcome.SUCCESS


def test_client_stops_when_cancelled(gallery, alice):
    cancel, fake = Event(), None
    c = client(gallery, [noisy(alice)] * 3)
    cancel.set()
    assert c.authenticate(request(), cancel).outcome == AuthOutcome.TIMEOUT and c.embedder.calls == 0


def test_frame_buffer_hands_out_the_frame_it_was_given():
    buffer, frame = LatestFrameBuffer(), np.ones((2, 2, 3), np.uint8)
    assert buffer.get() is None
    buffer.put(frame)
    frame[:] = 9  # later mutation by the UI thread must not leak into auth
    assert buffer.get().max() == 1


def test_register_adds_new_member_and_allows_reenroll(gallery):
    new = person()
    register(gallery, "carol", [noisy(new), noisy(new)], 0.5)
    register(gallery, "carol", [noisy(new)], 0.5)  # re-enrolling the same person is fine
    assert gallery.member_ids == ["alice", "bob", "carol"]


def test_register_blocks_duplicate_identity(gallery, alice):
    with pytest.raises(DuplicateIdentityError, match="alice"):
        register(gallery, "mallory", [noisy(alice), noisy(alice)], 0.5)
    assert "mallory" not in gallery.member_ids
