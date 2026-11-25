"""Live owner-vs-stranger check with OpenCV SFace (D11, D15, D17). Frames stay in memory; nothing is written to disk.

Usage: uv run sface_live.py [--cam N]
  Confirm the preview is the BUILT-IN camera (index 0 can be the Continuity iPhone), then press `e` to enroll (~5 s, owner alone).
  HOLD a key to record: o owner | s stranger | p owner-photo. Frames count only while "REC" shows (key held, exactly one face).
  Each new press after a pause starts a new segment: one short segment per condition (yaw 0/+-30, lighting A/B,
  glasses on/off, each stranger). Stranger photos: keep YOUR face out of frame and check the box is on the photo. q quits.

Bar v1 (D15, pre-registered): PASS iff min(owner) > max(stranger). Result 2026-11-25: FAIL (margin -0.775), with labelling
  contaminated (stranger photos on a phone, owner likely in frame and counted as stranger). Kept on record and still printed.
Bar v2 (pre-registered 2026-11-25, committed before any v2 data):
  counted frame = label key held, exactly one face with detector score >= 0.9; segments with < 20 frames are ignored
  PASS iff p5 of EVERY owner segment > p95(all strangers), with >= 2 distinct strangers (people or photos)
  threshold = midpoint of p5(all owner) and p95(all stranger); FRR/FAR at that threshold are reported
  owner-photo is reported only (it is expected to match: the owner suppresses but never disarms).
"""
import argparse, time
import cv2
import numpy as np

from fetch import fetch

LABELS = {ord("o"): "owner", ord("s"): "stranger", ord("p"): "owner-photo"}
ENROLL_S, DET_MIN, HOLD_S, MIN_N = 5.0, 0.9, 0.6, 20


def unit(v):
    v = np.ravel(v)
    return v / np.linalg.norm(v)


def pct(s, q):
    return float(np.percentile(s, q))


def summary(segments):
    """segments: list of (label, [scores]). Prints per-segment stats, bar v1 and bar v2; returns (v2 passed, v2 margin)."""
    by, owner_p5 = {}, []
    for i, (label, s) in enumerate(segments, 1):
        if not s:
            continue
        used = len(s) >= MIN_N
        print(f"seg {i:2d} {label:11s} n={len(s):4d} min={min(s):.3f} p5={pct(s, 5):.3f} p50={pct(s, 50):.3f} "
              f"p95={pct(s, 95):.3f} max={max(s):.3f}{'' if used else '  (ignored: < 20 frames)'}")
        if used:
            by.setdefault(label, []).extend(s)
            if label == "owner":
                owner_p5.append(pct(s, 5))
    if not by.get("owner") or not by.get("stranger"):
        print("RESULT: incomplete (need owner and stranger segments with >= 20 frames)")
        return None, None
    own, st = np.array(by["owner"]), np.array(by["stranger"])
    print(f"bar v1 (record only): {'PASS' if own.min() > st.max() else 'FAIL'} margin={own.min() - st.max():+.3f}")
    hi = pct(st, 95)
    margin = min(owner_p5) - hi
    thr = (pct(own, 5) + hi) / 2
    print(f"RESULT v2: {'PASS' if margin > 0 else 'FAIL'} worst owner-segment p5={min(owner_p5):.3f} "
          f"p95(stranger)={hi:.3f} margin={margin:+.3f} threshold={thr:.3f} (OpenCV ref 0.363) "
          f"FRR={np.mean(own < thr):.1%} FAR={np.mean(st >= thr):.1%}")
    if by.get("owner-photo"):
        ph = by["owner-photo"]
        print(f"owner-photo: p5={pct(ph, 5):.3f} p50={pct(ph, 50):.3f} (report only)")
    print("check: >= 2 distinct strangers? one owner segment per condition?")
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
    segments, label, held_at = [], None, 0.0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        _, faces = det.detect(frame)
        faces = [] if faces is None else list(faces)
        now = time.time()
        rec_on = label is not None and now - held_at < HOLD_S  # key auto-repeat keeps this fresh while held
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
                if rec_on and len(faces) == 1:
                    segments[-1][1].append(score)
            cv2.rectangle(frame, (x, y), (x + fw, y + fh), (0, 255, 0), 2)
            cv2.putText(frame, txt, (x, y - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        status = (f"REC seg {len(segments)} {label} n={len(segments[-1][1])}" if rec_on and len(faces) == 1
                  else "hold o / s / p to record" if owner is not None else "press e to enroll")
        cv2.putText(frame, status, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2)
        cv2.imshow("byaku sface_live (in memory only)", frame)

        k = cv2.waitKey(1) & 0xFF
        if k == ord("q"):
            break
        if k == ord("e") and not enroll_until:
            enroll, enroll_until, label = [], now + ENROLL_S, None
            print("enrolling: owner alone, look at the screen")
        elif k in LABELS and owner is not None:
            if not rec_on or LABELS[k] != label:  # a new press after a pause = a new segment
                label = LABELS[k]
                segments.append((label, []))
                print(f"seg {len(segments)}: {label}")
            held_at = now
    cap.release()
    cv2.destroyAllWindows()
    summary(segments)


if __name__ == "__main__":
    main()
