# App Store screenshots — v2

Sixteen frames: eight for the iPhone 6.9" slot (1320×2868) and eight for the
iPad 13" slot (2064×2752). Upload them in filename order; the numbering *is* the
order App Store Connect should show them in.

The previous set lives in `../store/` and is kept for reference only.

## Why this set looks different

v1 put a whole phone on a purple radial gradient scattered with four-point
sparkles. Two problems. The gradient-plus-sparkle look is the house style of
every AI image generator and every Canva app-store kit, so it reads as a
template rather than as a product. And shrinking a whole screen to fit inside a
device bezel means the interface is illegible at the ~250px width a shopper
actually sees in search results — which is where the decision gets made.

What the category leaders ship instead (pulled from the live store via the
iTunes lookup API, `screenshotUrls`):

| App | Ground | Headline | UI treatment |
|---|---|---|---|
| Clue | full-bleed photography | mixed serif/sans | one cut-out element, trust pills |
| Flo | flat lavender | light setup + heavy payload in a pill | zoomed ~2× bled off the bottom |
| Natural Cycles | flat | heavy black | a white card overlapping the device |

The shared grammar: **flat ground, one typographic emphasis, the interface
zoomed in and cropped rather than shrunk down, and the panel bleeding off the
bottom edge instead of floating.** That is what `_build/compose.py` implements,
in Caelyn's own palette and in SF — the typeface the app itself is drawn in — so
the store page and the product look like the same thing.

## The eight frames

| # | Frame | Job |
|---|---|---|
| 1 | `01-know` | The billboard. Deep plum, "Day 14" legible at thumbnail size, and the two things a shopper cannot get from Flo or Clue stated as badges. |
| 2 | `02-normal` | "Is this normal?" is the question this audience actually types into a search box, and the typical-range table is the one thing no rival surfaces this directly. |
| 3 | `03-private` | The claim the whole product rests on. Near-black, because for this one serious beats pastel. |
| 4 | `04-patterns` | Four big numbers — the most thumbnail-legible screen in the app. |
| 5 | `05-log` | A day that was *actually logged*: medium flow, pain 5/10, cramps and fatigue. (v1 shot this screen empty.) |
| 6 | `06-calendar` | Colour does the work, so the headline stays out of the way. |
| 7 | `07-switch` | Most installs in this category are switchers. Naming Clue, Flo, Period Tracker, Natural Cycles, Glow and Eve is a concrete promise. |
| 8 | `08-doctor` | The closer: the reason to still be logging in month six. |

The iPhone and iPad frames tell the same story from the same screenshots; they
differ only in how `_build/` crops them. Two things are deliberately not shared:

* **Frame 3.** The phone overlays a white breakout card, because at 1320pt the
  privacy page's body copy is unreadable. The iPad has the room to show the page
  itself edge to edge at close to 1:1, and adding the card there would have
  repeated the page's own heading back at the reader word for word.
* **Frame 3's headline** says "your phone" on iPhone and "your iPad" on iPad.

## Regenerating

Sources are captured by `CaelynUITests/ScreenshotTests`' `testStore*` cases,
which are permanent — the store set is reproducible from a clean checkout.

```sh
# Pin the status bar first, or the frames carry whatever time the sim woke up at.
xcrun simctl status_bar <udid> override --time "9:41" \
    --cellularBars 4 --wifiBars 3 --batteryState charged --batteryLevel 100

xcodebuild test -project Caelyn.xcodeproj -scheme Caelyn \
    -destination 'platform=iOS Simulator,id=<udid>' \
    -only-testing:CaelynUITests/ScreenshotTests/testStore1_Home \
    -only-testing:CaelynUITests/ScreenshotTests/testStore2_PhaseGuide \
    -only-testing:CaelynUITests/ScreenshotTests/testStore3_Privacy \
    -only-testing:CaelynUITests/ScreenshotTests/testStore4_Insights \
    -only-testing:CaelynUITests/ScreenshotTests/testStore5_Calendar \
    -only-testing:CaelynUITests/ScreenshotTests/testStore6_LoggedDay \
    -only-testing:CaelynUITests/ScreenshotTests/testStore7_BringHistory \
    -only-testing:CaelynUITests/ScreenshotTests/testStore8_Export \
    -resultBundlePath store.xcresult

xcrun xcresulttool export attachments --path store.xcresult --output-path raw
# copy the S*.png attachments into _sources/iphone or _sources/ipad, then:

cd _build && python3 build_iphone.py && python3 build_ipad.py
```

Requires Pillow and the two fonts referenced at the top of `_build/compose.py`:
SF Pro Display Black (from Apple's SF Pro download, installed in `~/Library/Fonts`)
and the system SF text face.

## Device notes

Both sets were captured on simulators — iPhone 17 Pro Max and iPad Pro 13" (M5) —
and that is not a fallback for the iPad: the connected physical iPad is a 12.9"
4th-generation, whose native 2048×2732 is not the 2064×2752 the 13" slot
requires. For iPhone the simulator is pixel-identical to the device at this
size. Capturing on the physical iPhone is blocked on Caelyn's provisioning
profile, which needs App Groups, iCloud and HealthKit entitlements that the
wildcard profile the device is currently registered under cannot carry.
