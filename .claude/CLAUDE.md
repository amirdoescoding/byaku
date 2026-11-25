# byaku: Claude Code instructions

@../AGENTS.md

The rest of this file covers Claude Code only. Everything shared lives in `AGENTS.md`.

## Project memory files

- @ARCHITECTURE.md: pipeline, modules, decisions, open risks
- @MEMORY.md: key facts and decisions
- @RESTART.md: where the last session stopped
- @TODOS.md: backlog

## Browsing

Use `/browse` from gstack for all web browsing. Never use the `mcp__claude-in-chrome__*` tools.

## UI / UX

- Any UI work (menu bar, overlay, banner, settings, onboarding) goes through the `impeccable` skill and follows
  `DESIGN.md` and `PRODUCT.md` at the repo root.
- After a UI build, run the impeccable agents: `impeccable-finish-reviewer` and `impeccable-documenter`. The
  documenter keeps `DESIGN.md` in sync with what shipped.

## Agents and skills

- Swift / AppKit / AVFoundation / Vision → `swift-expert`
- `ml/` models, conversion and training → `ml-engineer`, `machine-learning-engineer`
- Privacy and security (camera, Keychain, lock) → `security-auditor`, `/cso`
- Planning: `/plan-eng-review`, `/office-hours`
- Before merging: `/review`, `/code-review`
- Testing the running app: `/qa`
- Between sessions: `/context-save`, `/context-restore`
- Run independent work in parallel.
