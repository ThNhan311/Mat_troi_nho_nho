"""Admin enrollment at the gym. Stores embeddings only (no images), encrypted at rest.

Run from repository root:
  python -m face.prototype.enroll --new-key
  python -m face.prototype.enroll --member-id M001 --gallery face/data/gallery.enc
Only enroll people who have given informed consent to biometric processing.
"""
import argparse
from pathlib import Path
from time import monotonic
import numpy as np
from .embedder import Embedder, InsightFaceEmbedder
from .gallery import Gallery, generate_key, key_from_env

DEFAULT_GALLERY = "face/data/gallery.enc"


class DuplicateIdentityError(ValueError):
    pass


def register(gallery: Gallery, member_id: str, embeddings, duplicate_threshold: float) -> None:
    """Add a profile unless it looks like a DIFFERENT enrolled member (BR-FR-02)."""
    mean = np.mean(np.stack([np.asarray(e, dtype=np.float32) for e in embeddings]), axis=0)
    ranked = gallery.search(mean, exclude=member_id)
    if ranked and ranked[0][1] >= duplicate_threshold:
        raise DuplicateIdentityError(f"Face resembles existing member {ranked[0][0]!r} (score {ranked[0][1]:.2f})")
    gallery.add(member_id, embeddings)


def capture(embedder: Embedder, camera_index: int, samples: int, interval: float, show: bool) -> list:
    import cv2
    from .camera import CameraCapture
    camera, vectors, next_at = CameraCapture(camera_index, 1.0), [], 0.0
    title = "FitCenter enrollment - Q/Esc to cancel"
    try:
        while len(vectors) < samples:
            now = monotonic()
            frame = camera.read(now)
            if frame is not None and now >= next_at:
                vector = embedder.embed(frame)
                if vector is not None:
                    vectors.append(vector)
                    next_at = now + interval
            if show and frame is not None:
                cv2.putText(frame, f"Look at the camera, turn slightly: {len(vectors)}/{samples}", (8, 24),
                            cv2.FONT_HERSHEY_SIMPLEX, .6, (240, 240, 240), 2)
                cv2.imshow(title, frame)
                if cv2.waitKey(1) & 0xFF in (27, ord("q")):
                    raise KeyboardInterrupt
    finally:
        camera.close()
        if show:
            cv2.destroyAllWindows()
    return vectors


def main():
    parser = argparse.ArgumentParser(description="Enroll a member's face (embeddings only).")
    parser.add_argument("--new-key", action="store_true", help="Print a new gallery key and exit")
    parser.add_argument("--member-id")
    parser.add_argument("--gallery", default=DEFAULT_GALLERY)
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--samples", type=int, default=8)
    parser.add_argument("--interval", type=float, default=0.7, help="Seconds between samples")
    parser.add_argument("--duplicate-threshold", type=float, default=0.5)
    parser.add_argument("--remove", action="store_true", help="Delete the member's profile")
    args = parser.parse_args()
    if args.new_key:
        print(f"Set this in your environment, keep it out of the repository:\nFITCENTER_GALLERY_KEY={generate_key()}")
        return
    if not args.member_id:
        parser.error("--member-id is required")
    if args.samples < 3:
        parser.error("--samples must be >= 3")
    try:
        key = key_from_env()
        model = InsightFaceEmbedder.model_name
        gallery = Gallery.load_or_new(args.gallery, key, model)
        if args.remove:
            if not gallery.remove(args.member_id):
                parser.exit(1, f"No profile for {args.member_id!r}\n")
            gallery.save(args.gallery, key)
            print(f"Removed {args.member_id!r}; {len(gallery)} member(s) remain")
            return
        vectors = capture(InsightFaceEmbedder(), args.camera, args.samples, args.interval, show=True)
        register(gallery, args.member_id, vectors, args.duplicate_threshold)
        Path(args.gallery).parent.mkdir(parents=True, exist_ok=True)
        gallery.save(args.gallery, key)
        print(f"Enrolled {args.member_id!r} with {len(vectors)} samples; gallery has {len(gallery)} member(s)")
    except KeyboardInterrupt:
        parser.exit(1, "Enrollment cancelled; nothing saved\n")
    except (ValueError, OSError, ImportError, RuntimeError) as error:
        parser.exit(1, f"Enrollment failed: {error}\n")


if __name__ == "__main__":
    main()
