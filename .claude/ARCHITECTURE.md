# Architecture

Status: **v0 spike CLI exists** (`Sources/Byaku`: `detect`, `lock-test`). The app pipeline below is still planned.

## Pipeline

```
AVCaptureSession (low res ~640×480, adaptive 1–5 fps)
        │  CVPixelBuffer, in memory only
        ▼
Detect: Vision VNDetectFaceRectanglesRequest (ANE)
        │  faces[] with bbox, yaw, pitch, roll
        ▼
Owner: is this face the enrolled owner?
        │  SFace embedding (CoreML) vs stored embedding, cosine threshold
        │  cheap path first: largest, most central face = owner candidate
        ▼
Gaze: is this non-owner face looking at the screen?
        │  v0: yaw/pitch thresholds from VNFaceObservation
        │  v1: small trained CoreML classifier on face crops (see ml/)
        ▼
Policy: debounce (N of last M frames), cooldown, mode
        ▼
Actions
  Guard: banner, dim overlay
  Away:  loud sound + lock
```

## Modes

| Mode | Who counts as a threat | Actions | Failure behavior |
|------|------------------------|---------|------------------|
| Guard | Any non-owner face looking at the screen | Banner and/or dim (configurable) | Fail open: stop guarding and show an icon state |
| Away | **Any** face looking, the owner included unless re-verified | Sound + lock | **Fail closed: lock** |

## Actions

- **Banner**: a non-activating panel or notification.
- **Dim**: a borderless, click-through `NSWindow` at screen-saver level on every display. Opacity is configurable.
- **Sound**: `NSSound` / `AVAudioPlayer` at full volume.
- **Lock**: an **open risk**, to be settled in the spike. `SACLockScreenImmediate` is a private API (it may break or be
  rejected). `pmset displaysleepnow` only locks if "require password immediately" is on. Pick a method, verify that it
  really locks, and document the result here.

## Planned layout

```
Package.swift
Sources/Byaku/
  Capture/   AVCaptureSession, frame-rate control
  Detect/    Vision face detection
  Owner/     enrollment + embedding match
  Gaze/      looking-at-screen decision
  Policy/    debounce, modes, cooldown
  Actions/   banner, dim, sound, lock
  UI/        menu bar, settings
  Settings/  UserDefaults-backed settings
Tests/
ml/          uv project: eval, conversion, training (not shipped)
```

## Power tactics

Most of the savings come from the pipeline, not the language.

- Use the lowest camera preset that still detects faces at ~2 m, and set the frame rate on the device rather than dropping frames.
- Adaptive rate: ~1 fps when only the owner is visible, bursting to ~5 fps when a new face appears.
- Skip owner matching and gaze checks when only one face is present and it matches the last owner track.
- Keep everything on the ANE (Vision, CoreML). No CPU inference loops.
- Measure each change with `powermetrics`, and log the numbers here.

## Decision log

| Date | Decision | Why |
|------|----------|-----|
| 2026-11-25 | Swift app + Python `ml/` tooling (not Python+OpenCV) | Power is the top priority. OpenCV DNN runs on the CPU only, while Vision/CoreML use the ANE. EyesOff reaches ~1.5 W natively |
| 2026-11-25 | Apple Vision for detection instead of YuNet ONNX | Built in, runs on the ANE, no model to ship, and exposes yaw/pitch |
| 2026-11-25 | SFace (opencv_zoo) as the owner-embedding candidate | Small and MIT-friendly. Needs CoreML conversion |
| 2026-11-25 | CompreFace rejected | A Docker server is far too heavy for a menu-bar app |
| 2026-11-25 | macOS first, MIT license | Focus |
| 2026-11-25 | Lock = private `SACLockScreenImmediate` (dlopen `login.framework`), `pmset displaysleepnow` fallback | Spike: `locked=true` on macOS 15.6 / M1, verified by `CGSSessionScreenIsLocked` and a password prompt on unlock |
| 2026-11-25 | Away: the owner's face suppresses triggers but never disarms; disarm is an explicit click | A photo of the owner would match SFace; no liveness check needed in v1 |
| 2026-11-25 | Camera keeps delivering frames while the screen is locked | Spike: 300 frames in 10 s while locked, so Away can keep watching after it locks |
| 2026-11-25 | M1 FaceTime HD has only fixed 30 fps formats (640×480, 1280×720) | "Low fps" is a software throttle; the sensor stays at 30 fps |
| 2026-11-25 | Camera + Vision at 1–2 fps costs ~0.3–0.4 W whole-system on M1, well under the 1.5 W budget; duty-cycling not needed yet | See power table below |

## Power measurements

`scripts/power.sh`: whole-system draw from the battery (`ioreg` Voltage × InstantAmperage). Conditions: unplugged, fixed brightness, 3 × 120 s alternating runs, powermetrics not running. M1, macOS 15.6.1, 2026-11-25, `byaku detect` release build. The sensor stays at 30 fps in every row.

| Setting | Processed fps | Mean ± sd (W) | Δ vs idle, all runs | Δ vs idle, runs 2–3 |
|---------|---------------|---------------|---------------------|---------------------|
| idle | – | 7.386 ± 0.547 | 0 | 0 (idle 7.00) |
| detect 1 fps | 1.0 | 7.146 ± 0.193 | −0.24 | +0.28 |
| detect 2 fps | 1.9 | 7.397 ± 0.018 | +0.01 | +0.39 |
| detect 5 fps | 4.5 | 7.727 ± 0.413 | +0.34 | +0.95 |

The idle sample in run 1 (8.16 W) looks like warm-up from the release build that had just compiled. It inflates the idle sd, so the run 2–3 column is the more honest read.

Takeaway: camera + Vision costs roughly 0.3–0.4 W at 1–2 fps and roughly 1 W at 5 fps. Noise is about ±0.5 W. All settings fit the 1.5 W budget, so keep a ~1–2 fps baseline and burst to 5 fps only briefly.

## Open risks

- **Model conversion route.** coremltools no longer ships an ONNX frontend. The likely route is ONNX → onnx2torch → coremltools.
  Settle it in the `ml/` spike.
- **Camera permission (TCC)** needs a `.app` bundle with `NSCameraUsageDescription`. Only Command Line Tools are
  installed, not Xcode. SwiftPM builds work, but bundling and signing may need Xcode or a bundling script.
- **Gaze accuracy.** Yaw/pitch thresholds alone will false-positive on people looking near the screen. EyesOff
  trained a custom ~300k-parameter classifier on ~80k images.

## Prior art

- EyesOff ([blog](https://www.eyesoff.app/blog/how-eyesoff-spots-shoulder-surfers/)): YuNet detection at ~5 fps, a
  custom looking/not-looking classifier, skips the main user's face, on-device, macOS, ~1.5 W on an M2 Air.
- [opencv_zoo face_recognition_sface](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface)
- [CompreFace](https://github.com/exadel-inc/CompreFace) (evaluated, not used)
