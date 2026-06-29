# Caelyn — Full Diagnosis & Plan

> **Generated 2026-06-28** by a 48-agent diagnostic workflow: 18 feature areas read line-by-line, 7 whole-app cross-cutting sweeps (date/TZ, SwiftData, concurrency, StoreKit, privacy, accessibility, edge-states), 3 market lenses — every claimed bug adversarially re-verified against source. Coverage: 18 areas, 82 bugs claimed → 54 confirmed + 25 cross-cutting findings. The headline Critical/High items were additionally hand-verified against the code, and a clean `xcodebuild` was run to catch compile-time blockers a static read cannot see.

---

## 0. BUILD STATUS — the app does not compile (P0, blocks everything)

A clean build fails (`xcodebuild -scheme Caelyn ... build` → exit 65). SwiftData's `@Model` macro rejects **enum-shorthand defaults** on stored properties:

```
UserProfile.swift:21:9: error: A default value requires a fully qualified domain named value (from macro 'Model')
UserProfile.swift:62:9: error: A default value requires a fully qualified domain named value (from macro 'Model')
```

- `Caelyn/Models/UserProfile.swift:21` — `var theme: AppTheme = .system`
- `Caelyn/Models/UserProfile.swift:62` — `var birthControlMethod: BirthControlMethod = .pill`

**Fix (1 file, 2 lines):** fully-qualify the enum defaults → `AppTheme.system` and `BirthControlMethod.pill`. The `.system` / `.pill` used in the `init(...)` *parameter* defaults (lines 80, 106) are correct and need no change. **Effort: S.** This must land first — nothing else in this report can be built or tested until the project compiles. (The 48-agent audit read the code but did not build it, so it did not surface this; my build did.)

---

## 1. Executive summary

**Verdict: structurally excellent, shippably risky.** Caelyn is a feature-rich, well-architected SwiftUI/SwiftData period tracker whose *engines* (prediction, analytics, pattern, calendar math, notifications) are genuinely solid — DST-safe date handling, guarded empty states, no force-unwraps, balanced continuations, correct `@MainActor` isolation. The codebase is far above typical indie-app quality. But three release-blocking defect classes — **all Critical** — stand in the way: **(1) a marketed-but-dead iCloud backup** that exposes users to total data loss and ships inaccurate App Store metadata; **(2) a partner-Share feature that is non-functional, falsely marketed as end-to-end encrypted, and carries a latent public-link leak**; and **(3) a data race during export that can crash.** Several "complete" features are in fact stubs or silently broken in exactly the situations users care most about (late period, first-run, offline Pro, midnight rollover).

**Headline numbers**

| Metric | Count |
|---|---|
| Areas audited | 18 (+ 6 cross-cutting sweeps) |
| Features inventoried | ~190 |
| Truly broken / stub / fake (UI present, no real function) | 5 (iCloud sync, Share mode, HealthKit symptom-read, onboarding reminders 2/4, watch data for non-Pro) |
| **Critical bugs** | **3** |
| **High bugs** | **8** |
| **Medium bugs** | **14** |
| **Low bugs** | **30** |

**Single biggest opportunity:** Caelyn's no-backend architecture makes its privacy claim *structurally true and independently verifiable* — something every cloud competitor cannot say after the recent wave of femtech privacy actions. Fix the iCloud claim (make it real via private CloudKit, or stop claiming it), then weaponize "warrant-proof by architecture" + on-device intelligence as the entire brand. That is the wedge no large rival can copy — but it only works if the false iCloud/Share claims are corrected first, because a privacy brand caught shipping a false E2E claim is worse off than one that never made it.

---

## 2. Feature inventory

### Complete and working (free unless noted)
- **Logging:** flow, pain (level + types), 22+ built-in symptoms + up to 5 custom, symptom severity, mood (11), energy (5), basal temperature, cervical mucus, medication, ovulation/LH test, pregnancy/sexual-activity, free-form note. Date selector (14-day pills), delete with confirmation, auto-save on blur.
- **Engines:** cycle reconstruction, recency-weighted cycle length, variation, current cycle day, next-period prediction + window, ovulation estimate, fertile window (Pro), adaptive PMS window (Pro), phase classification, irregular-cycle detection, confidence levels, logging streak.
- **Home:** header, hero cycle ring, quick actions, streak grid, period-state prompts, period-start editor, irregular banner, Coming Up timeline, pattern insight, TTC dashboard (Pro), Pregnancy/Postpartum cards (Pro).
- **Calendar:** 42-day grid, first-weekday localization, multi-state day markers, day-detail sheet, month summary, legend, swipe nav, predicted/active-period rendering.
- **Insights:** stats grid, patterns, Pro pattern insights, Year-in-Review (Pro 12mo / free 3mo), cycle-history timeline, 6 charts (Pro), empty state, upsell.
- **Settings:** cycle/period length, last-period date, irregular toggle, condition modes (Perimenopause/Endo/PCOS — Pro), TTC/Pregnancy/Postpartum (Pro), privacy trust center, app lock (biometric/passcode), preview masking, private notifications, theme, first-day-of-week, reminders summary, delete-all, export.
- **Services:** HealthKit bidirectional flow sync (write + import + dedup), symptom/pain write, notifications (daily check-in, medication, birth-control, quiet hours, privacy mode), StoreKit 2 (monthly/yearly, restore, transaction listener, dynamic pricing), biometrics, rating gate, persistence cascade (CloudKit→local→in-memory), CSV/PDF export.
- **Platforms:** WidgetKit (5 families), watchOS app (ring, quick log, countdown), app-group bridge, app shell, lock gate, education/phase guides.

