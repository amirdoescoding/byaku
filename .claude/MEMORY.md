# Memory: key facts & decisions

- 2026-11-25: byaku = macOS menu-bar shoulder-surfer detector. Guard mode (banner/dim) + Away mode (sound + lock).
- **Power is the #1 priority.** Hence Swift + Vision/CoreML (ANE), not Python + OpenCV (CPU).
- Python only lives in `ml/` (uv) for model eval, conversion and training. It is never shipped.
- macOS first. MIT license.
- Impeccable stays for UI. `DESIGN.md` and `PRODUCT.md` live at the repo root because impeccable reads them there.
- Only Xcode Command Line Tools are installed (no Xcode). This may matter for XCTest and app bundling.
- Prior art: EyesOff (YuNet + ~300k-param gaze classifier, ~1.5 W on M2 Air). CompreFace was rejected as too heavy.
