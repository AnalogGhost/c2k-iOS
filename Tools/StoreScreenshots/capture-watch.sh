#!/bin/bash
# Captures watch/<locale>/watch.png: C2K's interval alert ("RUN 1:30", the cue the app posts when
# a run starts) as a paired Apple Watch simulator shows it, in each App Store language.
#
# Creates (once) an iPhone + Apple Watch simulator pair, installs a Debug build of C2K, and runs
# the WatchCaptureSetup UI test to allow notifications and lock the phone. The alert itself is
# delivered with `simctl push` using the app's own translated interval label, and the watch is
# switched to each language in turn so its own text ("now", "Dismiss") matches.
#
# Usage: Tools/StoreScreenshots/capture-watch.sh [locale ...]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
BUNDLE_ID="com.hackerapps.c2k"
PHONE_NAME="C2K Watch Shot iPhone"
WATCH_NAME="C2K Watch Shot Watch"
LOCALES=("$@")
[ ${#LOCALES[@]} -eq 0 ] && LOCALES=(en-US de-DE es-ES fr-FR pt-BR ru tr)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

udid() { xcrun simctl list devices | grep -F "$1 (" | head -1 | grep -oE '[0-9A-F-]{36}'; }

PHONE="$(udid "$PHONE_NAME" || true)"
WATCH="$(udid "$WATCH_NAME" || true)"
if [ -z "$PHONE" ] || [ -z "$WATCH" ]; then
  PHONE="$(xcrun simctl create "$PHONE_NAME" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max)"
  WATCH="$(xcrun simctl create "$WATCH_NAME" com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm)"
  xcrun simctl pair "$WATCH" "$PHONE" >/dev/null
fi
xcrun simctl boot "$PHONE" 2>/dev/null || true
xcrun simctl boot "$WATCH" 2>/dev/null || true
xcrun simctl bootstatus "$PHONE" -b >/dev/null
xcrun simctl bootstatus "$WATCH" -b >/dev/null

# Allow notifications and lock the phone (WatchCaptureSetup), which also installs the app.
MARKER="$WORK/locked"
(cd "$ROOT" && TEST_RUNNER_WATCH_CAPTURE_MARKER="$MARKER" xcodebuild -scheme CtoKUITests \
  -destination "platform=iOS Simulator,id=$PHONE" \
  -only-testing:CtoKUITests/WatchCaptureSetup test >"$WORK/setup.log" 2>&1) \
  || { tail -30 "$WORK/setup.log"; exit 1; }
[ -f "$MARKER" ] || { echo "Phone was not locked; see $WORK/setup.log"; exit 1; }

label() {  # the app's translated "RUN" for an App Store locale
  python3 - "$ROOT/Sources/Localizable.xcstrings" "$1" <<'PY'
import json, sys
strings = json.load(open(sys.argv[1]))["strings"]
lang = {"en-US": "en", "de-DE": "de", "es-ES": "es", "fr-FR": "fr"}.get(sys.argv[2], sys.argv[2])
print(strings["RUN"].get("localizations", {}).get(lang, {}).get("stringUnit", {}).get("value", "RUN"))
PY
}

for locale in "${LOCALES[@]}"; do
  lang="${locale%%-*}"; [ "$locale" = "pt-BR" ] && lang="pt-BR"
  xcrun simctl spawn "$WATCH" defaults write -g AppleLanguages -array "$lang"
  xcrun simctl spawn "$WATCH" defaults write -g AppleLocale "${locale/-/_}"
  xcrun simctl shutdown "$WATCH"; xcrun simctl boot "$WATCH"; xcrun simctl bootstatus "$WATCH" -b >/dev/null
  # The phone hands alerts over only once it has sat locked for a while.
  sleep 20
  printf '{"Simulator Target Bundle": "%s", "aps": {"alert": {"title": "%s", "body": "1:30"}, "sound": "default"}}' \
    "$BUNDLE_ID" "$(label "$locale")" >"$WORK/cue.apns"
  xcrun simctl push "$PHONE" "$BUNDLE_ID" "$WORK/cue.apns" >/dev/null
  sleep 6
  mkdir -p "$HERE/watch/$locale"
  xcrun simctl io "$WATCH" screenshot "$HERE/watch/$locale/watch.png" >/dev/null 2>&1
  echo "$locale: watch/$locale/watch.png"
done
