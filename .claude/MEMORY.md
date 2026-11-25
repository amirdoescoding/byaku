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
- 2026-11-25 PR2: SFace passes owner-vs-stranger (bar v2, margin +0.633, threshold 0.437). It converts to CoreML (onnx2torch route) with exact parity. Run it with `.cpuAndNeuralEngine`, because `.all` wakes the GPU (+0.1 W). Embed cost is ~20–25 mW at 1 Hz.
- Pre-register pass bars in a commit before collecting data. Live labelling is error-prone: the owner holding a phone photo gets scored as the "stranger".
- Workflow: one PR per session. Stop after each PR for the user's OK, and the context gets cleared between PRs.
