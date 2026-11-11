"""Run from repository root: python -m face.service  (needs the env vars listed in the README)."""
import argparse
import os
from ..prototype.embedder import InsightFaceEmbedder
from ..prototype.gallery import Gallery, key_from_env
from .api import create_app

DEFAULT_GALLERY = "face/data/gallery.enc"


def main():
    parser = argparse.ArgumentParser(description="FitCenter local face service (no liveness)")
    parser.add_argument("--host", default="127.0.0.1", help="Loopback by default; the API is plain HTTP")
    parser.add_argument("--port", type=int, default=8750)
    parser.add_argument("--gallery", default=DEFAULT_GALLERY)
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--margin", type=float, default=0.05)
    args = parser.parse_args()
    try:
        import uvicorn
        key = key_from_env()
        tokens = {name: os.environ.get(name, "") for name in ("FITCENTER_KIOSK_TOKEN", "FITCENTER_ADMIN_TOKEN")}
        missing = [name for name, value in tokens.items() if not value]
        if missing:
            raise ValueError(f"Set {' and '.join(missing)} (long random strings, at least 16 characters, different from each other)")
        embedder = InsightFaceEmbedder()
        gallery = Gallery.load_or_new(args.gallery, key, embedder.model_name)
        app = create_app(embedder, gallery, args.gallery, key, tokens["FITCENTER_KIOSK_TOKEN"],
                         tokens["FITCENTER_ADMIN_TOKEN"], args.threshold, args.margin)
    except (ValueError, OSError, ImportError, RuntimeError) as error:
        parser.exit(1, f"Face service could not start: {error}\n")
    uvicorn.run(app, host=args.host, port=args.port, access_log=False)


if __name__ == "__main__":
    main()
