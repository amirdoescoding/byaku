# Guided onboarding tour (PR #18, feat/guided-tour)

The rc1 QA fix. The tour now lives in the real menu: a coach card (`CoachRow`) as the first item, Next lights one row at a time with
the rest greyed and inert, and only Finish or Skip tour go to the video. A stray close reopens the menu on the same step. 6 core steps (the user's pick).

Process: plan, then a spike (live isEnabled flips and reopening from a Timer both work), then mockups (user OK, "core only" steps), then Swift.
A harness compiled the app sources with a fake status menu and screenshotted the steps. It caught un-lit rows going blank (a nil attributedTitle).

Self-rating: 8/10. Solid constraint analysis (an in-menu card is the only clickable surface). I lost time to a harness bug (it pressed Skip, not Next).
A real mouse click on Next was verified only by the user walk, not by me.
