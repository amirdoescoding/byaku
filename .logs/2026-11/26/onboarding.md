# PR12 onboarding (2026-11-26)

## What happened
- The plan was approved with user choices: native Core Animation mascot, a circular preview deferred to PR B, split scope,
  and a native video frame. The user then redirected the tour to run on the real menu (mascot floats to the menu bar, steps happen around it).
- Spike: a panel at `.popUpMenu + 1` draws over an open status menu, and CA keeps animating during tracking. My synthetic-hover
  attempt raised an Accessibility prompt (denied).
- Design: ui-designer mockups (4 sheets) and a frontend-developer motion prototype with CA-compatible springs. The outro was
  reworked to "one mark from start to finish" after the user called it abrupt.
- Build: `Onboarding.swift` (MascotView, Sfx, WordmarkView + SVG reader, OnboardingFlow, CoachOverlay), App.swift wiring,
  `EnrollPanel.copy`, tokens, 2 tests, `bundle.sh` ships `founder.mp4`.
- Hardware iterations with the user:
  - the window opened behind VS Code → `.floating`
  - the lockup was cramped → brand proportions
  - the first flight was laggy → prebuilt overlay
  - the tour→video transition was rigid → flight straight into the lockup
  - no blink during the tour → keyframe blink
  - the hard cut at the handoff → frame-placed mascot + cross-fade
  - impatience → the "stressed" twitch

## Self-rating: 7/10
Good: real-menu tour feasibility was spiked before mockups; the user steered by feel and every round was one rebuild.
Weak:
- Several issues reached the user that a stricter first pass would have caught: activation under macOS 14, layer transforms
  on hidden views, main-queue blocks during menu tracking.
- I couldn't click through the flow myself, so every motion check went through the user.
- The first prototype shipped with placeholder copy.
