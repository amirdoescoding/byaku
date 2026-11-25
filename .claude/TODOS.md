# Backlog

## Next (pick one per PR)
- [ ] Menu-bar app skeleton (impeccable) + in-app enrollment
- [ ] Optional: `scripts/power.sh 3 120 "1" "--embed ml/models/sface.mlpackage"` battery row (rails already show ~+20–25 mW)

- [ ] Yawed-face owner match in Swift (margin +0.228 vs Python +0.633; −30° worst). Try: landmarks on a tighter or upright crop, a different
      eye/nose mapping judged by pixel error on real yawed faces, or multi-pose enrollment. Pre-register before re-running.

## Done: PR3 Swift alignment (2026-11-25)
- [x] Similarity solve + bilinear warp; warp parity 1.00000 vs alignCrop (`byaku align`)
- [x] Vision landmarks → 5 points on the live path (32BGRA); landmark parity reported (FAIL 0.98, weak proxy)
- [x] `byaku match` + `ml/score_segments.py`: Swift live bar v2 PASS (+0.228, threshold 0.300)
- [x] Rails: GPU 8 / ANE 17 / CPU 100 mW, ≲ +10 mW vs unaligned

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
- [ ] Owner enrollment + embedding match in the app (Swift path works in `byaku match`); embed every face, not just the largest
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
