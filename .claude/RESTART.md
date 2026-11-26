# Restart

**2026-11-26**: PR10 `feat/release` (#11, open; CI + release dry run green). `scripts/dev-identity.sh` made the local "byaku dev"
signing identity (done on this Mac); `bundle.sh` signs with it. `release.yml`: tag `v*` → zip + sha256 on GitHub Releases.
**Waiting on the user**: camera grant survives a rebuild (after `tccutil reset Camera dev.byaku.app` + one grant), Open at login
still on, downloaded zip opens via Open Anyway. After merge: user OKs pushing tag `v0.1.0`.

Next (from TODOS): Away sound picker + voice level, or the covered-lens fail-closed gap.
