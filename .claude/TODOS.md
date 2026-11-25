# Backlog

## Next: PR2 `feat/v0-owner-match` (plan: `docs/designs/v0-spike.md` steps 6–8)
- [ ] `ml/` uv project + `sface_live.py` (OpenCV FaceRecognizerSF, enroll then score in one run), pre-registered pass bar
- [ ] `convert_sface.py` → CoreML with parity assert (cosine > 0.99 vs onnxruntime, public sample faces)
- [ ] `byaku embed`: runtime compile, ANE placement (MLComputePlan), power with `scripts/power.sh`

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
- [ ] uv project; settle the ONNX → CoreML conversion route
- [ ] Gaze dataset + trained looking/not-looking classifier

## Ideas (later)
- Away "who looked" log: times and counts only, never images
- Frosted-glass Guard overlay (measure power first)
- Per-window blur of sensitive apps
- Context-aware strictness (home Wi-Fi vs train)
