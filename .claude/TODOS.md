# Backlog

## Next (pick one per PR)
- [ ] `.app` bundle (Info.plist, NSCameraUsageDescription, LSUIElement, model in Resources, menu-bar PDF + .icns); split a library target then
- [ ] Verify the violet icon on a light menu bar (picks from the drawing appearance; spec wants `button.effectiveAppearance`)
- [ ] Optional: `scripts/power.sh 3 120 "1" "--embed ml/models/sface.mlpackage"` battery row (rails already show ~+20–25 mW)

- [ ] Yawed-face owner match in Swift (margin +0.228 vs Python +0.633; −30° worst). Try: landmarks on a tighter or upright crop, a different
      eye/nose mapping judged by pixel error on real yawed faces, or multi-pose enrollment. Pre-register before re-running.

- [ ] Verify Vision rev-3 yaw/pitch are continuous (turn head under `byaku detect`); tune the ±30°/±25° gaze gate with a second person
- [ ] Power: `scripts/power.sh` row with Guard on + one face (whole system); scroll baseline without the overlay
- [ ] Away alarm: loud SFX + "byaku spotted a threat!" voice + looping sound; needs a redistributable audio source (Epidemic's licence doesn't allow bundling)
- [ ] Guard sound: replace `Submarine` once a licence-clean file exists

## Done: PR6 Guard actions (2026-11-26)
- [x] Spec + mockups approved (Mode ladder Whisper/Iris/Shade/Awaken, banner with rotating line, Lift for now)
- [x] Gaze gate before embedding, every facing face embedded, 2-of-3 debounce; unit tests
- [x] BannerPanel (AnchoredPanel shared with EnrollPanel), PanelButton `.close`, WatchOverlay per screen
- [x] Live: × first click, lines rotate, cleared on lock, mist scaled per screen; GPU held ≈ 0 (gradient strips)
- [x] DESIGN.md §3/§5/§8/§11 + palette exception (impeccable-documenter); finish-reviewer skipped (no screen capture, user's call)
- [ ] Leftover: banner/overlay over a full-screen app and Reduce Motion not checked live

## Done: PR4 brand (2026-11-25)
- [x] Round 1 exploration (6 symbols × 3 weights, 5 faces, 4 violets) → E2 + Rondel 500 + iris/dusk
- [x] Final SVG set, palette.md (computed contrast), app icon, menu-bar template, philosophy.md
- [ ] Export the app icon to `.icns` and the menu-bar template to PDF when the app target exists

## Done: PR5 menu-bar app (2026-11-25)
- [x] Spec + mockups (approved), `byaku app`: icon states, menu, face setup panel, Guard on/off, delete
- [x] Typed components + Tokens.swift + `scripts/check-ui.sh` in CI; 2 review agents, 21 fixes
- [x] Live: owner setup, photo → alert, dark-mode panel
- [ ] Leftovers (low): panel shadow during scale-in; button-row overflow under localisation; enrollment threshold (10 frames) to tune

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
- [x] Owner match in the app; every facing face embedded (PR6)
- [x] Gaze v0: yaw/pitch thresholds (PR6, provisional)
- [x] Debounce N-of-M (PR6)
- [ ] Adaptive fps (burst on suspicion)

## Actions
- [x] Guard: banner, Iris/dim overlay (all displays, click-through) (PR6)
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
