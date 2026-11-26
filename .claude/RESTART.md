# Restart

**2026-11-27**: PR B1 `feat/face-scan` (local commits, not pushed). Guided face scan with a live mesh mask:
- Design: the user OK'd the prototype (`design/scan/prototype.html`, live camera mode) after three rounds: expressions
  follow, no side-band ceiling, and the intro order camera → mask on top → sweep wipes the camera.
- Swift: `ScanView` (onboarding + Set up face panel), `ScanPose` + 6 tests, `ScanMesh.swift` from `ml/scan_mesh.py`,
  `Camera.onLandmarks`, Tokens.Scan. Build, check-ui and 26 tests are green; synthetic-head snapshots looked right.

**Stopped at:** the user's hardware QA (checklist in TODOS "PR B1 hardware QA"). After their OK: push, open the PR, CI.
Then B2 (the multi-pose template behind a pre-registered bar).
