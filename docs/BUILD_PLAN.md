<!-- Generated 2026-06-28 from docs/DIAGNOSIS.md via a 9-agent planning workflow (7 parallel track designs -> sequence -> adversarial refine). 7 tracks, 73 tasks. -->

# Caelyn — Master Delivery Roadmap (Finish & Ship)

**Source:** `/Users/smile/Desktop/caelyn/docs/DIAGNOSIS.md` + 7 track designs (Stabilize, Data, Monetization, Intelligence, Platform-Polish, Privacy, QA/Release-Ops), merged into one dependency-ordered plan.

**Operating decisions baked in (the "fast path"):**
- **Phase 0 RETRACTS iCloud backup and DISABLES Partner Share** (keeps schema unchanged, ships honestly local-only). The *real* private-CloudKit backup + Partner Share are rebuilt across **Phase 3 (schema foundation, sync OFF) → Phase 6 (sync ON + Share)**.
- **Source of truth for Pro is always StoreKit `Transaction.currentEntitlements`**, never a stored flag.
- **Every honest-UI / privacy-label claim ships only after the behavior it describes is true.** No surface (app, watch, widget, Trust Center, metadata) may display fabricated or unearned claims in any release.
- Effort key: **S** ≈ 0.5–1 day · **M** ≈ 2–4 days · **L** ≈ 5–8 days. Phase totals are 1-engineer estimates; a 2–3 person team runs phases in ~⅓ the calendar time and parallelizes where noted.

> **Overlap note:** Three P0 fixes were independently authored in two tracks. They are the *same work*, listed once with both ids: **stz-005 = mon-1** (offline-Pro), **stz-006 = mon-5** (de-gate contraceptive), **stz-008 = priv-1** (app-switcher leak).

---

## Phase 0 — Compile, De-risk, De-fraud, Ship (v1.0)

**Goal:** The app (1) compiles cleanly across all targets, (2) cannot crash/race on export, (3) makes **no false claim** to App Review or users — iCloud + Share retracted/disabled, **no fabricated cycle data shipped on any surface** (incl. the watch), and in-app Trust Center copy reconciled — (4) is correct on the first-run / late-period / logging / mode-card paths users actually hit, and (5) ships behind a CI gate + regression net to TestFlight → App Store.

**Why now / dependencies:** `stz-001` is the root of the entire tree — nothing builds or tests until it lands. This phase clears **all** P0 release blockers; no later phase is buildable or submittable until it exits green.

### 0a — Compile + CI backbone (do first, in order)
| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **stz-001** Fix compile blocker (fully-qualify enum `@Model` defaults) | `Models/UserProfile.swift:21,62` (leave init params `:80,106`) | S | `xcodebuild` of Caelyn **and** CaelynWatch exit 0 |
| **qa-1** Stand up CI (build all 3 targets + unit/UI gate, iOS 17.0 floor run) | `.github/workflows/ci.yml`, `project.yml`, `fastlane/Fastfile` | M | Failing test turns PR check red; `.xcresult` artifact uploaded |
| **qa-2** Test-support infra (injectable `Calendar`, on-disk store fixtures, `--uitest-state`) | `CaelynTests/TestSupport/*`, `PredictionEngine/CalendarMath/PatternEngine` (default-param), `RootView.swift` | M | Engine math testable under Asia/Tokyo on US runner; deterministic UI launch states; existing tests unchanged |

### 0b — Crash/race + false-marketing/false-data retraction (the App-Review blockers)
| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **stz-002** Kill export data race (generate on MainActor; no `@Model` across actor boundary) | `Views/Settings/ExportView.swift:267-278` | S | CSV+PDF valid for populated & single-entry stores; rapid Generate during concurrent writes never crashes |
| **stz-003** Retract iCloud: deterministic local-only store + honest copy + strip iCloud entitlements (KEEP `CycleEntry.@Attribute(.unique)`) | `Services/Persistence.swift:33-44`, `iCloudSyncView.swift`, `SettingsView.swift`, `Caelyn.entitlements` | M | No CloudKit container created; existing on-disk store opens with **zero data loss**; no UI string claims sync/restore; app re-signs & builds |
| **stz-004** Disable Partner Share entry point; remove false E2E copy; `publicPermission = .none` defensively | `SettingsView.swift:359-365`, `ShareModeView.swift:180` | S | No reachable Share path; no E2E/partner copy in settings/paywall/metadata |
| **stz-005 = mon-1** Stop downgrading offline Pro (refresh entitlements in `init()` + catch path, network-independent) | `Services/PurchaseService.swift:65-78,116-124` | S | `isPro` correct on cold launch at 100% packet loss; happy-path purchase/restore unregressed |
| **stz-006 = mon-5** Un-gate basic contraceptive reminder to free | `SettingsView.swift:408-416`, `BirthControlView.swift`, `NotificationService.swift` | S | Free user can enable+receive a pill reminder; paywall no longer advertises it as Pro |
| **stz-008 = priv-1** Close app-switcher/lock-gate leak (mask+relock on `phase != .active`, opaque, no fade; guard Face-ID `.inactive` loop via `attemptingAuth`) | `Views/Main/AppPreviewMask.swift:9,19`, `AppLockGate.swift:34,41-48` | S | Switcher thumbnail shows opaque shield (verify on device); **no Face-ID relock loop** |
| **stz-018** Watch: replace hardcoded placeholder cycle data with honest empty state (no fabricated "Day 14"); treat `""` flow as empty | `CaelynWatch/WatchHomeView.swift:7,42`, `WidgetDataSync.swift:148-150`, `WatchQuickLogView.swift:130` | S | Nil/absent snapshot → explicit "Open iPhone"/empty state on device; **no fabricated day/phase/countdown ships**; midnight-recompute + structured fertility deferred to `plat-4` |
| **priv-5** Content-free notifications hardening (brand-free strict tier; no health term ever leaks; derive quiet-hours label) | `NotificationService.swift:78-111`, `UserProfile.swift`, `RemindersView.swift:267` | S | Unit test asserts no period/ovulation/medication term in any private-mode notification |

