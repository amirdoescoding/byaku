# Guard actions: UI spec (build 2)

Scope: what Guard does when someone else looks. That covers the banner, the edge/dim overlay, sound, and their menu controls.
Away mode stays out of scope. Builds on `docs/designs/menubar.md` (tokens §4, motion §5, components §6).
Mockups: `design/guard/` (`src/mockups.py`). The user approves them before any code.

**Status: approved by the user 2026-11-26 (Mode › Whisper · Iris · Shade · Awaken; edge style A; visible is fine; Lift for now kept; rotating banner line).**

## 1. When an alert fires (pipeline, for context)

- A **looker** is a face facing the screen (|yaw| ≤ 30°, |pitch| ≤ 25°, provisional) that either:
  - scores below the owner threshold, or
  - can't be embedded while 2 or more faces are in view.
- A lone face that can't be embedded never alerts (fail open).
- **Fire**: 2 of the last 3 frames have a looker. At 1 fps that's about 2 s.
- **Clear**: 3 frames in a row with no looker, about 3 s.
- The owner may be absent; a stranger looking still alerts. Sound and lock stay Away-only.

## 2. Menu

The status line and icon states are unchanged from build 1. The row that build 1 reserved under Guard now holds the
level submenu, and two checkmarks follow it.

| # | Item | Copy | Key | Notes |
|---|---|---|---|---|
| 4 | Guard | "Guard" | ⌘G | unchanged |
| 5 | Mode submenu | "Mode" | › | 4 radio items, one checked. Enabled even when Guard is off. |
| 6 | Banner | "Banner" | none | checkmark, default **on** |
| 7 | Sound | "Sound" | none | checkmark, default **off** |

During an alert only, a new row 2 appears: **"Lift for now" ⌘L**. It hides the banner, edges and dim until the next
*separate* alert; the icon stays at Alert while the looker is still there. This is the DESIGN §5 escape hatch, because
the overlay itself ignores keys and the mouse by the user's choice.

All three settings are stored in `UserDefaults`: level, banner and sound.

### 2.1 Levels

Each radio item carries its plain meaning in `NSMenuItem.subtitle` (macOS 14+).

| Level | Title | Subtitle | Layers |
|---|---|---|---|
| 0 | Whisper | banner only | none |
| 1 (default) | Iris | violet edges | edges |
| 2 | Shade | light dim | dim |
| 3 | Awaken | edges + dim | dim + edges |

## 3. Banner

| Property | Value |
|---|---|
| Class | `NSPanel`, borderless, non-activating, level `.statusBar + 1` (above the overlay, below the menu so an open menu covers it); never takes key focus (typing goes on in the user's app) |
| Size | 320 × 64 pt, fixed; under the status item, top 8 pt below the menu bar, clamped 8 pt inside the screen (same as EnrollPanel) |
| Fill | `surface`, 1 pt `line`, 12 pt radius, standard shadow |
| Content | the alert mark at 20 pt in `accent` (the symbol, so violet = seen), 12 pt gap, title 13/20 semibold `ink` "Someone else is looking", body 12/16 `mute`: one of the rotating lines below |
| Close | × at the top right, 24 pt hit area, `mute` → `ink` on hover, pressable. Hides the banner until the next separate alert. VoiceOver label "Close" |
| Lifetime | shown on fire; leaves on clear, on ×, on Lift for now, on Guard off, on lock and on quit |
| VoiceOver | the existing announcement ("Someone else is looking at your screen") covers it. The panel gets no focus. |

**Rotating body line.** Each new alert takes the next line, in order, and wraps around. The line never changes while
an alert is showing, because nothing on the banner moves once it's up.
The lines are "Mind your screen.", "Eyes on your screen.", "Be aware." and "Not your face." Each one must fit on one line
in the 224 pt text column. Store them in an array in the banner component; this is copy, not tokens.

It never shows a camera image or the looker's position.

## 4. Edges and dim (overlay)

- One borderless window per `NSScreen` at `.statusBar` level (below NSMenu at `.popUpMenu` and the banner, so the menu and "Lift for now" stay on top; verify over a full-screen app), `ignoresMouseEvents = true`, `canJoinAllSpaces` + `fullScreenAuxiliary`.
- The window sits **below the menu bar** (frame = `visibleFrame` top edge), so the status item and the menu stay usable.
- Windows are rebuilt on `NSApplication.didChangeScreenParametersNotification`.

| Level | Layers |
|---|---|
| 0 | none |
| 1 | edges |
| 2 | dim: black 40% (provisional) |
| 3 | dim + edges |

**Edge style: A, soft violet mist** (the user's choice, 2026-11-26). It's four `accent` gradient strips fading inward from every edge, 5% of the screen width deep (96 pt on a 1920 pt display, 72 on a 1440 pt laptop); mist only, no border, no blur or shadow (power)
at 70% alpha, coming in from every edge, like an eye activating.
- This is a **deliberate exception** to palette.md ("violet is never a gradient or a glow"). The overlay is the one
  place violet may glow, because it *is* the "seen" moment. palette.md and DESIGN.md record the exception.
- On a light desktop it tints the whole screen violet, which is intended: Iris has to be noticed.

Both styles render static after entry, as a pre-drawn layer, so a held alert costs ~0 GPU.

## 5. Sound

When the Sound checkmark is on, one macOS system sound plays (`NSSound(named: "Submarine")`, provisional) when an alert fires.
It never repeats while the alert holds and nothing is bundled. DESIGN §3 says "No sound" for Guard; that becomes "off by default, opt-in".

## 6. Motion

All of this uses the existing tokens and ease-out only. Prototype: `design/guard/mockups.html` §motion.

| Element | In | Out |
|---|---|---|
| Banner | `enter` 200 ms, opacity + scale 0.96 → 1 from the icon's bottom centre | `exit` 150 ms back into the icon |
| Edges | new `edgeIn` 280 ms: the violet shadow spreads inward from 0 | `exit` 150 ms fade |
| Dim | `enter` 200 ms opacity | `exit` 150 ms opacity |

- Reduce Motion: everything fades only, with no scale and no spread.
- Nothing pulses while an alert is held.

## 7. Components and tokens

- `BannerPanel`: subclass of `AnchoredPanel` (EnrollPanel's present/dismiss-from-anchor code, lifted into a shared base).
- `CloseButton`: a variant of `PanelButton` (role `.close`, clicks through on first press) so hover, press and focus stay in one place.
- `WatchOverlay(mode: Mode)`: `enum Mode: Int { case whisper, iris, shade, awaken }`, one window per screen.
- New tokens go in `Tokens.swift` only:
  - `dimAlpha 0.40`
  - `edgeDepth 0.05` (× screen width), `mist` stops (edge → inner side)
  - `edgeAlpha 0.70` (on `accent`)
  - `Motion.edgeIn 0.28`

## 8. DESIGN.md changes (applied by `impeccable-documenter` after the build)

- §3: Guard is calm by default (Iris + banner). Shade and Awaken deliberately signal "seen" to the looker. Sound is opt-in and off by default.
- §5: the overlay ignores input; "Lift for now" (⌘L) in the menu, or turning Guard off, clears it.
- §8 / palette.md: the Iris overlay is the single allowed violet glow.
