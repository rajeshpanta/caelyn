# Caelyn: Period & Cycle Tracker

A private, beautiful iOS period tracker built in SwiftUI. The on-device display name is "Caelyn" — the longer "Caelyn: Period & Cycle Tracker" is reserved for the App Store listing and in-app About surface, so anyone glancing at her phone sees nothing about cycles.

> **Status:** Phase 0 — Project bootstrap complete.

## Requirements

- macOS with Xcode 17 or later (developed on Xcode 26.1)
- iOS 17.0+ deployment target
- A real iPhone for testing Face ID and HealthKit (the Simulator can't fully exercise these)

## Getting started

```bash
open Caelyn.xcodeproj
```

In Xcode, hit `⌘R` to build and run on the iOS Simulator.

## Project structure

```
Caelyn/
├── App/             # @main, app entry, root scene
├── Theme/           # design tokens — colors, typography, spacing       (Phase 1)
├── Components/      # reusable UI — cards, buttons, chips, ring         (Phase 2)
├── Models/          # SwiftData @Model types                            (Phase 3)
├── Services/        # prediction engine, HealthKit, notifications, …    (Phases 7+)
├── Mock/            # preview / sample data                             (Phase 4)
├── Views/
│   ├── Onboarding/                                                      # Phase 6
│   ├── Home/                                                            # Phase 8
│   ├── Calendar/                                                        # Phase 10
│   ├── Log/                                                             # Phase 9
│   ├── Insights/                                                        # Phase 11
│   ├── Settings/                                                        # Phase 12
│   └── Premium/                                                         # Phase 16
├── Resources/       # asset catalog
└── Preview Content/ # SwiftUI preview-only assets
```

## Regenerating the Xcode project

The Xcode project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). You normally work in Xcode without touching XcodeGen; the YAML is a safety net if `project.pbxproj` ever gets corrupted or for clean re-bootstraps.

```bash
brew install xcodegen   # one-time
xcodegen generate
```

## Privacy

All cycle data is stored locally on the device via SwiftData. The app ships with:

- No analytics, no tracking, no third-party SDKs
- Optional Face ID lock
- Optional HealthKit sync (user-controlled, granular)
- Optional iCloud backup (planned)
- Export to CSV / PDF
- Delete-all-data action

## Build plan

18 phases from foundation through TestFlight. Phase 0 (this commit) sets up the project skeleton; subsequent phases add the design system, components, data model, and screens.
