# PR11 Away sounds

- Planned with ui-designer + frontend-developer agents (user request). Mockups (`design/away/sheet-sounds.png`) approved before UI code.
- Built:
  - Alarm sound picker (Siren + runtime list of /System/Library/Sounds)
  - Message panel (record / play / record again / delete, ×) on a shared `CardPanel`
  - `MessageStore` / `MessageRecorder`, mic usage string
  - Per-alarm engine with an output-change rebuild
  - Spoken-line fallback when the recording can't play
- User feedback loop:
  - The menu closed per pick → custom `SoundRow` views, 1.5 s preview per pick.
  - Play test removed.
  - Added a × to the panel.
  - Away greyed by the open panel → arming now closes it.
  - Tone then message → simultaneous.
  - Siren too loud → `sirenTrim` 0.5 → 0.25. `toneGain` 0.35 → 0.45.
- Verified: swift test 18/18 (2 new), check-ui, installed app; the user confirmed on hardware that everything works.
- Not verified: headphone unplug mid-alarm, VoiceOver lead before recording.
- Self-rating 7/10: shipped what was asked, but the first cut kept the native menu (closes per pick) and the sequential cycle. Both cost a round.
