# Memory: key facts & decisions

- 2026-11-25: byaku = macOS menu-bar shoulder-surfer detector. Guard mode (banner/dim) + Away mode (sound + lock).
- **Power is the #1 priority.** Hence Swift + Vision/CoreML (ANE), not Python + OpenCV (CPU).
- Python only lives in `ml/` (uv) for model eval, conversion and training. It is never shipped.
- macOS first. MIT license.
- Impeccable stays for UI. `DESIGN.md` and `PRODUCT.md` live at the repo root because impeccable reads them there.
- Only Xcode Command Line Tools are installed (no Xcode). swift-testing works and XCTest is absent. There's no `coremlcompiler`, so models compile at runtime.
- Prior art: EyesOff (YuNet + ~300k-param gaze classifier, ~1.5 W on M2 Air). CompreFace was rejected as too heavy.
- 2026-11-25 spike: the lock is `SACLockScreenImmediate` (verified on 15.6). The camera keeps running while locked. The M1 FaceTime camera is fixed at 30 fps, so low fps is a software throttle. Detect costs ~0.3–0.4 W at 1–2 fps.
- Away v1: manual arm. The owner's face suppresses triggers but never disarms (photo spoof). Disarm is a click.
- Owner-match plan: test SFace with OpenCV Python first, then convert to CoreML with a parity check (PR2).
- Workflow: one PR per session. Stop after each PR for the user's OK, and the context gets cleared between PRs.
