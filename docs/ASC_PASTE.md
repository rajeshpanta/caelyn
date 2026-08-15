# App Store Connect — paste-ready field values

Everything here fits Apple's character limits and matches the shipping code
(`Caelyn.storekit`, `PurchaseService.swift`, `project.yml`). Paste verbatim.

Bundle ID: `smallpanta-icould.com.caelynperiodtracker` (hyphen — bundle IDs allow it)
Version: 1.0 · Build: 8

IAP Product IDs use an **underscore**: App Store Connect rejects hyphens in
product IDs ("Only alphanumeric characters, periods, and underscores are
allowed"), so they cannot mirror the bundle ID exactly. Build 7 had the
hyphenated IDs compiled in and is dead — build 8 is the first uploadable one.

---

## Name (30)

```
Caelyn Period Tracker
```

## Subtitle (30)

```
Private cycle companion
```

## Promotional Text (170)

```
Understand your cycle on your phone, nowhere else. Caelyn learns your personal PMS timing and fertile window—all 100% on-device, with no account, no server, no tracking.
```

## Keywords (100 exactly)

Do not repeat words already in the name or subtitle — Apple indexes those fields
too and combines terms across them. So no "period", "tracker", "private", "cycle".

```
menstrual,ovulation,fertility,PMS,cramps,calendar,women,health,symptoms,flow,luteal,log,predict,mood
```

## Description (plain text, under 4000)

App Store descriptions render literally — no markdown. Asterisks and `###` would
show as characters. This is the plain-text version.

```
Caelyn is a period tracker that learns your cycle and keeps what it learns on your phone.

No account. No server. No tracking. Your cycle history exists in one place: your device.

UNDERSTAND YOUR CYCLE
• See your cycle day, current phase, and how far through it you are
• Predictions for your next period, PMS window, fertile days, and ovulation
• Useful by week two, personal by cycle three
• Irregular cycles handled without losing predictions

LOG WHAT MATTERS
• Flow, pain (location and severity), mood, energy, basal body temperature
• 11 core symptoms plus condition sets for PCOS, endometriosis, and perimenopause
• Notes, medication, sexual activity, cervical mucus, ovulation and pregnancy tests
• Add your own custom symptoms

STAY A STEP AHEAD
• Coming Up shows your next period, fertile window, and predicted PMS up to three months out
• Pattern cards surface early signals: which symptoms cluster before your period, your typical pain trend, predicted mood dips
• Home screen and lock screen widgets
• Apple Watch app for discreet checking and quick logging

INSIGHTS THAT ARE ACTUALLY YOURS
After three cycles, Caelyn shows what it learned about you: your real PMS timing, your luteal length, your pain trend. Not a textbook 14-day average. Your numbers, from your logs.

PRIVACY BY ARCHITECTURE
• Caelyn runs no servers and makes no network calls of its own
• No account, email, phone number, or signup, ever
• Zero third-party SDKs, zero analytics, zero ads
• App Lock with Face ID, Touch ID, or PIN, with auto-lock on background
• Hide the app preview in the task switcher
• Private notifications that never show details on your lock screen
• Duress PIN silently wipes everything, then reopens the app looking fresh

Because Caelyn holds nothing and runs nothing, there is nothing to breach or hand over. That is architecture, not a promise.

YOUR DATA, PORTABLE
• CSV export anytime
• PDF cycle report for doctor visits (Pro)
• Apple Health sync: read flow, write flow, symptoms, and pain
• CSV import from other apps with Switch Kit
• Delete everything in one tap

FREE INCLUDES
Unlimited cycle and symptom logging, full predictions and phase tracking, logging streak, five pattern insights, six months of year view, small home widget, App Lock, Hide Preview, Private Notifications, CSV export, and Apple Health sync.

CAELYN PRO ADDS
• Every pattern insight and the full 12-month year in review
• Charts for cycle length, period length, symptom frequency, mood, pain, and temperature
• Medium and large home widgets plus lock screen widgets
• TTC fertility dashboard with daily scoring and signals
• Pregnancy and postpartum modes
• Condition modes for PCOS, endometriosis, and perimenopause
• PDF clinical report
• Learned luteal length and adaptive PMS timing

Caelyn Pro is $3.99 per month with a 7-day free trial, $19.99 per year, or $99.99 once for lifetime access. Every tier gets the same privacy. We meter depth of analysis, never privacy.

Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in your Apple Account settings.

Caelyn is a tracking and awareness tool. It is not a medical device, does not diagnose, and is not a contraceptive.

Privacy Policy: https://rajeshpanta.github.io/caelyn/privacy.html
Terms of Use: https://rajeshpanta.github.io/caelyn/terms.html
Support: https://rajeshpanta.github.io/caelyn/support.html
```

## What's New (v1.0)

```
Caelyn 1.0 — your cycle, your phone, your control.

Learn your body without leaking it. Caelyn is a period tracker where the intelligence lives on your phone instead of a company's servers, so it knows you better and can't tell anyone.

• Unlimited logging: flow, pain, symptoms, mood, energy, temperature
• Daily predictions: next period, PMS window, fertile days, ovulation
• Personal patterns: your true PMS timing, luteal length, symptom clusters
• App Lock, Hide Preview, Private Notifications, Duress PIN with secure wipe
• Charts and year in review (Pro)
• TTC fertility dashboard, pregnancy and postpartum modes (Pro)
• Apple Watch app and widgets
• Apple Health sync, CSV import, PDF clinical export
• No account, no ads, no tracking, no servers
```

## URLs

- Support: `https://rajeshpanta.github.io/caelyn/support.html`
- Privacy Policy: `https://rajeshpanta.github.io/caelyn/privacy.html`
- Marketing (optional): leave blank

## Categories

- Primary: **Health & Fitness**
- Secondary: **Medical**

## Age rating: 12+

Answer the questionnaire as: **None** for everything except
**Sexual Content or Nudity → Infrequent/Mild** (optional sexual-activity logging
is a data field) and **Medical/Treatment Information → Infrequent/Mild**.
Unrestricted web access: **No**. Gambling: **No**.

---

## In-App Purchases — exact values

Subscription group name: `Caelyn Pro`
Group display name (localization): `Caelyn Pro`
Group description: `Caelyn Pro unlocks advanced pattern insights and PDF cycle reports.`

| | Monthly | Yearly | Lifetime |
|---|---|---|---|
| Type | Auto-renewable | Auto-renewable | Non-consumable |
| Product ID | `smallpanta_icould.com.caelynperiodtracker.pro.monthly` | `smallpanta_icould.com.caelynperiodtracker.pro.yearly` | `smallpanta_icould.com.caelynperiodtracker.pro.lifetime` |
| Reference name (internal) | `Caelyn Pro Monthly` | `Caelyn Pro Yearly` | `Caelyn Pro Lifetime` |
| Display name (30 max) | `Pro Monthly` | `Pro Yearly` | `Pro Lifetime` |
| Duration | 1 month | 1 year | — |
| Price (base, US) | $3.99 | $19.99 | $99.99 |
| Price (Nepal) | $1.99 | $9.99 | $99.99 (no discount) |
| Free trial | **1 week** | **NONE** | — |
| Family Sharing | ON | ON | ON |
| Rank in group | 1 (lowest) | 2 | — |

**Nepal pricing.** Subscriptions are discounted ~50% there; Lifetime is not, by
choice — discounted markets are meant to convert to subscriptions. Yearly must
stay at $9.99 rather than the auto-converted $19.99, otherwise the savings badge
drops to SAVE 16%: `PurchaseService.savingsPercent` derives it from live
storefront prices, so halving Monthly alone would gut the annual anchor in that
one market. $9.99 against $1.99 reproduces the same 58% everywhere.

Guardrail when adding storefronts: if any storefront ends up with
`monthly × 12 ≤ yearly`, `savingsPercent` returns 0 and `PaywallView` falls back
to a **"BEST VALUE"** badge on a plan that actually costs more than paying
monthly. Apple's per-currency rounding can drift a storefront into that state
without you touching it — spot-check the Yearly price table.

IAP review screenshot — the same file for all three products, since all three
sell from one screen:
`screenshots/iPhone/06_Paywall.png` (the "Unlock Caelyn Pro" comparison table).
Not a `screenshots/store/*` frame — those are captioned marketing art, and
`07-get` is the Reminders screen, not the paywall.

IAP review notes (same for all three):
`Caelyn Pro unlocks advanced pattern insights, charts, the full year in review, TTC fertility dashboard, pregnancy and postpartum modes, condition modes, PDF clinical export, and medium/large/lock-screen widgets. Tap any locked Pro feature or open Settings to reach the paywall shown in the screenshot.`

Descriptions — Connect shows a live *remaining*-character counter on this field
(40 chars used left 15 remaining, so the cap is around 55). The Lifetime string
in `Caelyn.storekit` is 77 characters and will not fit. Use these, which are
also just clearer:
- Monthly: `Full insights, charts and PDF reports.`
- Yearly: `Everything in Pro. Best value per month.`
- Lifetime: `Every Pro feature, forever. One payment.`

Display names are short on purpose. Apple shows the Caelyn icon and the
`Caelyn Pro` group header directly above them in Settings → Subscriptions, the
purchase sheet, and receipts, so `Caelyn Pro · Monthly` would repeat both words.
The paywall is unaffected either way — `PaywallView.swift` renders only
`product.displayPrice` and hardcodes its own labels.

Never put price, trial length, or "Save 58%" in a Display Name — Apple rejects
promotional and pricing language there. iOS surfaces the trial automatically
from the Introductory Offer.

**Only Monthly has a free trial.** `Caelyn.storekit` defines the introductory
offer on Monthly alone (commit f166e2b). The table in `APP_STORE_LISTING.md`
that shows a trial on Yearly is stale — do not follow it. A trial configured on
Yearly in Connect but absent from the code would misprice the paywall.

---

## Screenshots

| Slot | Required | Source |
|---|---|---|
| iPhone 6.9" (1320×2868) | Yes | `screenshots/store/01-know … 08-take/final.png` — captioned, in order |
| iPad 13" (2064×2752) | Yes (app is iPhone + iPad, `TARGETED_DEVICE_FAMILY: "1,2"`) | `screenshots/ipad/shot_1…6.png` — raw, no captions |
| Apple Watch (416×496) | Yes (Watch app ships in the binary) | `screenshots/watch/01_home.png`, `02_quicklog.png` |

App preview: `screenshots/store/_preview/caelyn-app-preview.mp4` — 28s, 1290×2796.
Verify Connect accepts that resolution in the 6.9" slot; if it rejects, re-export
at 1320×2868 or 886×1920.

---

## App Privacy — take the local-only branch everywhere

Top-level "Do you collect data?": **Yes** (HealthKit access and StoreKit
purchases count as collection under Apple's definition, even though nothing
leaves the device).

| Data type | Collected | Linked to identity | Used for tracking | Purpose |
|---|---|---|---|---|
| Health & Fitness | Yes | **No** | No | App Functionality |
| Purchases | Yes | Yes | No | App Functionality |
| Everything else | No | — | — | — |

Health & Fitness is **not** linked to identity: v1.0 ships with no CloudKit
entitlement and no sync UI, so there is no Apple-ID-linked copy anywhere.
Ignore every "if iCloud Sync is enabled" passage in `PRIVACY_LABEL.md` — those
are a template for a future release.

---

## Export compliance

Uses encryption: **Yes** → only Apple-provided HTTPS/Keychain → **exempt**
(standard exemption, no CCATS/year-end report required).

## Content rights

Contains third-party content: **No**

## Review notes

```
Caelyn stores all cycle data on-device in SwiftData. There is no account, no server, and no cloud sync in this version — the app makes no network calls of its own. No demo account is needed; the app opens straight to onboarding.

To review Pro features, use the sandbox account or restore purchases. Pro unlocks charts, the full year in review, TTC dashboard, pregnancy/postpartum modes, condition modes, PDF export, and medium/large/lock-screen widgets.

Caelyn is an awareness and tracking tool. It makes no diagnostic claims and no contraceptive-efficacy claims.

The Duress PIN feature (Settings → Security) intentionally erases all app data when a secondary PIN is entered. It is a safety feature for users in coercive situations and only ever deletes data belonging to this app.
```
