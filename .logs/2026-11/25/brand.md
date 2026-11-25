# PR4 brand (2026-11-25)

The user asked for a brand philosophy, palette, logo and variations before starting the menu-bar UI.

- They described byaku as "a quiet shinobi, dangerous yet subtle". The symbol is a subtle nod to the Byakugan.
- Round 1 (`design/brand/explore/`): 6 symbol concepts × 3 weights, 5 fontzz faces, 4 violets.
  Artifact: https://claude.ai/artifact/Avz7krWCVHVtKozkYo7puy
- Picks: Rondel 500 + E2 lockup ("cool and organic"), P1 on dark / P3 on light, 白眼 optional. They kept the
  off-centre blades over a centred sample.
- Final set (`design/brand/final/`, `src/final.py`). Artifact: https://claude.ai/artifact/8RXwvgHBcqsSy6WwkXbftf

Self-rating: 7/10. The first type sheet rendered every row in the system font because of a quoting bug in the
`style` attribute; I caught it by looking at the render. The menu-bar icon at 16 px is still thin, so check it in
the real menu bar.