### 0c — User-facing correctness P0s
| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **stz-009** Fix dead late-period UI + lying countdown (un-rolled `expected = lastStart + cycleLength`; remove dead `case 0`) | `PredictionEngine.swift:100-113`, `HomeView.swift:245-264,305` | S | Overdue user sees late prompt w/ correct `daysLate`; not-late countdown intact; unit test added |
| **stz-010** Fix first-run "Period in 0 days" + fake "Day 1 · Cycle" header (gate on real prediction) | `HomeCopy.swift:64-68`, `HomeHeader.swift:15-25`, `HomeView.swift` | S | Fresh install shows "Nothing on the horizon"; header subline hidden when phase `.unknown` |
| **stz-011** Stop phantom empty entries on date-view (no-op commits when nil & no entry; guard flow/energy/ovulation toggles) | `Views/Log/DailyLogForm.swift:46-50,80,470,597,767-769` | S | Scrubbing dates creates **0** rows; real edits still persist (test) |
| **stz-012** Stop basal-temp corruption on revisit (seed `%.2f`; no-op when parsed==stored) | `DailyLogForm.swift:44,847-857` | S | 36.67 stays 36.67 after revisit; no rewrite |
| **stz-013** Persist date on Pregnancy/Postpartum enable so Home card renders; cap stale mode windows | `Views/Settings/CycleSettingsView.swift:337-340,382-385`, `PregnancyModeCard.swift:14-52,104-107` | S | Toggling mode immediately renders the card without touching picker; never overwrites a set date; past-due prompts a mode switch and postpartum weeks are bounded (no "Week 230") |
| **stz-014** Thread `today` into cycle reconstruction (exclude future-dated flow); clear stale `lastPeriodStart` on quick-log toggle-off | `PredictionEngine.swift:10-24`, `CalendarMath.swift:157`, `HomeView.swift:500-511` | S | Future flow excluded from averages/irregular banner; `logPeriodToday` toggle-off clears/recomputes `lastPeriodStart`; unit test added |
| **stz-015** Stop HealthKit symptom backfill duplicating samples (delete-own-then-rewrite; log delete errors) | `Services/HealthKitService.swift:159,167-180` | S | Backfill ×2 = single sample set; only app-authored samples deleted |

### 0d — QA net + submission package
| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **stz-016** Persistence launch smoke + regression tests for the P0 fixes | `CaelynTests/CaelynTests.swift` | M | Local-only store round-trips; tests cover overdue/first-run/phantom/future-flow |
| **qa-3** Expand engine unit coverage incl. degenerate data (split monolith) | `CaelynTests/PredictionEngineTests.swift`, `CalendarMathTests.swift`, `PatternEngineTests.swift`, `TTCFertilityEngineTests.swift` | M | ≥85% branch coverage on the 4 engine files |
| **qa-7** P0/P1 regression suite — one guard per fixed Critical/High (cite bug+file:line) | `CaelynTests/RegressionTests.swift`, `CaelynUITests/RegressionUITests.swift` | L | Each P0 test fails on pre-fix, passes post-fix; CI reports "P0 regressions: N/N"; manual-only items listed explicitly |
| **qa-8** StoreKit entitlement + restore regression (`SKTestSession`) | `CaelynTests/StoreKitEntitlementTests.swift`, `PurchaseService.swift`, `Caelyn.storekit` | M | Cold init with products-fetch forced to throw still resolves `isPro==true`; network restore → network error msg |
| **qa-9** UI-test stability + critical-flow coverage (kill `sleep()`, add a11y ids, iPhone+iPad) | `CaelynUITests/*`, `MainTabView.swift`, `OnboardingSteps.swift`, `PaywallView.swift` | M | 4 flows pass on iPhone+iPad; 0 flakes over 10 reruns |
| **qa-10** Screenshot capture matrix (6.9" iPhone + 13" iPad, pinned OS); verify post-fix UI shows **no retracted claim** | `CaelynUITests/ScreenshotTests.swift`, `fastlane/Snapfile`, `scripts/screenshots.sh` | M | One command regenerates both sizes; no screenshot shows iCloud/E2E or fabricated watch data |
| **qa-13** Privacy-preserving post-launch monitoring (MetricKit, OSLog categories, `caelyn.storeFailed` banner) | `Services/DiagnosticsService.swift`, `Components/DataStatusCard.swift`, `docs/MONITORING.md` | M | MetricKit subscriber logs payloads; on-disk open failure sets `caelyn.storeFailed`, falls back to in-memory **with a user-facing warning + "export now" banner** (first-launch with no prior store does not trip it). *Flag + banner only; non-destructive preserve-aside of a failed store is hardened in Phase 3 `data-inmemory-safety`* |
| **qa-14** Phase test-gate definitions + release-readiness gate (living doc) | `docs/QA_GATES.md`, CI required checks | S | Per-phase DoD written; build+unit+UI-smoke are blocking checks (migration-gate row defined now, activates in Phase 3) |
| **stz-007** Align App Store metadata/screenshots/Privacy manifest **and in-app Privacy Trust Center copy** to local-only behavior | `Resources/PrivacyInfo.xcprivacy`, `Views/Settings/PrivacyTrustView.swift` + ASC edits (out-of-repo) | S | Manifest = no 3p sharing; description/keywords drop all iCloud/E2E claims; Trust Center removes the false "no network entitlement" line and any sync/backup claim (full verifiable-proof rebuild deferred to `priv-6`) |
| **priv-7** Finalize Privacy Nutrition Labels + ASC privacy copy (LAST in phase, mirrors shipped behavior) | `docs/AppStore/privacy-labels.md`, `Info.plist`, ASC | M | Labels = "Data Not Collected"; word-consistent with in-app copy; versioned doc records rationale |
| **qa-11** TestFlight beta plan + archive/upload pipeline | `docs/TESTFLIGHT_PLAN.md`, `fastlane/Fastfile`, `scripts/archive_upload.sh` | S | Reproducible archive→TestFlight; charter covers cross-midnight, offline-Pro, HealthKit-deny |
| **qa-12** App Store submission checklist + review notes (HealthKit, no-account, contraceptive framing, no-FDA, local-only) | `docs/RELEASE_CHECKLIST.md`, `docs/REVIEW_NOTES.md`, `docs/appstore-copy.md` | M | Every listing claim traces to a shipping feature; review notes pre-empt 2.3/5.1 |
| **stz-017** Track gate: clean Release build (Caelyn+Watch+Widget), green suite, archive validation, submission package | `Caelyn.xcodeproj/project.pbxproj` | M | All schemes Release exit 0; archive passes ASC validation (no entitlement mismatch); device smoke done |

