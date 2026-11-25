# AGENTS.md

Instructions for any coding agent (Claude Code, Codex, Cursor, …) working on byaku.

## What byaku is

byaku is an open-source macOS menu-bar app that uses the webcam to detect when someone other than you is
looking at your screen. All processing happens on the device.

- **Guard mode** (you are at the computer): a looker triggers a banner and/or dims the screen. Both are configurable.
- **Away mode** (you stepped away): any looker triggers a loud sound and locks the computer.

Read `README.md` for the product and `.claude/ARCHITECTURE.md` for the pipeline and decisions.

## Stack

| Part | Tech | Why |
|------|------|-----|
| App | Swift, SwiftPM, AppKit menu bar | Native, lowest power |
| Camera | AVFoundation (`AVCaptureSession`) | Exact control of resolution and frame rate |
| Face detection | Apple Vision (`VNDetectFaceRectanglesRequest`) | Runs on the Neural Engine; no model to ship |
| Owner match / gaze | CoreML | Neural Engine |
| Model tooling | Python in `ml/`, managed by `uv` | Evaluate, convert and train models only; never shipped |

macOS first. Other platforms are not planned yet, so don't add cross-platform abstractions.

## Commands

Verified on an M1 with Command Line Tools only (no Xcode). `swift test` runs swift-testing.

```sh
swift build                           # build the spike CLI
swift test                            # swift-testing unit tests
.build/debug/byaku detect --fps 2     # built-in camera → face count, yaw, pitch; prints delivered/processed fps
.build/debug/byaku lock-test          # LOCKS THE SCREEN; verifies the lock and camera-while-locked
scripts/power.sh                      # unplugged: whole-system W vs idle, 3×120 s alternating
.build/debug/byaku detect --fps 1 --embed ml/models/sface.mlpackage   # + SFace on the largest face (power runs only)
.build/debug/byaku embed ml/models/sface.mlpackage ml/models/parity  # Swift parity vs Python, ANE placement, latency
(cd ml && uv run convert_sface.py)    # fetch models, SFace ONNX → CoreML, three-way parity assert (cv2/ORT/CoreML)
(cd ml && uv run sface_live.py)       # live owner vs stranger scoring, pre-registered pass bar (camera)
graphify query "<question>"           # ask the knowledge graph (see below)
```

Camera permission belongs to the app that launches the CLI (Terminal, VS Code), not to the binary.

## Invariants (never break these)

1. **Frames never leave the device and never touch disk.** No frame logging, no screenshots, and no debug dumps in release builds.
2. **No network calls** from the app. Models are bundled.
3. **Power budget**: target ≤ ~1.5 W extra while guarding on Apple silicon. Every pipeline change states its power impact, measured whole-system on battery with `scripts/power.sh` (includes the camera). For a per-rail breakdown, use a separate `sudo powermetrics --samplers cpu_power,gpu_power,ane_power` run.
4. **Away mode fails closed.** If the camera or pipeline errors in Away mode, lock the screen.
5. **Owner data** (face embedding) stays in the user's Keychain or Application Support, and the user can delete it with one click.

## Context via graphify (read first)

The knowledge graph lives in `graphify-out/`, which is gitignored. Build it locally with `/graphify .`.

- Before a task, query it: `graphify query "<question>"`, `graphify path "<A>" "<B>"`, `graphify explain "<node>"`.
  Read only the files it points to. `graphify-out/GRAPH_REPORT.md` gives the broad overview.
- After code changes, run `graphify update .`. It is AST-only and free, and the git hooks run it too.
  After doc changes, run `/graphify . --update`.
- Noise is excluded in `.graphifyignore`.

## Git

- One branch per feature (`feat/…`, `fix/…`, `chore/…`). Never commit to `main`.
- Small, focused commits with conventional prefixes.
- Never commit models (`*.onnx`, `*.mlpackage`, `*.mlmodel`), secrets, or anything in `graphify-out/`.

## How to work

### 1. Think before coding
Don't assume, don't hide confusion, and surface tradeoffs. State your assumptions. If there are several
interpretations, present them. If a simpler approach exists, say so. If something is unclear, stop and ask.

### 2. Simplicity first
Write the minimum code that solves the problem. No speculative features, no single-use abstractions, no
configurability nobody asked for, and no error handling for impossible cases. If 200 lines could be 50, rewrite it.

### 3. Surgical changes
Touch only what you must. Match the existing style. Don't refactor what isn't broken. Remove only the
orphans your own change created, and mention other dead code instead of deleting it.

### 4. Goal-driven execution
Turn each task into a verifiable goal, then loop until it is verified:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
```

For the detection pipeline, "verified" means it was tested on a real camera with a second person or a photo,
not only in unit tests.

## Session close

1. Write a recap and self-rating to `.logs/YYYY-MM/DD/<slug>.md`.
2. Update `.claude/MEMORY.md` with key facts and decisions.
3. Update `.claude/RESTART.md` with what you were doing and where you stopped.
4. Update `.claude/TODOS.md` with everything still left to do.
5. Update `.claude/ARCHITECTURE.md` if the structure changed.
