# Releasing C2K for iOS

The release pipeline is [fastlane](https://fastlane.tools). It is **local-first**:
releases are cut from a Mac with the App Store Connect API key on disk, and no
release credentials live in CI. GitHub Actions only runs tests and, on demand,
generates screenshots.

This mirrors the Android app (`~/Projects/c2k`).

## One-time setup

1. **Install the toolchain**

   ```sh
   bundle install          # fastlane, pinned in Gemfile.lock
   brew install xcodegen    # if not already installed
   gh auth status           # the `release` lane shells out to gh
   ```

2. **Create an App Store Connect API key**

   App Store Connect → Users and Access → Integrations → App Store Connect API →
   generate a key with the **App Manager** role. Download the `.p8` **once** and
   store it outside the repo:

   ```sh
   mkdir -p ~/.config/c2k
   mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.config/c2k/
   ```

3. **Point fastlane at the key**

   ```sh
   cp fastlane/.env.default.example fastlane/.env.default
   # edit fastlane/.env.default: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH
   ```

   `fastlane/.env.default` is git-ignored. fastlane loads it automatically.
   Confirm it works:

   ```sh
   bundle exec fastlane check   # prints the latest TestFlight build number
   ```

4. **Set the App Review contact details** (name, email, phone) directly in
   App Store Connect → App Review Information. They are deliberately not kept in
   the repo; `deliver` leaves those fields alone.

## Cutting a release

1. **Bump the version.** Edit `MARKETING_VERSION` in `project.yml` (the single
   source of truth — `CFBundleShortVersionString`/`CFBundleVersion` reference it).
   The build number is set automatically to `latest TestFlight build + 1`.

2. **Write the release notes.** Replace `fastlane/metadata/en-US/release_notes.txt`
   with this version's "What's New", then update `release_notes.txt` in each of the
   `de-DE/ es-ES/ fr-FR/ pt-BR/ ru/ tr/` dirs. The listing `description.txt` /
   `promotional_text.txt` are the contributors' translations ported from Android;
   `subtitle.txt` / `keywords.txt` are machine-drafted (see `fastlane/metadata/README.md`).

3. **Refresh screenshots** if the UI changed:

   ```sh
   bundle exec fastlane screenshots
   git add fastlane/screenshots && git commit -m "Regenerate store screenshots"
   ```

   This captures raw shots into `fastlane/screenshots/raw/` (via `snapshot`),
   then composites the framed + captioned marketing set into
   `fastlane/screenshots/framed/` (via `Tools/ScreenshotComposer`, a small
   Swift/CoreGraphics program — mirrors the Android app's composer). deliver
   uploads the framed set. Edit the caption text in
   `fastlane/screenshot_captions.yml` and re-run `bundle exec fastlane
   frame_screenshots` to re-frame without re-capturing.

   (Or run the **Screenshots** GitHub Actions workflow and commit the artifact.)

4. **Commit the version bump and notes.**

5. **Upload the build and metadata.** Dry run first (default):

   ```sh
   bundle exec fastlane store                    # verify_only, uploads nothing
   bundle exec fastlane store verify_only:false  # real upload
   ```

   Add `submit:true` to also submit for review, `skip_screenshots:false` to push
   screenshots with the build.

6. **Verify** the build in App Store Connect → TestFlight, then finish the
   version in App Store Connect (or use `submit:true` above).

7. **Tag and publish the GitHub release:**

   ```sh
   bundle exec fastlane release
   ```

   This tags `v<MARKETING_VERSION>` locally, shows the release notes, and waits
   for a confirmation before pushing the tag and running `gh release create`.
   Nothing is pushed if you decline; remove the local tag with
   `git tag -d v<version>` and re-run.

## Lanes

| Lane | What it does | Default |
|---|---|---|
| `check` | Verify the App Store Connect API key authenticates. | — |
| `screenshots` | Capture raw screenshots (`snapshot`) + composite the framed/captioned set. No upload. | — |
| `frame_screenshots` | Re-run only the framing step over the existing raw screenshots. | — |
| `store` | Build a signed app-store IPA and upload the build + metadata. | **dry run** (`verify_only:true`) |
| `metadata` | Upload only the listing text, URLs, and release notes. No build. | **dry run** |
| `upload_screenshots` | Upload only the screenshots. No build. | **dry run** |
| `beta` | Build and upload to TestFlight only. | — |
| `release` | Tag `v<version>` and create the GitHub release, behind a confirm prompt. | — |

Common options: `verify_only:false` (actually upload), `submit:true` (submit for
review), `skip_screenshots:false`, `skip_metadata:true`.

## Signing

`build_app` uses Xcode-managed automatic signing with `-allowProvisioningUpdates`
plus the App Store Connect API key, so no certificates or profiles are stored in
the repo (no `match`). The first run on a new machine may pause while Apple
registers the distribution profile.

## What must never be committed

`*.p8` App Store Connect keys, `fastlane/.env.default`, `.ipa`/`.xcarchive`
build output. All are covered by `.gitignore`.
