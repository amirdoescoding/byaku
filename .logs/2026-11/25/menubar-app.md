# PR: menu-bar app skeleton + face setup (feat/menubar-app)

**Done**
- Camera/model load throw instead of exiting, and `Camera.stop()`.
- Owner.swift: counting rule, unit-mean template, `verdict`, OwnerStore (owner.json).
- UI spec by the ui-designer agent and canvas mockups (`design/menubar/`), approved after two rounds. The user changed
  the icon states (blades always on, violet while guarding) and asked for trigger-origin motion and alive buttons.
- `byaku app`:
  - status icon states, NSMenu, EnrollPanel (grows from the icon), PanelButton, ProgressRing
  - Tokens.swift
  - `scripts/check-ui.sh` in CI
- The frontend-developer and ui-designer reviews found 25 issues. 21 are fixed, including an orphaned camera after a cancelled start.
- Live test (user):
  - owner setup works, photo → alert, dark-mode panel OK
  - found the menu auto-enabling bug, now fixed

**Not verified:** the alert/guarding violet on a light menu bar (the user's bar is tinted); Guard power, though it's the same pipeline as `detect --fps 1 --embed`.

**Self-rating: 7/10.**
- I went straight to code and ignored the existing brand work until the user pointed it out. Mockups-first is now a memory.
- The SVG arc sign bug was caught only by rendering the icons.
- I wrote a menu that ignored `isEnabled`; only the live test caught it.
