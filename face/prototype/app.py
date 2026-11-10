"""Run from repository root: python -m face.prototype.app --synthetic."""
import argparse
from time import monotonic
from .auth_client import MockAuthClient, SingleFlightWorker
from .camera import CameraCapture, SyntheticVideoSource
from .config import PrototypeConfig
from .controller import PrototypeController
from .detector import MediaPipeFaceDetector, MockFaceDetector, measure_candidates
from .selector import EligibleFaceSelector
from .types import AuthOutcome, SelectionStatus


def run(args) -> dict:
    import cv2
    import numpy as np
    config = PrototypeConfig.load(args.config) if args.config else PrototypeConfig()
    selector = EligibleFaceSelector(config)
    controller = PrototypeController(config, SingleFlightWorker(MockAuthClient(AuthOutcome(args.mock_outcome), args.mock_delay)))
    camera = CameraCapture(args.camera, config.reconnect_seconds,
                           factory=(lambda _: SyntheticVideoSource())) if args.synthetic else CameraCapture(args.camera, config.reconnect_seconds)
    detector = None
    started, next_detection = monotonic(), 0.0
    frames = detections = 0
    selection, faces = None, []
    detector_warning = ""
    title = "FitCenter - MOCK AUTH ONLY - Q/Esc to quit"
    try:
        detector = MockFaceDetector() if args.synthetic else MediaPipeFaceDetector(args.model)
        while True:
            now = monotonic()
            if args.seconds is not None and now - started >= args.seconds:
                break
            frame = camera.read(now)
            selection_update = None
            invalid = frame is None
            if frame is None:
                selection, faces = None, []
                frame = np.zeros((480, 640, 3), dtype=np.uint8)
            else:
                if not args.synthetic:
                    # Mirror before detection so boxes and ROI match the preview.
                    frame = cv2.flip(frame, 1)
                frames += 1
                if now >= next_detection:
                    next_detection = now + 1 / config.detection_hz
                    try:
                        faces = measure_candidates(frame, detector.detect(frame))
                        selection = selector.select(frame.shape[1], frame.shape[0], faces)
                        selection_update = selection
                        detections += 1
                        detector_warning = ""
                    except Exception:
                        selection, faces = None, []
                        detector_warning = "Detector error; authentication disabled until recovery"
                        invalid = True
            # Timestamp after capture/detection: an expensive detector cannot extend auth deadline.
            controller.update(monotonic(), selection_update, invalid)
            if not args.headless:
                h, w = frame.shape[:2]
                roi = config.roi
                cv2.rectangle(frame, (int(roi.x * w), int(roi.y * h)),
                              (int((roi.x + roi.width) * w), int((roi.y + roi.height) * h)), (255, 200, 0), 2)
                for index, face in enumerate(faces):
                    b = face.box
                    if not b.valid:
                        continue
                    reasons = dict(selection.rejection_reasons).get(index, ()) if selection else ()
                    color = (0, 210, 0) if not reasons else (0, 100, 255)
                    cv2.rectangle(frame, (int(b.x), int(b.y)), (int(b.x + b.width), int(b.y + b.height)), color, 2)
                    cv2.putText(frame, ",".join(reasons) or "ELIGIBLE", (int(b.x), max(20, int(b.y) - 5)), cv2.FONT_HERSHEY_SIMPLEX, .4, color, 1)
                status = selection.status if selection else SelectionStatus.NO_ELIGIBLE_FACE
                guide = {SelectionStatus.NO_ELIGIBLE_FACE: "Move into ROI; check light, sharpness and distance",
                         SelectionStatus.READY: "Hold still",
                         SelectionStatus.MULTIPLE_ELIGIBLE_FACES: "Only ONE eligible person in ROI, please"}[status]
                machine = controller.machine
                lines = ["MOCK ONLY - no identity, liveness, attendance or real access",
                         f"{machine.state.value} | {status.value} | eligible={len(selection.eligible_faces) if selection else 0}", guide]
                if machine.last_result:
                    lines.append(f"MOCK result: {machine.last_result.outcome.value}")
                if machine.needs_leave:
                    lines.append("Leave ROI to re-arm after mock SUCCESS")
                if controller.worker.busy and machine.state.value != "VERIFYING":
                    lines.append("Auth transport still stopping; no new request allowed")
                lines.extend(filter(None, [camera.warning, detector_warning]))
                for i, line in enumerate(lines):
                    cv2.putText(frame, line, (8, 20 + i * 22), cv2.FONT_HERSHEY_SIMPLEX, .45, (240, 240, 240), 1)
                cv2.imshow(title, frame)
                if cv2.waitKey(1) & 0xFF in (27, ord("q")):
                    break
                if cv2.getWindowProperty(title, cv2.WND_PROP_VISIBLE) < 1:
                    break
            else:
                # Synthetic headless mode has no hardware read/waitKey pacing.
                from time import sleep
                sleep(1 / 30)
    finally:
        controller.shutdown()
        camera.close()
        try:
            if detector is not None:
                detector.close()
        finally:
            if not args.headless:
                cv2.destroyAllWindows()
    elapsed = monotonic() - started
    return {"mode": "synthetic" if args.synthetic else "webcam", "frames": frames, "detections": detections,
            "elapsed_seconds": round(elapsed, 3), "requests_sent": controller.requests_sent,
            "last_mock_result": controller.machine.last_result.outcome.value if controller.machine.last_result else None}


def main():
    parser = argparse.ArgumentParser(description="Local face selection demo. Authentication is MOCK ONLY.")
    parser.add_argument("--config")
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--model", help="MediaPipe BlazeFace short range TFLite path (required for webcam)")
    parser.add_argument("--synthetic", action="store_true", help="Generated video and mock detector; no webcam")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--seconds", type=float)
    parser.add_argument("--mock-outcome", choices=[s.value for s in AuthOutcome], default="SUCCESS")
    parser.add_argument("--mock-delay", type=float, default=0.5)
    args = parser.parse_args()
    from math import isfinite
    if args.headless and (args.seconds is None or not args.synthetic):
        parser.error("--headless requires --synthetic and a bounded --seconds duration")
    if args.seconds is not None and (not isfinite(args.seconds) or args.seconds <= 0):
        parser.error("--seconds must be finite and positive")
    if not args.synthetic and not args.model:
        parser.error("Webcam mode requires --model; use --synthetic to run without a model/camera")
    try:
        import json
        print(json.dumps(run(args)))
    except (ValueError, OSError, ImportError, RuntimeError) as error:
        parser.exit(1, f"Prototype could not start: {error}\n")


if __name__ == "__main__":
    main()
