# GymTimerPro

GymTimerPro is an iOS (SwiftUI) app to track rest periods between gym sets: set the total number of sets and the rest duration, then start a simple countdown.

## Features

- Configure total sets and rest duration.
- On-screen countdown updated every second.
- Live Activity (Lock Screen / Dynamic Island) with current set, remaining time, and mode.
- Hold-to-reset button (prevents accidental resets).
- Timer persistence (UserDefaults) to keep state across background/foreground.
- Keeps the screen awake while the app is open (disables the idle timer).

## Live Activities / Notifications

- The widget (`ActivityKit`) shows the countdown on the Lock Screen and Dynamic Island (device support required).
- If Live Activities are unavailable or fail, the app attempts to schedule a local notification when the rest ends (notification permission required).

## Requirements

- Xcode 16+ recommended.
- iOS `18.4` (current deployment target).

## Running the app

1. Open `GymTimerPro.xcodeproj` in Xcode.
2. Select the `GymTimerPro` scheme.
3. Run on a simulator or device.
4. (Optional) Allow Notifications and enable Live Activities in Settings.

## Project structure

- `GymTimerPro/ContentView.swift`: main UI and timer model (`RestTimerModel`).
- `GymTimerPro/LiveActivityManager.swift`: Live Activity handling + local notification fallback.
- `Shared/GymTimerLiveActivityAttributes.swift`: shared types (`GymTimerAttributes`) for app and widget.
- `GymTimerProWidget/GymTimerProWidget.swift`: Live Activity UI (Lock Screen + Dynamic Island).

## Author

Alejandro Esteve Maza — `https://alejandro-esteve.com`