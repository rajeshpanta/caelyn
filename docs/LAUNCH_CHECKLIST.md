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

## B. iCloud Sync (Phase 6) — only if enabling sync at launch

Sync is opt-in and OFF by default; you can ship without it. To enable it:

- [ ] Xcode → Signing & Capabilities → **iCloud → CloudKit**, container
      `iCloud.smallpanta-icould.com.caelynperiodtracker` (matches `Persistence.cloudKitContainerID`).
- [ ] Add **Background Modes → Remote notifications**.
- [ ] Push the CloudKit schema to **Production** in the CloudKit console.
- [ ] **Migration test** (do this even without sync — it affects every upgrade):
      install a **pre-Phase-6** build, add entries (incl. an intentional same-day
      pair), upgrade to this build, confirm entries survive and the launch
      `CycleStore.dedupeSameDay` collapses duplicates. See `PHASE6_CLOUDKIT_SETUP.md`.
- [ ] Verify two-device sync, and that with sync OFF nothing leaves the device.

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
- [ ] **App Privacy "nutrition label"**: declare Health & Fitness data as **not
      linked, not used for tracking**, stored on device (and, if sync is on, in the
      user's iCloud). No third-party SDKs — confirm.
- [ ] Age rating (12+), screenshots (the screenshot seeder + `screenshots/` assets),
      keywords, description (no medical-device / contraceptive-efficacy claims).
- [ ] Export-compliance: uses only Apple-provided encryption (HTTPS / CloudKit /
      Keychain) → standard exemption.

## E. Known polish deferred (not blockers)

- [x] ~~Dark-mode contrast pass~~ — done (low-opacity informational text lifted app-wide).
- [x] ~~Dead Partner Share~~ — `ShareModeView` deleted; rebuild on the CloudKit-sharing
      foundation when that feature is genuinely scheduled.
- [ ] Dynamic Type: ~129 fixed-size fonts don't scale — audit largest sizes for clipping.

## F. Stand-out features shipped in code (verify on device)

- [ ] **Switch Kit**: onboarding Apple Health history import + payoff card; Settings →
      Import data (CSV from Caelyn's own export or another app's).
- [ ] **Day-1 aha**: first prediction shown on the onboarding Done screen; one-time
      "predictions are live" card on Home.
- [ ] **What Caelyn learned about you** (Insights, free at 3+ cycles) + TTC signal points.
- [ ] **Free tier**: 5 insights (was 2), 6 months of year view (was 3).
- [ ] **Period-end recap** card; **streak grace** (no reset on a single missed day);
      **compassionate pregnancy-mode close-out** dialog.
- [ ] **Threat model** ("What if…") section in the Trust Center; **Paranoid Mode** in
      Settings → Privacy.
