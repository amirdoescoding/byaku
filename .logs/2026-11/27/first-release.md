# First release prep (PR #15)

- Planned the launch with the user: release gate + landing page (site/ in this repo, Vercel, editorial/playful,
  mascot hero that watches the cursor, docking download pill, Remotion Guard demo, Vercel Web Analytics).
- `release.yml`: stable `Byaku-arm64.zip` asset; hyphen tags → prerelease. Caught a `case` inside `$()` that
  older shells can't parse and replaced it.
- `v0.1.0-rc1` published and verified (sha256, codesign, version). Fonts: all OFL.
- Self-rating: 8/10. Small diff, verified end to end. The hardware gate still needs the user and a second person.
