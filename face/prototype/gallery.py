"""Face embedding gallery. Stores embeddings only, never images.

Embeddings are biometric data: the file is encrypted at rest and the key is never
kept in the repository. Embeddings from different models are not comparable, so the
file records the model name and refuses to load for a different one.
"""
from base64 import urlsafe_b64decode, urlsafe_b64encode
import io
import json
import os
from pathlib import Path
import numpy as np

EMBEDDING_DIM = 512
KEY_ENV = "FITCENTER_GALLERY_KEY"


def generate_key() -> str:
    return urlsafe_b64encode(os.urandom(32)).decode("ascii")


def _normalize(vector: np.ndarray) -> np.ndarray:
    vector = np.asarray(vector, dtype=np.float32).reshape(-1)
    if vector.shape[0] != EMBEDDING_DIM or not np.all(np.isfinite(vector)):
        raise ValueError(f"Embedding must be a finite vector of {EMBEDDING_DIM} values")
    norm = float(np.linalg.norm(vector))
    if norm == 0:
        raise ValueError("Embedding must be non-zero")
    return vector / norm


class Gallery:
    """In-memory gallery: member_id -> unit-length embeddings."""

    def __init__(self, model_name: str):
        self.model_name = model_name
        self._members: dict[str, list[np.ndarray]] = {}

    def __len__(self) -> int:
        return len(self._members)

    @property
    def member_ids(self) -> list[str]:
        return sorted(self._members)

    def add(self, member_id: str, embeddings) -> None:
        """Replace a member's profile. One active profile per member (BR-FR-02)."""
        if not member_id:
            raise ValueError("member_id is required")
        vectors = [_normalize(e) for e in embeddings]
        if not vectors:
            raise ValueError("At least one embedding is required")
        self._members[member_id] = vectors

    def get(self, member_id: str) -> list[np.ndarray] | None:
        vectors = self._members.get(member_id)
        return list(vectors) if vectors is not None else None

    def remove(self, member_id: str) -> bool:
        return self._members.pop(member_id, None) is not None

    def search(self, embedding, exclude: str | None = None) -> list[tuple[str, float]]:
        """Best cosine score per member, highest first."""
        query = _normalize(embedding)
        scored = []
        for member_id, vectors in self._members.items():
            if member_id != exclude:
                scored.append((member_id, float(np.max(np.stack(vectors) @ query))))
        return sorted(scored, key=lambda item: item[1], reverse=True)

    def save(self, path: str | Path, key: str) -> None:
        from cryptography.fernet import Fernet
        arrays = {f"m{i}": np.stack(self._members[m]) for i, m in enumerate(self.member_ids)}
        meta = json.dumps({"model": self.model_name, "members": self.member_ids})
        buffer = io.BytesIO()
        np.savez(buffer, meta=np.frombuffer(meta.encode("utf-8"), dtype=np.uint8), **arrays)
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(path.suffix + ".tmp")
        temporary.write_bytes(Fernet(key.encode("ascii")).encrypt(buffer.getvalue()))
        os.replace(temporary, path)  # An interrupted save never corrupts the old file.

    @classmethod
    def load(cls, path: str | Path, key: str, model_name: str) -> "Gallery":
        from cryptography.fernet import Fernet, InvalidToken
        try:
            plain = Fernet(key.encode("ascii")).decrypt(Path(path).read_bytes())
        except InvalidToken as error:
            raise ValueError("Gallery cannot be decrypted: wrong key or corrupted file") from error
        with np.load(io.BytesIO(plain), allow_pickle=False) as data:
            meta = json.loads(bytes(data["meta"]).decode("utf-8"))
            if meta["model"] != model_name:
                raise ValueError(f"Gallery was built with model {meta['model']!r}, not {model_name!r}; re-enroll")
            gallery = cls(meta["model"])
            for i, member_id in enumerate(meta["members"]):
                gallery.add(member_id, list(data[f"m{i}"]))
        return gallery

    @classmethod
    def load_or_new(cls, path: str | Path, key: str, model_name: str) -> "Gallery":
        return cls.load(path, key, model_name) if Path(path).exists() else cls(model_name)


def key_from_env() -> str:
    key = os.environ.get(KEY_ENV)
    if not key:
        raise ValueError(f"Set {KEY_ENV} (generate one with: python -m face.prototype.enroll --new-key)")
    try:
        if len(urlsafe_b64decode(key.encode("ascii"))) != 32:
            raise ValueError
    except ValueError:
        raise ValueError(f"{KEY_ENV} is not a valid key") from None
    return key
