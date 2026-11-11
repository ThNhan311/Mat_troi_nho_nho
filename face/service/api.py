"""Local HTTP face service. Contract: docs/face/API_CONTRACT.md. No liveness; embeddings never leave this process."""
import hmac
import re
from threading import Lock
from uuid import uuid4
import cv2
import numpy as np
from fastapi import FastAPI, File, Form, Header, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from ..prototype.embedder import Embedder
from ..prototype.enroll import DuplicateIdentityError, register
from ..prototype.gallery import Gallery
from ..prototype.matcher import Matcher

MAX_IMAGE_BYTES = 2 * 1024 * 1024
MAX_IMAGE_SIDE = 4096
MAX_IDENTIFY_FRAMES = 5
ENROLL_FRAMES = (5, 15)
MIN_ENROLL_FACES = 3
MIN_TOKEN_LENGTH = 16
MEMBER_ID = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
REQUEST_ID = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")


class ApiError(Exception):
    def __init__(self, status: int, code: str, detail: str):
        self.status, self.code, self.detail = status, code, detail


def _authorize(provided: str | None, expected: str) -> None:
    if provided is None or not hmac.compare_digest(provided.encode("utf-8"), expected.encode("utf-8")):
        raise ApiError(401, "UNAUTHORIZED", "Missing or invalid token")


def _decode(upload: UploadFile) -> np.ndarray:
    data = upload.file.read(MAX_IMAGE_BYTES + 1)
    if len(data) > MAX_IMAGE_BYTES:
        raise ApiError(413, "IMAGE_TOO_LARGE", f"Each image must be at most {MAX_IMAGE_BYTES} bytes")
    image = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR) if data else None
    if image is None or max(image.shape[:2]) > MAX_IMAGE_SIDE:
        raise ApiError(400, "INVALID_IMAGE", "Frame is not a decodable JPEG/PNG within size limits")
    return image


def create_app(embedder: Embedder, gallery: Gallery, gallery_path: str, gallery_key: str, kiosk_token: str,
               admin_token: str, threshold: float = 0.5, margin: float = 0.05,
               duplicate_threshold: float = 0.5) -> FastAPI:
    if len(kiosk_token) < MIN_TOKEN_LENGTH or len(admin_token) < MIN_TOKEN_LENGTH:
        raise ValueError(f"Kiosk and admin tokens must each be at least {MIN_TOKEN_LENGTH} characters")
    if kiosk_token == admin_token:
        raise ValueError("Kiosk and admin tokens must differ")
    matcher = Matcher(gallery, threshold, margin)
    busy = Lock()  # One heavy operation at a time; the gallery is shared mutable state.
    # No interactive docs/OpenAPI: the contract document is the reference.
    app = FastAPI(title="FitCenter Face Service", docs_url=None, redoc_url=None, openapi_url=None)

    @app.exception_handler(ApiError)
    def _api_error(_: Request, error: ApiError):
        return JSONResponse({"error": error.code, "detail": error.detail}, status_code=error.status)

    @app.exception_handler(RequestValidationError)
    def _validation_error(_: Request, __: RequestValidationError):
        return JSONResponse({"error": "INVALID_REQUEST", "detail": "Malformed or missing request fields"}, status_code=400)

    def exclusive(function):
        if not busy.acquire(blocking=False):
            raise ApiError(503, "BUSY", "Another operation is in progress; retry")
        try:
            return function()
        finally:
            busy.release()

    def persist(function_on_failure):
        try:
            gallery.save(gallery_path, gallery_key)
        except Exception:
            function_on_failure()
            raise ApiError(500, "STORAGE_ERROR", "Gallery could not be saved; no change was made")

    @app.get("/v1/health")
    def health():
        return {"status": "ok", "members": len(gallery), "model": embedder.model_name}

    @app.post("/v1/identify")
    def identify(frames: list[UploadFile] = File(default=[]), request_id: str | None = Form(default=None),
                 x_kiosk_token: str | None = Header(default=None)):
        _authorize(x_kiosk_token, kiosk_token)
        if request_id is not None and not REQUEST_ID.match(request_id):
            raise ApiError(400, "INVALID_REQUEST", "request_id must be 1-64 characters of A-Za-z0-9_.-")
        if not frames:
            raise ApiError(400, "NO_FRAMES", "Send at least one frame")
        if len(frames) > MAX_IDENTIFY_FRAMES:
            raise ApiError(400, "TOO_MANY_FRAMES", f"At most {MAX_IDENTIFY_FRAMES} frames")
        images = [_decode(f) for f in frames]

        def run():
            vectors = [v for v in (embedder.embed(image) for image in images) if v is not None]
            body = {"request_id": request_id or str(uuid4()), "liveness": "NOT_PERFORMED"}
            if not vectors:
                return {**body, "outcome": "NO_FACE", "member_id": None, "score": None}
            result = matcher.match(np.mean(np.stack(vectors), axis=0))
            return {**body, "outcome": "SUCCESS" if result.member_id else "REJECTED",
                    "member_id": result.member_id, "score": round(result.score, 4)}
        return exclusive(run)

    @app.post("/v1/enroll")
    def enroll(member_id: str = Form(), frames: list[UploadFile] = File(default=[]),
               x_admin_token: str | None = Header(default=None)):
        _authorize(x_admin_token, admin_token)
        if not MEMBER_ID.match(member_id):
            raise ApiError(400, "INVALID_MEMBER_ID", "member_id must be 1-64 characters of A-Za-z0-9_-")
        low, high = ENROLL_FRAMES
        if len(frames) < low:
            raise ApiError(400, "TOO_FEW_FRAMES", f"Send at least {low} frames")
        if len(frames) > high:
            raise ApiError(400, "TOO_MANY_FRAMES", f"At most {high} frames")
        images = [_decode(f) for f in frames]

        def run():
            vectors = [v for v in (embedder.embed(image) for image in images) if v is not None]
            if len(vectors) < MIN_ENROLL_FACES:
                raise ApiError(400, "NO_FACE", f"A face was found in only {len(vectors)} frame(s); need {MIN_ENROLL_FACES}")
            previous = gallery.get(member_id)
            try:
                register(gallery, member_id, vectors, duplicate_threshold)
            except DuplicateIdentityError:
                raise ApiError(409, "DUPLICATE_IDENTITY", "Face resembles a different enrolled member") from None
            persist(lambda: gallery.add(member_id, previous) if previous else gallery.remove(member_id))
            return {"member_id": member_id, "samples_used": len(vectors), "members": len(gallery)}
        return exclusive(run)

    @app.delete("/v1/members/{member_id}")
    def delete_member(member_id: str, x_admin_token: str | None = Header(default=None)):
        _authorize(x_admin_token, admin_token)

        def run():
            previous = gallery.get(member_id)
            if previous is None:
                raise ApiError(404, "NOT_FOUND", "No such member")
            gallery.remove(member_id)
            persist(lambda: gallery.add(member_id, previous))
            return {"member_id": member_id, "removed": True}
        return exclusive(run)

    return app
