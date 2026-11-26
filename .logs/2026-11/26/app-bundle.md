# PR7 app bundle

- Built `Byaku.app` without Xcode: `scripts/bundle.sh` (release build, `app/Info.plist`, `app/AppIcon.icns`, sface.mlpackage in Resources, ad-hoc codesign last).
- `main.swift` launches the app when `Bundle.main` is an `.app`, so no library split was needed. The menu-bar PDF was dropped because the icon is drawn in code.
- Icon: `qlmanage` painted a white background, so it's rendered via AppKit and run through `iconutil`.
- Verified: codesign strict verify, 13 tests, check-ui; user live-checked the camera prompt, enroll, photo alert and Finder relaunch.
- Self-rating 8/10: small diff, plan held; one unverified timing claim caught before commit.
