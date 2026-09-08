# App Store listing metadata

`fastlane deliver` reads this tree. Push it with the `metadata` / `appstore`
lanes (see `../../RELEASING.md`). Adapted from the Android app's
`fastlane/metadata/android/en-US/` copy.

## Layout

```
metadata/
  copyright.txt                     App-wide copyright line
  en-US/
    name.txt                        App name        (30 char max)
    subtitle.txt                    Subtitle        (30 char max)
    promotional_text.txt            Promo text      (170 char max, no review needed)
    keywords.txt                    Keywords        (100 char max, comma-separated)
    description.txt                 Description      (4000 char max)
    release_notes.txt               "What's New" for the current version
    support_url.txt                 Support URL
    privacy_url.txt                 Privacy policy URL
  de-DE/ es-ES/ fr-FR/ pt-BR/ ru/ tr/   Other locales (same files as en-US, minus the URLs)
  review_information/
    notes.txt                       Notes for App Review
    demo_user.txt / demo_password.txt   Empty — the app has no accounts
```

## Locales

Store copy covers `en-US` plus `de-DE`, `es-ES`, `fr-FR`, `pt-BR`, `ru`, `tr`.
The app also ships **Galician (`gl`)**, but App Store Connect has no Galician
storefront localization, so there is no `gl` directory here.

The non-English copy is **machine-drafted and needs a native review** before those
locales are enabled in App Store Connect. Until then, push `en-US` only
(`fastlane metadata` uploads every populated dir).

## Review contact details

First/last name, email, and phone for App Review are **not** kept in this repo.
Set them once directly in App Store Connect > App Review Information — `deliver`
leaves fields alone when the matching file is absent from `review_information/`.
