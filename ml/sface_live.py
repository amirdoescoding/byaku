"""Live owner-vs-stranger check with OpenCV SFace (D11, D15, D17). Frames stay in memory; nothing is written to disk.

Usage: uv run sface_live.py [--cam N]
  Confirm the preview is the BUILT-IN camera (index 0 can be the Continuity iPhone), then press `e` to enroll (~5 s, owner alone).
  Keys: o owner | s stranger | p owner-photo | space pause | q quit. Each key starts a new numbered segment;
  say out loud / note which condition it is (yaw 0/+-30, lighting A/B, glasses on/off, which stranger).

Pre-registered pass bar (D15, fixed before any data):
  counted frame = recording, exactly one face with detector score >= 0.9
  PASS iff min(owner) > max(stranger), owner over >= 3 yaws x 2 lights x glasses on/off, >= 2 strangers (people or photos)
  margin = min(owner) - max(stranger); provisional threshold = midpoint (OpenCV reference: 0.363)
  owner-photo is reported only.
"""
import argparse, time
import cv2
import numpy as np

from fetch import fetch

LABELS = {ord("o"): "owner", ord("s"): "stranger", ord("p"): "owner-photo"}
ENROLL_S, DET_MIN = 5.0, 0.9


def unit(v):
    v = np.ravel(v)
    return v / np.linalg.norm(v)


def summary(segments):
    """segments: list of (label, [scores]). Prints per-segment stats and the pass-bar line; returns (passed, margin)."""
    by = {}
    for i, (label, s) in enumerate(segments, 1):
        if s:
            print(f"seg {i:2d} {label:11s} n={len(s):4d} min={min(s):.3f} mean={np.mean(s):.3f} max={max(s):.3f}")
            by.setdefault(label, []).extend(s)
    if not by.get("owner") or not by.get("stranger"):
        print("RESULT: incomplete (need owner and stranger segments)")
        return None, None
    lo, hi = min(by["owner"]), max(by["stranger"])
    margin = lo - hi
    print(f"RESULT: {'PASS' if margin > 0 else 'FAIL'} min(owner)={lo:.3f} max(stranger)={hi:.3f} "
          f"margin={margin:+.3f} threshold={(lo + hi) / 2:.3f} (OpenCV ref 0.363)")
    if by.get("owner-photo"):
        print(f"owner-photo: min={min(by['owner-photo']):.3f} max={max(by['owner-photo']):.3f} (report only)")
    return margin > 0, margin


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cam", type=int, default=0)
    cam = ap.parse_args().cam
    models = fetch()
    cap = cv2.VideoCapture(cam)
    ok, frame = cap.read()
    if not ok:
        raise SystemExit(f"camera {cam} gave no frame (permission for the terminal app? wrong index?)")
    h, w = frame.shape[:2]
    print(f"camera {cam}: {w}x{h}. Confirm it's the built-in camera, then press `e` to enroll.")
    det = cv2.FaceDetectorYN.create(str(models / "yunet.onnx"), "", (w, h), DET_MIN)
    rec = cv2.FaceRecognizerSF.create(str(models / "sface.onnx"), "")

    owner, enroll, enroll_until = None, [], None
    segments, label = [], None
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        _, faces = det.detect(frame)
        faces = [] if faces is None else list(faces)
        now = time.time()
        if enroll_until and faces:
            f = max(faces, key=lambda f: f[2] * f[3])
            enroll.append(unit(rec.feature(rec.alignCrop(frame, f))))
        if enroll_until and now >= enroll_until:
            enroll_until = None
            if enroll:
                owner = unit(np.mean(enroll, axis=0))
                print(f"enrolled from {len(enroll)} frames")
        for f in faces:
            x, y, fw, fh = map(int, f[:4])
            txt = "enrolling" if enroll_until else ""
            if owner is not None:
                score = float(unit(rec.feature(rec.alignCrop(frame, f))) @ owner)
                txt = f"{score:.3f}"
                if label and len(faces) == 1:
                    segments[-1][1].append(score)
            cv2.rectangle(frame, (x, y), (x + fw, y + fh), (0, 255, 0), 2)
            cv2.putText(frame, txt, (x, y - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        status = f"seg {len(segments)} {label}" if label else ("paused" if owner is not None else "press e to enroll")
        cv2.putText(frame, status, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        cv2.imshow("byaku sface_live (in memory only)", frame)

        k = cv2.waitKey(1) & 0xFF
        if k == ord("q"):
            break
        if k == ord("e") and not enroll_until:
            enroll, enroll_until, label = [], now + ENROLL_S, None
            print("enrolling: owner alone, look at the screen")
        elif k == ord(" "):
            label = None
            print("paused")
        elif k in LABELS and owner is not None:
            label = LABELS[k]
            segments.append((label, []))
            print(f"seg {len(segments)}: {label}")
    cap.release()
    cv2.destroyAllWindows()
    summary(segments)


if __name__ == "__main__":
    main()