### Partial / Stub / Fake (UI present, no real function) — called out explicitly
- **FAKE/STUB — iCloud backup/sync.** `iCloudSyncView` shows "iCloud backup active … syncs automatically across your devices … reinstall and your history returns." In reality the CloudKit container **never initializes** (schema incompatible) and the app runs local-only on every launch. The status is derived from "is the user signed into iCloud at all," not from whether sync works. **Users are told their data is backed up when it is not.**
- **FAKE/STUB + LATENT LEAK — Share with partner.** Creates a CKShare on an **empty custom zone** (no cycle data is ever written there → a partner sees nothing today), and sets `publicPermission = .readOnly`. Two distinct problems: (1) the in-app "end-to-end encrypted, read-only for your partner" promise is **false now** regardless of data flow; (2) the public permission means data becomes **world-readable by link the moment** the feature is fixed to push real records. Non-functional today *and* unsafe by design.
- **PARTIAL — Birth-control mode.** Functional, but the contraceptive-adherence reminders (pill/patch/ring) are locked behind Pro — an App-Review sensitivity (gating safety-adjacent features).
- **PARTIAL — HealthKit "Read symptoms from Health."** Disabled placeholder ("coming in a future update"). Intentional, but the read path is one-directional today.
- **PARTIAL — Onboarding reminders.** Only 2 of 4 reminder types (daily check-in, medication) are exposed; `remindPeriodStart` / `remindOvulation` always persist as `false`.
- **FAKE — Watch data for non-Pro / pre-sync.** Watch shows hardcoded placeholder cycle data (Day 14, Follicular, "Period in 14 days") as if real, because the phone only pushes snapshots for Pro and app-group containers aren't shared phone↔watch.
- **PARTIAL — CSV export.** Medication/notes escaped per RFC 4180; custom symptoms are **not** escaped (comma → malformed CSV).
- **BUGGY — Mood Check-In / CycleRingView.** Dead code branch; 1-indexed display vs 0-indexed arc → visual off-by-one.
- **INTENTIONAL — Screenshot/Pro-override mode.** Deliberate stub for App Store captures.

---

## 3. Bugs & issues

Sorted Critical → Low. Per-area and cross-cutting findings merged and deduped.

