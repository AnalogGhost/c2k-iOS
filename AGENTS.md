# Repository guidelines

## Project structure

C2K for iOS is a SwiftUI running trainer targeting iOS 17. Source code is under `Sources/`, unit tests are under `Tests/`, App Store copy and review material are under `AppStoreMetadata/`, and `project.yml` is the canonical XcodeGen project definition. Generated `.xcodeproj` and workspace files are ignored and must not be committed.

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
