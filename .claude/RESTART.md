# Restart

**2026-11-27**: Going public. PR #15 `chore/first-release` is open: `release.yml` also uploads a stable
`Byaku-arm64.zip` (the site links `releases/latest/download/Byaku-arm64.zip`), and hyphen tags publish as prereleases.
`v0.1.0-rc1` prerelease is out (checksum, codesign, version verified; `latest` 404s until `v0.1.0`, as intended).
Plan: `~/.claude/plans/onboarding-is-finished-and-ticklish-kite-of-2ae572eb-1064-41a4-ab02-07b4089a3b73.md`.

Next: the user runs the pre-launch gate on the rc (TODOS → Launch), then merges #15, tags `v0.1.0`, deletes the rc
release + tag. Then PR B `feat/site`: design round 2 → mockups in `design/site/` → OK → static `site/` on Vercel.
