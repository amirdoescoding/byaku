# Backlog

## Next: v0 spike
- [ ] SwiftPM package skeleton (`Package.swift`, `Sources/Byaku`, `Tests`); confirm `swift build`/`swift test` work with Command Line Tools only
- [ ] Camera → Vision face count + yaw/pitch printed in the terminal
- [ ] Measure baseline power with `powermetrics` at 1 fps and 5 fps
- [ ] Pick and verify the lock method (see ARCHITECTURE open risks)

## Pipeline
- [ ] Owner enrollment + embedding match (SFace → CoreML)
- [ ] Gaze v0: yaw/pitch thresholds
- [ ] Policy: debounce N-of-M, cooldown, adaptive fps

## Actions
- [ ] Guard: banner, dim overlay (all displays, click-through)
- [ ] Away: loud sound + lock, fail closed

## App
- [ ] Menu-bar UI + settings (impeccable)
- [ ] `.app` bundle with NSCameraUsageDescription, signing
- [ ] CI (build + test on macOS runner)

## ML (`ml/`)
- [ ] uv project; settle the ONNX → CoreML conversion route
- [ ] Gaze dataset + trained looking/not-looking classifier
