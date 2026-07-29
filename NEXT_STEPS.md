# Next Steps — Picking This Up on macOS

This repo was synced up with the Android app's current feature set (v1.2.12) in a
Linux environment with no Xcode/Swift toolchain available — every change below was
written and reviewed by hand, but **none of it has been compiled**. This doc is the
checklist for the first session on a Mac.

## 1. Get it building

```sh
brew install xcodegen
xcodegen generate
open CtoK.xcodeproj
```

Expect compiler errors on the first pass — treat them as the real code review this
work hasn't had yet. Likely trouble spots, roughly in order of risk:

- **`Sources/Localizable.xcstrings`** — hand-authored JSON in the String Catalog
  format, ~193 keys, built partly by hand and partly by a script that extracted
  Android's real translated strings. Xcode should open and parse it in the editor;
  if it doesn't, that's the first thing to fix.
- **Plural variations** (`home_streak`, `tts_seconds_remaining`, `tts_duration_minutes`,
  `tts_duration_seconds`, `history_stats_workouts`, `program_preview_duration`) — these
  use the catalog's `variations.plural` schema with `one`/`few`/`many`/`other`
  categories (Russian needs all four; the rest use `one`/`other`). This schema was
  written from documentation, not verified against a real Xcode-generated example.
  **Specifically test**: switch the simulator's language to Russian and run a
  workout long enough to hear "1 second remaining" vs "2 seconds remaining" vs "5
  seconds remaining" — those should use three different Russian words if the plural
  resolution is working.
- **`String(localized:)` / `NSLocalizedString` call sites** — every dynamic string
  (TTS announcements, interval labels, elapsed/pace/distance text, coaching tips,
  guide entries) was rewired to pull from the catalog instead of hardcoded English.
  Grep for `String(localized:` and `NSLocalizedString(` to see the full list; spot
  check a few against the Settings screen and a live workout.
- **Format specifiers** — Android's strings use Java-style `%1$s`/`%1$d`; these were
  mechanically converted to Swift's `%1$@`/`%1$lld` via script. Worth a close look at
  `tts_interval_run`, `tts_interval_walk`, `tts_duration_min_sec`, and the three
  plural keys above, since those are exactly the ones the conversion touched.

## 2. Get a native speaker to review the machine-translated strings

Most of the catalog's translations are real, human-written text ported straight
from Android's own `strings.xml` (which already has community translations for
es/gl/ru and shipped translations for de/fr/pt-BR). But ~8 strings had no Android
equivalent and were machine-translated by Claude this session. They're marked
`"state": "needs_review"` in the catalog — Xcode's String Catalog editor will
visibly flag these (usually with a dot or warning indicator per language). Search
for `needs_review` in `Sources/Localizable.xcstrings` to see exactly which ones:

- `"No workouts yet"` — History empty-state title
- `"Voice"` / `"Workout"` — Settings section headers
- `"Sessions"` — History section header

These are short, low-risk strings, but still worth a real speaker's pass for de/es/
fr/gl/pt-BR/ru before shipping, especially since some of Android's own credited
translators (xmgz, Ilyushenok Ilya) are exactly the kind of people who could sanity
check them.

## 3. Verify the two bug fixes behaviorally

Two fixes went in that address real (if minor) bugs; both are easy to verify once
you can run the app:

- **TTS completion cutoff** — finish a workout and confirm "Workout complete, great
  job!" plays all the way through instead of getting cut off when the completion
  screen appears.
- **GPS pause bug** — start a GPS-tracked workout, pause it, physically move around
  (or drive), then resume. Distance should not have increased while paused.

## 4. Everything else this session touched

For the full list of what changed — Pre-C25K program port, Contributors screen,
Settings backlog (treadmill mode, weight/calories, audio ducking, mid-interval
cues, etc.), landscape layout, and the full localization pass — see the git log
and diff once you're on the Mac. `ROADMAP.md` has the longer-term list of what's
*still* missing (onboarding screen, push notifications, Apple Watch, iCloud sync,
km/mi toggle) — nothing in this session addressed those.

## 5. Once it builds clean

- Run on both a real device and the simulator — GPS/background-audio behavior in
  particular can't be meaningfully tested in the simulator alone.
- Bump `MARKETING_VERSION`/`CFBundleShortVersionString` in `project.yml` off the
  placeholder `"1.0"` before any real release, and decide on a versioning scheme
  relative to Android's (currently at 1.2.12).
- Consider seeding at least a few unit tests (`WorkoutEngineTest`, `ProgramsTest`
  equivalents) — Android has real test coverage for the engine/repository logic;
  iOS currently has none.
