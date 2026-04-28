# Caelyn — Period & Cycle Tracker

A private, beautiful iOS period and cycle tracker built in SwiftUI. The on-device display name is **Caelyn**; the longer "Caelyn: Period & Cycle Tracker" is reserved for the App Store listing and the in-app About surface, so a glance at the home screen reveals nothing about cycles.

- Website & legal: <https://rajeshpanta.github.io/caelyn/>
- Support: <https://rajeshpanta.github.io/caelyn/support.html>
- Privacy Policy: <https://rajeshpanta.github.io/caelyn/privacy.html>
- Terms of Use: <https://rajeshpanta.github.io/caelyn/terms.html>

## Privacy

All cycle data is stored locally on the device via SwiftData. The app ships with:

- No analytics, no tracking, no third-party SDKs
- No user accounts, no server, no cloud sync
- Optional Face ID / Touch ID app lock
- Optional Apple Health (HealthKit) sync — user‑controlled, granular, revocable
- CSV export (free) and PDF cycle reports (Pro)
- Delete‑all‑data action in Settings

See the full [Privacy Policy](https://rajeshpanta.github.io/caelyn/privacy.html) for specifics.

## Requirements

- macOS with Xcode 17 or later
- iOS 17.0+ deployment target
- A real iPhone for testing Face ID and HealthKit (Simulator can't fully exercise these)

## Getting started

```bash
open Caelyn.xcodeproj
```

In Xcode, hit `⌘R` to build and run on the iOS Simulator.

## Regenerating the Xcode project

The Xcode project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). You normally work in Xcode without touching XcodeGen; the YAML is a safety net if `project.pbxproj` ever gets corrupted or for clean re‑bootstraps.

```bash
brew install xcodegen   # one-time
xcodegen generate
```

## Project structure

```
Caelyn/
├── App/             # @main, app entry, root scene
├── Theme/           # design tokens — colors, typography, spacing
├── Components/      # reusable UI — cards, buttons, chips, ring
├── Models/          # SwiftData @Model types
├── Services/        # prediction engine, HealthKit, notifications, purchases
├── Mock/            # preview / sample data
├── Views/
│   ├── Onboarding/
│   ├── Home/
│   ├── Calendar/
│   ├── Log/
│   ├── Insights/
│   ├── Settings/
│   └── Premium/
├── Resources/       # asset catalog, privacy manifest
└── Preview Content/ # SwiftUI preview-only assets

docs/                # Privacy, Terms, Support pages — published via GitHub Pages
```

## License

This repository is published for transparency (privacy/legal docs are hosted from `/docs`). All source code is © Caelyn — all rights reserved unless a separate license is added.
