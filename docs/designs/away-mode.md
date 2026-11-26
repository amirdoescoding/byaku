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
- **Trigger**: the camera stops, the screen locks (`SACLockScreenImmediate`), and the alarm starts: the alarm sound loops the whole
  time, and the message (the user's recording, else the system voice saying "byaku spotted a threat!") plays over it at once, then
  again 1 s (`Tokens.Away.messageGap`) after each time it ends. While it plays, the default output is unmuted at the alarm volume;
  the old volume and mute are restored when it stops.
- **Levels (set by ear, PR11)**: the sound sits under the message at `Tokens.Away.toneGain` 0.45; the siren gets an extra
  `sirenTrim` 0.25 (a clipped square is far denser than the system sounds). Message playback is at full gain.
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
- Letting go is silent (PR11). The previews are the sound picks below: each plays at the slider level, the volume goes back
  afterwards, and a real alarm takes over from a preview.
- The fail-closed fallback (the lock didn't take) always plays at 100%.
- VoiceOver: role slider, "Alarm volume", value in percent, increment/decrement in 25% steps.

## Alarm sound (PR11, mockups `design/away/sheet-sounds.png`, approved 2026-11-26)
- "Alarm sound ▸" under the slider; subtitle = the pick. Siren first, a separator, then every `/System/Library/Sounds/*.aiff`
  A–Z, listed at runtime (the set differs between macOS versions). Stored in UserDefaults `alarmSound` ("" = Siren); a
  sound that no longer exists plays and shows as the Siren.
- Rows are custom views (`SoundRow`) so the menu stays open: a click checks the row and plays 1.5 s (`pickSeconds`) at the
  slider level, like the iPhone alarm picker. Return doesn't pick (custom views in NSMenu); click or VoiceOver press does.
- A system sound loops on an `AVAudioPlayerNode` (connected with the file's own format). The engine is built per alarm and
  rebuilt if the output device changes mid-alarm (`AVAudioEngineConfigurationChange`), so unplugging headphones keeps it sounding.

## Message (PR11)
- "Message…" (subtitle "Spoken line" / "Recorded · N s") opens `MessagePanel` (336 × 160, × in the corner, Esc closes).
  States: Record a message → Waiting for microphone (first time) → Recording (8 s countdown, Stop keeps the take) →
  Message saved (Delete / Record again / **Play**: replays at the alarm volume) · Microphone access is off · Couldn't record.
- Saved to `~/Library/Application Support/byaku/message.m4a` (AAC mono). A new take goes to `message-new.m4a` and replaces the
  old one only when kept; takes under 0.5 s are dropped. Delete is one click (invariant 5).
- The mic runs only while recording (`NSMicrophoneUsageDescription`). With VoiceOver on, the mic starts 2.5 s after the
  "Recording" announcement so it isn't in the take. Locking, quitting or arming Away drops a take in progress.
- At alarm time: if the file is missing or won't play, the spoken line plays instead. Never a silent gap.
- Hidden in a terminal-run CLI (mic permission would go to the terminal, which has no usage string).

## Licence
No audio file ships. The siren is computed (`siren(t)` in `Alarm.swift`), the other sounds are macOS's own (read from
`/System/Library/Sounds` at runtime, never copied), the line uses the system voice (`AVSpeechSynthesizer`), and a recording is the user's.

## Icon (DESIGN §6: differs by shape)
| State | Mark | Colour |
|---|---|---|
| Away (arming + armed) | Solid iris: the ring's outer disc (r 28) filled, blades knocked out | violet (non-template) |
| Alarm | Same as Alert (mark + centre dot). The screen is locked, so nobody sees the bar | violet |

VoiceOver: "byaku, away, locks if anyone looks" / "byaku, alarm, someone looked while you were away".

## Menu while armed
Guard (checked, greyed), Away ✓, Alarm sound, Message…, Mode, Banner and Sound greyed, Set up face / Delete face data greyed.
The volume slider and Quit stay live; Quit restores the volume.

## Known gaps
- Covering the lens keeps frames coming (black), so it doesn't trip the stall check. Tracked in TODOS.
- With headphones plugged in, the alarm plays in the headphones.
