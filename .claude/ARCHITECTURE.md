# Architecture

Status: **v0 spike CLI exists** (`Sources/Byaku`: `detect [--embed]`, `embed`, `lock-test`; `ml/`: SFace conversion + live eval). The app pipeline below is still planned.

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
| 2026-11-25 | Owner matcher = SFace 2021dec, provisional cosine threshold 0.437 | Live bar v2 PASS (margin +0.633), see "Owner match" below |
| 2026-11-25 | Conversion route: ONNX → onnx2torch → `torch.jit.trace` → coremltools 9.0 mlprogram, ImageType RGB raw 0–255, torch pinned 2.7.0 | Three-way parity cv2/ORT/CoreML cosine 1.0000 on 8 public faces; Swift matches too. The model normalises inside ((x−127.5)/128) |
| 2026-11-25 | Run SFace with `.cpuAndNeuralEngine`, not `.all` | `.all` puts the head (BN + 50176→128 linear) on the GPU: +100–130 mW while a face is visible. CPU+ANE: GPU flat, 1.25 ms/embed |
| 2026-11-25 | Vision feature-print baseline dropped | It was expected to lose, and a fair test needs a Swift live loop; SFace already passes |

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

## Owner match (SFace, `ml/sface_live.py`)

M1 FaceTime HD 640×480, OpenCV YuNet + alignCrop, 2026-11-25. Bar v1 (min owner > max stranger) first FAILED at −0.775:
stranger photos were held on a phone with the owner in frame, so the owner was scored as "stranger". Bar v2 was
pre-registered and committed (823003f) before the re-run: p5 of every owner segment > p95 of all strangers.

| Segment | n | p5 | p50 |
|---|---|---|---|
| owner, light A, yaw 0 / +30 / −30 | 93 / 41 / 56 | 0.941 / 0.919 / 0.939 | 0.956 / 0.934 / 0.945 |
| owner, light B, yaw 0 / +30 / −30 | 52 / 45 / 48 | 0.824 / 0.779 / 0.790 | 0.845 / 0.818 / 0.820 |
| owner, glasses on / off | 47 / 44 | 0.747 / 0.838 | 0.762 / 0.850 |
| stranger 1 / 2 (photos) | 59 / 73 | p95 0.125 / 0.032 | 0.084 / 0.002 |
| owner photo (report only) | 55 | 0.715 | 0.738 |

Result: v2 **PASS**, margin +0.633, threshold 0.437, FRR 0% / FAR 0% at that threshold (v1 on this data: PASS, +0.559).
The owner photo matches (0.74), which confirms "owner suppresses, never disarms". Caveats: one owner, two strangers
(photos), frames counted only with exactly one face; the live Swift path uses an unaligned crop until Swift alignment lands.

## Embed cost (powermetrics rails, `detect --fps 1` vs `--embed`, face in view, 60 × 1 s, medians)

| Rail | detect | + embed (CPU+ANE) | + embed (`.all`, before fix) |
|---|---|---|---|
| GPU | ~16 mW | ~16 mW | 100–165 mW while a face is visible |
| ANE | ~15 mW | ~17 mW | ~17 mW |
| CPU | ~70 mW | ~90 mW (noisy) | – |

Placement (`MLComputePlan`, CPU+ANE): 58 ops on the ANE and 4 on the CPU (the linear head). Latency: 1.25 ms (CPU+ANE),
1.5 ms (`.all`), 3.1 ms (CPU only). Embedding at 1 Hz costs ~+20–25 mW, which is below battery-measurement noise.

## Open risks
- **Camera permission (TCC)** needs a `.app` bundle with `NSCameraUsageDescription`. Only Command Line Tools are
  installed, not Xcode. SwiftPM builds work, but bundling and signing may need Xcode or a bundling script.
- **Gaze accuracy.** Yaw/pitch thresholds alone will false-positive on people looking near the screen. EyesOff
  trained a custom ~300k-parameter classifier on ~80k images.

## Prior art

- EyesOff ([blog](https://www.eyesoff.app/blog/how-eyesoff-spots-shoulder-surfers/)): YuNet detection at ~5 fps, a
  custom looking/not-looking classifier, skips the main user's face, on-device, macOS, ~1.5 W on an M2 Air.
- [opencv_zoo face_recognition_sface](https://github.com/opencv/opencv_zoo/tree/main/models/face_recognition_sface)
- [CompreFace](https://github.com/exadel-inc/CompreFace) (evaluated, not used)