**Exit criteria / milestone — v1.0 SUBMITTED:** Clean Release build of all 3 targets, green CI (unit+UI), archive validates, on-device smoke (onboarding → log → CSV+PDF export → App-Lock/Hide-preview switcher → offline Pro → watch shows honest empty state, never fabricated data) passes, metadata + in-app Trust Center + privacy labels internally consistent, build uploaded to App Store Connect.

**Est. effort:** ~18 S · ~12 M · 1 L ≈ **46–56 person-days** (the release-gating phase — largest by task count; parallelize 0b/0c after 0a lands).

---

## Phase 1 — Platform Polish & Finish the Stubs (v1.1)

**Goal:** Make widgets/watch correct across midnight, pass WCAG-AA + Dynamic Type + VoiceOver, fix the iPad onboarding trap + layout, cut runtime cost, and finish every half-built surface (onboarding reminders, HealthKit symptom-read, export correctness).

**Why now / dependencies:** Needs Phase 0's compile + correctness base. `plat-1` (shared cycle math) + `plat-2` (snapshot anchors) are the foundation for all widget/watch work — do them first, then fan out. `plat-13`/`qa-5` sit in the same export files as the Phase-0 `stz-002` race fix, so they land on top of it. `plat-4` extends the honest watch empty state already shipped in `stz-018`.

| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **plat-1** Extract pure cycle day-math into extension-shared module | `Services/CycleDayMath.swift` (new), `PredictionEngine.swift`, `CyclePrediction.swift`, `project.pbxproj` | M | Pure file (`import Foundation` only) member of Caelyn+Widget+Watch; engine delegates; existing tests unchanged |
| **plat-2** Add raw anchors + structured `FertilityStatus` + `hidePreview` to `WidgetSnapshot` (decode-tolerant) | `Services/WidgetDataStore.swift`, `WidgetDataSync.swift` | M | Old-schema snapshot still decodes (round-trip test); fertility from math, not string match |
| **plat-3** Widget midnight recompute + real empty state + Dynamic Type (`isPro:false` placeholder) | `CaelynWidget/CaelynWidgetProvider.swift:23-31`, `WidgetViews.swift` | M | One entry per local midnight ×7d, recomputed; crossing midnight increments day w/o reopening |
| **plat-4** Watch: midnight recompute, structured fertility, phone→watch push-gating (honest empty state already shipped in `stz-018`) | `CaelynWatch/WatchHomeView.swift`, `WatchQuickLogView.swift`, `WatchDataModel.swift`, `WidgetDataSync.swift` | M | Day increments across local midnight without reopening; fertility from structured enum (no substring match); push-gating decision implemented; `stz-018` empty state retained |
| **plat-5** Privacy-mask lock-screen accessory widgets (honor `hidePreview`) | `WidgetViews.swift:286-349`, `WidgetDataSync.swift` | M | Masked accessory shows no day/phase/countdown; reloads on preference change |
| **plat-6** WCAG-AA contrast + Dynamic-Type numerals + CycleRing off-by-one | `CaelynButton.swift:46`, `MoodChip.swift:17`, `Typography.swift:15-16`, `CycleRingView`, `Color+Caelyn.swift` | M | ≥4.5:1 in light+dark; Day 1 sits at ring origin |
| **plat-7** VoiceOver consolidation + non-color flow/pain encoding | `WidgetViews.swift`, `DayCell.swift`, `DayDetailSheet.swift`, `MonthSummaryCard.swift` | M | Each widget reads one phrase; flow/pain distinguishable w/o color |
| **plat-8** Fix iPad onboarding back-button trap + iPad layout | `OnboardingSteps.swift:921-924`, `OnboardingStep.swift`, `OnboardingViewModel.swift`, `OnboardingFlow.swift` | M | Back from Reminders works on iPad; progress count consistent; content width-constrained |
| **plat-9** Cache date formatters + memoize cycle derivations | `DayCell.swift`, `DayDetailSheet.swift`, `MonthSummaryCard.swift`, `DataStatusCard.swift`, `HomeView.swift` | M | Shared pinned formatter; `cycles()` computed once per entries change |
| **plat-10** Serialize fire-and-forget HealthKit syncs + bind scene-phase work to lifecycle | `Services/HealthKitSync.swift`, `HomeView.swift:491-566`, `CaelynApp.swift:34-39` | M | Rapid edit→delete→edit produces no duplicate Health samples; tasks don't stack |
| **plat-11** Finish all four onboarding reminder types | `OnboardingSteps.swift`, `OnboardingViewModel.swift` | S | Period-start + Ovulation toggles persist & schedule; "No reminders" mutual-exclusion holds |
| **plat-12** HealthKit symptom-read + dedup symptom backfill (or remove the "reads symptoms" copy) | `HealthKitService.swift:167-180`, `OnboardingSteps.swift` | M | Symptom import creates no dup days; copy matches behavior; only app samples deleted |
| **plat-13** Finish export: CSV escaping, PDF pagination/footer, calendar pinning, range normalization | `Services/ExportService.swift:44-50,82,347-353,389-394` + formatter sites | M | Comma-symptom round-trips; long note paginates w/ footer on every page; Gregorian dates regardless of device calendar; boundary day included |
| **qa-4** Date/TZ/DST edge-case suite (DST, leap day, year boundary, UTC+14, non-Gregorian) | `CaelynTests/DateTimeZoneTests.swift`, CI TZ matrix | M | Engine math stable across ≥3 TZs incl. DST + UTC+14; cross-TZ duplicate-day case asserts mitigation |
| **qa-5** Export correctness + concurrency-safety tests (Sendable-snapshot enforced) | `CaelynTests/ExportServiceTests.swift` | M | Buddhist-calendar export emits Gregorian years; export API takes Sendable snapshot (compile-enforced) |

