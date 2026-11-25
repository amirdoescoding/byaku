# Restart

**2026-11-25**: on branch `feat/v0-spike` (PR1 of the v0 spike, not pushed yet). The plan is in `docs/designs/v0-spike.md`.

Done and verified on the real M1:
- (a) `swift build` / `swift test` work with Command Line Tools only.
- `byaku detect` shows 0/1/2 faces correctly (you, an empty frame, a phone photo).
- (c) `byaku lock-test` reports `locked=true` via SACLockScreenImmediate, and the camera keeps running while the screen is locked.
- The FaceTime HD camera is fixed at 30 fps, so low fps is a software throttle.

Waiting on: (b) the power table. The user runs `scripts/power.sh | tee ~/byaku-power.txt` unplugged (~25 min).

Next: paste the power table into ARCHITECTURE and update AGENTS.md Commands plus invariant 3 (battery and rails).
Then update TODOS with the 4 approved items from the plan, MEMORY, and the `.logs/2026-11/25/v0-spike.md` recap. Push, open PR1, and STOP for user confirmation.
After that, `/clear` and start PR2 `feat/v0-owner-match` from the plan.
