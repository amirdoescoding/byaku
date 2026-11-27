# PR B: landing page (`feat/site`)

- Release: deleted v0.1.0-rc1; v0.1.0 published by release.yml; the stable Byaku-arm64.zip link → 200.
- Plan with the user: Astro static + React islands (shadcn-style Radix), live Remotion Player demo (mode ladder + Guard↔Away),
  Rondel + Beacon, free-roam mascot with guardrails, FAQ + contributions block (no "MIT").
- /design-shotgun had no image key, so it used 4 live HTML sketches with the real fonts and mascot instead; the user picked A "Pale Watch".
- ui-designer: `design/site/` mockups + motion prototype → approved (copy fixes: Modes, open source).
- frontend-developer built `site/`; ui-ux-tester (/browse) found mobile overflow, unreachable demo controls by Tab,
  small touch targets, an unmuted Player and the mascot crossing the hero text. All fixed. Remotion moved to a lazy chunk.
- Lighthouse mobile 98/100/96/100, desktop 100/100/96/100 (BP: only the local analytics 404).
- Vercel project `byaku` (root site, astro). byaku.vercel.app was taken, so production = byaku-eight.vercel.app.
- Self-rating: 8/10. Quality bar met and verified in a browser; the real-device feel and production are still unchecked.
