# Backlog

## Next (pick one per PR)
- [ ] Swift 5-point alignment (Vision landmarks → SFace template), checked against OpenCV alignCrop (cosine > 0.98); then re-run the live owner match in Swift
- [ ] Menu-bar app skeleton (impeccable) + in-app enrollment
- [ ] Optional: `scripts/power.sh 3 120 "1" "--embed ml/models/sface.mlpackage"` battery row (rails already show ~+20–25 mW)

## Done: PR2 owner match (2026-11-25)
- [x] `ml/` uv project; `sface_live.py` with bar v2 PASS (margin +0.633, threshold 0.437)
- [x] `convert_sface.py`: onnx2torch route, three-way parity 1.0000
- [x] `byaku embed` + `detect --embed`: Swift parity, placement, latency; CPU+ANE instead of `.all` (GPU +0.1 W)
- [x] Vision feature-print baseline: dropped (SFace passes; a fair test needs a Swift live loop)

## Done: v0 spike PR1 (2026-11-25)
- [x] SwiftPM skeleton; build + swift-testing work with Command Line Tools only
- [x] Camera → Vision face count + yaw/pitch (verified: 0/1/2 faces with a photo)
- [x] Power table (ARCHITECTURE): ~0.3–0.4 W at 1–2 fps
- [x] Lock: SACLockScreenImmediate verified on macOS 15.6; camera runs while locked

## Pipeline
- [ ] Owner enrollment + embedding match (SFace → CoreML)
- [ ] Swift 5-point face alignment (Vision landmarks → SFace template), checked against OpenCV alignCrop (cosine > 0.98)
- [ ] Gaze v0: yaw/pitch thresholds
- [ ] Policy: debounce N-of-M, cooldown, adaptive fps

## Actions
- [ ] Guard: banner, dim overlay (all displays, click-through)
- [ ] Away: manual arm, loud sound + lock, fail closed; owner face suppresses but never disarms (disarm = click)
- [ ] Opt-in auto-arm for Away (off by default; revisit after a week of manual use)

## App
- [ ] Menu-bar UI + settings (impeccable)
- [ ] `.app` bundle with NSCameraUsageDescription, signing
- [ ] Whitelist consent + privacy: store embeddings only (never photos), consent wording, per-person delete
- [ ] CI is live once this PR lands (build + test on macos-15); verify the first run

## ML (`ml/`)
- [ ] Gaze dataset + trained looking/not-looking classifier

## Ideas (later)
- Away "who looked" log: times and counts only, never images
- Frosted-glass Guard overlay (measure power first)
- Per-window blur of sensitive apps
- Context-aware strictness (home Wi-Fi vs train)
