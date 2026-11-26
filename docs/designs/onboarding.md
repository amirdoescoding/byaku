# Onboarding (as shipped, v0.1)

The first-run flow for the public release. Mockups are in `design/onboarding/` (`mockups.html`, `sheet-*.png`). The motion
prototype is `design/onboarding/motion.html`, whose springs and timings were ported 1:1 to `Tokens.Onboarding`.
Code: `Sources/Byaku/Onboarding.swift`, wired from `App.swift`.

## When it shows

- On first launch, when the `onboarded` default is unset, and from **Welcome tour…** in the menu (above Open at login).
- Done, ×, or Esc at any step sets `onboarded` and ends it. Ending stops the camera, the timers, the player and the overlay,
  so nothing runs afterwards.
- The window is borderless, 480 × 360 pt, `surface`, and floating. An accessory app can't take focus from the front app
  under macOS 14 cooperative activation, so a normal-level window opened behind the editor.

## The mascot

The brand mark (`symbol-dark.svg`, 64-unit space) is a character. The ring never moves. The two blades are eyebrows: each
rotates about its outer base and scales about its own centre.

| Expression | Pose (degrees, SVG units) | Spring (stiffness / damping) | Used for |
|---|---|---|---|
| rest | 0 | 300 / 26 | default |
| raise | a −9°, ty −2.5, tx −0.6 | 380 / 22 | face saved, arriving at the menu, the outro smile |
| frown | a +16°, ty +2.5, tx +0.8 | 220 / 28 | scan failures |
| focus | a +5°, ty +3, sx 0.78 | 260 / 30 | scanning |
| look(dx, dy) | group (1.8dx, −1.8dy), r 3.5dx | 300 / 26 | toward the menu bar (↗), toward the menu (→) |
| blink | scaleY 1 → 0.12 → 1, one 0.2 s keyframe | — | every 2–3.5 s while shown, including during the tour |
| stressed | raise, frown, focus, look ↗, look ← … every 0.15 s × 8, then frown | — | tour: no hover for 6 s |

- Springs retarget from the presentation value, so changing expression mid-motion never jumps.
- The blink is a single keyframe, not two timed springs: main-queue blocks don't run while a menu is open.
- Reduce Motion: poses snap with a 150 ms cross-fade, and there is no blink, no stress and no flight (fade, jump, fade).

## Steps

1. **Welcome**: the mascot (blinking), "byaku watches who's looking.", and [Start].
2. **Face** (skipped when a face is already saved):
   - An intro, "First, your face", with [Skip] [Scan my face].
   - Then AppController's own 5 s enrollment, with `showEnroll` routing its phases to the window and the same words as the
     Set up face panel (`EnrollPanel.copy`). The countdown digit sits under the mascot. No camera preview (that is PR B).
   - Focus while counting, raise + flick when saved, frown + flick on failure. A screen lock mid-scan returns to the intro.
3. **Tour**:
   - "Here's the menu." [Skip] [Show me]. The mascot looks up-right. The full-screen `CoachOverlay` (level `.popUpMenu + 1`,
     click-through) is built invisibly here, because building it on the press made the first flight stutter.
   - Show me: the window fades, and the mascot whooshes along an arc (x leads, y lags) to beside the status item. The real
     menu opens 0.25 s after the press. The mascot raises its brows (flick), then faces the menu and blinks.
   - The bubble (288 × 76, notch on its right edge) sits 14 pt left of the menu, centred on the hovered row (the pointer's
     y). It shows the item name and shortcut, one line, and "N of M · Click anywhere to finish".
   - Copy lives in `CoachOverlay.coach`, keyed by item title. The volume slider, the Mode submenu entries and Welcome tour…
     aren't counted.
   - Unvisited-row dots from the mockups were cut: a native NSMenu can't draw in its gutter without custom views for every row.
4. **Founder video** (`founder.mp4`, bundled):
   - From the tour, the mascot flies straight from the menu bar into the lockup. The window is resized to 680 × 424
     while invisible, then fades in. The handoff waits for the flight springs to settle, then cross-fades (0.12 s) to the
     window's own 84 pt mascot, which is placed by frame.
   - From Skip, the ring draws on, the blades wake (raised → rest, flick), it blinks, and the wordmark rises.
   - Lockup proportions come from `lockup-dark.svg`: wordmark 0.917 × mark height, starting at 1.364 × mark.
   - Then the wordmark fades and the mark whooshes into the frame's top-right (28 pt, ink) as the corner logo, while the
     video grows in (`AVPlayerView`, floating controls).
   - At the end: a `surface` scrim (0.92) over the last frame, the mark whooshes back to centre in accent, blinks and smiles,
     and "Thanks for trying byaku." arrives with [Replay] [Contribute on GitHub] [Done] (60 ms stagger). It never ends on an empty card.
   - Without the file (a terminal run), the step is skipped.

## Sound

`Sfx` synthesises everything in code, as the siren is, with no audio files (Epidemic Sound can't be bundled in this MIT repo).
- Whoosh: noise through a two-pole low-pass swept 300 → 3000 Hz (in, peak late) or back (out, peak early), 0.42 s, peak 0.22.
- Flick: a 70 ms soft tick gliding up (brows raise) or down (brows drop), peak 0.16.

All four are rendered once to WAV `NSSound`s when the flow starts (`Sfx.prewarm`), so the first one plays on the press.

## Founder video file

`app/founder.mp4` is re-encoded from the 4K HEVC original with `-map 0:v:0 -map 0:a:0 -map_metadata -1` (strips the
iPhone GPS and extra tracks), `scale=1920:-2,fps=30`, `hevc_videotoolbox -q:v 55`, `-tag:v hvc1` and AAC 128k, giving 5.3 MB.

## Power

The camera runs only during the scan step (5 fps × 5 s, as before). After onboarding: no timers, no layers on screen, the
player is released and the overlay is ordered out. Guard's power is unchanged.
