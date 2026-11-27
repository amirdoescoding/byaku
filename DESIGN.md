# DESIGN

byaku's UI principles. The full token system is written by `impeccable-documenter` after the first UI build.

1. **Native macOS.** Use SF Symbols, system fonts and system colors, and respect light/dark mode and Reduce Motion.
2. **Menu bar first.** One icon whose state (off / guarding / away / alert / error) is readable at a glance.
3. **Guard is calm by default.** The default mode is Iris + banner. Shade and Awaken dim the screen and deliberately
   signal *seen* to the looker. Sound is opt-in and off by default: one macOS system sound per alert, never repeated.
4. **Away is loud.** It's the only mode allowed to be alarming.
5. **Never trap the user.** The overlay ignores the mouse and keys by design and sits below the menu bar.
   "Lift for now" (⌘L, in the menu only during an alert) or turning Guard off clears it. The banner's × closes the
   banner until the next separate alert.
6. **Accessibility.** VoiceOver labels on every control. Never rely on color alone for state.
7. **Privacy is visible.** Show when the camera is active, and never show a camera preview unless the user asks.
   The one exception is the face scan, which the user starts: the mirrored, monochrome camera shows only until the
   mask has formed over it, then the sweep wipes it away and it never returns. Nothing is recorded.
8. **Brand.** The symbol, wordmark, palette and app icon live in `design/brand/` (see `philosophy.md` and `palette.md`).
   The menu bar uses `final/menubar-template.svg` as a template image. Violet means *seen*: in the app it marks only
   the symbol and the "someone is looking" state. Violet is never a gradient or a glow, with one exception: the Iris
   mist (§11) is the single sanctioned violet gradient (recorded in `palette.md` too).
9. **Menu bar as shipped** (spec: `docs/designs/menubar.md`, mockups: `design/menubar/`). The full mark stays in every state.
   - Off: ink (template).
   - Guarding: violet.
   - Alert: violet + centre dot.
   - Error: ink + diagonal cut.
   - Away (arming + armed): violet solid iris (the ring's disc filled, blades knocked out). Spec: `docs/designs/away-mode.md`.
   - Alarm: as Alert (the screen is locked).

   Off vs Guarding differ by colour only. The user accepted this; the VoiceOver label, status line and camera dot cover it.
   **Away** (⌘A) sits under Guard, followed by the Alarm volume slider (Control Center style, 25–100%, silent on release), "Alarm sound ▸" (Siren + macOS sounds; the menu stays open and each pick plays 1.5 s) and "Message…" (record panel); while armed, Guard (checked), Alarm sound, Message, Mode, Banner, Sound and face setup/delete are greyed.
   The last menu section is **Open at login** (a checkmark like Banner/Sound, shown only in `Byaku.app`) then **Quit byaku**.
10. **Motion.**
    - Anything a trigger opens grows from that trigger.
    - Ease-out only. Transitions take 300 ms or less; the countdown and spinner show time, so they run longer.
    - Buttons respond on press.
    - Colours and timings live only in `Sources/Byaku/Tokens.swift`; `scripts/check-ui.sh` enforces this in CI.
11. **Guard alert as shipped** (spec: `docs/designs/guard-actions.md`, mockups: `design/guard/`).
    - Mode ladder: Whisper (banner only), Iris (violet edges, default), Shade (dim), Awaken (dim + edges).
      Banner is a separate checkmark (default on) and applies to every mode.
    - Banner: 320 × 64 pt `surface` panel under the status item, alert mark in `accent`, one rotating body line per
      alert that never changes while shown. It never takes focus.
    - Iris mist: four `accent` gradient strips fading inward from each edge, depth 5% of screen width, no rim.
      Dim: black at `dimAlpha`.
    - Window levels: overlay `.statusBar`, banner `.statusBar + 1`, the menu above both.
    - Power: no live blur or shadow on full-screen overlays. Use pre-drawn gradients; a held alert must cost ~0 GPU
      (the strips measured 2–4 mW vs a 1–5 mW baseline; the old blurred shadow cost +13 mW).
    - Nothing pulses while an alert is held. Reduce Motion: fade only.
12. **Onboarding as shipped** (spec: `docs/designs/onboarding.md`, mockups + motion prototype: `design/onboarding/`).
    - First launch and "Welcome tour…": welcome → face (skipped if saved) → tour on the real menu → founder video.
    - The mark is the mascot: the ring is still, the blades are eyebrows (raise, frown, focus, look, blink, stressed).
      Violet stays the mark's colour; at the video's corner the mark turns ink.
    - The tour never fakes the menu: the real NSMenu opens and a click-through coach bubble sits beside it.
    - Springs (CASpringAnimation, retargeting) carry every move. A flight is travel, so it may settle a little past 300 ms.
    - Sounds are synthesised (whoosh, brow flick). Reduce Motion: snaps and fades, no blink, no flight.
13. **Face scan as shipped** (spec: `docs/designs/face-scan.md`, prototype + sheets: `design/scan/`).
    - It's the same `ScanView` in onboarding and in the Set up face panel. The sequence: the camera alone, then the mask
      fades on over it, then the sweep wipes the camera away. Then straight → left → right, each held 1 s.
    - The mask is the user's face in geometry: a low-poly wireframe (ink) that follows the head and the expressions.
      A held pose's third fills from the inside out and turns violet once captured (violet = *seen*). At the end, the
      mask collapses into the mascot's ring.
    - Exception to §10's 300 ms limit: the sweep (0.9 s), the camera hold and the collapse show progress, like the
      countdown did. Reduce Motion: cross-fades, and the mask still tracks the head.
14. **Site** (`site/`, Astro static + React islands; mockups + motion prototype: `design/site/`).
    - Brand tokens from `design/brand/palette.md` as CSS variables (`site/src/styles/global.css`); follows the system theme.
      Rondel for headlines and the wordmark, Beacon (variable) for body. One violet use per screen: the roaming mascot.
    - Hero "Pale Watch": a centred mascot that watches the pointer, then "Know who's looking." and Download.
    - Download docks into a bottom-centre pill (FLIP spring) once the hero button scrolls out. A mono mini mascot in
      the pill emotes: hover = happy, press = joy.
    - The violet mascot roams the side gutters (only when a gutter is ≥ 130 px wide), never rests on text, changes
      expression per section (idle, raised, focus, calm, look, frown, happy, joy), and hops away when clicked.
      rAF stops when the tab is hidden. Reduce Motion: it stays still.
    - The Guard demo is a live `@remotion/player` (loads when scrolled into view): a flat 2D Mac with the real mode
      ladder (Whisper / Iris / Shade / Awaken) and a Guard ↔ Away switch. No sound.
    - Components are hand-restyled Radix (the shadcn pattern): no default shadows, focus ring = accent 2 px.
