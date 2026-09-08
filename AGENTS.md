# Repository guidelines

## Project structure

C2K for iOS is a SwiftUI running trainer targeting iOS 17. Source code is under `Sources/`, unit tests are under `Tests/`, the screenshot UI test is under `UITests/`, App Store copy and screenshots are under `fastlane/metadata/` and `fastlane/screenshots/`, and `project.yml` is the canonical XcodeGen project definition. Generated `.xcodeproj` and workspace files are ignored and must not be committed.

## Development commands

- `xcodegen generate` regenerates `CtoK.xcodeproj` from `project.yml`.
- `open CtoK.xcodeproj` opens the generated project in Xcode.
- `xcodebuild -scheme CtoK -destination 'platform=iOS Simulator,name=iPhone 15' test` runs tests when that simulator is installed; adjust the destination to an available simulator.

## Coding and testing

- Keep workout state and timing in `Sources/Engine/`, persistence in `Sources/Data/`, location handling in `Sources/Location/`, and SwiftUI presentation in `Sources/Views/`.
- Preserve optional GPS behavior and background audio operation.
- Add or update XCTest coverage for changes to programs, calculations, workout transitions, and persisted statistics.
- Regenerate the project after changing `project.yml`, then build and run the relevant tests before committing.
- Keep signing credentials, derived data, archives, and generated projects out of Git.

## Releases

Release automation is fastlane, run locally. Full procedure in `RELEASING.md`.

- A version bump (`MARKETING_VERSION` in `project.yml`) needs a matching
  `fastlane/metadata/en-US/release_notes.txt`.
- The `store`, `beta`, and `release` lanes upload to App Store Connect and
  create git tags / GitHub releases — run them only on explicit request. Upload
  lanes default to a dry run (`verify_only:true`).
- Never commit `*.p8` App Store Connect keys, `fastlane/.env.default`, or
  `.ipa`/`.xcarchive` build output.
- `bundle exec fastlane screenshots` regenerates App Store screenshots via the
  `CtoKUITests` scheme; the resulting PNGs under `fastlane/screenshots/` are
  committed by hand, never by CI.
