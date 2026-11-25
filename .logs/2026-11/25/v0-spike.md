# v0 spike PR1 (2026-11-25)

**What:** ran office hours and the eng review (decisions D1–D18 in `docs/designs/v0-spike.md`), then built the spike CLI.

**Answers on the M1:**
- (a) Build/test with Command Line Tools: yes.
- (b) Power: ~0.3–0.4 W at 1–2 fps, under the budget.
- (c) Lock: SACLockScreenImmediate works on 15.6.
- (d) Owner-match: moved to PR2.

**Surprises:**
- The FaceTime HD camera is fixed at 30 fps. The delivered-fps check caught it.
- The camera keeps delivering frames while the screen is locked.
- In the first run, the idle sample was inflated by build warm-up.

**Self-rating: 7/10.** The questioning surfaced real bugs before any code: the enroll gap, fps reset, and battery vs rails. The review process was heavy on ceremony, though, and the power noise (±0.5 W) means a longer baseline would help next time.
