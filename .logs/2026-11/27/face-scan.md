# PR B1 guided face scan (2026-11-26 → 27)

**What happened**
- Planned the scan with the user over 4 question rounds: mask only, hybrid 3D mesh, straight/left/right, fill by
  region, the mascot cueing, collapse into the ring, two PRs.
- Built the mesh tooling (`ml/scan_mesh.py`, `ml/vision_dump.swift`). The Vision→MediaPipe map was derived on the parity
  faces (median error 0.037 IOD).
- Built a live prototype (scripted head + webcam). Iterated with the user three times:
  - the facing-based fill lit almost everything, so it became region thirds
  - a full turn failed, so the side ceiling was removed
  - added expressions and the camera-first intro, slowed into three beats
- Ported to Swift: `ScanView`, `ScanPose` with tests, `Camera.onLandmarks`, both hosts.
- The advisor caught a late-fail cliff (too few prints on a slow camera), fixed with a print-count gate and a test.

**Self-rating:** 7/10.
- The design loop worked: the user tuned it live.
- Not verified on hardware: turn direction, the camera beat, pitch sign, panel layout, owner match after a rescan.
- The bundle build ran in the background past the advisor check.
