# App Store Connect listing metadata

Paste these directly into the matching App Store Connect fields under App Information / Version Information. Adapted from the Android app's `fastlane/metadata/android/en-US/` listing copy (Play Store wording removed, lock-screen controls feature added).

- `name.txt` → App Name (30 char limit)
- `subtitle.txt` → Subtitle (30 char limit)
- `promotional_text.txt` → Promotional Text (170 char limit, editable without a new review)
- `keywords.txt` → Keywords (100 char limit, comma-separated)
- `description.txt` → Description (4000 char limit)

## Screenshots

Not yet captured. Apple only strictly requires the largest device per family: 6.9" iPhone (1320×2868 px), plus 13" iPad (2064×2752 px) only if iPad is supported. Suggested shot list, mirroring Android's `fastlane/metadata/android/*/images/phoneScreenshots/`:

1. Home (program list + streak)
2. Program select (week/day grid)
3. Workout — active interval
4. Workout — completed / personal best
5. History (stats + sessions)
6. Guide (FAQ)
7. Settings

Capture on a real device or the largest iPhone simulator (`xcrun simctl io <device> screenshot`) once you've clicked through the app yourself.
