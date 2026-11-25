# DESIGN

byaku's UI principles. The full token system is written by `impeccable-documenter` after the first UI build.

1. **Native macOS.** Use SF Symbols, system fonts and system colors, and respect light/dark mode and Reduce Motion.
2. **Menu bar first.** One icon whose state (off / guarding / away / alert / error) is readable at a glance.
3. **Guard is calm.** The banner and dim are discreet, so a shoulder-surfer shouldn't notice them. No sound.
4. **Away is loud.** It's the only mode allowed to be alarming.
5. **Never trap the user.** The dim overlay is click-through, and a menu-bar click or shortcut dismisses it.
6. **Accessibility.** VoiceOver labels on every control. Never rely on color alone for state.
7. **Privacy is visible.** Show when the camera is active, and never show a camera preview unless the user asks.
