# App Store screenshots — v3

Sixteen frames: eight for the iPhone 6.9" slot (1320×2868) and eight for the
iPad 13" slot (2064×2752). Upload in filename order — the numbering *is* the
order App Store Connect should show them in.

`../store/` is v1 and `../store-v2/` is v2; both are kept only for reference.

## Why there was a third pass

**v1** put a whole phone on a purple radial gradient scattered with four-point
sparkles. That is the house style of every AI image generator and every Canva
app-store kit, and shrinking a whole screen to fit inside a bezel left the
interface illegible at the ~250px a shopper actually sees in search results.

**v2** fixed the legibility — flat grounds, heavy SF, the UI zoomed and bled off
the bottom edge. It is a competent modern set. It is also **cold**. Deep plum
grounds and a black grotesque read *technical*: a developer tool, a security
product. This app is for women choosing somewhere to keep the most intimate
record they own, and "trustworthy" and "severe" are not the same feeling.

**v3** went back to the category properly — twelve apps rather than three.

| | Ground | Headline | UI | Trust |
|---|---|---|---|---|
| Moody Month | soft sage wash | light serif | floating, soft shadow | VOGUE · Women's Health · ELLE |
| Clue | editorial colour blocks | bold sans **+ italic serif** | cut-out card | "Strict data privacy" pills |
| Flo | pale lavender | light + highlighted payload | floating | — |
| Natural Cycles | warm beige, photography | serif | in-hand photo | "#1 FDA Cleared", 93%/98% |
| Ovia | cream + lavender | serif | floating, huge margins | — |
| Stardust | dark cosmic | big serif | floating | ELLE · GLAMOUR · NYT, "2M monthly" |
| Period Calendar | pink | bold sans | floating | **"Trusted by 300M women"** as frame 1 |

### What search results actually look like

The decisive view is not the product page — it is the search grid, where three
frames sit side by side at roughly 250px. Put the set there and the gap is
obvious: Lively's angled floating cards and Period Calendar's huge type hold up,
and a single flat rectangle of UI on a pale wash does not. So the frames are
built from **pieces** of the app rather than pictures of it — a card lifted out,
rounded, tilted a degree or two, dropped on its own shadow, with the last piece
running off the bottom edge so the screen reads as continuing rather than
stopping. Depth and contrast are what survive being shrunk.

Two further things almost all of them do that v2 did not:

1. **An elegant serif.** Nearly every frame that reads premium in this category
   pairs a sans with a serif, usually italic, usually carrying the emotional half
   of the sentence. It is the single biggest difference between "an app" and "an
   app I would want". v3 uses **New York** — Apple's own serif, drawn to sit
   beside SF, so it reads as part of iOS rather than as an imported font. That
   matters when the whole promise is that this app belongs on your phone.

2. **Trust worn on the surface.** User counts, press logos, FDA clearance, star
   ratings. Caelyn can claim none of those honestly — it is new and has no press.
   But it can say the one thing none of them can, and say it as a badge rather
   than as body copy: *Private on device · No account · No ads · No trackers ·
   Nothing sold.*

The palette is Caelyn's own, used the way the app uses it: light grounds, plum
reserved for ink and accent. v2 inverted that, and the result looked like a
different product.

## The eight frames

| # | Frame | Ground | Job |
|---|---|---|---|
| 1 | `01-know` | blush | The billboard. "Day 14" legible at thumbnail size, and the two promises no rival can make, as badges. |
| 2 | `02-normal` | sage | "Is this normal?" is what this audience types into a search box, and the typical-range table is the one thing no rival surfaces this directly. Sage is the colour the app itself uses for "in a common range". |
| 3 | `03-private` | lavender | The claim everything rests on. v2 said it in near-black, which read like a warning; it should read like a reassurance. |
| 4 | `04-patterns` | warm sand | Four big numbers — the most thumbnail-legible screen in the app. |
| 5 | `05-log` | blush | A day that was *actually logged* — medium flow, pain 5/10, cramps and fatigue. (v1 shot this screen empty.) |
| 6 | `06-calendar` | cream → rose | Colour does the work, so the words stay out of the way. |
| 7 | `07-switch` | lavender | Most installs in this category are switchers. Naming Clue, Flo, Natural Cycles, Glow, Eve and Period Tracker is a promise the generic "import your data" line never makes. |
| 8 | `08-doctor` | sage | The closer: the reason to still be logging in month six. |

iPhone and iPad tell the same story from the same screenshots and differ only in
how `_build/` crops them. Two deliberate exceptions: frame 3's headline says
"your phone" on iPhone and "your iPad" on iPad, and the iPad shows the privacy
page edge to edge at close to 1:1 because it has the room.

## Regenerating

Sources come from `CaelynUITests/ScreenshotTests`' `testStore*` cases, which are
permanent — the set is reproducible from a clean checkout.

```sh
# Pin the status bar, or the frames carry whatever time the sim woke up at.
xcrun simctl status_bar <udid> override --time "9:41" \
    --cellularBars 4 --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl ui <udid> appearance light

xcodebuild test -project Caelyn.xcodeproj -scheme Caelyn \
    -destination 'platform=iOS Simulator,id=<udid>' \
    -only-testing:CaelynUITests/ScreenshotTests/testStore1_Home \
    ... (testStore2_PhaseGuide … testStore8_Export) \
    -resultBundlePath store.xcresult

xcrun xcresulttool export attachments --path store.xcresult --output-path raw
# copy the S*.png attachments into _sources/iphone or _sources/ipad, then:
cd _build && python3 build_iphone.py && python3 build_ipad.py
```

Requires Pillow. Fonts: **New York** and **SF** ship with macOS; **SF Pro Display
Black** comes from Apple's SF Pro download and lives in `~/Library/Fonts`.

## Why these are simulator captures, not device captures

Not a fallback — a requirement.

* **iPhone.** The App Store 6.9" slot is **1320×2868**. A physical iPhone 15 Pro
  Max renders at **1290×2796** and cannot fill it. The simulator runs the same
  binary and renders identically at the exact required size.
* **iPad.** The 13" slot is **2064×2752**. The connected iPad is a 12.9"
  4th-generation at **2048×2732**.

The data is not mocked up either: every frame is the real app running under
`--screenshot-mode`, which seeds a believable five-cycle history into an
in-memory store. Real screens, real layout, real type — invented history.
