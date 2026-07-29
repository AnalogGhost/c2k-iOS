# CtoK Roadmap

## Must-have before App Store submission

- [ ] Onboarding / first-run screen — users land cold with no context
- [ ] Push notifications / run reminders — retention depends on this
- [ ] Xcode project generation (`xcodegen` from `project.yml`) — `.xcodeproj` not in repo
- [ ] App Store assets (screenshots, description, privacy policy URL)

## High value, low effort

- [ ] In-workout pace guidance via TTS — `LocationTracker` already computes speed, `TTSManager` just needs to announce it

## Bigger features (post-v1)

- [ ] Progress charts — pace trends, weekly adherence %
- [ ] Apple Watch companion app
- [ ] km / miles unit preference — currently km-only throughout
- [ ] Cloud sync / iCloud backup — all data is local-only right now

---

## Known gaps (not blocking v1)

- No GPS permission denied UI — falls back silently to time-only
- No injury/rest day logic — nothing prevents back-to-back hard days
- No localization — English only, no i18n setup
- No crash reporting or usage analytics
- No custom interval builder — programs are fully hardcoded (matches Android)
- No social / sharing features
- No Siri integration
- No test coverage — Android has unit + instrumented tests for engine/repository/viewmodel behavior; iOS has none yet
