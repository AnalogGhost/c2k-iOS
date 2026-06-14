# C2K — Couch to 5K

A free, open-source running trainer for iOS 17+. No account, no subscription, no ads.

## Programs

| Program | Weeks | For |
|---------|-------|-----|
| Couch to 5K | 9 | Complete beginners |
| Couch to 10K | 14 | Continues from C25K |
| Bridge to 10K | 6 | C25K graduates not ready to jump to C210K |
| One Hour Runner | 13 | Running 30 → 60 minutes continuously |
| 5K Improver | 8 | Runners who can already complete 5K |

## Features

- Voice coaching announces every interval
- Optional GPS distance and pace tracking
- Workout history with streak tracking
- Background audio — screen can stay off during workouts

## Requirements

- Xcode 15+
- iOS 17+ device or simulator
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project

## Building

```sh
brew install xcodegen
xcodegen generate
open CtoK.xcodeproj
```

Set your development team in Xcode under Signing & Capabilities, then build and run.
