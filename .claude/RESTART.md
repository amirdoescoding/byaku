# Restart

**2026-11-27**: v0.1.0 is released (stable `releases/latest/download/Byaku-arm64.zip` → 200; rc1 deleted). PR B
`feat/site` is pushed with a PR open: the landing page in `site/` (Astro static + React islands, shadcn-style Radix,
Remotion Player demo), mockups in `design/site/`. Vercel project `byaku` (root `site`, framework Astro; previews always
build, `main` builds only when `site/` changes). Production = byaku-eight.vercel.app after merge.

Next: merge PR B, check production, enable Web Analytics, then check on a real iPhone. App side: the launch gate tests 1–9 in
TODOS, then B2 multi-pose template.
