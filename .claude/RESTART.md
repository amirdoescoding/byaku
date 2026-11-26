# Restart

**2026-11-26**: PR9 `feat/away-mode` (#10, open; app installed): Away mode (⌘A): 5 s arming, the Guard pipeline with the stricter rule, lock + computed siren
+ system voice until unlock, fail closed. Unit tests pass. **Live checks are waiting on the user** (see TODOS "PR9").
Run: `scripts/bundle.sh --install`, then `.build/debug/byaku alarm-test 6` for the sound alone.

Next: user runs the PR9 live checks (list in PR #10), then the recorded-message PR (mockups first).
