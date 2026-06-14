# CtoK Roadmap

## Must-have before App Store submission

- [ ] Onboarding / first-run screen — users land cold with no context
- [ ] Push notifications / run reminders — retention depends on this
- [ ] Xcode project generation (`xcodegen` from `project.yml`) — `.xcodeproj` not in repo
- [ ] App Store assets (screenshots, description, privacy policy URL)

## High value, low effort

- [ ] Fill in missing coaching tips in `Sources/Models/CoachingTips.swift` — only a handful of weeks have entries
- [ ] In-workout pace guidance via TTS — `LocationTracker` already computes speed, `TTSManager` just needs to announce it
- [ ] Personal best callout on workout completion screen — data already tracked in `WorkoutView`

## Bigger features (post-v1)

- [ ] Progress charts — pace trends, weekly adherence %
- [ ] Apple Watch companion app
- [ ] km / miles unit preference — currently km-only throughout
- [ ] Cloud sync / iCloud backup — all data is local-only right now

---

## Known gaps (not blocking v1)

- Coaching tips missing for most weeks across all five programs
- No GPS permission denied UI — falls back silently to time-only
- No injury/rest day logic — nothing prevents back-to-back hard days
- No localization — English only, no i18n setup
- No crash reporting or usage analytics
- No custom interval builder — programs are fully hardcoded
- No social / sharing features
- No Siri integration