**Exit criteria / milestone — v1.1:** Widgets/watch show correct numbers across midnight in all families; real empty states everywhere (no fabricated data); a11y/contrast/Dynamic-Type pass on iPhone+iPad incl. VoiceOver; export is correct under any calendar/locale; all four reminder types work. CI green incl. TZ matrix.

**Est. effort:** ~1 S · ~14 M ≈ **40–45 person-days**.

---

## Phase 2 — Monetization Funnel & Growth (v1.2)

**Goal:** Turn the StoreKit layer into a privacy-led conversion funnel that is App-Review-safe: free trial, lifetime tier, one dismissible privacy-framed soft paywall after the first prediction reveal, honest per-tier disclosure, delight-timed review prompts, and ASC parity.

**Why now / dependencies:** Needs Phase 0's offline-Pro fix (`mon-1`) and Phase 0's first-run/prediction correctness (`stz-009`/`stz-010` — the soft paywall must only fire when a *real* prediction exists). `mon-4` reuses the Phase-0 first-run gate.

| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **mon-2** Configure free trial (intro offer) in StoreKit + expose eligibility | `Caelyn.storekit`, `PurchaseService.swift` | M | Yearly carries a real intro offer; `isEligibleForIntroOffer` exposed; ineligible users never see trial copy; no synthetic urgency |
| **mon-3** Add lifetime non-consumable "own-it-forever" tier | `Caelyn.storekit`, `PurchaseService.swift`, `PaywallView.swift`, `PaywallTierCard.swift` | L | Lifetime purchase = permanent Pro; restorable; copy has no "renews" language |
| **mon-4** Privacy-led soft onboarding paywall after first prediction reveal (once, dismissible, never Pro) | `HomeView.swift`, `PaywallView.swift` | M | Shows ≤1×/install, only when real prediction exists, fully dismissible into a working free app |
| **mon-6** Honest pricing/offer display (per-tier disclosure, fix load-flash/CTA/restore-error bugs) | `PaywallView.swift:22-29,257-298,431-434`, `PaywallTierCard.swift`, `ProUpsellCard.swift` | M | Each tier shows StoreKit-derived terms; no hardcoded prices; no error flash before load |
| **mon-7** Tune review-prompt timing to delight moments; never collide with paywall/failed purchase | `Services/RatingService.swift`, `DailyLogForm.swift:776` | M | No review request in same session as paywall/failed purchase; throttles intact; `sessionCount` removed |
| **mon-9** App Store Connect IAP/subscription parity + monetization metadata | `Caelyn.storekit` + ASC | M | All 3 products exist in ASC w/ matching IDs/prices/trial; listing reflects free contraceptive reminders + trial + lifetime |

> **`mon-8` (retire vestigial `UserProfile.isPro`) is mapped to Phase 3** so the property removal rides the versioned migration (one destructive change, not two). De-reference its reads/writes opportunistically here in Phase 2 while in `PurchaseService`, but do not remove the stored property until the V2 migration.

**Exit criteria / milestone — v1.2:** Trial-eligible users see a real "Free for N days, then …" CTA; lifetime tier purchasable+restorable; soft paywall converts at the value moment and is fully dismissible; every price/term string is StoreKit-derived and Apple-compliant; ASC products match the binary. `qa-8` (Phase 0) extended to cover trial+lifetime entitlement.

**Est. effort:** ~5 M · 1 L ≈ **20–24 person-days**.

---

