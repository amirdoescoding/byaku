# DESIGN

byaku's UI principles. The full token system is written by `impeccable-documenter` after the first UI build.

1. **Native macOS.** Use SF Symbols, system fonts and system colors, and respect light/dark mode and Reduce Motion.
2. **Menu bar first.** One icon whose state (off / guarding / away / alert / error) is readable at a glance.
3. **Guard is calm.** The banner and dim are discreet, so a shoulder-surfer shouldn't notice them. No sound.
4. **Away is loud.** It's the only mode allowed to be alarming.
5. **Never trap the user.** The dim overlay is click-through, and a menu-bar click or shortcut dismisses it.
6. **Accessibility.** VoiceOver labels on every control. Never rely on color alone for state.
7. **Privacy is visible.** Show when the camera is active, and never show a camera preview unless the user asks.
8. **Brand.** The symbol, wordmark, palette and app icon live in `design/brand/` (see `philosophy.md` and `palette.md`).
   The menu bar uses `final/menubar-template.svg` as a template image. Violet means *seen*: in the app it marks only
   the symbol and the "someone is looking" state.
9. **Menu bar as shipped** (spec: `docs/designs/menubar.md`, mockups: `design/menubar/`). The full mark stays in every state.
   - Off: ink (template).
   - Guarding: violet.
   - Alert: violet + centre dot.
   - Error: ink + diagonal cut.

   Off vs Guarding differ by colour only. The user accepted this; the VoiceOver label, status line and camera dot cover it.
10. **Motion.**
    - Anything a trigger opens grows from that trigger.
    - Ease-out only. Transitions take 300 ms or less; the countdown and spinner show time, so they run longer.
    - Buttons respond on press.
    - Colours and timings live only in `Sources/Byaku/Tokens.swift`; `scripts/check-ui.sh` enforces this in CI.
