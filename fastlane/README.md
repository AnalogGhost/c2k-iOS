fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios check

```sh
[bundle exec] fastlane ios check
```

Verify the App Store Connect API key authenticates

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture raw screenshots in every locale, then composite the framed/captioned

marketing set into fastlane/screenshots/framed (what deliver uploads). No upload.

### ios reframe

```sh
[bundle exec] fastlane ios reframe
```

Re-run only the framing step over the existing raw screenshots

### ios store

```sh
[bundle exec] fastlane ios store
```

Build and upload a release to App Store Connect. Dry run by default; pass verify_only:false to ship.

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload only the listing text, URLs, and release notes. No build. Dry run by default.

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload only the screenshots. No build. Dry run by default.

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight only

### ios release

```sh
[bundle exec] fastlane ios release
```

Tag v<MARKETING_VERSION> and create the matching GitHub release

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