| Severity | Area | Issue | File:line | Fix |
|---|---|---|---|---|
| **Critical** | SwiftData / iCloud | CloudKit store can never init: `@Attribute(.unique) var date` + non-optional `date` with no default are both illegal for CloudKit, so the container throws every launch → app silently runs local-only. iCloud sync has **never** worked despite being entitled and marketed → real data-loss exposure + inaccurate App Store metadata. | `Persistence.swift:33-44,21`; `CycleEntry.swift:6` | Remove `.unique`, make model fully optional/defaulted, enforce one-entry-per-day at app layer + dedup pass. Pair with a migration plan (below). |
| **Critical** | Export / Concurrency | `Task.detached` reads SwiftData `@Model` objects (`CycleEntry`/`UserProfile`, non-Sendable) off the main actor while the main context/CloudKit/`@Query` may mutate the same rows → data race, possible `EXC_BAD_ACCESS`/torn reads during export. Reproducible export crash is also an App-Review reject. | `ExportView.swift:267-278` (reads in `ExportService.swift:67-89,196-369`) | Snapshot needed fields into Sendable value structs on MainActor, pass only those to the background task; or generate on MainActor. |
| **Critical** | Settings / Share | Partner share sets `publicPermission = .readOnly` while the UI promises "end-to-end encrypted, read-only for your partner." The shared zone is empty so nothing leaks *yet*, but (a) the false E2E claim alone is an App-Review (5.1) + trust blocker now, and (b) the public permission makes data world-readable by link the instant the feature is fixed to push real records. | `ShareModeView.swift:180` | Disable the feature now; before re-enabling, set `publicPermission = .none` and add participants via `UICloudSharingController([.allowReadOnly])`. |
| **High** | iCloud / UX honesty | CloudKit init failure swallowed by `try?` (no log, no flag); `iCloudSyncView` reports "backup active" purely from `ubiquityIdentityToken != nil`, decoupled from whether sync runs → actively misleads users into skipping manual export. | `Persistence.swift:41`; `iCloudSyncView.swift:5-7,59-64` | do/catch with concrete logging; expose `isCloudKitActive`; drive UI status from that flag. |
| **High** | SwiftData | No `VersionedSchema`/`SchemaMigrationPlan`. The CloudKit fix (removing a unique attr, defaulting `date`) is a destructive change inferred migration can't handle → store may fail to open → in-memory fallback silently drops all data. | `Persistence.swift:21,56-58` | Introduce v1 VersionedSchema + migration plan; model CloudKit change as v2 custom stage; add a launch test opening a v1 store with v2 schema. |
| **High** | Settings / Share | Share targets a brand-new empty `CaelynShared` zone; SwiftData data lives in its own CloudKit zone, never mirrored → partner sees nothing. Feature is non-functional. | `ShareModeView.swift:176` | Mirror/share the SwiftData-managed records, or don't ship as working until data actually flows. |
| **High** | Widget / Watch | Snapshot stores precomputed `cycleDay`/`daysUntilPeriod`; widget/watch never recompute for the new day. After midnight (app not opened) the single most important number is **wrong for up to a day**. | `CaelynWidgetProvider.swift:23-31`; `WidgetDataSync.swift:20-96`; `WatchHomeView.swift:42` | Store raw anchor inputs + share PredictionEngine day-math; emit a timeline entry per local midnight (`.after(nextMidnight)`); recompute per entry. |
| **High** | Home | Late-period prompt can **never** display and countdown is misleading: `nextPeriodStart` rolls forward to always be `>= today`, so `isPeriodLate` is always false and a 7-days-overdue user is told "Period in 21 days." | `HomeView.swift:245-264`; `PredictionEngine.swift:100-113` | Compute un-rolled `expected = lastPeriodStart + cycleLength`; base late-detection/`daysLate` on that; keep rolled value only for the not-late countdown. |
| **High** | Home / First-run | Brand-new or "Not sure" users (lastPeriodStart nil — a primary acquisition path) see "Period expected in 0 days" with no real prediction. | `HomeCopy.swift:64-68` | Gate period/PMS/fertile rows on `phase != .unknown` / `nextStart != nil`; fall back to "Nothing on the horizon." |
| **High** | Log | `onDisappear` unconditionally commits note/medication/temp → `withEntry` inserts an empty `CycleEntry` for any date merely *viewed* (`.id(selectedDate)` tears down on each pill tap). Phantom "logged" dots, phantom delete button, suppressed onboarding hint, inflated counts/review gate. | `DailyLogForm.swift:46-50,767-769,839-857` | Make commit helpers no-op when value is nil and no existing entry (mirror pain-slider guard at line 163). |
| **High** | StoreKit | Entitlement refresh is coupled to a successful product network fetch; on offline cold launch a paying Pro user silently reverts to free (also an App-Review risk on flaky Wi-Fi). | `PurchaseService.swift:65-78,104-124` | Call `refreshPurchasedProducts()` in `init()` unconditionally and on catch paths (currentEntitlements is cache-served, no network needed). |
| **Medium** | Log | 2-decimal basal temp gets silently re-rounded to `%.1f` and re-saved on revisit even when untouched → user data mutated. | `DailyLogForm.swift:44,527,847-857` | Seed draft with `%.2f`; skip commit when parsed draft equals stored value. |
| **Medium** | Settings | Toggling Pregnancy/Postpartum mode on never persists a date (picker shows a default that's never written) → Home card silently never appears. | `CycleSettingsView.swift:337-340,382-385` | In onChange, persist default date when enabling the mode. |
| **Medium** | HealthKit | `backfillSymptomsToHealth` doesn't delete existing app-written samples first (flow path does) → re-tapping Backfill duplicates symptom/pain samples in Health. | `HealthKitService.swift:167-180` | Delete own symptom/pain samples before rewrite, paralleling `deleteAllOwnFlowSamples()`. |
| **Medium** | Onboarding | HealthStep `onAppear` calls `vm.next()` whenever HealthKit unavailable (iPad!) → Back button bounces forward; user can never return to fix Goals/lengths. | `OnboardingSteps.swift:921-924` | Respect nav direction (skip backward on back); or exclude `.health` from sequence when unavailable. |
| **Medium** | Export | Custom symptoms not CSV-escaped → comma in a symptom corrupts the row. | `ExportService.swift:82` | `loggedCustomSymptoms.map(escape).joined(separator:";")`. |
| **Medium** | Export | Long notes silently clipped in PDF (`draw(in:)` truncates with no indicator). | `ExportService.swift:393-394` | Manual line-breaking/pagination or truncation ellipsis. |
| **Medium** | Export / TZ | All export DateFormatters set only `dateFormat`, inheriting device calendar → non-Gregorian calendars (Buddhist/Hijri) render wrong era/year in the clinical export. | `ExportService.swift:56-57,173-174,253-254,336-337,386-387,451-452` | Pin `calendar = .gregorian`, `locale = en_US_POSIX` for machine-readable fields. |
| **Medium** | Watch | Non-Pro (and pre-first-sync Pro) watch shows hardcoded placeholder cycle data as if real; quick-log still accepts input. | `WidgetDataSync.swift:148-150`; `WatchHomeView.swift:7` | Show explicit empty/"open iPhone" state when snapshot nil; reserve placeholder for previews; reconsider the isPro push gate. |
| **Medium** | Watch | Fertility label derived by substring-matching `upcomingLine1` ("ovulat"/"fertil") → silent breakage if phone text format changes. | `WatchHomeView.swift:99-101` | Add structured `FertilityStatus` enum to the snapshot. |
| **Medium** | Engine / Integrity | `cycles(from:today:)` ignores `today`; a future-dated flow tap becomes a "period start" → huge fake cycle skews `averageCycleLength` app-wide and can false-trigger irregular banner. | `PredictionEngine.swift:10-24`; `CalendarMath.swift:157` | Filter dayStarts to `<= startOfDay(today)` (param already threaded); same in `activePeriodWindow`. |
| **Medium** | Concurrency | Overlapping fire-and-forget HealthKit sync Tasks aren't serialized; delete-then-rewrite can interleave → duplicate/missing Health samples. | `HomeView.swift:491,508,547,566`; `DailyLogForm.swift:781` | Per-date sync coordinator that cancels the prior in-flight task. |
| **Medium** | Privacy | App-switcher snapshot can capture content before the 150ms privacy-shield fade completes (`shouldMask` only on `.background`). | `AppPreviewMask.swift:9,14-19` | Trigger mask on `.inactive`; drop the fade; consider snapshot-ignore API. |
| **Medium** | Privacy | AppLockGate relocks only on `.background` and animates a 0.25s opacity cover → unlocked UI is visible in the switcher carousel during `.inactive` and mid-fade. | `AppLockGate.swift:40-48,20-21,34` | Relock when `newPhase != .active`; render lock overlay opaquely with no animation. |
| **Medium** | StoreKit / Review | Contraceptive (pill/patch/ring) reminders gated behind Pro — Apple flags gating of safety-adjacent features. | `SettingsView.swift:408-416` | Move at least the basic pill reminder to free, or justify in review notes. |
| **Low** | Engine | `cycleLengthVariation` integer-truncates `(max-min)/2`; a 15-day spread yields 7 (not `>7`) → under-flags irregular cycles at boundary. | `PredictionEngine.swift:72,248` | Round, or compare on undivided spread `(max-min) > 14`. |
| **Low** | Engine | `adaptivePmsDaysBefore()` truncates mean instead of rounding (inconsistent with `weightedMean`). | `PredictionEngine.swift:176` | Use `.rounded()`. |
| **Low** | Calendar | Predictions shown only for the single next cycle; months 2+ ahead appear empty of markers. | `CalendarMath.swift:110-132` | Project cycle forward across visible days. |
| **Low** | Engine | Engine cycle/period averages unclamped (Settings clamps 18–45 / 1–12); frequent small-gap logging can yield "Day x of 3" rings. | `PredictionEngine.swift:55-73` | Clamp returned averages to realistic bounds. |
| **Low** | Log | Flow/energy/ovulation toggles create empty entries when set to nil on an empty form (pain slider guards correctly; these don't). | `DailyLogForm.swift:80,470,597` | Add `(value != nil || entry != nil)` guard. |
| **Low** | TTC | `result()` accepts `cycleDay`/`cycleLength` that are never used (stale signature). | `TTCFertilityEngine.swift:16-18` | Remove unused params. |
| **Low** | Pattern | Insight body says symptom appeared "in N of your last cycles" but N is occurrence count, not cycles → inflates pattern strength. | `PatternEngine.swift:129` | Reword to occurrences, or compute distinct-cycle count. |
| **Low** | Home | Dead `case 0` in `latePromptTitle` (unreachable). | `HomeView.swift:305` | Remove. |
| **Low** | Home | `logPeriodToday` toggle-off clears flow but not `lastPeriodStart` → stale period-start drives predictions. | `HomeView.swift:500-511` | Mirror `removePeriodLog`: clear/recompute lastPeriodStart. |
| **Low** | Home | Header shows "Day 1 · Cycle" for users with no logged cycle, under a "Welcome to Caelyn" hero. | `HomeHeader.swift:15-25` | Suppress subline when phase `.unknown`. |
| **Low** | Home | Stale Pregnancy/Postpartum modes freeze at "Week 42 · 0 days left" / unbounded "Week 230 postpartum." | `PregnancyModeCard.swift:14-52,104-107` | Prompt mode switch when due date past; cap postpartum window. |
| **Low** | Calendar/Components | DateFormatter allocated per render in DayCell, DayDetailSheet, MonthSummaryCard, DataStatusCard; several use locale-ignoring fixed formats. | `DayCell.swift:7-11`; `DayDetailSheet.swift:7-11`; `MonthSummaryCard.swift:7-11,27-30`; `DataStatusCard.swift:30` | Use `Date.formatted(.dateTime…)`; centralize cached formatters. |
| **Low** | Insights | A11y labels compute averages via integer division (28.5→28). | `InsightsCharts.swift:11,68,207` | Average as Double, format `%.1f`. |
| **Low** | Insights | Empty-state "/3 cycles" + "a couple more" copy contradicts the 2-cycle unlock threshold. | `InsightsView.swift:41`; `InsightsEmptyState.swift:47-49,68` | Drive denominator + copy from one shared constant. |
| **Low** | Settings | Pregnancy due-date picker has no range constraint. | `CycleSettingsView.swift:344-351` | Add `in:` range. |
| **Low** | Settings | `BiometricService.availableKind()` called 4× (4 LAContexts) in one array init. | `PrivacyTrustView.swift:25-26` | Hoist to a local. |
| **Low** | Settings/Reminders | Quiet-hours window label hardcoded "(10 PM–7 AM)" while logic uses constants → latent drift. | `RemindersView.swift:267` | Derive from `quietHoursStart/End`. |
| **Low** | Settings/Share | CloudKit zone-discovery errors silently caught in `try?`. | `ShareModeView.swift:159` | Log errors. |
| **Low** | Onboarding | Silent fetch error could create duplicate profiles; no error feedback if completion save fails; unused `skipHealthStep()` + `FeatureSlideIllustration` dead code; unused reminder types persist false. | `OnboardingViewModel.swift:82-84,110,31-37`; `OnboardingAnimations.swift:118-154` | Proper error handling; remove dead code; expose or drop reminder flags. |
| **Low** | Onboarding / TZ | `lastPeriodStart` stored without `startOfDay` normalization (every other write site normalizes). | `OnboardingViewModel.swift:11,97` | Normalize at write. |
| **Low** | Export / TZ | Range cutoff computed from `.now` (with time) vs midnight-stored entries → boundary day dropped. | `ExportService.swift:44-50` | Normalize base to startOfDay before subtracting. |
| **Low** | Export | `drawEntryTable` and `drawNotes` call `beginPage()` directly → footer skipped on overflow pages. | `ExportService.swift:347-353,389` | Use `breakPage(page:ctx:)`. |
| **Low** | Paywall | First-open flashes "Couldn't load subscription options" before `.task` sets loading. Purchase button doesn't dim when already Pro. Tier card can appear selected but be unpurchasable if only one product loads. | `PaywallView.swift:22-29,257,302-304` | `hasAttemptedLoad` flag; dim on `isPro`; require both products. |
| **Low** | StoreKit | Restore failures (network) reported as "no subscription found"; vestigial `UserProfile.isPro` flag diverges from StoreKit truth; unused strikethrough-price infra. | `PaywallView.swift:431-434`; `UserProfile.swift:68,87,104`; `PaywallTierCard.swift:6,114-122` | Branch on `lastError`; delete `UserProfile.isPro`; keep strikethrough nil/remove. |
| **Low** | Widget | Lock-screen accessory widgets expose cycle data with no privacy filtering; placeholder `isPro:true`; hardcoded fonts ignore Dynamic Type; no combined VoiceOver labels; empty content area in no-data state. | `WidgetViews.swift:286-349,66/127/200`; `WidgetDataStore.swift:34-51,48` | Privacy-masked accessory mode; `isPro:false` placeholder; scale fonts; `.accessibilityElement(.combine)`; empty-state row. |
| **Low** | Watch | Empty log submittable (None flow = `""` ≠ nil); `pendingLogSent` set but never read/cleared. | `WatchQuickLogView.swift:130`; `WatchDataModel.swift:31` | Treat `""` as empty; use or remove the flag. |
| **Low** | Components | Hardcoded white text on dark-mode plum fails WCAG AA (CaelynButton primary + MoodChip selected); fixed font sizes (`numberLarge/Medium`) ignore Dynamic Type; CycleRingView 1-indexed display vs 0-indexed arc → off-by-one. | `CaelynButton.swift:46`; `MoodChip.swift:17`; `Typography.swift:15-16`; CycleRingView | Adapt foreground per colorScheme; scaled fonts; align ring indexing. |
| **Low** | Persistence/Notifications | Unused `RatingService.sessionCount` key; outdated "14 requests" comment; `dateSuffix` formatter not calendar-pinned. | `RatingService.swift:14`; `NotificationService.swift:46-50,368-372` | Remove/implement; update comment; pin calendar. |
| **Low** | HealthKit | Delete completion errors ignored → silent failures may cause duplicates; HKSampleQuery handlers touch `@MainActor static store` from background queue (Swift-6 strict-concurrency warning, safe today). | `HealthKitService.swift:159,264,149-162,221-235,251-271` | Log delete errors; capture local `let store` or `nonisolated(unsafe)`. |
| **Low** | App shell / Concurrency | Per-scene-phase unstructured Tasks can stack; highlight Task untied to view lifetime. | `CaelynApp.swift:34-39`; `MainTabView.swift:147` | Use `.task(id:)`; cancel prior. |

---

## 4. Cross-cutting risks

- **SwiftData / data loss — CRITICAL.** iCloud sync is dead-on-arrival yet marketed as active; no migration plan means the *fix itself* is destructive; removing the unique constraint for CloudKit erases the only duplicate-per-day backstop; the in-memory fallback can silently discard everything. **This is the report's headline risk.**
- **Privacy promise vs reality — CRITICAL (false E2E claim) / HIGH (rest).** Two marketed promises are false: "iCloud backup active" (sync never runs) and "end-to-end encrypted, read-only for your partner" (public permission on an empty zone). The false E2E claim is an App-Review + brand-existential blocker on its own. Lock-screen widgets and the app-switcher snapshot/lock-gate timing also leak data for a privacy-first brand. Everything else (local-only, no analytics, no SDKs) is genuinely true — protect that.
- **Concurrency — CRITICAL (one site) / otherwise clean.** The ExportView `Task.detached` over `@Model` objects is a true cross-actor race. Services are otherwise correctly `@MainActor`, continuations balanced, StoreKit listener uses `[weak self]`, WCSession delegates hop to MainActor. Secondary: non-serialized HealthKit sync Tasks (Medium).
- **StoreKit / App-Review compliance — HIGH.** Largely compliant (live `displayPrice`, Restore in two places, verify+finish, full auto-renew disclosure, no synthetic discounts/countdowns). Blockers: offline entitlement loss (High — tester-visible), contraceptive reminders gated behind Pro (Medium — safety gating), inaccurate metadata once the iCloud/Share claims change, and a vestigial local `isPro` flag (Low).
- **Date / TZ / DST — LOW (engines) / MEDIUM (edges).** Core math is DST-safe and uses `Calendar.startOfDay` + day-component arithmetic; no naive 86,400-second bugs. Real risks at the edges: widget/watch staleness across midnight (High), non-Gregorian export dates (Medium), `CycleEntry.date` stored as a TZ-bound absolute instant that can produce duplicate "days" after travel (Medium), and a few non-normalized writes (Low).
- **Accessibility / dark mode — LOW–MEDIUM.** Strong VoiceOver coverage in main views. Gaps: WCAG-AA contrast failures (white-on-plum), fixed font sizes ignoring Dynamic Type (typography + widgets), widget VoiceOver fragmentation, color-only flow/pain encoding.

---

## 5. Competitive gap analysis

> Reviewer note: the figures below are directional market context, not audited facts. Verify every specific number, settlement amount, and conversion benchmark before using any of it in public marketing or board materials. Named cloud rivals have well-documented privacy controversies; the precise dollar/percentage claims are not independently confirmed here.

| App | Model | Privacy posture | Key edge over Caelyn | Caelyn's edge over them |
|---|---|---|---|---|
| **Flo** | Cloud | Damaged — FTC action + reported Meta-related litigation (verify) | Brand, content, cloud AI, perimenopause, pregnancy | Structural privacy; no data to subpoena |
| **Clue** | Cloud/GDPR | Good (but server-based) | Inclusive/gender-neutral, 30+ data points, partner Connect, perimenopause | Local-only; on-device AI lane open |
| **Natural Cycles** | Cloud, paid | Commended | Only FDA-cleared contraceptive; wrist-temp ovulation | Free core; privacy; no regulated claims to defend |
| **Apple Health** | On-device | Strong default | Free, pre-installed, Watch, pregnancy + perimenopause notifications | Depth: doctor PDF, conditions, explainable predictions, coaching |
| **Euki / drip** | Local-only | Gold-standard (decoy PIN, sweeps, open source) | Threat-model UX; trust | Polish, modern UX, charts, modes, (planned) private backup |
| **Stardust** | Cloud | Reportedly compromised (verify) | Viral astrology angle | Honest, verifiable privacy |
| **Emerging "local + on-device AI" entrant** | Local + on-device AI | Claims Caelyn's exact pitch | First-mover risk on the "local + AI" slot | Must move fast before this slot is owned |

**Gaps that matter (scored by deliverability without breaking local-only):**
- **Must-have:** real private-CloudKit encrypted backup (neutralizes local-only's only weakness, out-privacies cloud rivals); adaptive on-device prediction (replace fixed 14-day luteal / 5-day PMS); **fix the offline-Pro and free-trial/onboarding-paywall funnel** (the biggest monetization lever — onboarding-time trial starts dominate paid conversion across the category).
- **High:** wrist-temperature ovulation read from HealthKit (Natural-Cycles value at $0, fully local); decoy/duress PIN + secure wipe (post-Roe trust); perimenopause mode (fastest-growing femtech; Apple only ships a notification); on-device cross-metric correlation insights ("your headaches cluster 2 days pre-bleed"); inclusive/de-gendered copy + pronouns; compassionate streak (freeze + grace).
- **Nice-to-have:** lifetime tier ("own it forever, nothing recurring, nothing in the cloud"), OPK vision scanner, privacy-safe partner/clinician share, bundled offline education, on-device LLM companion (Apple Foundation Models — the long-term killer wedge).

---

## 6. Prioritized plan

Every P0/P1 item is stated as **Problem → Fix → Effort**.

### P0 — Fix before next release (App-Review / privacy / data-loss / crash blockers first, then correctness)

1. **iCloud backup is dead and falsely marketed.**
   - **Problem:** CloudKit can never initialize (illegal `.unique` + non-optional un-defaulted `date`), so every launch silently runs local-only while `iCloudSyncView` reports "backup active" from `ubiquityIdentityToken != nil`. Users are told their data is backed up when it never is — data-loss exposure plus inaccurate App Store metadata. `Persistence.swift:21,33-44,41`; `CycleEntry.swift:6`; `iCloudSyncView.swift:5-7,59-64`.
   - **Fix:** Ship one of two paths this release. (a) Make it real: drop `.unique`, make the model fully optional/defaulted, add a `VersionedSchema` + `SchemaMigrationPlan` (CloudKit change as a v2 custom stage), enforce one-entry-per-day + dedup at the app layer, expose a true `isCloudKitActive` flag from a do/catch and drive the UI from it, and add a launch smoke test that opens a v1 store with the v2 schema. (b) Or retract: remove every backup/sync claim, surface a visible "local-only — export to back up" state, and ensure the in-memory fallback can never silently discard data without warning.
   - **Effort:** L (make real) / S (retract claim).

2. **Partner Share is broken, unsafe, and falsely marketed as E2E.**
   - **Problem:** The feature shares an empty zone (partner sees nothing) with `publicPermission = .readOnly` while the UI promises end-to-end encryption. The false E2E claim is an App-Review (5.1) + trust blocker now; the public permission becomes a world-readable leak the instant real data flows. `ShareModeView.swift:159,176,180`.
   - **Fix:** Disable the Share entry point in the UI this release. Before re-enabling: set `publicPermission = .none`, add participants via `UICloudSharingController([.allowReadOnly])`, share the actual SwiftData-managed records, stop swallowing zone-discovery errors in `try?`, and only then restore the E2E copy.
   - **Effort:** S (disable) / L (fix properly).

3. **Export data race → crash.**
   - **Problem:** `Task.detached` reads non-Sendable `@Model` objects off the main actor while the context/CloudKit/`@Query` may mutate the same rows → race, torn reads, possible `EXC_BAD_ACCESS`; a reproducible export crash is also an App-Review reject. `ExportView.swift:267-278`; `ExportService.swift:67-89,196-369`.
   - **Fix:** Snapshot needed fields into Sendable value structs on the MainActor and pass only those to the background task (or generate entirely on the MainActor).
   - **Effort:** S.

4. **Offline Pro users silently downgraded.**
   - **Problem:** Entitlement refresh is coupled to a successful product network fetch; on an offline cold launch a paying Pro user reverts to free — reviewers on flaky Wi-Fi see Pro disappear (reject risk) and real customers lose paid features. `PurchaseService.swift:65-78,104-124`.
   - **Fix:** Call `refreshPurchasedProducts()` unconditionally in `init()` and on every catch path (`currentEntitlements` is cache-served, no network needed).
   - **Effort:** S.

5. **Safety-adjacent contraceptive reminders gated behind Pro.**
   - **Problem:** Pill/patch/ring adherence reminders are Pro-locked; Apple flags paywalling of safety-adjacent health features. `SettingsView.swift:408-416`.
   - **Fix:** Move at least the basic pill reminder to the free tier, or document the rationale in review notes.
   - **Effort:** S.

6. **App Store metadata + privacy labels don't match reality.**
   - **Problem:** Once iCloud/Share claims change, the store description, screenshots, and Privacy Nutrition Labels still assert backup/sync and E2E sharing — inaccurate metadata (2.3) is a rejection cause on its own, and mismatched privacy labels compound it.
   - **Fix:** Audit and align the description, screenshots, and privacy labels with shipped behavior (local-only, no third-party data sharing, accurate backup status); keep them in lockstep with whichever iCloud/Share path you choose.
   - **Effort:** S.

7. **Unlocked content visible in the app switcher.**
   - **Problem:** `AppPreviewMask` masks only on `.background` with a 150ms fade, and `AppLockGate` relocks only on `.background` with a 0.25s opacity cover, so unlocked cycle data is captured in the switcher during `.inactive` and mid-fade — a visible hole for a privacy-first brand. `AppPreviewMask.swift:9,14-19`; `AppLockGate.swift:20-21,34,40-48`.
   - **Fix:** Mask and relock when `newPhase != .active`, render the cover opaquely with no animation, and consider the snapshot-ignore API.
   - **Effort:** S.

8. **Late-period UI is dead and the countdown lies.**
   - **Problem:** `nextPeriodStart` rolls forward to always be `>= today`, so `isPeriodLate` is never true and a 7-days-overdue user is told "Period in 21 days." `HomeView.swift:245-264,305`; `PredictionEngine.swift:100-113`.
   - **Fix:** Compute un-rolled `expected = lastPeriodStart + cycleLength`; base late-detection / `daysLate` on it; keep the rolled value only for the not-late countdown; remove the dead `case 0`.
   - **Effort:** S.

9. **First-run users see "Period expected in 0 days."**
   - **Problem:** Brand-new / "Not sure" users (`lastPeriodStart == nil`, a primary acquisition path) get "Period expected in 0 days" with no real prediction. `HomeCopy.swift:64-68`; `HomeHeader.swift:15-25`.
   - **Fix:** Gate period/PMS/fertile rows on `phase != .unknown` / `nextStart != nil`; fall back to "Nothing on the horizon"; suppress the "Day 1 · Cycle" subline when phase is `.unknown`.
   - **Effort:** S.

10. **Phantom empty entries created merely by viewing a date.**
    - **Problem:** `onDisappear` unconditionally commits note/medication/temp, and `.id(selectedDate)` tears the form down on every pill tap, so `withEntry` inserts an empty `CycleEntry` for any date merely viewed → phantom "logged" dots and delete buttons, suppressed onboarding hint, inflated counts that skew the review gate. `DailyLogForm.swift:46-50,767-769,839-857`.
    - **Fix:** Make the commit helpers no-op when the value is nil and no entry exists (mirror the pain-slider guard at line 163); apply the same guard to flow/energy/ovulation toggles (`:80,470,597`).
    - **Effort:** S.

11. **Basal temperature silently corrupted on revisit.**
    - **Problem:** A 2-decimal basal temp is re-rounded to `%.1f` and re-saved on revisit even when untouched → user data mutated without action. `DailyLogForm.swift:44,527,847-857`.
    - **Fix:** Seed the draft with `%.2f`; skip the commit when the parsed draft equals the stored value.
    - **Effort:** S.

12. **Pregnancy/Postpartum card never appears.**
    - **Problem:** Enabling the mode never persists a date (the picker shows a default that's never written), so the Home card silently never renders. `CycleSettingsView.swift:337-340,382-385`.
    - **Fix:** In `onChange`, persist the default date when the mode is enabled.
    - **Effort:** S.

13. **Future-dated flow corrupts stats; Health backfill duplicates.**
    - **Problem:** `cycles(from:today:)` ignores `today`, so a future-dated flow tap becomes a "period start" → a huge fake cycle skews `averageCycleLength` app-wide and can false-trigger the irregular banner. Separately, `backfillSymptomsToHealth` doesn't delete existing app-written samples first, so re-tapping Backfill duplicates samples in Health. `PredictionEngine.swift:10-24`; `CalendarMath.swift:157`; `HealthKitService.swift:167-180`.
    - **Fix:** Filter `dayStarts` to `<= startOfDay(today)` in `cycles` and `activePeriodWindow`; delete own symptom/pain samples before rewrite (mirror `deleteAllOwnFlowSamples()`).
    - **Effort:** S.

### P1 — Make it competitive (close must-haves, finish stubs, polish)

1. **Real private-CloudKit encrypted backup.**
   - **Problem:** Local-only's single churn driver is "I'll lose everything if I lose my phone"; today there is no safe backup at all.
   - **Fix:** After the P0 schema/migration work lands, enable the CloudKit private database (encrypted, in the user's own iCloud), marketed as "your iCloud, still invisible to us."
   - **Effort:** L.

2. **Free trial + privacy-led soft onboarding paywall.**
   - **Problem:** A cold, direct purchase forfeits the top conversion lever; onboarding-time trial starts dominate paid conversion in this category.
   - **Fix:** Add a 7–14 day trial and a dismissible soft paywall surfaced right after the first prediction reveal, with privacy as the social-proof slot; remove any synthetic discount/countdown badges.
   - **Effort:** M.

3. **Personalized onboarding payoff ("aha in 60s").**
   - **Problem:** Onboarding collects inputs but never reflects value back, and double-logging vs Apple Health raises drop-off.
   - **Fix:** Reflect inputs back as an on-device prediction + a "this never leaves your iPhone" beat; offer Apple Health cycle-history import; fix the duplicate-profile / silent-save-failure paths and normalize `lastPeriodStart` to `startOfDay`. `OnboardingViewModel.swift:11,82-84,97,110`.
   - **Effort:** M.

4. **Adaptive prediction engine.**
   - **Problem:** Fixed 14-day luteal / 5-day PMS and unclamped, truncated averages misfire for irregular/PCOS users and can render impossible rings.
   - **Fix:** Learn per-user luteal/PMS windows, clamp returned averages to realistic bounds, round (not truncate) variation and PMS means, project predictions across multiple visible cycles, and drop the stale `result()` params. `PredictionEngine.swift:55-73,72,176,248`; `CalendarMath.swift:110-132`; `TTCFertilityEngine.swift:16-18`; `PatternEngine.swift:129`.
   - **Effort:** M.

5. **Widget/watch midnight recompute + real states.**
   - **Problem:** Snapshots store precomputed `cycleDay`/`daysUntilPeriod` that never recompute, so after midnight (app unopened) the most important number is wrong for up to a day; the watch shows hardcoded placeholder data as if real and derives fertility by fragile substring match; lock-screen accessory widgets show cycle data unmasked. `CaelynWidgetProvider.swift:23-31`; `WidgetDataSync.swift:20-96,148-150`; `WatchHomeView.swift:7,42,99-101`; `WidgetViews.swift:286-349`.
   - **Fix:** Store raw anchor inputs, share the PredictionEngine day-math, emit a timeline entry per local midnight (`.after(nextMidnight)`) and recompute per entry; add a structured `FertilityStatus` enum; show an explicit empty/"open iPhone" state when the snapshot is nil; privacy-mask the lock-screen accessory and fix the `isPro:true` placeholder.
   - **Effort:** M.

6. **Finish the stubs and partials.**
   - **Problem:** Several "complete" features are half-built or silently wrong: onboarding exposes only 2 of 4 reminder types, HealthKit symptom-read is a placeholder, custom symptoms aren't CSV-escaped, PDF notes clip and footers drop on overflow pages, and export DateFormatters inherit the device calendar (wrong era/year on Buddhist/Hijri). `OnboardingSteps.swift`; `HealthKitService.swift:167-180`; `ExportService.swift:44-50,82,347-353,389,393-394` + formatter sites.
   - **Fix:** Ship all four reminder types (or remove the unused flags), implement or hide the symptom-read path, escape custom symptoms, paginate/ellipsize long notes and route overflow through `breakPage`, normalize export ranges to `startOfDay`, and pin `calendar = .gregorian` / `locale = en_US_POSIX` for machine-readable fields.
   - **Effort:** M.

7. **Accessibility + dark-mode pass.**
   - **Problem:** WCAG-AA contrast failures (white-on-plum in `CaelynButton`/`MoodChip`), fixed font sizes ignoring Dynamic Type (typography + widgets), fragmented widget VoiceOver labels, color-only flow/pain encoding, and the CycleRingView 1-indexed display vs 0-indexed arc off-by-one. `CaelynButton.swift:46`; `MoodChip.swift:17`; `Typography.swift:15-16`; `WidgetViews.swift`.
   - **Fix:** Adapt foreground per color scheme, scale fonts with Dynamic Type, combine widget VoiceOver elements, add non-color flow/pain encoding, align the ring indexing.
   - **Effort:** M.

8. **iPad onboarding trap + performance + concurrency hygiene.**
   - **Problem:** HealthStep's `onAppear` calls `vm.next()` whenever HealthKit is unavailable (every iPad), so Back bounces forward and the user can never return to fix goals/lengths; separately, per-render DateFormatter allocation and un-memoized cycle derivation cost CPU, and fire-and-forget HealthKit/scene-phase Tasks can interleave or stack. `OnboardingSteps.swift:921-924`; `HomeView.swift:491-566`; `DailyLogForm.swift:781`; `CaelynApp.swift:34-39`; `MainTabView.swift:147`.
   - **Fix:** Respect nav direction (don't auto-skip on back) or drop `.health` from the sequence when unavailable; centralize cached formatters and memoize derivations; add a per-date HealthKit sync coordinator that cancels the prior in-flight task and move scene-phase work to `.task(id:)`.
   - **Effort:** S–M.

### P2 — Make it stand out (beat the field on privacy + intelligence)
1. **"Warrant-proof by architecture" brand + Privacy Trust Center**, proven in-app (no network entitlement, plain-language manifest, optional audit/open data layer). Make privacy the headline, not a hidden fact. **Effort: S.**
2. **Wrist-temperature ovulation, on-device.** Read Apple Watch temp from HealthKit, compute retrospective ovulation locally — Natural-Cycles value at $0, no cloud. **Effort: L.**
3. **On-device "Private Intelligence" insights** (Apple Foundation Models): natural-language cycle summaries, cross-metric correlations, doctor-visit prep — 100% offline, with a non-AI fallback. The one AI story a cloud app can't match. **Effort: M (insights) → XL (companion).**
4. **Coercion-resistant privacy suite:** decoy/duress PIN, scheduled auto-sweep, content-free notifications. **Effort: M.**
5. **Lifecycle modes competitors gate/lack:** perimenopause first, then pregnancy depth — keep high-LTV users in-app. **Effort: L.**
6. **Compassionate streak + lifetime "own-it-forever" tier + glanceable lock-screen widget** (shipped privacy-masked per P1) — engagement and trust levers uniquely aligned with local-only. **Effort: M.**

---

## 7. The stand-out thesis

Caelyn wins by making its **architecture the product**: it is the only credible period tracker whose privacy promise is *structurally true and verifiable* — no backend, no account, nothing to sell, breach, or subpoena — at a moment when every cloud rival is reputationally exposed and the gold-standard local-only apps are too bare to love. The winning position is **"private like nothing else, smart like the cloud leaders, and there for the life stages Apple and the others gate"**: on-device intelligence (Foundation Models insights + wrist-temperature ovulation) that cloud apps cannot match on privacy, plus perimenopause/conditions depth the free Apple baseline won't touch, plus felt-safety features (decoy PIN, secure wipe) that turn the promise into proof. Caelyn must avoid Natural Cycles' regulated turf — compete on honesty and transparent uncertainty, never FDA efficacy claims.

**Build/fix these three first:** (1) **make iCloud real or stop claiming it, and fix the false Share E2E claim** — the marketed-but-dead backup is the top data-loss and trust risk, the false E2E claim is an App-Review blocker, and a real private-CloudKit backup converts local-only's biggest objection into a selling point; (2) **fix the funnel** — offline-Pro entitlement, free trial, and a privacy-led soft onboarding paywall, the single highest-leverage monetization gap; (3) **ship the on-device intelligence wedge** (private insights + wrist-temperature ovulation) before a local+AI entrant or the next iOS release claims the "local + AI" slot.