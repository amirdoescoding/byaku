# PR: Guard actions (feat/guard-actions)

**Done**
- Planned with the user through 5 question rounds: Mode ladder (Whisper/Iris/Shade/Awaken under "Mode"), banner under the icon with ×
  and a rotating line, Lift for now, sound opt-in (macOS sound; Epidemic can't be bundled), 2-of-3 debounce, ±30° gaze gate.
- Spec + mockups approved (`docs/designs/guard-actions.md`, `design/guard/`).
- Pipeline: gaze gate before SFace, embed every facing face (cap 4), `frameHasLooker` + `Debounce`, unit tests. CLI eval paths untouched.
- UI: AnchoredPanel (shared with EnrollPanel), BannerPanel, PanelButton `.close`, WatchOverlay per screen, menu wiring.
- Advisor caught: overlay at `.screenSaver` would cover banner + menu; × needing first-mouse; first line skipped.
- Live (user): × first click, lines rotate, clears on lock, mist look approved after two changes (no solid frame; depth per screen).
- Power: blurred-shadow mist measured +13 mW held / >100 mW scrolling → gradient strips, held 2–4 mW (≈ baseline).
- DESIGN.md / palette.md updated by impeccable-documenter.

**Not verified**: yaw/pitch granularity, gate angles with a second person, full-screen app, Reduce Motion, power.sh whole-system row,
scroll baseline. Finish reviewer skipped (no screenshots; user's call).

**Self-rating: 7/10.**
- The spec's "~0 GPU" claim for a blurred shadow was wrong; only the user's measurement caught it. Should have picked gradients first.
- Screenshot verification failed silently (no Screen Recording permission) and cost a detour.
- Good: questions before building, mockups-first held, advisor review before declaring done.
