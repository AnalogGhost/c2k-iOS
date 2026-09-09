# C2K for iOS — Roadmap

The iOS app is at **feature parity with the Android app (1.2.17)**. The
release pipeline (fastlane: build, metadata, screenshots, TestFlight, GitHub
release) is in place — see `RELEASING.md`.

## Before the next App Store submission

- [x] Generate and commit the framed store screenshots for all locales
      (captured on the Screenshots GitHub Action — see `RELEASING.md`)
- [ ] Native review of the ~52 `needs_review` strings in
      `Sources/Localizable.xcstrings` (the iOS-only Settings labels with no
      Android equivalent) and the machine-drafted store `subtitle.txt` /
      `keywords.txt`
- [ ] Fill in App Review contact details in App Store Connect
- [ ] Confirm the privacy-policy URL (`fastlane/metadata/en-US/privacy_url.txt`)

## Not a parity gap (Android doesn't have these either)

- Onboarding / first-run screen
- Run / rest-day reminder notifications
- Apple Watch app, home-screen widgets, App Intents / Siri, Live Activities
- Progress charts (pace trends, weekly adherence)
- iCloud / cloud sync — all data is local-only on both platforms
- km / miles unit preference — km-only on both

## High value, low effort

- [ ] In-workout pace guidance via TTS — `LocationTracker` already computes
      speed; `TTSManager` just needs an announcement type for it (also on
      Android's roadmap)

## Known gaps (not blocking a release)

- No GPS-permission-denied UI — falls back silently to time-only (same on Android)
- No injury / rest-day logic — nothing prevents back-to-back hard days
- No crash reporting or usage analytics (deliberate — matches Android's privacy stance)
- No custom interval builder — programs are hardcoded (matches Android)
- No social / sharing features beyond GPX + CSV export

## Post-parity ideas

- Live Activity for a richer lock-screen workout view (would exceed Android)
- Route map in history (Android roadmap item too)
