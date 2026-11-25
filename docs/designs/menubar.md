# Menu-bar app: UI spec (build 1)

Scope: status item, NSMenu, enrollment panel. Away mode, banner/dim and Settings are out of scope (slots reserved
below). Follows DESIGN.md 1-8. Mockups render from this file; the user approves them before any code.

## 1. Status item icon

Base: `design/brand/final/menubar-template.svg`, viewBox `4 4 56 56`, centre (32,32), ring r 25.75, stroke 4.5,
two blade crescents. Rendered 16 pt inside an 18x18 pt canvas (36x36 px @2x). 1 unit = 0.57 px @2x.
No animation, no pulse, in any state.

| State | Mark | Type | Colour |
|---|---|---|---|
| Off | Full mark: ring + both blades. | template | system (ink) |
| Guarding | Full mark, unchanged shape. | non-template | dusk `#6A5DB8` on light bars, iris `#C8BFEF` on dark bars |
| Alert | Full mark + solid dot, r 6, at (32,32) (r 3.5 vanished at 16 pt). | non-template | violet, as Guarding |
| Error | Full mark + 45-degree slash along x+y=64, butt caps, clipped to the ring's outer edge, stroke 4.5. Knock out 1.5 units each side of the slash. | template | system (ink) |

- User decision (2026-11-25): the mark keeps its blades in every state; violet = the eye is open (Guarding, Alert).
- **Off vs Guarding differ by colour only.** That breaks DESIGN §6, and the user accepted it. Covered by: the VoiceOver label, the menu
  status line, and the system camera dot. Alert (dot) and Error (slash) still differ by shape.
- Pick the violet from `button.effectiveAppearance` (menu-bar appearance, not app appearance).
- The state swap is instant: a menu-bar icon doesn't animate (Pale Watch: nothing pulses).

VoiceOver (set on the button, role stays "menu button"):

| State | Label |
|---|---|
| Off | "byaku, Guard off" |
| Guarding | "byaku, guarding, camera on" |
| Alert | "byaku, alert, someone else is looking" |
| Error | "byaku, not guarding, " + reason (e.g. "camera access denied") |

On entering Alert, also post an `NSAccessibility` announcement: "Someone else is looking at your screen".

## 2. NSMenu

Native NSMenu, system font, sentence case, system colours, no violet, no custom views. Tracked small labels are not
used here: NSMenu titles cannot be tracked without attributed titles that break Dynamic Type, vibrancy and the
highlight inversion, and the menu must read as a macOS menu. Brand lives in the icon.

Order (top to bottom):

| # | Item | Copy | Key | Notes |
|---|---|---|---|---|
| 1 | Status (disabled) | see status table | none | Never clickable. Text is the only place state is written out. |
| 2 | Error action (error + camera denied only) | "Open camera settings…" | none | Opens System Settings > Privacy > Camera. |
| 3 | separator | | | |
| 4 | Guard | "Guard" | Cmd-G | Checkmark = on. Disabled until a face is enrolled. |
| 5 | reserved | (Away mode toggle) | | Reserve one row. Do not draw it. |
| 6 | separator | | | |
| 7 | Set up face | not enrolled: "Set up face…"; enrolled: "Set up face again…" | Cmd-E | Opens the enrollment panel. |
| 8 | Delete face data | "Delete face data" | none | Disabled when not enrolled. No ellipsis (no further input). |
| 9 | separator | | | |
| 10 | reserved | (Settings… Cmd-,) | | Reserve one row. |
| 11 | Quit | "Quit byaku" | Cmd-Q | |

Status line copy (row 1):

| Condition | Copy |
|---|---|
| Not enrolled | "Set up your face to turn on Guard" |
| Enrolled, off | "Guard is off" |
| Guarding | "Guarding. Camera is on" |
| Alert | "Someone else is looking" |
| Error: camera denied | "Not guarding: camera access denied" |
| Error: model missing | "Not guarding: face model missing" |
| Error: other | "Not guarding: camera unavailable" |

