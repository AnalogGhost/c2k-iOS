# Screen recording script — App Review resubmission

Run through this on a real-device cloud session (BrowserStack App Live / AWS
Device Farm remote access) with `build/dev-export/C2K.ipa` installed. No
narration needed — Apple just wants to see the flow happen. Target ~90–120
seconds total; don't linger on any one screen.

Before starting: fully close the app if it's already open, so the recording
captures a true cold launch.

| # | Action | What it demonstrates |
|---|--------|----------------------|
| 1 | Tap the app icon to launch from a cold start | Launch |
| 2 | Sit on the Home screen for ~2s — show program list + streak counter | Core UI, no login wall |
| 3 | Tap into a program (e.g. Couch to 5K) — show the week/day grid | Program browsing |
| 4 | Tap a day to open the workout preview, then tap Start | Entering a workout |
| 5 | **System location permission dialog appears** — pause, then tap **Allow While Using App** | Sensitive-data prompt, satisfies "prompts requesting access to sensitive data" |
| 6 | Let the workout run long enough to hear a voice cue ("Start running" / "Walk for 90 seconds") — leave the device audio unmuted | Voice coaching / audio feature |
| 7 | Press the device Lock button (or use the remote-control panel's lock/home action), wait ~3s | Background audio continuing with the screen off |
| 8 | Unlock — show the Lock Screen / Control Center widget with interval progress and pause/resume controls if it's visible before unlocking | Lock screen controls feature |
| 9 | Back in-app, tap Pause then Stop/End the workout | Stopping a workout |
| 10 | Show the workout completion screen | Completion flow |
| 11 | Navigate to History — show the newly logged session (distance/time/pace) | Workout history feature |
| 12 | Navigate to Settings — show voice/vibration/units toggles | Settings, confirms no hidden paywall/account screen |

Not needed in the recording (app has none of these): account registration,
login, account deletion, purchases/subscriptions, user-generated content,
content reporting/blocking, or ATT prompt.

## After recording

- Trim dead air at the start/end so it opens right at app launch.
- If the platform's video includes browser chrome around the device frame,
  crop to just the device screen if the export tool allows it — not
  mandatory, but cleaner.
- Export as .mp4 and attach it in App Store Connect per their upload
  instructions for the review resolution.
