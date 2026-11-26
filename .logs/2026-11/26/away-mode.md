# Away mode (PR9)

- Built: Away arm/arming/watch/trigger/disarm, `Alarm` (computed siren + AVSpeechSynthesizer, full volume, restored on stop), shared
  `lockScreen()`, icon A (solid iris), menu row 5, `alarm-test` CLI, spec + mockups, tests.
- Decisions (user): computed siren + system voice now, recorded message next PR; unlock = disarm; icon A; menu as drawn.
- Hiccup: branched from a stale local main again (PR #9 had landed). Caught it before committing; stash + reset to origin/main + pop, clean.
- Not verified yet: live sound, lock + alarm, fail-closed paths, power row. the impeccable skill was not run on the icon/menu diff (the two impeccable agents aren't installed). Fail-closed copy deviates from the mockup: the lock happens at once, so the reason shows in the next menu instead ("Away locked: camera unavailable").
- Self-rating: 6/10. Scope stayed tight and the tests cover the new rules, but the stale-main slip repeated and live checks are still open.