- Error copy states the consequence ("Not guarding"), because Guard fails open.
- Delete failure (one file in our own folder) only beeps; no error state, since Guard may still be running.
- Delete: no confirmation. It is one deliberate menu pick, sits away from Quit, and redoing takes 5 s with nothing
  else lost. Result: face data removed, Guard turned off, status becomes "Set up your face to turn on Guard".
  Revisit only if enrollment ever becomes expensive.
- Cmd keys fire only while the menu is open (accessory app); say so in docs, do not promise a global hotkey.

## 3. Enrollment panel

Custom surface. Brand tokens from `palette.md`; system font. No camera preview, ever (DESIGN 7).
The Rondel wordmark does not appear: the name is said once (philosophy) and the user just clicked it in the menu.

| Property | Value |
|---|---|
| Class | `NSPanel`, `.borderless` + `.nonactivatingPanel`, floating, can become key (for Esc/VoiceOver), not key-stealing from the user's app |
| Size | 320 x 160 pt, fixed |
| Position | Under its trigger, the status item: top edge 8 pt below the menu bar, horizontally centred on the icon, clamped 8 pt inside the screen |
| Fill | `surface`; 1 pt `line` border; 12 pt corner radius; standard window shadow only |
| Padding | 24 pt all sides |
| Row 1 (h 56) | Ring 48x48 at x 24, y 28 (vertically centred in the 56 row). Text column x 88, w 208, 16 pt gap from ring. |
| Text | Title 13/20 semibold `ink`; 4 pt gap; body 12/16 regular `mute`, up to 2 lines |
| Row 2 (h 32) | Buttons right-aligned, 8 pt apart, 24 pt below row 1 |
| Buttons | h 32, min w 80, 6 pt radius (no capsule/pill), 13 pt medium. Primary: `ink` fill, `bg` text. Secondary: no fill, 1 pt `line` border, `ink` text. |
| Violet | 0 uses. The single allowed use stays unspent: nothing here means "seen". |

Ring (single stroke, flat, no glow, no pulse): 48 pt circle, 4 pt stroke (matches the 4.5/56 brand ratio),
butt caps. Track `line`. Progress `ink`, starting at 12 o'clock, clockwise. Centre: remaining seconds, 20 pt
semibold, monospaced digits, `ink`.

| Phase | Ring | Title | Body | Buttons |
|---|---|---|---|---|
| Starting (camera warm-up, up to 2 s; the 5 s starts at the first frame) | track + a 90° `ink` arc spinning at 600 ms/turn, linear | "Starting camera…" | none | Cancel |
| Capturing, 5 s | fills 0 to 100% linearly in 5.0 s; centre 5, 4, 3, 2, 1 | "Look at the screen" | "Be the only person in view. Nothing is saved except a face print." | Cancel |
| Success | full `ink` ring; centre a check: 3 pt polyline (15,25) (21,31) (33,18) in the 48 box | "Face saved" | "Stored on this Mac only. Delete it any time from the menu." | Done (auto-closes after 3 s) |
| Failure: no face | `mute` ring with a 30 degree seam at 12 o'clock; centre empty | "No face seen" | "Face the screen in good light, then try again." | Try again, Cancel |
| Failure: several faces | same seam ring | "More than one face" | "Only you should be in view. Try again when you're alone." | Try again, Cancel |
| Failure: camera denied | same seam ring | "Camera access is off" | "Allow byaku in System Settings, then try again." | Open camera settings…, Cancel |

- Failure is shape (seam) plus words; success is a check plus words. No colour carries meaning.
- Failure rule (as built):
  - A second face in any frame fails at once ("More than one face").
  - At the end, "No face seen" if fewer than 10 frames passed the pre-registered counting rule (exactly one face, conf ≥ 0.5,
    aligned embedding). 10 frames is 2 s at 5 fps. That's provisional; tune it from real failures.
  - No first frame within 4 s → "Couldn't set up face" / "The camera didn't start. Try again."
  - Save error → "Couldn't set up face" / "Couldn't save. Try again." The copy stays short and fixed, never a system error string.
- Reduce Motion: no continuous sweep. The ring advances in five 72 degree steps, one per second, with the number,
  no easing. Check/seam appear instantly. Auto-close is unchanged.
- Return = primary button, Esc = Cancel. Success does not turn Guard on.
- VoiceOver: panel title "Set up face". Announce phase changes (title + body). Announce "5" then each remaining second.