## Phase 3 — Data Foundation: Versioned Schema + Migration + Dedup (v1.3, sync OFF)

**Goal:** Convert the single-version store into a **versioned, migratable, CloudKit-valid** schema with an app-layer one-entry-per-day invariant replacing the soon-to-be-dropped `@Attribute(.unique)` — **with zero existing-user data loss**. Ships **local-first with CloudKit sync OFF** so the schema change is field-proven before bidirectional sync (Phase 6) is switched on.

**Why now / dependencies:** This is the riskiest engineering and the headline data-loss surface. Schema + migration + dedup **must ship atomically in one release**. It is the prerequisite for both the privacy-moat secure-wipe (Phase 5) and real CloudKit (Phase 6). It needs Phase 0's compile fix and `qa-2` fixture infra to begin, but is sequenced here so monetization/polish value ships first and this plumbing gets dedicated, careful runway. The CloudKit entitlement stays stripped (re-added in Phase 6); with the flag OFF the schema is merely CloudKit-*valid*, not CloudKit-*connected*.

| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **data-schema-versioned** Introduce `CaelynSchemaV1` (current shape) + `CaelynSchemaV2` (CloudKit-valid: drop `.unique`, default `date`, share `UserProfile`); top-level typealiases | `Models/Schema/CaelynSchemaV1.swift`, `CaelynSchemaV2.swift`, `CycleEntry.swift`, `UserProfile.swift` | M | Compiles with typealiases → V2; no call-site change; V2 has no `.unique` & all attrs optional/defaulted; V1 reproduces today's exact shape |
| **data-migration-plan** `CaelynMigrationPlan` with custom v1→v2 stage (normalize `date` → startOfDay, run dedup in `didMigrate`) | `Models/Schema/CaelynMigrationPlan.swift` | M | Populated v1 store → v2 with counts preserved; idempotent on already-v2; failures logged, never swallowed |
| **data-dedup-layer** App-layer one-entry-per-day (`CycleStore.upsertEntry` + `dedupeEntries` merge policy) routing all 4 insert sites | `Services/CycleStore.swift` (new), `DailyLogForm.swift:767-769`, `HomeView.swift:468,516-558` | M | Two upserts same day → 1 entry; merge unions arrays/maxes severity/newest-scalar-by-`updatedAt`; no bare inserts remain |
| **data-container-wiring** Wire `migrationPlan` into every `ModelContainer`; honest `storeMode`/`isCloudKitActive`; gate CloudKit behind `cloudSyncEnabled=OFF` (local path, no entitlement) | `Services/Persistence.swift:33-64`, `iCloudSyncView.swift`, `SettingsView.swift`, `CaelynTests.swift` | M | All inits use versioned schema+plan; flag-off ⇒ local-only & `isCloudKitActive==false`; status reads flag not iCloud token |
| **data-inmemory-safety** Make in-memory fallback honest + non-destructive (preserve failed store aside; persistent warning banner; read/reset `storeFailed` set by `qa-13`) | `Persistence.swift:57`, `App/CaelynApp.swift`, `Components/DataStatusCard.swift` | S | Failed open preserves on-disk store (`.corrupt-<ts>`); in-memory ⇒ explicit warning; first-launch doesn't nag |
| **data-migration-tests = qa-6** Open a real v1 on-disk store with v2 schema+plan (empty / ~1000-entry / idempotent re-open / dup-merge) | `CaelynTests/MigrationTests.swift`, `DedupTests.swift`, `Fixtures/Caelyn_v1.store*` | M | v1 fixture → v2 with zero data loss; `caelyn.storeFailed` asserted false; breaking the plan fails the test |
| **mon-8** Retire vestigial `UserProfile.isPro` (folded into the V2 schema change) | `Models/UserProfile.swift:68`, `OnboardingViewModel.swift:102` | S | No code reads `profile.isPro`; removed via the same migration (no separate destructive change) |

**Exit criteria / milestone — v1.3:** Existing v1.0–v1.2 installs upgrade to V2 with **no data loss** (proven by `qa-6` + a manual device upgrade smoke); store is CloudKit-valid; one-entry-per-day invariant enforced at the app layer; sync remains OFF; honest local-only copy intact. The `qa-14` migration-gate row is now wired as a **blocking** CI check.

**Est. effort:** ~5 M · 2 S ≈ **16–22 person-days** (highest *risk*; budget contingency for SwiftData store-URL continuity + fixture flakiness).

---

## Phase 4 — Intelligence & Differentiation (v1.4 → v1.5)

**Goal:** Build the on-device intelligence layer that beats Flo/Clue/Apple on privacy+smarts: adaptive predictions, a cross-metric insight feed with doctor-visit prep, wrist-temperature ovulation, Foundation-Models NL summaries (with a non-AI fallback), and real perimenopause/conditions depth — zero cloud, zero FDA/medical claims, no false precision.

**Why now / dependencies:** Needs the stable engine base (Phase 0 future-flow/late-period fixes) and Phase 1's shared cycle-math; **`int-2`'s doctor-visit PDF builds directly on Phase 1's corrected export layer (`plat-13`/`qa-5`)**. **Sequence within phase:** `int-1` first (foundation) → `int-2` + `int-5` in parallel (both extend `int-1`) → `int-4` (summarizes `int-1`+`int-2`). `int-3` runs as an independent HealthKit track; its confirmed-ovulation output can later refine `int-1`'s luteal learning. *This phase depends on Phase 0 — and, for `int-2`, Phase 1's export correctness — and can otherwise run as a parallel workstream alongside Phases 2–3.*

| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **int-1** Adaptive prediction engine (learned luteal/PMS, clamp/round, multi-cycle projection, irregular/PCOS ranges) | `PredictionEngine.swift`, `CalendarMath.swift`, `TTCFertilityEngine.swift`, `AdaptiveCycleModel.swift` (new) | M | Luteal learned from confirmed-ovulation signals (≥3 cycles, else 14d fallback); averages clamped 18–45/1–12; variation/PMS means rounded (not truncated); Calendar projects ≥3 future cycles; irregular/PCOS → dated range w/ lowered confidence; stale `result()` params removed |
| **int-2** On-device cross-metric insight feed + calibrated confidence + doctor-visit PDF | `PatternEngine.swift`, `CorrelationEngine.swift` (new), `DoctorVisitReport.swift` (new), `ExportService.swift`, `InsightsView.swift` | L | ≥3 lag-aware correlation detectors; true distinct-cycle counts; ranked, dismissible (persisted); on-device PDF w/ "not medical advice" + zero network (builds on Phase 0/1 export fixes) |
| **int-3** Wrist-temperature ovulation read (Apple Watch, retrospective, on-device, no FDA claims) | `HealthKitService.swift`, `WristTempOvulationEngine.swift` (new), `InsightsCharts.swift`, `TTCDashboardCard.swift` | L | Reads `appleSleepingWristTemperature`+BBT; biphasic detector unit-tested; chart overlay; clean "needs Apple Watch" empty state; read-only, no network |
| **int-4** Private Intelligence — Foundation Models NL summaries + deterministic fallback (weak-linked, `#available(iOS 26)`) | `PrivateIntelligenceService.swift` (new), `CycleSummaryFallback.swift` (new), `InsightsView.swift`, `project.pbxproj` | M | iOS 26 → on-device NL summary (zero egress); all other OS → equivalent templated fallback; only structured facts fed (never raw notes); medical-claims guard test |
| **int-5** Perimenopause (P1) + PCOS/Endo (P2) depth beyond stub modes | `UserProfile.swift`, `PredictionEngine.swift`, `ConditionInsights.swift` (new), `CycleSettingsView.swift`, `DailyLogForm.swift`, `ConditionModeCard.swift` (new) | L | Perimenopause = irregularity/anovulatory-aware + ≥3 insights/education items, never false single-date; PCOS never flags long-but-typical cycles as late; Endo feeds doctor-prep; each mode has a Home card; all copy observational |

**Exit criteria / milestone — v1.4/v1.5:** Predictions adapt per-user and degrade honestly for irregular/PCOS; the insight feed surfaces calibrated cross-metric correlations and a shareable on-device doctor PDF; wrist-temp + Foundation-Models summaries ship with first-class fallbacks; perimenopause depth lands. All copy passes the health-claim guard; verified zero network egress.

**Est. effort:** ~2 M · 3 L ≈ **22–26 person-days** (split across v1.4 = int-1/int-2/int-5-perimeno, v1.5 = int-3/int-4/endo+PCOS).

---

## Phase 5 — Privacy Moat & Coercion-Resistance (v1.6)

**Goal:** Turn the local-only architecture into a threat-model-grade, verifiable moat: app-managed PIN, duress/decoy unlock + complete secure-wipe, scheduled auto-sweep, and a Trust Center that is verifiable proof rather than prose.

**Why now / dependencies:** Hard-depends on **Phase 3** — the new `UserProfile` PIN/sweep fields ride the versioned migration, and `priv-3`/`priv-4` secure-wipe must purge *every then-existing* storage location (SwiftData store file, app-group widget snapshot, Keychain, pending notifications, and the Apple Health samples Caelyn wrote). CloudKit is still OFF this release, so the CloudKit private-DB purge is **added to the wipe in Phase 6**, not here. `priv-2` is the prerequisite for the duress suite. `priv-6` re-finalizes copy against shipped behavior.

| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **priv-2** App-managed PIN (Keychain salted hash, `…ThisDeviceOnly`, throttled lockout) | `Services/PINService.swift` (new), `BiometricService.swift`, `AppLockGate.swift`, `SettingsView.swift`, `UserProfile.swift` | M | Raw PIN never persisted; coexists w/ biometrics without breaking the Phase-0 switcher cover / Face-ID no-loop; delete-all clears the Keychain entry |
| **priv-3** Duress/decoy PIN — coercion-resistant unlock (decoy vault **or** silent secure wipe) + complete `SecureWipeService` | `PINService.swift`, `SecureWipeService.swift` (new), `Persistence.swift`, `AppLockGate.swift`, `NotificationService.swift` | L | Duress flow indistinguishable from normal unlock; wipe removes store file + widget snapshot + notifications + Keychain + Caelyn-authored Health samples; decoy path never loads the real vault; test harness verifies completeness (CloudKit purge added in Phase 6) |
| **priv-4** Scheduled auto-sweep (inactivity auto-lock + opt-in, heavily-warned auto-wipe; injectable clock) | `Services/AutoSweepService.swift` (new), `CaelynApp.swift:34-39`, `SettingsView.swift`, `UserProfile.swift`, `AppLockGate.swift` | M | Auto-lock after configured window; auto-wipe OFF by default, requires explicit opt-in, only fires on genuinely-elapsed window (tested w/ mock clock); reuses `SecureWipeService` |
| **priv-6** Privacy Trust Center proof — data manifest, honest network statement, reconciled claims | `Views/Settings/PrivacyTrustView.swift`, `iCloudSyncView.swift`, `AppURLs.swift`, `Caelyn.entitlements` | M | Every claim true of shipped behavior; manifest enumerates real storage locations; **no "no network entitlement" line** (false on iOS) — states egress is Apple-only + points to App Privacy Report; `availableKind()` hoisted to one call |

