# Caelyn — App Store Launch Checklist

The code is at "ready-with-caveats" (see the distribution-readiness audit). Every
item below is an **out-of-repo / on-device** step the build machine can't do or
verify. Work top to bottom before submitting.

## A. App Store Connect — in-app purchases (required for a working paywall)

The code + `Caelyn.storekit` are internally consistent, but ASC products must be
created and must match exactly, or the paywall shows nothing / review fails.

- [ ] Create the **auto-renewable subscription group** and two subscriptions:
  - `…pro.monthly` — **$3.99 / month**, **7-day free trial** intro offer.
  - `…pro.yearly` — **$19.99 / year**, **7-day free trial** intro offer.
- [ ] Create the **non-consumable**: `…pro.lifetime` — **$49.99**.
- [ ] Turn **Family Sharing ON** for all three products (the local .storekit now has it on — ASC must match).
- [ ] Confirm every product ID matches `PurchaseService.ProductID` **exactly**.
- [ ] Fill in localized display name, description, review screenshot per product.
- [ ] Complete **Paid Apps agreement**, banking, and tax forms (IAPs won't load otherwise).
- [ ] **Sandbox test**: sign into a sandbox account and confirm `loadProducts()`
      returns all three, purchase + **restore** both work, and the trial shows only
      for eligible accounts.

## B. iCloud Sync — NOT shipping in 1.0 (decided)

**1.0 is local-only.** The app carries no iCloud/CloudKit entitlement, so the sync
UI was removed rather than left to fail silently — a toggle that reports "syncing"
while data never leaves the device is a data-loss trap and inaccurate metadata.
`BackupInfoView` now states the truth (local-only, Export is the backup), and the
privacy policy, support page, listing copy, and privacy-label answers match it.

The `Persistence.isSyncEnabled` branch remains as dormant scaffolding. **To ship
sync in a later release, all of these, together:**

- [ ] Xcode → Signing & Capabilities → **iCloud → CloudKit**, container
      `iCloud.smallpanta-icould.com.caelynperiodtracker` (matches `Persistence.cloudKitContainerID`).
- [ ] Add **Background Modes → Remote notifications**.
- [ ] Push the CloudKit schema to **Production** in the CloudKit console.
- [ ] Restore a toggle in `BackupInfoView` driven by a **real "did the sync store
      open" flag** — never by the preference alone (that was the original defect).
- [ ] Re-add the sync language to privacy.html / support.html / listing / privacy label
      in the same release, not before.
- [ ] **Migration test** (do this even without sync — it affects every upgrade):
      install a **pre-Phase-6** build, add entries (incl. an intentional same-day
      pair), upgrade to this build, confirm entries survive and the launch
      `CycleStore.dedupeSameDay` collapses duplicates. See `PHASE6_CLOUDKIT_SETUP.md`.
- [ ] Verify two-device sync, and that with sync OFF nothing leaves the device.

**For 1.0, the only thing to confirm here:** Settings → Backup says "On this device",
there is no sync toggle anywhere, and the Trust Center makes no cloud claim.

## C. On-device verification (can't be simulated)

- [ ] **PIN / duress / biometrics**: set a PIN, unlock with it and with Face ID;
      set a duress PIN and confirm it silently wipes and reopens looking fresh;
      confirm fail-open (no biometrics + no PIN ⇒ never locked out).
- [ ] **Auto-sweep**: enable it, confirm the copy + that it's off by default.
- [ ] **Widgets / Watch**: add all widget sizes + the watch app; confirm empty
      states and midnight rollover.
- [ ] **int-3 wrist temp** (Apple Watch Series 8+) and **int-4 Foundation Models
      summary** (Apple-Intelligence iPhone) — verify the AI path and the fallback.
- [ ] **HealthKit**: grant/deny permission; confirm read/write + delete-on-wipe.

## D. App Store Connect — metadata

- [ ] Privacy Policy URL = `AppURLs.privacyPolicy`; add Support URL = `AppURLs.support`.
- [ ] Publish the latest `docs/privacy.html` before submission. The live URL is
      reachable, but the repo version adds the exact HealthKit read/write categories.
- [ ] **App Privacy "nutrition label"**: declare Health & Fitness data as **not
      linked, not used for tracking**, stored on device only (1.0 has no sync — see
      the banner in `PRIVACY_LABEL.md`). No third-party SDKs — confirm.
- [ ] Age rating (12+), keywords, description (no medical-device /
      contraceptive-efficacy claims, and **no sync/backup claims** — 1.0 is local-only).
- [ ] **Screenshots** — all three sets are in `screenshots/`, at ASC-accepted sizes:
      iPhone 6.9" `1320×2868`, iPad 13" `2064×2752`, Apple Watch `416×496`
      (Series 10 46mm). The Watch set is required because a watchOS app is bundled.
      To regenerate the Watch pair:
      ```
      xcodebuild -project Caelyn.xcodeproj -target CaelynWatch -sdk watchsimulator \
        -configuration Debug SYMROOT=<dir> build CODE_SIGNING_ALLOWED=NO
      xcrun simctl boot "Apple Watch Series 10 (46mm)"
      xcrun simctl install booted <dir>/Debug-watchsimulator/CaelynWatch.app
      xcrun simctl launch booted …watchapp --screenshot-mode   # then --screenshot-log
      xcrun simctl io booted screenshot out.png
      ```
- [ ] Export-compliance: uses only Apple-provided encryption (HTTPS / CloudKit /
      Keychain) → standard exemption.

## E. Known polish deferred (not blockers)

- [x] ~~Dark-mode contrast pass~~ — done (low-opacity informational text lifted app-wide).
- [x] ~~Dead Partner Share~~ — `ShareModeView` deleted; rebuild on the CloudKit-sharing
      foundation when that feature is genuinely scheduled.
- [x] Onboarding + Home/Calendar/Log/Insights first-use path passes on iPhone SE
      at Accessibility XXXL; all onboarding choices and actions remain reachable.
- [ ] Continue the full-app Dynamic Type pass: remaining data visualizations and
      compact controls still use fixed-size fonts and need physical-device review.

## F. Stand-out features shipped in code (verify on device)

- [ ] **Switch Kit**: onboarding Apple Health history import + payoff card; Settings →
      Import data (CSV from Caelyn's own export or another app's).
- [ ] **Day-1 aha**: first prediction shown once on the onboarding Done screen;
      Home opens directly to the cycle overview without a duplicate card or paywall.
- [ ] **What Caelyn learned about you** (Insights, free at 3+ cycles) + TTC signal points.
- [ ] **Free tier**: 5 insights (was 2), 6 months of year view (was 3).
- [ ] **Period-end recap** card; **streak grace** (no reset on a single missed day);
      **compassionate pregnancy-mode close-out** dialog.
- [ ] **Threat model** ("What if…") section in the Trust Center; **Paranoid Mode** in
      Settings → Privacy.