Close/cancel: Cancel, Esc, or quitting the app stops capture, releases the camera at once, and discards the partial
capture; nothing is saved and there is no confirm. Losing focus does not close it. Locking the screen cancels it.
Re-opening from the menu while open brings the existing panel forward.

## 4. Light / dark tokens used

| Token | Light | Dark |
|---|---|---|
| surface | #FFFFFF | #17161C |
| line | #E1E0E6 | #25232C |
| ink | #0E0D12 | #ECEBF0 |
| bg (primary button text) | #F5F5F7 | #0E0D12 |
| mute | #66636F | #8F8C99 |
| accent (icon, Alert only) | #6A5DB8 | #C8BFEF |

## 5. Motion

Rule: everything a trigger opens grows **from that trigger**, never from its own centre. In this build, that means the panel grows from the status item.
NSMenu is system-drawn and keeps its native animation.

| Token | Value | Use |
|---|---|---|
| `ease.out` | cubic-bezier(0.23, 1, 0.32, 1) | every UI transition; no ease-in anywhere |
| `dur.enter` | 200 ms | panel in: opacity 0 → 1, scale 0.96 → 1, anchor = the icon's bottom centre |
| `dur.exit` | 150 ms | panel out: the same path in reverse, back into the icon (Cancel, Done, Esc, auto-close) |
| `dur.hover` | 120 ms | button background/border shift on hover |
| `dur.press` | 100 ms | button press: scale 0.97 on mouse-down (feedback on press, not release); release springs back in 160 ms |
| `dur.check` | 240 ms | success check drawn on as one stroke (stroke-end 0 → 1) |
| spinner | 600 ms/turn, linear | Starting phase only |
| countdown | 1 s per step, linear | it's a clock, so it's linear on purpose |

- Every animation is under 300 ms except the spinner and the countdown, which show time and aren't transitions.
- **Alive buttons:**
  - hover tint (secondary: 6% ink wash plus a darker border; primary: ink lifts 14% toward bg)
  - press scale 0.97
  - keyboard focus ring = 2 pt accent, the one place violet appears on the panel (focus = *seen*). Only when the keyboard moved focus there:
    opening the panel focuses nothing, and Return reaches the primary button through its key equivalent
  - Return/Esc fire the same press feedback
- **Reduce Motion:**
  - no scale anywhere: panel and buttons fade/tint only
  - the spinner is a static arc
  - the check appears whole
  - the countdown steps per the table in §3
- Prototype: `design/menubar/mockups.html` §motion. Click the icon to see it.

## 6. Components, tokens, guard rails

Typed components: every prop is an enum, with no stringly-typed state and no raw colours or durations at call sites.

| Component | Props | Notes |
|---|---|---|
| `StatusIcon` | `state: GuardState` | Draws the mark from the template geometry; picks template vs violet itself |
| `ProgressRing` | `phase: .starting / .counting(remaining: Int) / .done / .failed` | 48 pt; owns the spinner, countdown and check |
| `PanelButton` | `role: .primary / .secondary`, `title`, `action` | Owns hover, press and focus states; the only button on custom surfaces |
| `EnrollPanel` | `anchor: NSStatusItem` | Positions itself and animates from the anchor |

- Semantic tokens live in one file, `Tokens.swift`: colours by role (`surface`, `line`, `ink`, `mute`, `bg`, `accent`) for light/dark, plus the motion tokens above.
- CI guard (`scripts/check-ui.sh`, run in the Swift workflow) fails the build when:
  - a hex colour or `NSColor(red:`/`(srgbRed:` appears outside `Tokens.swift`
  - an animation duration literal appears outside `Tokens.swift`
- Swift's type checker covers the "strict props" part. A grep is enough for the token rule, and SwiftLint isn't worth a new dependency yet.

## 7. Open questions for approval

1. Slash on the full mark (Error) vs a ring seam: slash chosen as it reads as "off the air", seam is kept for enrollment failure.
2. Panel sits under the status item (it grows from its trigger), so it is off-centre from the camera. The copy says "look at the screen", which is close enough at laptop distance.
