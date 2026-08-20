# Caelyn App Store text (paste ready)

Written to avoid dashes of any kind, and to read like a person wrote it.
Every claim below was checked against the shipping code.

---

## Subtitle (30 char max)

```
Private cycle companion
```

## Promotional text (170 char max)

```
Your cycle, understood. Caelyn learns your real timing from what you log, and keeps every bit of it on your iPhone. No account, no servers, nothing to leak.
```

## Description (4000 char max)

```
Your period, your patterns, your phone. Nothing leaves it.

Caelyn is a period tracker that learns how your cycle actually works, then keeps everything it learns on your iPhone. There is no account to create and no server of ours holding your health data, because we do not run one.

WHERE YOU ARE, EVERY DAY

Open the app and you know. Cycle day, the phase you are in, and what is coming next. Your next period, your fertile window, and when PMS is likely to start.

Log a period, a mood, a symptom, or nothing at all. Caelyn works with whatever you give it and gets sharper the more you log.

Track flow, pain and where it hurts, mood, energy, basal temperature, cervical mucus, ovulation and pregnancy tests, medication, and a private note for anything that does not fit a box. Eleven everyday symptoms are built in, and you can add your own.

IT LEARNS YOU, NOT AN AVERAGE

Most apps assume everyone ovulates fourteen days before their period. Caelyn watches your own logs and works out your real luteal length, your own PMS window, and the symptoms that tend to arrive before you bleed.

After a couple of cycles it starts telling you things you would not spot yourself. Which symptoms travel together. When your energy dips. Whether your cycle is steadier than you thought. Every one of those is worked out on your iPhone, from your data, and it shows you the numbers behind it.

IS THIS NORMAL

The question everyone actually has. Caelyn answers it with your cycle length, your period length, and your pain against the ranges most people fall into, and it says plainly when something is worth a conversation with a doctor. No judgement, no scare tactics.

BUILT SO YOUR DATA CANNOT LEAK

Every entry lives in a private database on your iPhone. Caelyn makes no network calls of its own. It has no analytics, no advertising, no third party trackers, and nothing to sell.

Lock it behind Face ID or a PIN. Hide the app in the switcher so a glance shows nothing. Turn on private notifications so your lock screen never spells out your cycle. Set a duress PIN that quietly erases everything if you ever need it to.

This is not a promise about how we behave. It is how the app is built. There is nothing for anyone to hand over, including us.

WHEN YOU NEED TO SHOW SOMEONE

Export a CSV whenever you like, and keep it wherever you want. Caelyn Pro adds a clear PDF of your history for an appointment, so you walk in with dates and patterns instead of trying to remember.

FREE, AND GENEROUS ABOUT IT

Unlimited logging, full predictions, the calendar, reminders, five pattern insights, six months of your year in review, a home screen widget, Apple Health, app lock, and CSV export are all free. They stay free.

CAELYN PRO

Every pattern Caelyn finds instead of the first five. Charts for cycle length, period length, symptoms, mood, pain and temperature. A full twelve months in review. A PDF for your doctor. Fertility tracking if you are trying to conceive, plus pregnancy and postpartum modes. Modes for PCOS, endometriosis and perimenopause. Your cycle on your Apple Watch and lock screen.

Pro is 3.99 a month with a seven day free trial, or 19.99 a year. You can also pay once and own it forever. Whichever you pick, the privacy is identical. We charge for depth of analysis, never for keeping your data safe.

A NOTE ON WHAT THIS IS

Caelyn is a personal cycle tracker, not a medical device. Predictions are estimates based on what you log, and they will sometimes be wrong. It should not be used as contraception. For anything that worries you, please talk to a doctor or nurse.

Made for anyone who wants to understand their body without handing it over.
Terms of Use:   https://rajeshpanta.github.io/caelyn/terms.html
Privacy Policy: https://rajeshpanta.github.io/caelyn/privacy.html
```

## Keywords (100 char max, comma separated, no spaces after commas)

```
period tracker,menstrual,ovulation,fertility,PMS,cycle calendar,symptom,mood,womens health,private
```

## What's New (first release)

```
The first release of Caelyn. Everything works offline and stays on your iPhone.
```

---

## IMPORTANT before you paste

**The free trial is real, on Monthly only.** Configured 2026-08-17 and verified
against the App Store Connect API: subscription 6801665064 (Monthly) carries a
FREE_TRIAL introductory offer of ONE_WEEK across 175 territories with no end
date. Yearly 6801681697 has none, by design. Nothing in the binary needed to
change — `PurchaseService.freeTrialLabel` reads the offer from StoreKit at
runtime, so the paywall picks it up on its own. If that offer is ever deleted,
strip the trial claim from the description, the App Review Notes and the three
hosted pages in the same pass.

**The two link lines at the end of the description are load-bearing.** Version
1.0 was rejected under guideline 3.1.2 for having no functional Terms of Use
(EULA) link in its metadata. The fix was appending those lines. They are part of
the description block above — if you re-paste this file, keep them.

**Lifetime is fine.** The non-consumable 6801689541 is IN_REVIEW, not
MISSING_METADATA as an earlier draft of this file warned, so "You can also pay
once and own it forever" is an accurate claim. `docs/ASC_PASTE.md` is an older,
superseded draft of this listing and disagrees with this file in several places;
this file is the source of truth.

## Every claim was checked against the code

  free tier          logging, predictions, calendar, reminders, app lock, Apple
                     Health, CSV export, small widget
  five insights      PatternInsightsSection.freeInsightCap = 5
  six months free    YearViewSection shows suffix(6) to non Pro
  charts are Pro     InsightsView gates the chart section on isPro
  PDF is Pro         ExportView locks the PDF option when not Pro
  modes are Pro      CycleSettingsView gates TTC, pregnancy, postpartum, PCOS,
                     endometriosis and perimenopause
  watch and widgets  WidgetDataSync pushes snapshots for Pro; medium, large and
                     lock screen widgets check isPro
  trial              seven days (ONE_WEEK) on Monthly only, 175 territories.
                     Yearly has no introductory offer. Verified against the
                     ASC API 2026-08-17.