> **Re-run `priv-7` (privacy labels) at this release** — the per-release checklist in `docs/AppStore/privacy-labels.md` must be re-verified now that a PIN/Keychain + secure-wipe exist.

**Exit criteria / milestone — v1.6:** PIN + duress/decoy unlock + complete secure-wipe + opt-in auto-sweep all ship and pass the completeness harness; Trust Center is verifiable and word-consistent with ASC privacy copy; no claim is false. Caelyn now matches Euki/drip on threat-model and beats them on polish.

**Est. effort:** ~3 M · 1 L ≈ **14–18 person-days**.

---

## Phase 6 — Real iCloud Sync + Partner Share (v2.0)

**Goal:** Make-real of what Phase 0 retracted: enable encrypted private-CloudKit sync (behind a staged flag, after the migration has baked), add conflict resolution + post-sync dedup, then rebuild Partner Share for real.

**Why now / dependencies:** Hard-gated by **Phase 3** (CloudKit-valid v2 schema + migration field-proven) and **`qa-6`** migration tests. CloudKit production schema deploys are **one-way/irreversible**, so the v2 shape must be frozen first. Bidirectional sync is far harder to roll back than a forward migration — hence it ships only after v1.3 has baked in the field. The CloudKit entitlement (stripped since Phase 0) is re-added here.

| Task | Files | Effort | Acceptance (gate) |
|---|---|---|---|
| **data-cloudkit-enable** Enable `.private` CloudKit sync behind `cloudSyncEnabled`; re-add entitlement; deploy v2 record types to production; honest 3-state status (`accountStatus`) | `Services/Persistence.swift`, `iCloudSyncView.swift`, `Caelyn.entitlements` | L | v2 types in CloudKit production; **first-enable of sync with pre-existing local data converges with no loss**; 2 signed-in devices converge; UI accurate for no-account/active/unavailable; simulator/flag-off runs local-only with zero crashes |
| **data-conflict-resolution** Conflict resolution + debounced post-sync dedup (remote-change observer); single-`UserProfile` convergence | `Services/CycleStore.swift`, `Persistence.swift` | M | Two-device same-day entry (incl. both seeded with pre-sync data) converges to one merged row; dedup debounced on remote-change; never two profiles; policy documented in-code |
| **Partner Share — rebuilt for real** *(deferred from Phase 0 `stz-004`; no track-design task id — newly scoped here)* | `ShareModeView.swift` (rebuild), `Services/CycleStore.swift` | L | Shares actual SwiftData records (not an empty zone); `publicPermission=.none` + `UICloudSharingController([.allowReadOnly])`; restore the E2E copy **only** once data genuinely flows |

> **Re-run `priv-6` + `priv-7`** for the iCloud-enabled wording: Trust Center/labels shift from "local-only, no servers" to "your iCloud, never our servers" — and the `SecureWipeService` (`priv-3`) must now **also purge the CloudKit private DB**; extend its completeness harness accordingly.

**Exit criteria / milestone — v2.0:** Encrypted private-CloudKit backup + multi-device sync converge correctly under conflict; Partner Share works end-to-end with honest E2E framing; secure-wipe purges the CloudKit private DB; the once-retracted features are now real and accurately marketed. Validated on two physical devices + a TestFlight cohort before broad rollout.

**Est. effort:** ~1 M · 2 L ≈ **15–19 person-days** (cannot be CI-validated — requires two real devices + sandbox iCloud; keep behind the kill-switch flag).

---

## Dependency callouts — the ordering traps that matter most

1. **`stz-001` is the universal root.** The project does not compile today (`UserProfile.swift:21,62`). Nothing — no build, test, CI, or other task in any track — exists until it lands. It is task #1, full stop.
2. **Schema/migration/dedup must ship atomically, and CloudKit must wait for it to bake.** Dropping `@Attribute(.unique)` (Phase 3) removes the *only* one-day backstop — `data-dedup-layer` + `data-migration-plan` must land in the **same release**, gated by `qa-6`, and `data-cloudkit-enable` (Phase 6) only after v1.3 is field-proven, because CloudKit production schema deploys are irreversible and bidirectional sync is hard to roll back. **Phase 0 sidesteps all of this by KEEPING `.unique` and retracting iCloud.**
3. **Honest UI cannot precede the truth it describes.** Phase 0 already audits *in-app* Trust Center copy for now-false claims (`stz-007`) and finalizes labels/metadata last (`priv-7`/`stz-007`); the watch ships an honest empty state, never fabricated data (`stz-018`). The full *verifiable-proof* Trust Center rebuild (`priv-6`) only claims secure-wipe/sync semantics after Phases 5/6. Re-verify labels every release via the versioned checklist.
4. **Secure-wipe depends on the full storage map.** `priv-3`/`priv-4` (Phase 5) require the Phase-3 store architecture *and* must purge the SwiftData file + widget app-group snapshot + Keychain + notifications + Caelyn-authored Health samples (and, once Phase 6 enables sync, the CloudKit private DB). An incomplete wipe silently breaks the entire privacy promise — gate it behind a completeness test harness, extended in Phase 6.
5. **Shared cycle-math precedes every widget/watch fix.** `plat-1` (pure `CycleDayMath` added to all 3 targets) must precede `plat-2/3/4/5`, or the extensions can only display stale precomputed numbers — the headline midnight-rollover defect.
6. **Four files are multi-owner — sequence to avoid churn.**
   - `ExportService.swift`: Phase-0 `stz-002` race fix → Phase-1 `plat-13`/`qa-5` correctness → Phase-4 `int-2` doctor PDF.
   - `HomeView.swift`: `stz-009`+`stz-010`+`stz-014` together (Phase 0) → `mon-4` soft paywall (Phase 2) → `data-dedup-layer` upsert routing (Phase 3) → `int-1` (Phase 4).
   - `PurchaseService.swift`: `stz-005=mon-1` (Phase 0) → `mon-2`/`mon-3` (Phase 2) → `mon-8` (Phase 3).
   - `PredictionEngine.swift`/`CalendarMath.swift`: `qa-2` injectable-Calendar + `stz-009`/`stz-014` correctness (Phase 0) → `plat-1` pure-math extraction (Phase 1) → `int-1` adaptive model (Phase 4).
   Land the earlier-phase fix first; the later edits sit on top.

