# Away message: hold to record (feat/hold-to-record)

The countdown confused a tester. Now: hold the button (mouse or Space) to record, let go to save; VoiceOver press toggles and keeps
the 2.5 s lead. Live waves follow the mic while recording and the file during Play; a 1 pt progress line shows the 8 s cap, which auto-saves.

Process: plan (3 user picks), mockup sheet `design/away/sheet-message-hold.png` (user OK), Swift, then /review over 3 cycles:
16 fixes (timer outliving playback, cap/release race, focus loss mid-hold, previews recorded into the take, Esc/Tab mid-hold, …),
3 new tests (29 total). Didn't converge in 3 cycles; the remaining notes are in TODOS. User's manual pass: all green.

Self-rating: 7/10. The shape held up, but review kept finding hold-state edge cases. A small explicit state machine up front would
have caught them sooner. The impeccable agents aren't installed, and codesign failed from my shell, so the user did the final install.
