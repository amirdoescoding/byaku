# Away mode: spec (PR8)

Builds on `docs/designs/menubar.md` (row 5 was reserved for this) and DESIGN.md principle 4 ("Away is loud").
Mockups: `design/away/` (`src/mockups.py`), approved 2026-11-26 (icon A, menu as drawn).

## Behaviour
- **Arm**: menu "Away" (⌘A, checkmark). Needs an enrolled face and the face model. Guard pauses: its checkmark stays,
  greyed out, and it resumes on disarm.
- **Arming**: 5 s (`Tokens.Away.armSeconds`) before frames count. Status line: "Away in N s. Step away".
- **Armed**: status line "Away. Locks if anyone looks". Same pipeline as Guard (1 fps, gaze gate, SFace, 2-of-3 debounce).
  Rule: any facing face that is not the owner's, **including a lone face that can't be embedded** (Guard lets that one through;
  Away fails closed). The owner's face only suppresses a trigger and never disarms anything.
- **Trigger**: the camera stops, the screen locks (`SACLockScreenImmediate`), and the alarm loops: siren for 3 s, then the system voice
  says "byaku spotted a threat!", then repeat. While it plays, the default output is unmuted at full volume; the old volume and mute
  are restored when it stops.
- **Disarm**: the screen unlocking (password or Touch ID), or clicking Away again before a trigger. The alarm stops, Away turns off,
  and Guard resumes if it was on.
- **Fail closed**: if the camera fails to start, or no frame arrives for 10 s, the screen locks with no siren (nobody looked)
  and Away turns off; the next menu's status line reads "Away locked: camera unavailable" (once). The lock is confirmed
  1 s later via `CGSSessionScreenIsLocked`; if it didn't take, the alarm sounds instead.

## Volume (mockup C, approved 2026-11-26)
- An "Alarm volume" row sits under Away in the menu: a custom `NSMenuItem.view` (`VolumeSlider`), styled like the Control Center
  Sound slider. It's a 24 pt pill with a white fill up to a white knob carrying the speaker glyph (1/2/3 waves by level). This is a
  user-approved exception to "no custom views in NSMenu" (menubar.md §2).
- Range 25–100% (`Tokens.Away.minVolume`), so the alarm is never silent. Default 100%. Stored in UserDefaults `alarmVolume`.
- Letting go plays a 1 s siren blip at that level. "Play test (3 s)" below it plays the siren for 3 s. Both are previews: the volume
  goes back afterwards, and a real alarm takes over from a preview.
- The fail-closed fallback (the lock didn't take) always plays at 100%.
- VoiceOver: role slider, "Alarm volume", value in percent, increment/decrement in 25% steps.

## Licence
No audio file ships. The siren is computed (`siren(t)` in `Alarm.swift`) and the line uses the system voice (`AVSpeechSynthesizer`).
A user-recorded message (next PR) will replace the spoken line when one is set.

## Icon (DESIGN §6: differs by shape)
| State | Mark | Colour |
|---|---|---|
| Away (arming + armed) | Solid iris: the ring's outer disc (r 28) filled, blades knocked out | violet (non-template) |
| Alarm | Same as Alert (mark + centre dot). The screen is locked, so nobody sees the bar | violet |

VoiceOver: "byaku, away, locks if anyone looks" / "byaku, alarm, someone looked while you were away".

## Menu while armed
Guard (checked, greyed), Away ✓, Mode, Banner and Sound greyed, Set up face / Delete face data greyed. Quit stays live and restores the volume.

## Known gaps
- Covering the lens keeps frames coming (black), so it doesn't trip the stall check. Tracked in TODOS.
- With headphones plugged in, the alarm plays in the headphones.
