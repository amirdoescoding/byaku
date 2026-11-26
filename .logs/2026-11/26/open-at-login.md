# Open at login + install docs (PR8)

- Built: "Open at login" checkmark (SMAppService.mainApp), Guard resume via persisted `guard` flag, `bundle.sh --install`
  + first-run model conversion, README Install/first run/update/uninstall/troubleshooting.
- Hiccup: PR7 (app bundle) landed on main while I was planning from a stale read. I first rebuilt a duplicate bundle
  (own Info.plist heredoc, own id), then noticed via `git diff` and backed out to PR7's files and `dev.byaku.app`.
  The test install under the throwaway id was removed (login item off, app, defaults, TCC).
- Live (user): register, Login Items, reinstall keeps login item + Guard, resume with LED on. Not done: real log-out/in.
- Self-rating: 6/10. The feature is small and verified, but I should have re-checked `git log` after creating the branch.