---

## Suggested release cadence

| App Store version | Phase(s) | Theme |
|---|---|---|
| **1.0** | Phase 0 | Stabilize & ship honest, local-only, crash-free (the gate release) |
| **1.1** | Phase 1 | Platform polish: widgets/watch/a11y/iPad + finished stubs |
| **1.2** | Phase 2 | Monetization funnel: trial, lifetime, soft paywall |
| **1.3** | Phase 3 | Data foundation: versioned schema + migration + dedup (sync OFF) |
| **1.4 / 1.5** | Phase 4 | Intelligence: adaptive engine, insights+doctor PDF, perimenopause → wrist-temp, on-device AI |
| **1.6** | Phase 5 | Privacy moat: PIN, duress/decoy, secure-wipe, auto-sweep |
| **2.0** | Phase 6 | Real private-CloudKit backup/sync + Partner Share (make-real) |

*Parallelization:* Phase 4 (Intelligence) depends on Phase 0 — and, for `int-2`'s doctor PDF, Phase 1's export correctness — and can otherwise run as a parallel workstream alongside Phases 2–3, pulling its ship forward if staffed separately. Phase 5 cannot start before Phase 3.

---

## One-screen summary

| Phase | Theme | Key outcome (milestone) | Effort |
|---|---|---|---|
| **0** | Compile · De-risk · De-fraud · Ship | **v1.0 submitted**: builds clean, no crash/race, no false iCloud/Share/watch claims, P0 correctness fixed, CI+regression net, on TestFlight→ASC | ~46–56 pd |
| **1** | Platform Polish & Stubs | **v1.1**: widget/watch correct across midnight, WCAG-AA + Dynamic Type + VoiceOver, iPad fixed, export/reminders/HealthKit finished | ~40–45 pd |
| **2** | Monetization Funnel | **v1.2**: free trial + lifetime + dismissible privacy-led soft paywall, honest disclosure, ASC parity | ~20–24 pd |
| **3** | Data Foundation | **v1.3**: versioned/migratable/CloudKit-valid schema + app-layer dedup, **zero data loss**, sync OFF | ~16–22 pd |
| **4** | Intelligence & Differentiation | **v1.4/1.5**: adaptive predictions, cross-metric insights + doctor PDF, wrist-temp, on-device AI, perimenopause depth | ~22–26 pd |
| **5** | Privacy Moat | **v1.6**: PIN + duress/decoy + complete secure-wipe + auto-sweep + verifiable Trust Center | ~14–18 pd |
| **6** | Real Sync + Share | **v2.0**: encrypted private-CloudKit backup/sync + conflict resolution + real Partner Share | ~15–19 pd |

---

## Deferred / explicitly out of scope

- **Partner Share rebuild** is deferred from Phase 0 (disabled there) to **Phase 6** and scoped as a new item — no track design produced a numbered task for it; treat as ~L.
- **Watch midnight-recompute, structured fertility, and phone→watch push-gating** are deferred from Phase 0 (`stz-018` ships only the honest empty state) to **Phase 1 `plat-4`**.
- **On-device LLM conversational companion** (full chat) is explicitly **out of scope** (the diagnosis marks it XL); only NL summaries (`int-4`) are in-plan.
- **`int-3` → `int-1` luteal-learning feedback** (temp-confirmed ovulation refining the adaptive engine) is a Phase-4 *optional* follow-up, not a hard dependency.
- **macOS/visionOS targets, OPK vision scanner, bundled offline education library** — not in any track; not planned.

**Every task id from all 7 tracks is mapped to exactly one phase** (the 3 cross-track duplicates — `stz-005/mon-1`, `stz-006/mon-5`, `stz-008/priv-1` — are noted as single combined rows in Phase 0; `stz-018` and the Phase-6 Partner Share rebuild are newly scoped and flagged as such).

**Key open questions to resolve before/within the noted phases** (carried from the tracks): App Store Connect access + demo/reviewer needs (Phase 0); lifetime price + trial length/placement (Phase 2); `CycleEntry.date` kept non-optional-with-default vs truly optional, and confirmation the last shipped schema == "current minus the compile bug" (Phase 3); duress behavior = decoy vault vs silent wipe vs both, and confirmation the wipe purges Caelyn-authored Health samples (Phase 5) and the CloudKit private DB (Phase 6); CloudKit Console access to freeze+deploy the v2 production schema (Phase 6).