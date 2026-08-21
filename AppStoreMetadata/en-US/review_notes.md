# App Review Notes — response to Guideline 2.1 rejection

Paste into App Store Connect → App Review Information → Notes. Fill in the
`[ ]` placeholders before submitting.

---

**1. Screen recording**

[Attach separately per App Store Connect's instructions — it doesn't go in
the Notes field itself.]

Record on a physical iPhone running the latest iOS. Suggested flow (~90–120s):

1. Launch the app from the home screen (cold launch).
2. Home screen — show the program list and streak counter.
3. Tap into a program — show the week/day grid.
4. Start a workout day — this triggers the location permission prompt
   (`NSLocationWhenInUseUsageDescription`). Show the system dialog appearing
   and tap Allow (or show declining it, then show the workout still working
   without GPS — that's worth demonstrating since GPS is optional).
5. Let a voice-coached interval play (e.g. "Start running" / "Walk for 90
   seconds") so audio coaching is audible.
6. Lock the screen or background the app briefly to show the workout keeps
   running (background audio) and that lock screen / Control Center controls
   appear.
7. Return to the app, finish or stop the workout, show the completion screen.
8. Open History — show a logged session with distance/time/pace.
9. Open Settings — show voice/vibration/units options.

No account registration, login, purchase/subscription flow, or user-generated
content exists in this app, so none of those need to appear in the recording.

**2. Devices and OS versions tested**

- iPhone 17, iOS [version — fill in]

(C2K is restricted to iPhone via `TARGETED_DEVICE_FAMILY`, so an iPad isn't
a relevant test target for this app.)

**3. App description and target audience**

C2K is a free, open-source running trainer that guides users from zero
running ability to running 5K, 10K, and beyond, using structured
run/walk interval programs (based on the well-known "Couch to 5K" method)
with audible voice coaching for each interval.

Target audience: beginner and intermediate runners who want a structured,
guided program rather than an unstructured GPS tracker — from complete
beginners (Pre-C25K, Couch to 5K) through to runners building up long-run
endurance (One Hour Runner, 5K Improver). The app solves the problem of
knowing when to run vs. walk and for how long during a training plan,
announced by voice so the runner doesn't need to look at the screen.

**4. Setup and access instructions**

No login, account, or sample data is required. The app has no account
system at all. On first launch, the user picks a program from the home
screen and starts Day 1 of Week 1. All features are immediately accessible;
there is nothing to configure before use.

**5. External services used**

None. The app makes no network requests and integrates no third-party
SDKs, analytics, crash reporting, or ad networks. Voice coaching uses
Apple's on-device `AVSpeechSynthesizer`. GPS distance/pace uses Apple's
on-device `CoreLocation`. All workout history and settings are stored
locally on-device (UserDefaults/local storage); nothing is transmitted
anywhere. This is documented in the app's Privacy Policy and reflected in
its Privacy Manifest (no tracking, no collected data types).

**6. Regional differences**

The app functions identically in every region. The only regional variation
is language: the app is localized into English, German, Spanish, French,
Galician, Portuguese (Brazil), and Russian. There are no region-locked
features, content, or pricing differences (the app has no purchases at all).

**7. Regulated industry / protected material**

Not applicable. C2K is a general-fitness training app, not a medical or
regulated-industry product, and contains no licensed or protected
third-party material.
