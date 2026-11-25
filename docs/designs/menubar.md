# Menu-bar app: UI spec (build 1)

Scope: status item, NSMenu, enrollment panel. Away mode, banner/dim and Settings are out of scope (slots reserved
below). Follows DESIGN.md 1-8. Mockups render from this file; the user approves them before any code.

## 1. Status item icon

Base: `design/brand/final/menubar-template.svg`, viewBox `4 4 56 56`, centre (32,32), ring r 25.75, stroke 4.5,
two blade crescents. Rendered 16 pt inside an 18x18 pt canvas (36x36 px @2x). 1 unit = 0.57 px @2x.
No animation, no pulse, in any state.

| State | Shape change on the 56-unit mark | Type | Colour |
|---|---|---|---|
| Off | Crescents removed. Empty ring only. | template | system |
| Guarding | Unchanged: ring + both crescents. | template | system |
| Alert | Guarding mark + solid dot, r 6, at (32,32) (r 3.5 vanished at 16 pt in the mockup). Gap to nearest crescent edge is 4 units or more. | non-template | dusk `#6A5DB8` on light bars, iris `#C8BFEF` on dark bars |
| Error | Guarding mark + 45-degree slash along x+y=64, butt caps, clipped to the ring's outer edge, stroke 4.5. Knock out 1.5 units each side of the slash from ring and crescents. | template | system |

- Distinguishing without colour: empty ring / two crescents / crescents + centre dot / crescents + diagonal cut.
  Colour (alert only) is redundant, not load-bearing.
- Pick the alert asset from `button.effectiveAppearance` (menu-bar appearance, not app appearance). Ship 2 alert PDFs.
- Check at 16 pt on both bars before sign-off. Fallback if the slash clutters the crescents: drop crescents under the
  slash only. Do not thicken the stroke.
- Guarding must differ from Off beyond the system green camera dot. It does, by the crescents. The dot is not ours:
  it sits in the system area, also lights for other apps, and an Off icon must never look like a guarding one.
  Keep our own state readable without it.
- Violet appears only in Alert (DESIGN 8).

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
| Position | Horizontally centred on the main screen, 8 pt below the menu bar (near the camera, so the user faces it) |
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
| Starting (camera warm-up, up to 2 s; the 5 s starts at the first frame) | track only | "Starting camera…" | none | Cancel |
| Capturing, 5 s | fills 0 to 100% linearly in 5.0 s; centre 5, 4, 3, 2, 1 | "Look at the screen" | "Be the only person in view. Nothing is saved except a face print." | Cancel |
| Success | full `ink` ring; centre a check: 3 pt polyline (15,25) (21,31) (33,18) in the 48 box | "Face saved" | "Stored on this Mac only. Delete it any time from the menu." | Done (auto-closes after 3 s) |
| Failure: no face | `mute` ring with a 30 degree seam at 12 o'clock; centre empty | "No face seen" | "Face the screen in good light, then try again." | Try again, Cancel |
| Failure: several faces | same seam ring | "More than one face" | "Only you should be in view. Try again when you're alone." | Try again, Cancel |
| Failure: camera denied | same seam ring | "Camera access is off" | "Allow byaku in System Settings, then try again." | Open camera settings…, Cancel |

- Failure is shape (seam) plus words; success is a check plus words. No colour carries meaning.
- Failure rule (for the implementer to confirm): a second face at any moment fails at once; no face fails at the end if
  fewer than 80% of frames had exactly one face.
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

## 5. Open questions for approval

1. Slash on the full mark (Error) vs a ring seam: slash chosen as it reads as "off the air", seam is kept for enrollment failure.
2. Panel position under the menu bar, centred, assumes the built-in camera at top centre.
