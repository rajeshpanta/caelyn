# Caelyn — fix plan

From the full-app audit of September 2026: 18 areas, 407 findings, 4 refuted,
238 behaviours confirmed working, 316 fix items after merging duplicates.

Severity across the items: **P0** 24, **P1** 100, **P2** 72, **P3** 120.
142 P3 items were carried without a second verification pass and are
marked unconfirmed; 154 findings could not be settled without a physical device.

## How to read the numbering

Two schemes, and they do not join — the audit compressed its findings after the
phases were drawn up. Phase item numbers are the **original finding numbers**
(`1`, `255`, `63`…); the catalogue at the end uses the **compressed item codes**
(`ACC-01`, `EXP-10`…). Phase 0 is written out in full because it is done; for the
later phases the narrative is the durable part and the catalogue holds the detail.

---

## Phase 0 — Nothing she wrote is lost, and nothing we said was deleted survives ✅ **complete**

### Goal

Two promises, kept. First: the update itself must not move or orphan a single logged
day — not for a woman who travels, and not for one whose phone is set to the Thai or
Japanese calendar. Second: the three ways Caelyn offers to erase everything (Delete
all data, the duress PIN typed under pressure, the inactivity sweep) must actually
erase everything — including the copy on her wrist, the leftover database sitting
beside the live one, and the file an export left in a temporary folder. Two release
mechanics ride along because nothing can ship without them: the three app bundles must
agree on a build number, and the iCloud schema for the new day field must be live in
production or sync silently stops for every existing user.

### Why this order

Every later phase reads or writes the same store and leans on the same wipe. If day
identity is still minted from whatever calendar the phone happens to be set to, every
number in Phases 2 and 3 is computed over mis-filed days. If a wipe still leaves a
readable copy, every privacy fix after it is decoration. These are also the only items
where the damage is silent and permanent: a wrong one-shot backfill cannot be noticed
by the user and cannot be undone. Ships alone, with no feature work in the same build.

### Items (17) — all closed

| # | Sev | What was wrong | Closed by |
|---|-----|----------------|-----------|
| 1 | P0 | `CivilDay` minted the day key with the device's *calendar system*, not just its time zone, so a Thai-calendar phone filed every entry under year 2569 and seven other calendars under other years. Day arithmetic was wrong too, and the four persisted-day helpers in the import path shared the bug — `ImportValues` read Caelyn's own `2026-03-05` export as the year 1483. | `6a3a73e` |
| 255 | P0 | The one-shot launch backfill derived each key from `Calendar.current`, so installing the update abroad re-dated her whole history by a day, permanently and invisibly. It also rewrote `date` on every row it kept — on a mirrored store that is an edit other devices accept and re-emit, and it destroyed the only evidence of the original day. | `6a3a73e` |
| 256 | P0 | `localDate(for:)` returned `.distantPast` for a key it could not resolve — a real `Date` that passes every reader's filter, so one unkeyed row anchored the whole prediction to the year 1. `CycleEntry.day` also hardcoded `.current`, bypassing the calendar argument. | `6a3a73e` |
| 219 | P0 | Sync claimed "backed up to your private iCloud" from account status alone. A field missing from the CloudKit **Production** schema fails every export while the account and store look fine — her history silently stops leaving the phone while the screen says it is safe. `dayKey` is exactly such a field. | `75496dc` |
| 147 | P0 | The app, widget and watch bundles disagreed about the build number, which blocks the upload. | `91eccb3` |
| 133 | P0 | `verify` checked the lockout before the duress PIN, so five wrong guesses by whoever was holding her phone blocked the emergency wipe — the only circumstance in which a duress PIN is ever typed. | `06a7c23` |
| 134 | P0 | A duress PIN could be armed with App Lock off, where there is no lock screen to type it into. She is told it is set; in the moment it matters the app just opens. | `06a7c23` |
| 130 | P0 | A sheet open when Caelyn locked stayed on screen and usable *above* the lock — the lock was a ZStack sibling hiding content by opacity, and sheets present in their own layer. | `06a7c23` |
| 131 | P0 | Auto-erase lived on the CloudKit-mirrored `UserProfile`, so it synced: a spare iPad past its window could wipe itself and export those deletions to iCloud and on to her daily phone. `lastActiveAt` synced too, keeping a genuinely lost phone "active". | `06a7c23` |
| 132 | P0 | Auto-erase armed on one tap, with no prompt then and none when it fires — while Paranoid Mode, far less destructive, confirms. | `06a7c23` |
| 135 | P0 | The auto-sweep stamped `lastActiveAt` onto the `UserProfile` it had just deleted; writing to a deleted model object can resurrect the row, leaving her name, averages, Pro flag and lock settings in a store meant to look brand new. | `06a7c23` |
| 126 | P0 | A wipe left her history in four places: a CSV/PDF export in the temporary directory, a preserved `default.store.corrupt-*`, the import ledger, and her Apple identity in the Keychain. | `06a7c23` |
| 284 | P0 | A wipe never reached the watch. The WatchConnectivity application context is persistent, so her cycle day and next predicted period stayed on her wrist across a relaunch. No code path could unset it. | `06a7c23` |
| 129 | P0 | An offline "delete my iCloud copy" was never retried: the reachability check ran before the pending marker was written, so asking on a plane recorded nothing and no launch tried again. | `06a7c23` |
| 63 | P0 | An edit arriving as delete-plus-re-add (how several trackers represent one) was decided against the pre-update store, so the clear was applied after the update — her corrected value was written and then erased, and a day holding nothing else was deleted. | `06a7c23` |
| 160 | P0 | `plausibleCycles` had a floor and no ceiling, so a pregnancy became a ~400-day cycle permanently: variation read ±190 days and Insights reported irregular cycles with skipped periods for the rest of her life. | `06a7c23` |
| 97 | P0 | Preserved corrupt stores accumulated, were never deleted by a wipe, and no screen offers them — while the banner said her data was "kept aside", implying a recovery that does not exist. | 06a7c23 + 5d3325b — residue and copy fixed; **reading a preserved store back is still not implemented** |

Everything above ships together and alone, with no feature work in the same
build. **One step is not code and is still outstanding:** the CloudKit
Production schema must carry `CD_dayKey` before build 16 reaches anyone —
see `PHASE6_CLOUDKIT_SETUP.md` §4.

### Verification

(a) Migration probe, run serially: seed a container shaped like 1.3 build 15 (rows
with dayKey == 0, written while TimeZone was Asia/Tokyo), then run the launch pass
three times — under America/Honolulu, under the Japanese calendar and under the Thai
Buddhist calendar — and assert per row that the civil day is unchanged, that no row
resolves to .distantPast, and that a second run changes nothing (idempotence). (b) Re-
run the full unit suite; the 590/0/1 baseline must hold, with new cases pinning
CivilDay to the fixed calendar and covering the dayKey == 0 sentinel. (c) Two-device
manual check: on device A tap Delete all data, then inspect the App Group container,
the keychain (PIN, duress, Apple user ID), Application Support (no
default.store.corrupt-*), the temp directory (no Caelyn-*.csv/.pdf) and the paired
watch face; device B must not resurrect rows. (d) Duress check on a real device: five
wrong unlock attempts, then the duress PIN — it must still wipe, and the keypad must
not reveal that it did. (e) Airplane-mode delete must leave a retry marker and must
not claim the iCloud copy is gone. (f) App Store Connect: upload the archive and
confirm app, widget and watch all report the same build.

### Risk

The largest and riskiest release in the plan, and the one that cannot be split: it
touches a stored, mirrored identity field and an irreversible destructive path at the
same time. The backfill must be written to be re-runnable and to prove per-row
invariance, because a wrong key is invisible to the user and permanent. Two seams are
deliberately deferred and must be called out in the release notes for the next build:
the final wipe step that drops the iCloud copy in-session, and a genuinely local-only
auto-erase, both need the container rebuild that opens Phase 1 — until then the wipe
must report honestly rather than overclaim. Item 134 ships a local guard against
arming a duress PIN that can never be typed, and adopts the shared readiness predicate
when Phase 1 lands it.

---

## Phase 1 — One place decides each dangerous thing

### Goal

Build the small number of shared mechanisms the rest of the plan depends on, so that
each dangerous decision is made once instead of in a dozen places: a database
connection that can actually let go of iCloud while the app is running; one answer to
what deleting means and how far it reaches, with a record of what it did and the
ability to finish after a crash; one answer to which settings row is hers and which
saved row is a given day; one list of fields that merging must never forget; one gate
that every reminder — including the notes she writes to herself — must pass; one
funnel that refreshes the widget and the watch whenever data changes, whoever changed
it; and a lock that is a real window over the whole app rather than a layer inside it.

### Why this order

These are the items other items are built on. The scope of a delete cannot be honest
until the container can be detached (144 before 220 and 128). Reminders cannot be
audited until delivered notifications are modelled and the note reminders are inside
the same gate (190, 188, 191) and until something reschedules at the write boundary
rather than on app foreground (189). Nothing about the widget or the wrist can be made
correct until the snapshot carries the right inputs, is refreshed by the data rather
than by one view, and the watch link is activated early and replayably (312, 290, 292,
285, 287, 288, 289). The derivation seams are deliberately NOT here: they belong with
the modes in Phase 2, because they are the same refactor of CycleModel.make.

### Items (48)

Original finding numbers: 144, 220, 128, 163, 178, 164, 168, 140, 196, 228, 204, 149, 98, 166, 80, 265, 260, 262, 263, 261, 267, 136, 137, 158, 169, 161, 170, 167, 190, 188, 191, 189, 192, 139, 69, 65, 68, 312, 290, 292, 285, 287, 288, 289, 142, 291, 307, 11

### Verification

(a) New unit coverage, one test per seam, written to fail on the old code: a merge-
completeness test that enumerates UserProfile and CycleEntry stored properties by
reflection and fails when a property is absent from merge/adopt (guards 196
permanently); a scope test asserting that a local-only wipe leaves cloud rows intact
and that a cloud wipe reaches them; a wipe-journal test that interrupts after each
step and asserts the resume completes; a ProfileStore.current test with two rows and
an out-of-order createdAt; a day-to-row funnel test proving two concurrent writes for
one day produce one row. (b) Watch-bridge test seam first (312), then a replay test
for activation (290) and a tier test (292) — these are the only automated coverage the
watch has ever had. (c) Probe for the container: assert Persistence can be rebuilt
mid-process with mirroring off and that a subsequent write does not reach CloudKit.
(d) Device checks: lock the app with a sheet open and confirm the sheet is covered in
the app switcher and on return; log a period on the watch and confirm the widget, the
watch ring and the scheduled reminder all move without backgrounding the phone; revoke
notification permission and confirm nothing re-arms. (e) The 30/0 UI suite must stay
green — the lock becoming a window-level presentation is the most likely thing to
break it.

### Risk

Wide blast radius and almost no visible payoff, which is exactly the combination that
gets shipped carelessly. The container-lifetime change (144) touches every read and
write in the app and is the single most dangerous refactor in the audit; it should
land first in its own build with the test probe above, not bundled with the reminder
or snapshot work. Making the lock a window-level presentation can break the UI suite's
navigation helpers. The merge-completeness test will likely fail immediately on fields
nobody knew were missing — treat each failure as a separate data-correctness decision,
not as a test to relax.

---

## Phase 2 — One derivation, and the switches finally reach it

### Goal

Today several settings change the look of the app and nothing else: Irregular, PCOS
and Perimenopause do not move a single number; Pregnancy and Postpartum leave Caelyn
predicting periods and announcing fertile windows for nine months; Birth Control Mode
still shows ovulation days to someone on the pill, and its reminders stop after the
first one; Gentle mode changes nothing until a full cycle exists, which is the
opposite of who it is for. The cause is the same in every case: there is no way for a
mode to reach the one calculation every screen reads. This phase gives that
calculation a seam — along with honest handling of a late period, of 'we don't know
yet', and of what Caelyn has actually learned about her — and then wires each switch
into it.

### Why this order

The seam has to exist before any switch can be connected, and the seam's own defects
have to be fixed first or the modes inherit them: '.unknown' must stop meaning two
different things (60), lateness must become a state instead of a wrapped day (41), the
textbook luteal default must stop overriding what was learned (223), and the fertile
window, the PMS window and the phase boundaries must each be derived once (40, 59,
72). Provenance comes next (57, 58), because judging 'is this normal' against a number
she typed during setup is the same class of error as judging it against a textbook.
Deterministic selection and one adequacy gate (210, 209) land before the modes so that
mode-aware copy is not built on claims that change between runs. Then the modes
themselves, with life stage made a single mode with an invariant (181) before anything
reads it.

### Items (29)

Original finding numbers: 60, 41, 223, 40, 57, 58, 59, 72, 210, 209, 179, 181, 180, 193, 47, 2, 3, 4, 6, 16, 183, 184, 186, 225, 171, 104, 269, 50, 67

### Verification

(a) A mode matrix test: for each of {none, irregular, PCOS, perimenopause, pregnancy,
postpartum, birth control, TTC, gentle} assert what CycleModel returns and what each
surface is allowed to say — specifically that pregnancy and postpartum yield no
fertile window, no ovulation badge, no 'period late' claim and no period/ovulation
notification, and that birth control with a hormonal method yields no ovulation claim.
(b) A lateness test crossing the old modulo boundary: day 29 of a 28-day model must
read '1 day late', not 'Day 1 of your period', on Home, in the calendar, in the
summary and in the snapshot. (c) A learned-values test asserting that no production
call site supplies the textbook luteal length — enforce it with a test that fails if
the default parameter is reintroduced. (d) Birth-control device check on a real phone:
enable Patch, accept the default first-patch date, force-quit, wait past the first
event, and confirm reminders continue past the first one and name the right action;
set a 22:30 pill reminder and confirm it fires at 22:30. (e) Toggle Apple Health write
scopes one at a time and confirm a declined type does not suppress the others;
disconnect Health and confirm wrist temperature is no longer read. (f) Second-device
check that the Health connection state does not appear on a device that was never
asked.

### Risk

Changing the single derivation changes every screen at once, including the widget and
the watch, so a regression here is loud and immediate — but the suite is weakest
exactly here (the TTC engine has no tests at all until Phase 3 writes them, which is
why the mode matrix in (a) must be written before the seam, not after). The mode
matrix is also a product decision as much as a code change: suppressing fertility
output in pregnancy mode is right, but 'what should Caelyn say instead' needs a
deliberate answer per surface rather than a blank space. No schema change is required
for the seam itself; life stage becoming one mode with an invariant does need a one-
time, additive normalisation of the existing flags.

---

## Phase 3 — What she is shown, exported and imported is true

### Goal

Make every number, sentence and file Caelyn produces match what she actually recorded.
Her period's start date must be editable and stick; a late period must not read as
bleeding; a temperature must be typeable in a comma-decimal language; a half-written
note must survive a phone call. The claims on Home and in Insights must stop being
stated with confidence from one or two logs, and must stop naming a different 'most
common symptom' each time. The PDF she hands a doctor must judge her against the same
thresholds the app uses, print only measured values, and not cut off the symptoms on
her heaviest days. Importing her own backup or another app's export must not quietly
rewrite severities, invent a period from spotting, read 'pain intensity' as flow, or
claim success when nothing was written. And the widget, the watch and the phone must
not contradict each other about the same day.

### Why this order

It sits after the plumbing and the derivation because almost every item here is a
reader: fixing the words while the underlying value is wrong just moves the lie.
Within the phase, the anchor comes first (273, 279, 274) because the period start date
feeds everything shown; then the pattern claims (205, 207, 212) which depend on Phase
2's adequacy gate and deterministic selection; then the TTC and temperature work, with
its test file written before its fixes (53, 54) since the feature currently ships with
no tests at all; then the Apple Health write-out, which depends on the symmetric write
path from Phase 1; then import, led by the calendar-consistency fix that the date-
detection fixes depend on (122 before 102, 103); then export and the clinical PDF,
which read the provenance-carrying values from Phase 2; then the widget and watch
parity, which consume the snapshot inputs from Phase 1; then the account and name
screens, the paywall copy, and the remaining privacy wording.

### Items (73)

Original finding numbers: 273, 279, 274, 278, 277, 280, 275, 276, 282, 296, 297, 227, 229, 205, 207, 212, 61, 62, 211, 53, 54, 45, 42, 46, 43, 49, 51, 66, 75, 76, 78, 79, 122, 102, 103, 71, 101, 109, 112, 110, 106, 99, 100, 107, 105, 70, 111, 114, 8, 30, 9, 233, 35, 36, 252, 213, 286, 294, 226, 10, 12, 13, 14, 15, 231, 232, 172, 173, 270, 148, 73, 74, 230

### Verification

(a) Round-trip test, the single highest-value one here: generate a Caelyn CSV from a
fixture with every severity level, a custom symptom, medication text, a note and a
temperature; parse it back; assert field-by-field equality including the custom
symptom's vocabulary row. It must fail on today's code. (b) A clinical-PDF test
asserting that every printed statistic is either measured or labelled as unavailable,
that the reference ranges come from the same constants the app uses, that mode
qualifiers (PCOS, perimenopause, pregnancy) appear, and that no cell is truncated —
compare against the app's own screens for the same fixture. (c) Import fixtures per
source (Clue with spotting, a US MM/dd list, a 'Day, Date, Flow' sheet, a sheet with a
'Pain intensity' column, a Clue .zip) asserting the detected date format, the chosen
date column, the mapped fields and the preview counts; plus a test that a commit which
writes nothing reports 'nothing to add' rather than success or failure. (d) New
TTCFertilityEngineTests with an injected today and calendar: a positive ovulation test
must outrank the calendar guess, the displayed signal list must sum to the score, and
a user with no logged period must get an insufficient-data state rather than a number.
(e) Device checks: a German-locale phone typing 36,7; a late period compared side by
side on phone, widget and watch; a doctor-facing PDF read on paper; VoiceOver over the
Home claim cards. (f) Re-run both suites.

### Risk

The biggest phase by count, so it must be landed in runs (anchor, patterns,
TTC/temperature, Health, import, export, parity) with the suite green between runs
rather than as one build. Two items change what is written, not just what is shown:
the import fixes alter values that land in her history, and the Apple Health write-
path fixes delete and rewrite samples Caelyn owns — both need a dry-run comparison on
a copy of a real store before release. The clinical PDF is the one artifact a third
party acts on, so its thresholds should be reviewed against the app's own copy by a
human, not just asserted in a test.

---

## Phase 4 — Polish, the unconfirmed, and the value already sitting in the data

### Goal

Everything that is wrong only in an edge case, costs performance, reads awkwardly, or
is a promise the architecture could already keep but doesn't. Three groups: (1)
suspected findings that need a device or a probe to confirm before anyone spends a day
on them — the wrist-temperature sample day, the App Group entitlement fallback, the
HealthKit read-authorisation assumption; (2) real but small defects — accessibility on
the export and guide screens, widget text that ignores her text size, haptics that
buzz twice, the savings badge rounding down, dead code that invites a fix to land in
the wrong copy, two unused 'Pro' fields, a store listing that promises a watch widget
that does not exist; (3) unrealized potential, where the data is already there: the
temperature shift Caelyn computes and throws away after one sentence, fertility
signals it reads from Health but never writes back, a share card reachable roughly
twice in a lifetime, dismissed insights that do not follow her to her other device,
and charts that were tuned for a six-cycle demo set rather than for the users with
years of history who pay for them.

### Why this order

Last because nothing here can lose data, break a promise, or produce a wrong health
number, and several items would be wasted work if done earlier: the perf items (the
import read and commit, the Insights fan-out, the widget refresh budget) should be
measured after Phases 1-3 have already changed the hot paths, and the unconfirmed
items should be probed rather than fixed on suspicion. The unrealized-potential items
are deliberately last because they extend the derivation seam built in Phase 2 — doing
them first would mean building on the old seam and then rewriting.

### Items (83)

Original finding numbers: 19, 20, 21, 22, 23, 24, 25, 26, 27, 29, 56, 300, 314, 34, 38, 39, 44, 52, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 115, 116, 117, 118, 119, 120, 123, 124, 125, 150, 151, 152, 153, 154, 159, 175, 177, 187, 197, 198, 199, 200, 214, 215, 216, 217, 218, 234, 235, 236, 238, 240, 241, 242, 243, 244, 245, 247, 248, 249, 250, 254, 259, 266, 268, 301, 306, 308, 309, 310, 311, 315

### Verification

(a) Confirm-or-close first, in one pass: a device probe for the wrist-temperature
sample day (log a night's sleep, read back which civil day Caelyn files it under), a
build signed without the App Group to see whether the widget store silently falls
back, and a HealthKit run where every read type is declined. Anything that does not
reproduce is closed with a note, not fixed. (b) Performance measurements with real
volumes rather than the demo set: a three-year import (time to preview, time to
commit, main-thread stalls), the Insights tab with 40+ cycles, and a count of widget
timeline reloads across a heavy logging day. (c) Accessibility sweep with VoiceOver
and the largest text size over the export screen, the guide's question rows, the lock
keypad and all five widget sizes. (d) Test-architecture items (306, 312's siblings)
verified by the new tests existing and failing when the behaviour they guard is
reverted. (e) The 590/0/1 and 30/0 baselines must be re-run and raised as items land.

### Risk

Low individually, but this is where scope quietly grows: several items are copy and
product decisions dressed as bugs (the store listing's watch widget, the share card's
entry points, whether notes belong in a doctor-facing PDF by default), and they should
be decided rather than coded around. Two items change stored data additively and
should not be treated as polish: syncing dismissed insights and writing fertility
types back to Apple Health both put new rows in places users can see. The dead-code
removals are the safest items here and are worth doing early in the phase, because
they shrink the surface every future fix has to reason about.

---

## Item catalogue

All 316 compressed items, by severity. The fix steps and tests are the audit's own
recommendations, not a commitment.

### P0 (24)

#### ACC-01, EXP-10 — 24 Optional Sign in with Apple — Delete all data / duress wipe / auto-sweep (and the export file's lifecycle)

After she taps 'Delete all data' — or after the duress PIN wipe that promises the app
'opens looking brand new, with no sign anything was deleted' — Caelyn still says
'Signed in with Apple' in Settings, with the account-management rows beside it. And
the last report she exported is still sitting on the phone as a plain-text file.
Someone who takes her phone after a panic wipe sees proof the app was in real use and
can read her entire history, notes included, out of the leftover export.

**Root cause.** SecureWipeService.wipeEverything is a hand-written enumeration of storage locations
(doc list SecureWipeService.swift:5-15, body :83-131) with no registry obliging a
newly added store to join it. Two stores were added after it was written and never
joined: AccountIdentityStore's Keychain item (service com.caelyn.account, account
appleUserID — AccountIdentityStore.swift:21-27, 48-51), and the export files
ExportService.writeToTempFile mints directly into
FileManager.default.temporaryDirectory with no owner and no lifecycle
(ExportService.swift:525-537; ExportView holds the URL only in @State,
ExportView.swift:13, and has no teardown). PINService.clearAll
(PINService.swift:47-50) only deletes three named accounts inside its own service, so
even a shared service name would not have swept appleUserID. All three wipe callers
leak both — SettingsView.swift:812, AppLockGate.swift:103-110,
AutoSweepService.swift:27.

**Fix.**

1. 1. Add `AccountIdentityStore.signOut()` beside `PINService.clearAll()` at
   SecureWipeService.swift:99, with a doc line in the 5-15 list naming the Keychain
   identity as a wiped location.
2. 2. Give ExportService an owned directory: `static var exportDirectory` =
   temporaryDirectory/Exports/, created on demand; writeToTempFile writes there. Add
   `static func purgeExports()` that removes the directory recursively.
3. 3. Call `ExportService.purgeExports()` from wipeEverything (same step list) so all
   three wipe entry points are covered by one call.
4. 4. Write exports with `.completeFileProtectionUnlessOpen` — NOT
   `.completeFileProtection`, which would make the file unreadable to a share
   extension that defers work (background upload, a retained Mail/Messages compose).
5. 5. One-time cleanup at first launch after the update: remove any `tmp/Caelyn-*.csv`
   and `tmp/Caelyn-*.pdf` left flat in tmp/ by 1.3 (15).
6. 6. PERMANENCE — make the next store fail loudly instead of silently surviving:
   define `protocol PurgeableStore { static func purge() }`, conform
   AccountIdentityStore, PINService, HealthSyncService, WidgetDataStore and
   ExportService to it, and have wipeEverything iterate a `[any PurgeableStore.Type]`
   list. This is what addresses the mechanism (hand enumeration) rather than the two
   instances.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/Account/AccountIdentityStore.swift`, `Caelyn/Services/ExportService.swift`, `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/PINService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/AutoSweepService.swift`

*Tests:* DeletionModelTests (or a new SecureWipeTests): sign in → wipeEverything(.thisDevice) →
XCTAssertFalse(AccountIdentityStore.isSignedIn). New ExportService test:
writeToTempFile places the file under Exports/ and purgeExports removes it;
wipeEverything removes it too. Existing
testDeletingTheAccountIdentityCannotTouchLocalOrCloudHistory is unaffected.

#### EXP-20, EXP-09 — CivilDay.key(for:) + ImportValues.day(from:) — day identity across calendars (cross-area, underpins export/import and every reader keyed to dayKey)

A woman whose iPhone is set to the Thai Buddhist or Japanese calendar — an ordinary
iOS setting, not a jailbreak — has every day filed under the wrong year. On her own
phone it looks fine, but the moment that history reaches a second phone (or she
changes the Calendar setting), her entries jump centuries. And a CSV Caelyn itself
wrote is rejected on re-import with 'nothing Caelyn could place on a calendar'.

**Root cause.** Day identity is minted with whatever calendar the device happens to be set to, and
nothing pins it. CivilDay.key(for:) asks
`calendar.dateComponents([.year,.month,.day])` with `calendar: Calendar = .current`
and packs the raw year component as year*10_000+month*100+day (CivilDay.swift:32-35);
the Buddhist year component for 2026 CE is 2569 → key 25690305, the Japanese is the
era year 8 → key 80305. localDate(for:) decodes with the same calendar (:44-52), so it
round-trips on one device and is meaningless anywhere else — and PredictionEngine,
CycleStore's dedupe (CycleStore.swift:38-40) and the export all key on it. The
identical omission exists on the import side: ImportValues.day(from:)'s ISO fast path
builds the Date with the caller's unmodified calendar (ImportValues.swift:122-129,
reached with Calendar.current from BringHistoryModel.swift:67) and its roll-over guard
reads the components back in that same calendar, so the error round-trips cleanly and
is invisible. ExportService already pins Gregorian when writing
(ExportService.swift:60-65); the reader was never pinned to match. The only
Calendar(identifier:) in production is that one formatter.

**Fix.**

1. 1. Pin inside CivilDay, not at call sites. In key(for:), localDate(for:),
   key(_:offsetBy:) and days(from:to:) (CivilDay.swift:32-66), derive `var g =
   Calendar(identifier: .gregorian); g.timeZone = calendar.timeZone` and do all
   component/date work with `g`. Time zone — the intended variable, 'the day she was
   living in' — is preserved; the device calendar can no longer reach the integer.
   Permanent because the key becomes calendar-independent at the only place it is ever
   minted.
2. 2. Pin the ISO import path the same way: in ImportValues.day(from:), replace
   `calendar.date(from: components)` at :122-129 with a Gregorian calendar carrying
   `calendar.timeZone`, and do the component read-back in that same Gregorian calendar
   before returning `iso.startOfDay(for: date)`.
3. 3. Repair already-written keys WITHOUT trusting the stored key: add a one-time
   repair that walks CycleEntry rows whose dayKey is outside a sane range (e.g. year
   component < 1900 or > 2200) and re-derives the key from the stored `date` instant
   using the pinned Gregorian calendar. Rows with sane keys are left untouched.
4. 4. Order matters: the repair must run BEFORE CycleStore.dedupeSameDay on both
   devices, or two rows that should merge will be deduped against mismatched keys.
5. 5. Release note: a device on a non-Gregorian calendar will see its dates correct
   themselves once on first launch after the update.

*Files:* `Caelyn/Models/CivilDay.swift`, `Caelyn/Services/Import/ImportValues.swift`, `Caelyn/Services/Import/Sources/CaelynExportSource.swift`, `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* CivilDayTests: add Buddhist and Japanese calendar cases asserting key(for:) ==
20260305 regardless of identifier. Import tests: round trip a Caelyn CSV with
`calendar = Calendar(identifier: .buddhist)` and assert 0 rejected and the restored
Gregorian y/m/d. Add a repair test: a row stored with dayKey 25690305 and a correct
`date` is re-keyed to 20260305 and then dedupes correctly.

#### HK-02, IMP2-02 — ImportReconciler.plan step 4 (deletions) + ImportReconciler.commit .clear branch

When another app corrects a day it already gave to Caelyn — she edits a flow entry in
the Health app, or Flo/Clue re-syncs yesterday — Caelyn erases that value instead of
updating it. The period day she just corrected disappears from Caelyn, and if it was
the only thing on that day the whole day's record is deleted. Nothing brings it back
except manually re-running 'Bring my history'.

**Root cause.** HealthKit samples are immutable, so an edit arrives as delete-old-UUID + save-new-
sample in ONE anchored batch (HealthKitReader.swift:104-123). ImportReconciler.plan
handles deletions in an independent fourth pass (ImportReconciler.swift:223-236) that
(a) never consults the per-(day,field) decisions step 3 just produced in `best`, and
(b) evaluates against the pre-plan `currentValue` snapshot — where stored still equals
the old claim — so it appends `.clear` for the very key the same batch re-supplied.
commit applies decisions in array order: the `.update` writes, then the `.clear` wipes
the field and deletes the row at :353 if the day is now empty. Underneath that sits a
second defect: `.clear` (:347-354) is the only mutating branch in commit with no live
re-check at all, while `.fill`/`.update` deliberately refetch and verify ownership
first (:328-340, with the comment explaining why the window matters). So a value that
changes between plan and commit — a second device's row arriving over CloudKit while
the preview sheet is open — is also erased.

**Fix.**

1. 1. In plan step 4 (ImportReconciler.swift:223-236), compute `let supplied =
   Set(best.keys)` before the loop and skip emitting `.clear` when
   `supplied.contains(Key(day: day, field: field))`. `best` includes keys that resolve
   to `.duplicate` as well as `.fill`/`.update`, which is exactly what rescues an
   identical-value re-sync; keys rejected by `validate` are absent from `best`, so a
   genuinely invalid re-supply still clears.
2. 2. Make the ordering invariant explicit: emit (or sort) decisions so a `.clear` can
   never follow an accepted write for the same (day, field), and assert it in a plan-
   level test rather than relying on array append order.
3. 3. Hoist the live re-check out of the `.fill`/`.update` case into one precondition
   applied to EVERY mutating decision, `.clear` included: fetch the entry, compare
   `entry.value(for: decision.field)` with `ledger.claim(day:field:)`, proceed only
   when the stored value still equals the claim. 'stored is nil' means proceed-for-
   fill, skip-for-clear.
4. 4. Keep provenance honest when the precondition skips a `.clear`: append to
   `pendingReleases` for that (day, field) so the ledger stops claiming a value Caelyn
   no longer owns. Note that `pendingClaims` is not flushed until after the save
   (:378), so inside one commit a `.clear` following an `.update` would compare the
   new value against the old claim — step 1 must make that case unreachable rather
   than relying on step 3 to catch it.
5. 5. Count skipped clears into the existing `stale` tally (:320, :383-388) so the
   result reads 'kept what you had' instead of silently reporting nothing.

*Files:* `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Health/HealthKitReader.swift`, `CaelynTests/HealthSyncTests.swift`

*Tests:* Add testSourceReplacingARecordInOneBatchUpdatesInsteadOfClears (probe below). Change
HealthSyncTests.testSourceEditingItsOwnRecordUpdatesTheValue to use a NEW recordID
plus deleted:[oldID] — a same-UUID edit does not exist in HealthKit, so the current
test exercises a state the platform never produces.
testDeletedRecordClearsAValueCaelynStillOwns and
testDeletingTheOnlyValueOnADayRemovesTheEmptyRow must still pass unchanged. Add a
plan-then-mutate-then-commit test proving a `.clear` is skipped when the live value no
longer matches the claim.

#### IMP-01 — 17 Import preview + undo + history (share-sheet entry) / AppLockGate presentation

If her phone is locked with Face ID or a PIN inside Caelyn, anyone holding the phone
can still open a CSV or JSON file from Mail or Files with 'Open in Caelyn' and get the
full import screen on top of the lock screen. They can read how many days of history
she has and that some days already have entries, tap 'Add to Caelyn' to write data
into her health log, and undo it — all without ever unlocking.

**Root cause.** AppLockGate implements the lock as an in-hierarchy sibling with render-level
suppression, not as a presentation authority: content() stays in the view tree and is
merely hidden via `.opacity(showLockScreen ? 0 : 1)` +
`.allowsHitTesting(!showLockScreen)` (AppLockGate.swift:26-29) with LockScreen drawn
as a ZStack peer (:31-53). A SwiftUI `.sheet`/`.fullScreenCover` is hosted at window
level, outside the parent's opacity and hit-testing, so any modal originating anywhere
in the gated subtree presents over the lock and stays interactive. CaelynApp attaches
`.sheet(item: $incomingFile) { BringHistoryView(incomingFile:) }` inside AppLockGate
(CaelynApp.swift:31-38) and `.onOpenURL` sets `incomingFile` unconditionally (:39-44),
and BringHistoryView's `.task` reads the file and renders the preview immediately
(BringHistoryView.swift:89-94). The import sheet is one reachable instance of the
gate's architecture, not the defect itself.

**Fix.**

1. 1. Make the gate a presentation authority: replace `.opacity`/`.allowsHitTesting`
   at AppLockGate.swift:26-29 with conditional inclusion — `if !showLockScreen {
   content() } else { LockScreen/PINPad }` — so the gated subtree is torn down while
   locked and cannot host a window-level modal. Verify no in-flight work depends on
   content() staying mounted (widget sync, CloudSyncCoordinator live in @main, not in
   content()).
2. 2. Move the incoming-file sheet out of the gated content and attach it to
   AppLockGate itself, conditioned on `!showLockScreen`, so the presentation is never
   registered while locked.
3. 3. Do not drop the file: keep `incomingFile` set in `.onOpenURL` but have the gate
   present the sheet only after a successful unlock, so a legitimate user's share-
   sheet import still works after Face ID.
4. 4. Publish lock state so the rule is testable and reusable: expose `showLockScreen`
   through an observable (environment object or a small LockState type) and add a
   single assertion point other future modals can honour, rather than fixing
   `incomingFile` alone.
5. 5. Audit the other window-level presentations reachable from the gated subtree
   (sheets/fullScreenCovers in ThemedContentView and its children, plus anything
   triggered by notification taps or Watch messages) and confirm step 1 covers them;
   list them in the PR so the next one is not added blind.

*Files:* `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/Import/BringHistoryView.swift`, `CaelynUITests`

*Tests:* No existing test covers this. Add a UI test: launch with lock enabled, background,
open a file URL, cancel Face ID, assert the lock screen exists AND the import confirm
button does not. Add a unit test on the lock-state publisher introduced in step 4.

#### LC-01 — Lifecycle: AppLockGate.verifyPIN(.duress) and AutoSweepService.checkAndSweep -> SecureWipeService.wipeEverything(modelContext:)

The two wipes that run without her watching — typing the duress PIN, and the auto-wipe
after she hasn't opened the app for a while — delete her history from a store that may
be mirroring to iCloud. Those deletions then travel to her private iCloud copy and
from there to every other device she owns. Both features are described to her as
wiping this phone.

**Root cause.** SecureWipeService.wipeEverything supplies scope: Scope = .thisDevice as a DEFAULT
(SecureWipeService.swift:74-77), so any caller that says nothing silently asserts 'no
cloud copy can exist' — a claim about the store's state that only SettingsView
actually checks, via deleteAllOffer(mayHaveCloudCopy:) (SettingsView.swift:175-199).
AppLockGate.swift:108 and AutoSweepService.swift:27 take the default and batch-delete
every CycleEntry and UserProfile in the live mainContext
(SecureWipeService.swift:84-86), having consulted nothing. The file's own doc comment
at :24-50 states that .thisDevice is only safe to offer when no cloud copy can exist,
and c2984d1 already fixed the Settings path on exactly this reasoning.

**Fix.**

1. 1. Remove the default: make `scope: Scope` a required parameter on wipeEverything.
   This alone converts every present and future unattended caller from a silent
   assertion into a compile error.
2. 2. Put the decision next to the rule that already exists rather than at each call
   site: callers derive scope from SecureWipeService.deleteAllOffer(mayHaveCloudCopy:
   Persistence.isSyncActive) instead of hard-coding one.
3. 3. Until a genuine local wipe exists, both unattended paths must pass
   .thisDeviceAndCloud whenever the live store opened mirrored. On a mirrored store
   .thisDevice is not local — that is precisely why Settings refuses to offer it — so
   'duress keeps .thisDevice' is not a safe compromise.
4. 4. Implement the real local wipe behind a rebuildable Persistence.reopen(mirrored:
   false): destroy the store files and reopen unmirrored, so .thisDevice becomes
   truthful again and duress can use it. This is the permanent fix; step 3 is the
   correct shipped behaviour until it lands.
5. 5. Update both features' arming copy (duress PIN setup, auto-wipe toggle) to state
   what will actually happen, including other devices and the iCloud copy. Neither
   warning mentions them today.
6. 6. Leave the cloud-first ordering at SecureWipeService.swift:74-86 unchanged — an
   interrupted wipe should leave data on the phone she is holding rather than an
   untouched copy in iCloud.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* DeletionModelTests.DeleteAllOfferTests gains cases for the duress and auto-sweep
paths. CaelynTests.swift:972 and DeletionModelTests.swift:252-290 call wipeEverything
and must pass an explicit scope once the default is removed (that compile break is the
point). Add a case asserting a duress wipe on a mirrored store selects
.thisDeviceAndCloud, and one asserting it selects .thisDevice on an unmirrored store.

#### LC-03 — Lifecycle: Persistence.preserveStoreAside / RootView.storeWarningBanner

If Caelyn ever fails to open her data file — an interrupted update, a full disk, a
damaged file after a crash — it keeps the old file safely on disk and starts fresh.
But nothing in the app can open, read, export or merge that kept file. The banner says
her previous data was kept aside; tapping its X means the app never mentions it again.
She experiences years of history as permanently lost while it sits on disk, and the
kept files pile up forever inside the app's storage.

**Root cause.** The preserved store has no in-app referent by construction. The only knowledge of its
path is Persistence.defaultStoreURL() — private, a single hard-coded default.store URL
with no enumerator (Persistence.swift:158-163) — and the only knowledge that a
preserve happened is an OSLog line (:179), which no code can read back, plus a boolean
storeFailedKey that records THAT a failure occurred and not WHICH file was kept, whose
only reader treats it as a dismissible banner flag (RootView.swift:87-107). storeMode
(Persistence.swift:94) was meant to carry the honest status into the UI but is
private(set) with zero readers. ExportView reads only the live @Query
(ExportView.swift:5) and the import flow accepts CSV/JSON/Health only, so no existing
path can reach a .store file.

**Fix.**

1. 1. Make discovery the single source of truth, not a flag: add
   Persistence.preservedStores() -> [URL] that enumerates Application Support for
   `default.store.corrupt-*`, excludes the -shm/-wal sidecars, and sorts by the parsed
   timestamp.
2. 2. Drive the banner's persistence AND a new Settings -> Data row off
   !preservedStores().isEmpty. Keep storeFailedKey only for 'this launch recovered',
   so dismissing the banner can never orphan the file again.
3. 3. Add RecoverPreviousDataView: open a chosen preserved store read-only in its own
   ModelContainer (cloudKitDatabase: .none, never mirrored), show entry count and date
   range, and offer two actions — export it through ExportService, and merge it into
   the live store through the existing additive CycleStore.merge path.
4. 4. Never auto-merge and never auto-delete. Offer 'Discard this copy' explicitly,
   and only after a successful export or merge.
5. 5. Stop the silent accumulation honestly: list every preserved copy with its date
   rather than pruning behind her back; discarding is hers to do.
6. 6. Change the banner copy to name the destination ('Recover previous data' in
   Settings -> Data) instead of 'kept aside' with nowhere to go, and expose storeMode
   so the in-memory fallback (Persistence.swift:147-152, where nothing persists at
   all) says so too.

*Files:* `Caelyn/Services/Persistence.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/CycleStore.swift`

*Tests:* New tests: write a seeded store at a .corrupt-* path and assert preservedStores()
finds and orders it; open it through the recovery API and export it; merge it into an
empty live store and assert counts, then merge it again and assert idempotence and
that the merge is additive (never blanks a field the live store holds).
UpgradeAndDeviceMatrixTests.withStore is reusable as the fixture builder.

#### LC2-01 — Lifecycle: locked-state handling / scenePhase (AppLockGate + AppPreviewMask)

If a pop-up panel was open when she last left the app — a day's details in the
calendar, the log sheet, the import flow, the export screen — that panel is still
fully readable and tappable when she comes back, sitting on top of the lock screen.
The App Lock she turned on so nobody else could read her cycle data does not cover it,
and 'hide app preview' leaks the same panel into the app switcher.

**Root cause.** The lock and the shield are composed as siblings of content() inside one SwiftUI
ZStack (AppLockGate.swift:25-33, AppPreviewMask.swift:15-22) and are switched on by
applying .opacity/.allowsHitTesting to that subtree. Those are render-time effects on
the presenting controller's view, while a SwiftUI .sheet is hosted by a separate view
controller that UIKit places in a presentation container ABOVE that view, so neither
effect reaches it. Every one of the app's ~23 .sheet sites is a descendant of that
closure (CaelynApp.swift:31 -> ContentView -> RootView:32 -> MainTabView), so the hole
is structural, not per-screen.

**Fix.**

1. 1. Do NOT move the lock to a .fullScreenCover at the WindowGroup root. When the
   lock fires the topmost presenter is usually a descendant (MainTabView's
   UITabBarController, or a NavigationStack's UINavigationController), and asking the
   root to present while a descendant holds a presentation is the configuration UIKit
   handles inconsistently across iOS versions (silent no-op / re-target / 'already
   presenting').
2. 2. Introduce a UIKit-level cover owned by the scene: a LockWindowPresenter that
   creates (or reuses) a UIWindow on the active UIWindowScene at an alert-adjacent
   windowLevel, hosting the existing lock and shield SwiftUI views. A second window
   sits above every presentation in the scene regardless of who presented it.
3. 3. Drive it from the state AppLockGate/AppPreviewMask already compute
   (showLockScreen, shouldMask). Keep the in-tree ZStack layer as a fallback for the
   no-sheet case, or delete it once the window path is proven on device.
4. 4. Keep the timing exactly as today: shield at .inactive (the snapshot moment,
   AppPreviewMask.swift:13), lock at .active. Only the host changes.
5. 5. Make the lock window non-dismissable by gesture, and tear it down only after a
   successful unlock — including the duress path, which currently unlocks into a wiped
   app.
6. 6. Present biometrics from the lock window's own root controller, not the app's, or
   the system Face ID / passcode sheet will be presented beneath the lock window and
   be unreachable.

*Files:* `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Main/AppPreviewMask.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/Main/ContentView.swift`, `Caelyn/Views/RootView.swift`

*Tests:* No test covers this today. Add the UI test below to CaelynUITests, then repeat it for
the log sheet presented from Home and for the app-switcher shield (hidePreview on,
background, assert the shield identifier is the only visible content). A unit test
cannot reach this — it is a presentation-hierarchy fact.

#### LC2-02, PRIV-12, PRIV-13 — 15 Delete all data · 11 duress PIN · 14 Auto-erase (SecureWipeService.wipeEverything + Persistence.preserveStoreAside + ExportService.writeToTempFile)

She taps "Delete all data … It cannot be undone", or types the duress PIN with someone
standing over her, and complete, readable copies of her cycle history are still
sitting in the app's own folders afterwards: any CSV or PDF she ever exported, and —
if Caelyn ever recovered from a damaged store — a full SQLite copy of her entire
previous history. The wipe deletes rows; it never deletes files.

**Root cause.** wipeEverything treats "erase" as a logical operation over a hand-maintained list of
subsystems (SecureWipeService.swift:83-134: two modelContext.delete(model:) batch
deletes, notifications, HealthKit, App-Group snapshot, PIN keychain, a literal
UserDefaults key array). Three file producers create plaintext on disk and none of
them transfers ownership of that file's lifetime to anything: (a)
Persistence.preserveStoreAside (Persistence.swift:167-180) renames
default.store/-shm/-wal to default.store.corrupt-<ts> and nothing ever reaps them; (b)
ExportService.writeToTempFile (ExportService.swift:525-536) returns a URL into
FileManager.temporaryDirectory and ExportView holds it only in @State
(ExportView.swift:277), so the last reference dies while the file lives; (c) the live
store itself is never unlinked — rows are freed as SQLite pages with secure_delete off
and pre-delete page images persist in -wal, because the container is a static let that
stays open for the process (Persistence.swift:96, and SecureWipeService.swift:49-50
documents container teardown as deferred work). Compounding (a): the wipe also clears
Persistence.storeFailedKey (in the key array at SecureWipeService.swift:~124), and
that flag is the sole trigger for RootView's banner (RootView.swift:8, 98) — the only
UI that ever mentions "Your previous data was kept aside". So the wipe destroys the
notice of the preserved copy while leaving the copy.

**Fix.**

1. 1. Add `static func purgePreservedStores()` to Persistence: enumerate Application
   Support with `FileManager.contentsOfDirectory`, match the literal prefix
   `default.store.corrupt-` across all three suffixes (``, `-shm`, `-wal`), and
   `removeItem` each. Enumerate the directory — never gate on `storeFailedKey`,
   `storeMode` or `isSyncActive`, because the file is normally left by a PREVIOUS
   launch while this launch's storeMode == .ok (the common case for the Settings
   path).
2. 2. Give exports a dedicated directory: `temporaryDirectory/Exports`, created by
   ExportService, and have `writeToTempFile` purge that directory's existing contents
   before writing the new file. Do NOT delete on ExportView.onDisappear — ShareLink
   hands the URL to the system share sheet, which can outlive the view and copy
   lazily; deleting on disappear yanks the file out of an in-flight AirDrop.
3. 3. Add `static func purgeExports()` that empties `temporaryDirectory/Exports`, and
   call it from a `scenePhase == .background` hook as well as from the wipe.
4. 4. In wipeEverything, add a numbered step 7 (local half, after the cloud step,
   before the return) that calls both purges. It must run even if the SwiftData
   deletes threw — wrap the row deletes so a throw cannot skip the file purge.
5. 5. Reap by age independent of the wipe: on launch, delete any
   `default.store.corrupt-*` set older than 90 days, so a user who never wipes does
   not accumulate full histories she cannot see.
6. 6. Update the file-header storage-location list (SecureWipeService.swift:10-15) to
   name "files Caelyn wrote outside the store (preserved stores, exports)" as a
   category, so the next file producer has a line to be added to.
7. 7. DEFERRED to the PRIV-14 container rebuild (do not attempt now): after the rows
   are gone, close the container, unlink default.store/-shm/-wal and recreate an empty
   store at the same URL, which discards the iOS per-file key and makes the residue
   cryptographically unrecoverable rather than merely unreferenced.
8. 8. Why permanent: steps 1-5 remove the artifacts (whole plaintext histories), not a
   residue class that depends on SQLite internals, and steps 2-3 make the producer
   self-cleaning so residue is bounded to one in-flight file rather than growing with
   every export.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/Persistence.swift`, `Caelyn/Services/ExportService.swift`, `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Views/RootView.swift`

*Tests:* Extend DeletionModelTests.testALocalOnlyWipeClearsEveryRowAndAttemptsNoCloudDeletion
and testDeletingBothAttemptsTheCloudAndClearsLocal with an assertion that no
`default.store.corrupt-*` file remains. Add
testWipeRemovesExportTempFilesAndPreservedStores: stage a fake Application Support
directory containing default.store.corrupt-123 plus -shm/-wal and a Caelyn-*.csv in
temporaryDirectory/Exports, run the wipe, assert both directories are clean. Add a
test that writeToTempFile called twice leaves exactly one file in the Exports
directory.

#### LC2-03, PRIV-06 — 15 Delete all data · 11 duress PIN · 14 Auto-erase (SecureWipeService keychain + preference steps)

After "Delete all data" — or after the duress PIN, which promises a result
indistinguishable from a brand-new install — Settings still shows an Apple account
next to "Signed in". The app keeps asking Apple about a sign-in the user believes she
destroyed, and someone who forced the duress PIN can see, on the supposedly wiped
phone, that it was in use and tied to an Apple ID.

**Root cause.** The wipe is a hand-maintained enumeration of storage locations with nothing that
forces a newly added location into it. Its only Keychain step is
`PINService.clearAll()` (SecureWipeService.swift:~99), scoped to the keychain service
"com.caelyn.pin" (PINService.swift:14), and the file-header list
(SecureWipeService.swift:10-15) names SwiftData, notifications, Health, App Group and
"app preference flags" — it never names Keychain as a category. 1.3 introduced a
SECOND keychain service, "com.caelyn.account" (AccountIdentityStore.swift:21),
deliberately isolated from the cycle store, so it could never be covered incidentally;
`AccountIdentityStore.signOut()` (AccountIdentityStore.swift:46-51) has no caller in
the wipe. The same literal-list defect drops `CloudDeletionTombstone.syncConsentKey`
(CloudDeletionTombstone.swift:36) from step 6's key array. The result renders as fact
because SettingsView derives the account row from the Keychain alone
(SettingsView.swift:450, :501-505) and AccountView seeds `isSignedIn` the same way
(AccountView.swift:20, :57), while the new profile's `accountLinked` is false — so
Keychain and profile openly disagree and the UI believes the Keychain.

**Fix.**

1. 1. In SecureWipeService.wipeEverything, extend the existing step 5 (do not append a
   5c) so the line reads as "every Keychain service Caelyn owns":
   `PINService.clearAll()` then `AccountIdentityStore.signOut()`.
2. 2. Add `CloudDeletionTombstone.syncConsentKey` to the literal key array in step 6
   (SecureWipeService.swift:~108-125).
3. 3. Leave `CloudDataDeletion.deletedAtKey` uncleared exactly as today —
   DeletionModelTests.testALocalWipeDoesNotForgetThatSheDeletedHerCloudCopy pins that
   and must keep passing.
4. 4. Rewrite the file-header comment (SecureWipeService.swift:10-15) to list Keychain
   as its own numbered storage category naming both services, so a third service has
   an obvious slot. Scope the comment's claim to "every Keychain service Caelyn owns
   is cleared here" — do NOT frame it as closing a duress tell, because the credential
   surviving a real reinstall is deliberate (AccountIdentityStore.swift:8-12,
   AccountView.swift:166); the wipe is only being made symmetric with the rest of the
   wipe.
5. 5. Stop rendering identity from one source: make SettingsView.swift:450 (and
   AccountView.swift:20/:57) require `profile?.accountLinked` as well as
   `AccountIdentityStore.isSignedIn`, so a Keychain-vs-profile disagreement can never
   again be shown to her as fact.
6. 6. Why permanent: both lines sit inside the single enumerated wipe, so all three
   callers (Settings, duress, auto-erase) inherit them with no per-caller opt-in; step
   5 removes the one surface that could display the contradiction if a fourth store is
   ever missed.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/Account/AccountIdentityStore.swift`, `Caelyn/Services/Account/CloudDeletionTombstone.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* Extend CaelynTests.testSecureWipeClearsSwiftData (~:961) and
DeletionModelTests.testALocalOnlyWipeClearsEveryRowAndAttemptsNoCloudDeletion with
`XCTAssertFalse(AccountIdentityStore.isSignedIn)` after a wipe, guarded the same way
the existing PIN assertion is for keychain-less test hosts. Add an assertion that
CloudDeletionTombstone.localConsent is nil after a wipe.
testSignOutKeepsLocalHistoryAndTouchesNothingInTheCloud is unaffected.

#### LC2-04 — Launch / scenePhase — auto-sweep (AppLockGate.sweepThenRecordActivity)

On the one launch where the auto-erase timer actually fires, the app immediately
writes to and saves the profile it just deleted. Either it crashes on that launch, or
it quietly resurrects her profile — leaving behind the evidence that Caelyn was set
up, which is the exact thing the feature promised to remove.

**Root cause.** `AutoSweepService.checkAndSweep` returns Void (AutoSweepService.swift:22-29) — it
tells its caller nothing about whether it swept. So
`AppLockGate.sweepThenRecordActivity` (AppLockGate.swift:91-95) chains
`recordActivity` unconditionally, and `recordActivity` (AutoSweepService.swift:31-36)
takes its subject as a CALLER-SUPPLIED reference (`profiles.first`, read from a @Query
array captured in the current view value) rather than resolving it at the point of
write. After `wipeEverything` has run `modelContext.delete(model: UserProfile.self)`
and saved (SecureWipeService.swift:85-86), that reference points at a deleted model;
`profile.lastActiveAt = now; modelContext.saveOrLog()` then either raises on an
invalidated model or re-inserts it. The mechanism is the missing signal plus the
caller-held subject, not any claim about @Query refresh semantics.

**Fix.**

1. 1. `@discardableResult static func checkAndSweep(...) async -> Bool` — return true
   when it called `wipeEverything`, false otherwise (AutoSweepService.swift:22-29).
2. 2. In AppLockGate.sweepThenRecordActivity (AppLockGate.swift:91-95): `if await
   AutoSweepService.checkAndSweep(profile: profiles.first, modelContext: modelContext)
   { return }`. There is nothing to stamp on a wiped store, and the early return makes
   that explicit rather than accidental.
3. 3. Make `recordActivity` resolve its own subject at the point of write instead of
   trusting a caller-held reference: fetch `UserProfile` sorted by createdAt inside
   the function and guard on a non-empty result, rather than taking `profile:` as a
   parameter. This is the half that makes the class of bug impossible rather than
   fixing this instance.
4. 4. Coordinate with the PRIV-01 item: that change also alters checkAndSweep's
   signature (adding the wipe reason). Land both edits in one patch so the signature
   changes once.
5. 5. If the PRIV-04 item lands, recordActivity writes UserDefaults rather than the
   profile and step 3 becomes moot — but step 1/2's early return is still required,
   because stamping after a wipe is wrong regardless of where the stamp lives.
6. 6. Why permanent: the sweep's effect becomes part of its contract (a return value
   the caller cannot ignore), and the writer stops holding a reference across an
   operation that can invalidate it.

*Files:* `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* CaelynTests.testAutoSweepWindow covers only the pure predicate and is unaffected. Add
the probe below as the first test that exercises checkAndSweep + recordActivity as a
pair.

#### MODES-03 — 28 Specialist modes — Pregnancy / Postpartum (cycle statistics after)

After a pregnancy (or any long gap without a period — breastfeeding, illness,
continuous contraception, or just months of not logging), Caelyn counts the whole gap
as one enormous "cycle", and for roughly the next six months her average cycle length,
her "varies by ±186 days", her irregularity label and her doctor PDF are all wrong.

**Root cause.** PredictionEngine.plausibleCycles is a floor-only filter — `cycles.filter { $0.length
>= minimumPlausibleCycleLength }` at
/Users/smile/Desktop/caelyn/Caelyn/Services/PredictionEngine.swift:45-47 (verified: no
upper bound). The reconstruction it filters is purely flow-gap based, so a 300-day
flow-free interval is emitted as a legitimate Cycle and enters every statistic:
weightedMean gives the newest cycle weight 1.0, clampCycleLength (:131, `min(45,
max(18, v))`) saturates the average at 45, cycleLengthVariation (:136-142) returns
(400-28)/2, and irregularCycleStatus's `lengths.contains { $0 > 45 }` (:408-411)
latches .skippedPeriods. One missing ceiling on a one-sided plausibility test produces
every symptom.

**Fix.**

1. 1. In /Users/smile/Desktop/caelyn/Caelyn/Services/PredictionEngine.swift, beside
   `minimumPlausibleCycleLength` (:41), add `static let maximumPlausibleCycleLength =
   90` with a doc comment explaining that a gap longer than this is an absence of
   cycling, not a cycle.
2. 2. Change plausibleCycles (:45-47) to `cycles.filter { $0.length >=
   minimumPlausibleCycleLength && $0.length <= maximumPlausibleCycleLength }`. This is
   permanent because it fixes the test, not the instance: every long-amenorrhoea cause
   is covered at once, and no downstream statistic needs to learn about pregnancy.
3. 3. Confirm the reconstruction itself is unchanged — CycleModel.make
   (/Users/smile/Desktop/caelyn/Caelyn/Models/CyclePrediction.swift:216-217) keeps
   `allCycles` for display and passes only `cycles` (the plausible subset) into the
   statistics, so the calendar still shows the real history while the maths excludes
   the gap.
4. 4. Do NOT add a stored pregnancy-episode date here. That field belongs to the life-
   stage item (MODES-04/MODES-05) and must not be duplicated; this item is a pure
   derivation change with no stored data.
5. 5. Re-check the clamp interaction: once the gap cycle is excluded,
   averageCycleLength no longer saturates at 45, so this item must land before the
   PCOS/perimenopause cap relaxation (MODES-13) or the two changes will be impossible
   to tell apart in test output.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* Add the probe fixture (five 28-day cycles, a 300-day gap, then a current period) to
CaelynTests.swift beside the averages tests at :862-863, asserting cycleLength == 28
and variation == 0 and irregularStatus == .regular. Existing tests
CaelynTests.swift:826-829 (artefacts → insufficient), :862-863 (averages) and
:1398-1433 (irregularity) must still pass unchanged with a 90-day ceiling — verify
none of their fixtures contain a cycle > 90.

#### PRIV-01 — 11 App Lock duress PIN · 14 Auto-erase · 15 Delete all data (SecureWipeService.Scope default)

The two wipes that happen with nobody watching — the duress PIN and the auto-erase
timer — only clear this phone. If she has ever used iCloud sync, the full copy of her
reproductive-health history stays in iCloud, and because the live store is still
mirrored for the rest of that session it can re-import into the just-emptied app
within seconds, while the person who coerced her is still holding the phone.

**Root cause.** `wipeEverything` carries a defaulted parameter `scope: Scope = .thisDevice`
(SecureWipeService.swift:74-81). The two unattended callers — AppLockGate.verifyPIN's
`.duress` branch (AppLockGate.swift:103-110) and AutoSweepService.checkAndSweep
(AutoSweepService.swift:22-29) — call it with no scope and silently inherit device-
only, so `CloudDataDeletion.deleteCloudCopy()` is never reached and no
`deletedAtKey`/pending marker is written. The service has no notion of WHY it is
wiping, so it cannot resolve the scope itself, and
`CloudDataDeletion.cloudCopyMayExistNow` (CloudDataDeletion.swift:70-79) — the one
predicate that answers "could anything of hers be in iCloud right now?" — is consulted
only by the two attended screens. The defaulted parameter is the actual trap: it lets
a new caller be written that is wrong by omission and still compiles.

**Fix.**

1. 1. DELETE the default: change the signature to `wipeEverything(modelContext:reason:
   WipeReason) async -> CloudDataDeletion.Outcome?` with `enum WipeReason { case
   userRequested(Scope), duress, autoErase }`. Removing the default is the structural
   half — the compiler, not a reviewer, now stops the next silent caller.
2. 2. Add `private static func resolvedScope(_ reason: WipeReason) -> Scope`:
   `.userRequested(let s)` returns s; `.duress` and `.autoErase` return
   `CloudDataDeletion.cloudCopyMayExistNow ? .thisDeviceAndCloud : .thisDevice`.
3. 3. Update the three call sites: SettingsView passes `.userRequested(scope)`
   (preserving today's dialog-chosen scope), AppLockGate.swift:103-110 passes
   `.duress`, AutoSweepService.swift:22-29 passes `.autoErase`.
4. 4. An unattended wipe cannot show an alert, so it must leave a retry marker: ensure
   `deleteCloudCopy()` writes `pendingKey` even on the `.unavailable` early return
   (see the PRIV-02/LC2-07 item — that change is a prerequisite for this one to be
   honest offline).
5. 5. Add `CloudDataDeletion.mayExistKey` handling to the wipe: it is currently absent
   from the cleared list (SecureWipeService.swift:~106-125) — deliberately keep it set
   when the cloud delete did not succeed, so the Account & iCloud card keeps offering
   "Delete my iCloud copy"; clear it only on a `.deleted`/`.nothingToDelete` outcome,
   which deleteCloudCopy already does.
6. 6. Why permanent: the scope stops being a value a caller may forget and becomes a
   value the caller must name, and the only two callers that cannot name it get the
   answer derived from the one predicate that knows.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`

*Tests:* DeletionModelTests.testALocalOnlyWipeClearsEveryRowAndAttemptsNoCloudDeletion keeps
passing (it names the scope explicitly) but its call must be updated to the new
`reason:` signature. Add testDuressWipeAttemptsCloudDeletionWhenACopyMayExist and
testUnattendedWipeLeavesARetryMarkerWhenOffline. All existing wipeEverything call
sites in the test suite need the signature change.

#### PRIV-02, LC2-07 — 15 Delete all data (device + iCloud)

She taps "Delete on this iPhone and iCloud" while in airplane mode or signed out of
iCloud. The phone is wiped, the app resets to the welcome screen, and she is told
nothing — so she believes her reproductive-health history is gone. It is still in
iCloud, and nothing will ever try again.

**Root cause.** Two defects in one flow. (a) No retry marker: `deleteCloudCopy()` returns
`.unavailable` at CloudDataDeletion.swift:107-110 BEFORE `defaults.set(true, forKey:
pendingKey)` at :113, so the launch guard `guard deletionIsPending ||
cloudCopyWasDeleted` at :159 — the only retry, called once from CaelynApp.swift:60 —
can never see that a deletion was requested. `honourRemoteDeletionIfNeeded` cannot
help either: the tombstone is only written on a success branch (:130, :140). (b) No
message: the honest report is `@State private var deleteAllResult` owned by
SettingsView (SettingsView.swift:21) with the alert at :200-207, assigned at :807-823
AFTER `wipeEverything` has already deleted every UserProfile row and saved
(SecureWipeService.swift:85-86) and then suspended for two more XPC round trips (:89,
:92). By the time the continuation resumes, RootView has seen `hasOnboarded == false`
and swapped MainTabView for OnboardingFlow (RootView.swift:28-42), animating the
branch over 0.4s. The assignment lands on a view node that is mid-removal or already
gone, so the alert never presents. The ownership is wrong: the operation that produces
the value destroys the view that owns it.

**Fix.**

1. 1. Move `defaults.set(true, forKey: pendingKey)` and `defaults.set(false, forKey:
   Persistence.syncEnabledKey)` ABOVE the `guard availability == .available` in
   CloudDataDeletion.swift:106-113, so `.unavailable` behaves exactly like `.failed`
   and the launch guard retries.
2. 2. Add the exit that keeps the marker from becoming permanent on a phone with no
   iCloud account: when availability is a CONFIRMED absence (.noAccount / .restricted)
   AND `mayExistKey` is false, there is provably nothing to delete — return
   `.nothingToDelete` and clear both markers. Without this, `cloudCopyMayExistNow`
   never returns false again on such a device.
3. 3. Hoist the outcome above the route. Introduce an `@Observable
   WipeOutcomeReporter` (or `@State` on RootView) and present the alert from
   RootView's own modifier chain — RootView is the root, so it survives the
   MainTabView→OnboardingFlow swap. Remove `deleteAllResult` from SettingsView.
4. 4. Persist the notice so a kill mid-operation still surfaces it: write a
   UserDefaults string on a non-deleted outcome, render it from RootView on next
   launch, clear it on acknowledgement. The `Task {}` at SettingsView.swift:811 is
   unstructured and guarantees nothing about completion.
5. 5. Keep the words that are already right (the comment above the assignment calls a
   silent failure "the worst possible outcome for someone deleting reproductive
   health") and make sure the onboarding-facing presentation says where to finish the
   job: Settings → Account & iCloud → Delete my iCloud copy, which the Account card
   already offers while mayExistKey is set.
6. 6. Why permanent: (a) makes the marker a function of "a deletion was requested",
   not of "the network happened to be up"; (3)+(4) move the report to an owner whose
   lifetime is not ended by the operation being reported on, so no future wipe-and-
   route flow can lose its own message.

*Files:* `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* Check DeletionModelTests.testUnavailableICloudIsReportedHonestlyAndNeverAsDeleted
(~:130) does not assert pendingKey is false — if it does, amend it. Add
testUnavailableICloudLeavesAPendingMarkerSoTheLaunchGuardRetries and
testConfirmedNoAccountWithNoCloudCopyClearsRatherThanPends.
testWhenTheCloudHalfFailsTheLocalHalfStillCompletesAndSaysSo keeps passing. Add a UI
test that the alert appears over the onboarding screen after a forced cloud failure.

#### PRIV-03, LC-04 — 11 App Lock · 12 Hide app preview

If a sheet is open when she puts the phone down — the daily log, the export screen,
the import preview — App Lock does not cover it. The next person sees that sheet in
the app switcher and, on reopening, can keep using it on top of the lock screen:
export her whole history, or read and write her log, without ever unlocking.

**Root cause.** The lock and the privacy shield are implemented as in-hierarchy ZStack siblings that
merely make the content transparent and non-hit-testable (AppLockGate.swift:26-29,
31-53; AppPreviewMask.swift:15-22). UIKit modal presentations are hosted ABOVE the
hosting controller's root view, as siblings in the window — so opacity,
allowsHitTesting, disabled and zIndex are all scoped to the wrong layer and are
structurally incapable of covering, disabling or suppressing a presented controller.
Second, because the gate keeps the content MOUNTED rather than removing it, every call
site's `@State` presentation flag stays true, so the modal survives the whole lock
cycle instead of being torn down. Third consequence, missed in both original findings:
sheets bound inside the hidden content can RAISE THEMSELVES while locked, with no user
interaction — `.sheet(item: $incomingFile)` fires whenever onOpenURL delivers a file
(CaelynApp.swift:31-44), so sharing a CSV to Caelyn from Files or Mail on a locked
phone opens BringHistoryView, which immediately reads the file and plans against her
live store (BringHistoryView.swift:89-94); and RootView's account-offer sheet presents
itself over the lock too (AppLockGate.swift:79-87).

**Fix.**

1. 1. Make the lock own the screen instead of sharing the hierarchy: create a
   `PrivacyOverlayController` that attaches a dedicated UIWindow to the active
   UIWindowScene at a windowLevel above .normal when the lock/shield should be up, and
   tears it down on unlock. A window covers presented modals, satisfies the app-
   switcher-snapshot requirement the current `scenePhase != .active` branch exists for
   (AppLockGate.swift:84-86), and makes every FUTURE presentation safe by construction
   with no per-call-site opt-in. `.fullScreenCover` is not sufficient — it is itself a
   presentation and loses to whichever presented first.
2. 2. Note the mechanic that makes this clean here: PINPadView
   (Caelyn/Views/Main/PINViews.swift) uses a custom digit pad with no
   TextField/SecureField/FocusState, so the overlay window never needs to become key
   or host a keyboard — the usual reason this pattern gets ugly does not apply.
3. 3. Drive the window from ONE source of truth. Today `showLockScreen`
   (AppLockGate.swift:79-87) and `shouldMask` (AppPreviewMask.swift:13) are computed
   independently in two views that each hold their own @Query and scenePhase; have
   both read the controller so they cannot disagree during a phase transition.
4. 4. Add the secondary gate for self-raising presentations: publish an
   `\.appIsUnlocked` environment value from the controller and condition the two
   automatic sheets on it — `.sheet(item: $incomingFile)` in CaelynApp.swift:31-44 and
   the account offer in RootView/AppLockGate. Queue the incoming file rather than
   dropping it, and present it after unlock. This is the second half, not the fix: on
   its own it leaves every other sheet live.
5. 5. Audit for sheets that must be dismissed rather than covered: when the overlay
   goes up, the export sheet's share state should not stay live behind it.
6. 6. Why permanent: the guard moves to the window layer, which is the layer
   presentations actually live in, so correctness no longer depends on each new
   `.sheet` remembering to opt in.

*Files:* `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Main/AppPreviewMask.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Views/Import/BringHistoryView.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* Existing CaelynUITests.testPINLockAndDuressWipeEndToEnd and
testPrivacyControlsAndDeleteAllDataJourney must keep passing with the overlay window
(XCUITest sees the top window). Add a UI test: with the PIN path enabled via --ui-
test-disable-device-auth, open Export (a sheet), background and foreground, assert
"Caelyn is locked" exists and app.buttons["Share"] is not hittable. Add a second: lock
on, deliver a file via onOpenURL, assert UIA.Import.Close is absent while locked and
present after unlock.

#### PRIV-04 — 14 Auto-erase if inactive

"Auto-erase if inactive" is not per-device. Turning it on on her iPhone turns it on
everywhere, and an iPad she rarely opens can wipe itself — and, through sync, wipe the
iPhone she uses daily — even though she has opened Caelyn every day. In the opposite
direction, a lost phone keeps its data forever, because using Caelyn on any other
device refreshes the lost phone's "last active" stamp.

**Root cause.** A per-DEVICE decision ("has this phone been untouched?") is stored in a per-ACCOUNT,
CloudKit-mirrored record. `autoWipeEnabled`, `autoWipeAfterDays` and `lastActiveAt`
are fields on UserProfile (UserProfile.swift:77-80), which is inside
Persistence.schema (Persistence.swift:21) and mirrored when sync is on (:105-107).
ProfileStore.merge then ORs the flag (ProfileStore.swift:74) and takes
`max(lastActiveAt)` (:98-101), which is exactly the wrong reducer for both fields. It
is then READ as if it were device-local at the one instant it cannot be trusted:
AppLockGate's first-render `.task` (AppLockGate.swift:55, 92-95) runs before any
CloudKit import has landed, because CloudSyncCoordinator is only started later from
CaelynApp.swift:55 and never touches the profile at all.

**Fix.**

1. 1. Move the three values to device-local storage: UserDefaults keys
   `caelyn.autoWipe.enabled`, `caelyn.autoWipe.afterDays`,
   `caelyn.autoWipe.lastActiveAt`, plus a Keychain `caelyn.installID` with
   kSecAttrAccessibleWhenUnlockedThisDeviceOnly so a restore to a new device is
   recognisably a different install.
2. 2. One-time migration on first launch of the new build: copy the profile's current
   values into the new keys, but set `lastActiveAt = now` unconditionally, so a stale
   synced stamp cannot fire a wipe on upgrade.
3. 3. Leave the UserProfile fields in place (additive policy) and stop reading them.
   Optionally write `autoWipeEnabled = false` so devices still on the old build disarm
   rather than fire on stale data.
4. 4. Keep `AutoSweepService.shouldSweep` pure and unchanged — it already takes all
   inputs as parameters, so only the call sites change.
5. 5. Handle the new keys in SecureWipeService step 6: ALWAYS reset `.lastActiveAt` to
   now after any wipe, and make an explicit, commented decision about whether
   `.enabled` survives a duress wipe (keeping it armed is residue that says the
   feature was configured; clearing it means a re-onboarded app is unprotected).
   Document whichever is chosen.
6. 6. Remove the now-dead ProfileStore.merge reducers for autoWipeEnabled (:74) and
   lastActiveAt (:98-101).
7. 7. Why permanent: the value's storage domain is made to match its semantic domain,
   so no merge rule, import timing or sync toggle can make it wrong again.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* CaelynTests.testAutoSweepWindow is unchanged (pure predicate). ProfileStoreTests
assertions on autoWipe/lastActiveAt merging become dead — remove them. Add
AutoSweepStateTests covering: the migration seeds lastActiveAt = now; enabling on one
store does not affect another; the install marker survives a relaunch and differs
after a simulated restore.

#### PRIV-05 — 14 Auto-erase if inactive (consent and window)

"Auto-erase if inactive" is a plain on/off switch with no confirmation and no
explanation that it cannot be undone, and there is no way to choose the idle period
even though the Privacy page says it erases "after your chosen idle period". One
accidental tap plus a four-week holiday and everything is gone, silently, before any
screen is shown.

**Root cause.** Two mechanisms. (a) A destructive setting is wired as an ordinary preference: a
`SettingsToggleRow` bound straight to `profile.autoWipeEnabled`
(SettingsView.swift:381-391), committing in the binding's setter with no confirmation
step and no copy about irreversibility or about the sweep running before any UI
appears. (b) `autoWipeAfterDays` was added to the model (UserProfile.swift:79) and is
read by the row subtitle and by `shouldSweep`, but NO view ever writes it — grep shows
the only non-default writer in the whole target is ProfileStore.merge
(ProfileStore.swift:98). A model field shipped ahead of its UI, with
PrivacyTrustView.swift:114 describing a control that was never built.

**Fix.**

1. 1. Land the scope fix first (see the PRIV-01 item) — it is the one-line half that
   needs no design: with `scope` non-defaultable, the auto-erase caller must state
   what it actually does, which on a mirrored container is a cross-device wipe.
2. 2. Decide and implement the mirrored-container behaviour explicitly: either pass
   `.thisDeviceAndCloud` (truthful about what happens) or refuse to sweep while a
   mirror is live and show a one-time "Auto-erase needs sync off" notice. A silent
   cross-device wipe is not what the row promises; pick one and put the rule in the
   service, not the call site.
3. 3. Replace the bare toggle with a confirmation step on turn-ON only: a sheet that
   states (a) it deletes everything on this device, (b) it cannot be undone, (c) it
   fires at launch before anything is shown, (d) the current window; requires an
   explicit destructive-styled confirm. Turning it off stays one tap.
4. 4. Build the window picker the copy already promises: a Picker writing
   `autoWipeAfterDays` (7 / 14 / 30 / 60 / 90), shown inside the same confirmation
   sheet and in the Settings detail row. Subtitle must interpolate the stored value,
   not the constant 30.
5. 5. Update PrivacyTrustView.swift:114 to match whatever the control actually offers.
6. 6. Why permanent: the irreversibility gate lives with the setting that arms it, and
   the promised choice becomes a real stored value with a writer, so the copy and the
   behaviour cannot drift again.

*Files:* `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* CaelynUITests.testPrivacyControlsAndDeleteAllDataJourney taps the toggle directly
(~:707-710) and MUST be updated to drive the new confirmation sheet. Add a unit test
that the row subtitle reflects a non-default autoWipeAfterDays, and that the picker's
write round-trips.

#### PRIV2-01 — 11 App Lock PIN + biometrics

The duress PIN — the code she types to destroy her history when someone is forcing her
to open the app — stops working after five wrong attempts. The person coercing her
will usually have burned those attempts guessing first, so at the exact moment the
feature exists for, she types the destroy code and the screen answers "Too many
attempts. Try again in 47 seconds" in front of him.

**Root cause.** `PINService.verify` (PINService.swift:55-68) is one overloaded entry point answering
three different questions — is this the owner's unlock code, is this the owner's
destroy command, and does this candidate collide with the primary — and the anti-
guessing guard sits above all three (`:56-58` returns `.lockedOut` before the primary
compare at :61 and the duress compare at :64). Guard-above-everything is the defect;
the refused duress attempt is one consequence of it. The verdict is then rendered to
her as a countdown (AppLockGate.swift:111-115), so the refusal is visible, while
PrivacyTrustView.swift:102-105 states the promise unconditionally.

**Fix.**

1. 1. Split the entry point rather than reordering it. Add `verifyDuress(_:) -> Bool`
   that compares only the duress hash and is never gated by the lockout, and keep
   `verify(_:)` for the unlock question with its guard intact.
2. 2. Do NOT simply hoist the duress compare above the lockout in the shared path:
   that makes the duress code testable at unlimited rate, turning every mashed 4-digit
   entry into a free 1-in-10,000 roll on a silent irreversible wipe. Today a mashing
   child gets 5 rolls per minute; an ungated compare gives them hundreds.
3. 3. Keep a rate limit on the duress compare that cannot block a deliberate entry: a
   short per-entry delay (e.g. 300-500 ms constant-time compare) and a separate, much
   larger duress-attempt budget, rather than the shared 60 s lockout. Document the
   chosen numbers and why.
4. 4. At the call site (AppLockGate.verifyPIN, AppLockGate.swift:~100-115): evaluate
   `verifyDuress` BEFORE `verify`, so a locked-out state never reaches the duress
   branch; keep the rendered message for `.lockedOut` identical so nothing about the
   duress path is observable to an onlooker.
5. 5. Also fix the second consequence of the same overload: the duress-vs-primary
   collision check used when SETTING a duress PIN goes through the same guarded
   `verify`, so a locked-out user can be told the wrong thing when choosing a duress
   code — route that through a dedicated unguarded comparison too.
6. 6. Why permanent: the guard is re-scoped to the only question it belongs to ("is
   this a guess at the unlock code?"), so adding a fourth question to PINService in
   future cannot inherit it by accident.

*Files:* `Caelyn/Services/PINService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Main/PINViews.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`

*Tests:* No existing test covers the lockout path (CaelynTests ~:984 only tests `hash`), so
nothing breaks. Add testDuressPINIsHonouredEvenWhileLockedOut (probe below), plus
testDuressCompareIsStillRateLimited asserting the duress budget exists, and a test
that setting a duress PIN equal to the primary is refused while locked out.

#### PRIV2-03 — 11 App Lock PIN + biometrics (duress arming)

She can set a duress PIN while App Lock is switched off — and then there is no screen
anywhere in the app on which it can ever be typed. She follows the privacy page
exactly, believes she is protected, and when she is coerced Caelyn opens straight to
her history with no PIN prompt at all.

**Root cause.** Two stores with different sync domains and lifetimes, and no screen that can see both.
The duress secret lives in the device keychain (PINService.swift:116/129/141 set no
kSecAttrSynchronizable), while the only thing that creates an entry point for it is
`UserProfile.lockEnabled` (UserProfile.swift:10, default false), a CloudKit-mirrored
field. `PINManageView` (PINViews.swift:203-254) declares no @Query and no modelContext
— it is pushed as `PINManageView()` with nothing passed in (SettingsView.swift:86-88)
— so its Duress section at :228 is gated only on `PINService.isSet` and can never
consult `lockEnabled`. `AppLockGate.showLockScreen` requires `lockEnabled`
(AppLockGate.swift:79-87), so with it false the pad is never rendered on any path. The
same split means a second iPhone can sync `lockEnabled = true` with no local PIN and
no local duress secret.

**Fix.**

1. 1. Extract a pure, testable predicate
   `DuressReadiness(lockEnabled:pinSet:duressSet:)` (the way `deleteAllOffer` was
   extracted) returning the combined state: notArmed / pinOnly / armedButUnreachable /
   armed.
2. 2. Give PINManageView a `@Query` for UserProfile and
   `@Environment(\.modelContext)`; pass nothing extra at the SettingsView.swift:86-88
   push site beyond what the environment already carries.
3. 3. Render the Duress section state-aware, NOT hidden: when `armedButUnreachable`,
   show an inline notice "A duress PIN only works when App Lock is on" plus a "Turn on
   App Lock" button routed through the same validation as `lockBinding`
   (SettingsView.swift:706-718) so it cannot enable a lock with no unlock method.
4. 4. Make the Settings row detail report the combined state rather than just
   "On"/"Off".
5. 5. Make `enableParanoidMode()` (SettingsView.swift:525-558) set
   `profile.lockEnabled = true` when a PIN exists — today it can arm the privacy
   posture without the lock.
6. 6. Make PrivacyTrustView's duress answer (:102-105) conditional on `lockEnabled`,
   mirroring the `hasCloudCopy` conditional already used at :91-93 and :110-112.
7. 7. Cover the cross-device case the same predicate exposes: on a device where
   `lockEnabled` synced true but no local PIN exists, surface the unreachable state
   instead of silently failing open (see the LC-18 item for the fail-open notice).
8. 8. Why permanent: the invariant becomes one named predicate that every surface
   renders from, instead of three screens each gating on whichever half of the state
   they happen to hold.

*Files:* `Caelyn/Views/Main/PINViews.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`, `Caelyn/Models/UserProfile.swift`

*Tests:* None existing. Add DuressReadinessTests over the pure predicate covering all four
states, plus a test that enableParanoidMode sets lockEnabled when a PIN is set. Add a
UI assertion that setting a duress PIN with App Lock off surfaces the notice.

#### SYNC-06 — Cloud deletion / duress wipe / auto-sweep

The two wipes that are supposed to protect her quietly destroy data she never meant to
touch: an auto-erase on a lost phone, or a duress PIN entered under coercion, deletes
her history from her iPad and her iCloud copy too — the backups the feature exists to
leave intact.

**Root cause.** SecureWipeService.Scope was never capable of making the row deletion local for ANY
caller. At SecureWipeService.swift:78-86, scope gates exactly one thing — whether
CloudDataDeletion.deleteCloudCopy() runs (:79-81). The SwiftData deletion at :84-86 is
unconditional and runs against Persistence.live's context, which is mirrored or not by
a decision made at launch (Persistence.swift:101-121) and unchangeable for the
process. So .thisDevice is not a narrower wipe; it is the same local write minus the
explicit zone deletion, and on a mirrored store those row deletions export to iCloud
and import on every other device. The service's own docs say the scope is unsafe on a
mirrored container and the UI withholds it for that reason
(SecureWipeService.swift:27-30, 36-50; SettingsView.swift:185-199) — but the two
silent callers, AppLockGate.verifyPIN(.duress) (AppLockGate.swift:103-110) and
AutoSweepService.checkAndSweep (AutoSweepService.swift:22-29), take the default scope
and bypass the rule. Separately the wipe leaves mayExistKey, syncConsentKey and
deletedAtKey in place (SecureWipeService.swift:106-134).

**Fix.**

1. 1. Make the scope honest about the mirror. Either (a) require every caller to pass
   scope explicitly (remove the default at SecureWipeService.swift:74-77) so the
   compiler forces all three call sites to state intent, or (b) better, add a third
   scope that is actually local: when Persistence.isSyncActive is true and the caller
   asks for a device-only wipe, the only truthful options are 'wipe local + cloud' or
   'wipe local knowing it propagates' — surface that choice in code and in copy rather
   than implying a narrowing the storage layer cannot provide.
2. 2. Duress path (AppLockGate.swift:103-110): on a mirrored store, a duress wipe that
   silently empties her other devices is worse than the threat it defends against.
   Decide and encode one policy — recommended: duress wipes local AND cloud (scope
   .thisDeviceAndCloud) so the outcome matches what actually happens, and update
   PrivacyTrustView copy to say so before shipping.
3. 3. Auto-sweep path (AutoSweepService.swift:27): same explicit scope decision; this
   one must land together with SYNC2-03 (device-local activity clock), because a
   device-local clock makes the sweep reliably reachable on second devices and
   therefore makes any propagating wipe far more likely to fire.
4. 4. Do NOT clear mayExistKey on a device-only wipe. CloudDataDeletion.swift:45-54
   documents why: the flag is the only affordance that can later remove a zone when
   sync is off, and clearing it (AccountView.swift:357-362 drives showCloudCopyCard
   from it) would leave her no route to delete the cloud copy at all. Clear
   deletedAtKey and syncConsentKey only where a cloud deletion actually ran.
5. 5. Reconcile the duress cover story with the cloud-copy UI: if a flag must survive
   the wipe for correctness, the 'brand-new app' copy on PrivacyTrustView must be
   narrowed to what is true.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`

*Tests:* DeletionModelTests: add 'duress wipe leaves no misleading cloud-presence state',
'auto-sweep passes an explicit scope', and a test that a device-only wipe on a
mirrored container is refused or escalated.
testALocalOnlyWipeClearsEveryRowAndAttemptsNoCloudDeletion stays as-is. Compile-time:
all three callers must be updated once the default is removed.

#### SYNC2-01 — 26 Private iCloud sync

After the next update, a woman who turned on iCloud sync so her history would reach a
new phone may have nothing uploading at all — every screen still tells her she is
backed up. She finds out on the new phone, when it is empty.

**Root cause.** Two mechanisms compound. (1) CycleEntry.dayKey (Caelyn/Models/CycleEntry.swift:25) was
added after the shipped 1.3/build-15 commit (37dddd7; `git show
824ca9b:Caelyn/Models/CycleEntry.swift` has no dayKey). A new stored property on a
CloudKit-mirrored @Model becomes a new field CD_dayKey on CD_CycleEntry. The
Development CloudKit environment auto-creates missing fields; Production does not — an
App Store build exports against a frozen Production schema and every record export is
rejected. (2) Persistence.isSyncActive (Caelyn/Services/Persistence.swift:103-122) is
latched once from ModelContainer(for:configurations:) returning non-nil on the
.private configuration. That proves only that a local store opened with mirroring
configured; it validates nothing about the remote schema and no export outcome ever
reaches it. Nothing anywhere subscribes to
NSPersistentCloudKitContainer.eventChangedNotification, so there is no sync-error
state in the app at all — the status surfaces (SettingsView.swift:480,
iCloudSyncView.swift:45-49) report setup, not uploads.

**Fix.**

1. 1. BEFORE any build carrying dayKey ships: deploy the CloudKit schema to Production
   from the CloudKit Dashboard (Development -> Production) so CD_dayKey exists on
   CD_CycleEntry. This is additive and safe for existing records (they return with the
   field absent, which SwiftData reads as the default). Record it in
   docs/LAUNCH_CHECKLIST.md:38 as a release gate, not a note.
2. 2. Add a committed schema manifest test: a checked-in list of every stored property
   on every mirrored @Model, and a unit test that enumerates the live models via
   reflection and fails when a property exists that is not in the manifest. Updating
   the manifest is then a deliberate act that forces the reviewer to ask 'has this
   been deployed to Production?'. Put it next to
   CloudSyncSafetyTests.testEveryStoredPropertyCanSurviveACloudRoundTrip.
3. 3. THE MECHANISM FIX — make sync status reflect exports, not setup. Where the
   mirrored container is created (Persistence.swift:109-121), subscribe to
   NSPersistentCloudKitContainer.eventChangedNotification and record the last .export
   event's succeeded / error / endDate into a device-local value (never mirrored,
   never synced).
4. 4. Replace the latched Bool isSyncActive with a three-state read: configured /
   confirmed-uploading (an export succeeded) / configured-but-failing-since-<date>.
   Change SettingsView.swift:480, iCloudSyncView.swift:45-49 and
   CloudSyncCoordinator's availability read to render the failing state as a visible,
   honest banner ('iCloud has not accepted an update since <date>'), never as 'Backed
   up'.
5. 5. Keep local-first intact: a failing export must not block, delay or alter any
   local write. The new state is display-only.

*Files:* `Caelyn/Models/CycleEntry.swift`, `Caelyn/Services/Persistence.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/iCloudSyncView.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `docs/LAUNCH_CHECKLIST.md`, `docs/ICLOUD_ARCHITECTURE.md`, `CaelynTests/CloudSyncSafetyTests.swift`

*Tests:* New: committed-schema manifest test (fails when a mirrored @Model gains an undeployed
property). New: export-event state machine test driving a synthetic succeeded/failed
event and asserting the three-state status. No existing test changes.

#### SYNC2-02 — 38 Backup status / secure wipe

If the app ever failed to open its database, it quietly kept a complete copy of her
entire history in a file on the phone. Nothing reads it, nothing shows it, and 'Delete
all data', the duress PIN and auto-erase all leave it behind — so a phone that looks
wiped still holds everything.

**Root cause.** preserveStoreAside (Persistence.swift:165-180) renames default.store plus -shm/-wal to
default.store.corrupt-<timestamp> on an open failure, and the app opens a fresh empty
store. That file is a full readable SQLite copy of every CycleEntry and the
UserProfile. It is unreachable by construction: both Persistence.defaultStoreURL()
(:159) and preserveStoreAside (:167) are private static and the filename is composed
inline at :175 from a runtime timestamp, so no other type can name the location. The
structural defect is the asymmetry: preserveStoreAside is a creator of a health-data
location running on a failure path, while SecureWipeService.wipeEverything is a
destroyer that enumerates six locations by hand (SecureWipeService.swift:83-134) and
never touches FileManager. No shared declaration of 'where Caelyn's data lives'
exists, so creator and destroyer can never agree.

**Fix.**

1. 1. Introduce one declared enumeration of preserved stores: `static func
   preservedStoreURLs(in directory: URL? = nil) -> [URL]` on Persistence, globbing
   default.store.corrupt-* (plus -shm/-wal) via contentsOfDirectory, defaulting to
   Application Support. Make the directory injectable — defaultStoreURL() is private
   and app-support-bound, so without injection the new wipe step is untestable, and
   this finding is exactly about an untested location.
2. 2. Consume it in SecureWipeService.wipeEverything: after the six existing
   locations, remove every URL returned by preservedStoreURLs(). This runs on all wipe
   paths, including duress and auto-sweep.
3. 3. Surface the file's existence while it exists: the storage/corruption banner
   (Persistence.swift:134-144, RootView) should state plainly that a previous copy is
   being held and offer 'Remove it' as the headline action.
4. 4. Do NOT ship 'Recover' as the headline action. The preserved file is by
   definition one SwiftData could not open; a second read-only open attempt will
   usually fail again. If a recovery affordance ships, it is secondary, best-effort,
   and must not block the removal path.
5. 5. Ship the removal and the affordance in the same release so a user currently
   holding a preserved store is not silently deprived of a copy she was never told
   about.
6. 6. Add a regression rule: any future code that writes app data to a new filesystem
   location must register it in the same enumeration (document it at the top of
   SecureWipeService).

*Files:* `Caelyn/Services/Persistence.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/AutoSweepService.swift`, `CaelynTests/DeletionModelTests.swift`

*Tests:* New: testASecureWipeLeavesNoPreservedStoreBehind (probe). Existing DeletionModelTests
wipe tests (testALocalOnlyWipeClearsEveryRowAndAttemptsNoCloudDeletion,
testDeletingBothAttemptsTheCloudAndClearsLocal) continue to pass unchanged — they
assert row counts, not files.

#### SYNC2-03 — Auto-erase if inactive

Turning on iCloud sync silently switches off 'Auto-erase if inactive' on every other
device. She loses her phone, keeps using her iPad, and the phone never erases itself —
because using the iPad counts as using the phone.

**Root cause.** lastActiveAt is an ordinary stored property on the CloudKit-mirrored UserProfile
(UserProfile.swift:77-80; the schema is mirrored at Persistence.swift:103-108), so a
per-device liveness clock is stored in shared state. AppLockGate stamps it on launch
and foreground (AppLockGate.swift:55, :71) and AutoSweepService.checkAndSweep compares
it to now (AutoSweepService.swift:22-36). With sync on there is one profile row across
devices, so the phone's stamp reaches the iPad — and ProfileStore.merge reinforces it
with `dst.lastActiveAt = max(dst.lastActiveAt, src.lastActiveAt)`
(ProfileStore.swift:101). max() is the right rule for a preference and the wrong rule
for a clock: the most recent activity on ANY device always wins, so an untouched
device never reaches its window.

**Fix.**

1. 1. Move the clock to device-local storage: UserDefaults.standard key
   `caelyn.lastActiveAt`, seeded once from profile.lastActiveAt so an upgrading
   single-device user's window is not reset. Leave autoWipeEnabled and
   autoWipeAfterDays on the profile — those ARE preferences and should sync.
2. 2. Leave the UserProfile.lastActiveAt attribute in place (removing a mirrored
   attribute is a non-additive CloudKit change Production would refuse). Mark it
   deprecated/unused and stop writing it from AppLockGate.swift:55, :71.
3. 3. Delete the max() merge line at ProfileStore.swift:101, or keep it harmlessly for
   the now-dead field — but the live clock must not pass through merge.
4. 4. Change AutoSweepService.checkAndSweep to take the timestamp as a parameter
   rather than reading it off the profile, so it stays purely testable.
5. 5. LAND WITH THE SWEEP-SCOPE DECISION (SYNC-06). A device-local clock makes an
   infrequently-opened second device reliably reach its window and call wipeEverything
   — which on a mirrored store propagates. Shipping this alone trades a silently-
   disabled promise for silent cross-device data loss. The scope policy must be
   settled first.
6. 6. Note the launch-ordering detail that makes today's failure deterministic rather
   than racy: AppLockGate's .task (:55) fires at first render ahead of any CloudKit
   round trip, so a cold launch would read the stale local value and correctly fire —
   it does not, because the synced value has already been merged into the single
   shared row. Add the probe below as the permanent regression guard.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/SecureWipeService.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* CaelynTests.swift:997-999 (pure shouldSweep) unaffected. checkAndSweep's signature
changes, so caller tests must pass the timestamp. New:
testAnotherDevicesActivityCannotPostponeThisDevicesAutoErase (probe). Add a
ProfileStore test that lastActiveAt is no longer merged.

#### T2-01, SYNC-02, SYNC-12 — 8 Local-first storage / 26 Private iCloud sync

The single launch that upgrades her from the App Store version decides — from whatever
time zone her phone happens to be in that morning — which calendar day every entry she
has ever logged belongs to, and in the same breath overwrites the original timestamps,
so if it guesses wrong her entire history slides one day earlier, permanently, with
the evidence gone. After that the same code keeps re-stamping those timestamps on
every sync pass, so a phone abroad and an iPad at home hand the same day back and
forth forever, each re-uploading it, and the date shown for a row flips depending on
which device touched it last.

**Root cause.** CycleStore.dedupeSameDay treats two different things as derivable from ambient
Calendar.current inside one loop (CycleStore.swift:35-53). (a) dayKey is a write-once
identity (guarded by `if entry.dayKey == 0`, :38) but is derived from
`Calendar.current` at :39, so the one launch that happens to run the backfill
permanently decides the answer; on every later launch dayKey != 0 and the row is never
re-keyed. (b) The keeper branch unconditionally re-derives the stored, CloudKit-
mirrored `date` from (dayKey x the READING device's calendar) at :48-50. Because the
store is mirrored, that is not a local normalisation — it is a broadcast of this
device's calendar onto a row another device owns, and it is also what erases the
original instant that is the only input capable of repairing (a) afterwards. Every
write path files `date` as the writer's local midnight (CycleEntry.swift:73,
CycleStore.swift:77) and CloudSyncCoordinator re-runs the pass on every remote arrival
(CloudSyncCoordinator.swift:61-83), which closes the ping-pong loop.

**Fix.**

1. 1. Split dedupeSameDay into two sequential passes over the fetched rows: pass A
   backfills dayKey for every row with dayKey == 0; pass B groups by dayKey, merges
   duplicates and keeps the keeper. Today the keeper branch rewrites `date` (:48-50)
   in the same iteration in which other rows are still being keyed from `date` (:39),
   so the key a later row gets depends on how far the loop has already got.
2. 2. In pass A, derive the legacy key from the stored instant itself, never from
   Calendar.current. Every 1.3 write path stored local midnight in the writer's zone,
   so scan UTC offsets from -12:00 to +14:00 in 15-minute steps and take the offset
   for which `date` is exactly start-of-day; if several match, prefer the one nearest
   the device's current offset; if none match (the row was never midnight-normalised)
   fall back to `CivilDay.key(for: entry.date, calendar: calendar)` as today. Document
   it honestly as 'the civil day this instant is midnight of in the zone that last
   wrote it' — for a never-travelled row that is the day she logged, for a row 1.3
   already re-normalised abroad it is the day 1.3 last showed her. Both are stable in
   every time zone, which is the whole point.
3. 3. Delete the `date` rewrite at CycleStore.swift:48-50 outright. `date` becomes
   what its own doc comment says it is — the instant, for formatters, exports, charts
   and HealthKit — and dayKey/`day` becomes the sole day identity. This is the
   permanent half: no device can impose its calendar on a row another device wrote, so
   the cross-zone ping-pong cannot exist regardless of time zones or app versions.
4. 4. Reconsider the matching stamp in `entry(for:)` at CycleStore.swift:76-77. There
   the key was just computed from the same calendar so it is self-consistent, but
   leaving it means a write path still files `date` as a derived value; prefer storing
   the real instant and keeping only `created.dayKey = key`.
5. 5. Step 3 cannot land until every day-reader is keyed to `day`/`dayKey` — grep
   every `\.date` use on CycleEntry across app, widget, watch and export (about 18
   sites) and convert each, leaving `.date` only where a timestamp is genuinely wanted
   (HealthKit sample dates, 'last updated' formatting). Deleting :48-50 with any day-
   reader still on `.date` reintroduces the timezone day-shift fixed in
   37dddd7/9776951 for exactly that reader.
6. 6. Sequencing is the whole migration: the corrected backfill MUST ship in the same
   build that first introduces dayKey. Once a user's launch has run the current
   backfill and the current `date` rewrite, the original instant is gone and no later
   release can tell a mis-keyed row from a correct one. Add a one-time
   `caelyn.dayKeyBackfillV2` marker so a corrected pass can re-run for anyone who
   upgraded on a TestFlight build with the old code, with the caveat that it can only
   repair rows whose `date` was not already rewritten.
7. 7. Add a fixed-point assertion to the pass: running dedupeSameDay twice, the second
   time under a different calendar, must change nothing.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/Models/CivilDay.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Views/RootView.swift`

*Tests:* CivilDayTests.testTheLaunchPassBackfillsOldRowsToTheDayTheyAlreadyShow
(CivilDayTests.swift:158-177) writes and backfills inside one travel(to:) block and
cannot see this — add a case that writes in Tokyo and backfills under a New York
calendar. CloudMigrationConflictTests.testMergingDoesNotShiftADayAcrossTimeZones
asserts startOfDay(after.date) in the test calendar — rewrite to assert
after.day/dayKey. UpgradeAndDeviceMatrixTests date-stability cases likewise. New:
idempotence/fixed-point test (two passes, two calendars, no change); new: a row
written in Tokyo and imported under a New York calendar keeps dayKey 20260601.

#### watch:W-03 — Watch companion / Secure wipe (SecureWipeService.wipeEverything step 4)

She taps "Delete all data" on her iPhone and everything really does go from the phone
— but her Apple Watch keeps showing her cycle day, her phase and whether she is
fertile. If the watch app is open it just keeps displaying it; even after the watch is
restarted the system has kept its own copy of the last thing the phone sent, so the
data can come back. Someone holding her watch can read what she believes she deleted.

**Root cause.** The wipe has no channel that can say "nothing". SecureWipeService step 4 reaches only
the phone's own App Group — WidgetDataStore.clear() +
WidgetCenter.reloadAllTimelines() (SecureWipeService.swift:94-96, verified: no
WCSession/Watch reference anywhere in that file) — and WatchBridgeService exposes
exactly one sender, pushSnapshot, which always carries a snapshot and returns early
unless a snapshot encodes (WatchBridgeService.swift:20-26). On the watch side
WatchDataModel acts only on a present, decodable ["snapshot"] key and leaves
self.snapshot untouched otherwise (WatchDataModel.swift:60-72), so an absent message
is indistinguishable from no message. The only thing that could ever push an empty
snapshot is WidgetDataSync.sync(), which is bound to the phone's scene lifecycle and
is additionally Pro-gated (WidgetDataSync.swift:125-141) — and the profile row it
would read has just been deleted. The surviving copy is WCSession's system-persisted
receivedApplicationContext, which no code clears.

**Fix.**

1. 1. Add `func pushCleared()` to WatchBridgeService
   (Caelyn/Services/WatchBridgeService.swift, beside pushSnapshot at :20-26): `guard
   WCSession.isSupported(), WCSession.default.activationState == .activated else {
   return }; try? WCSession.default.updateApplicationContext(["cleared": true])`. Gate
   ONLY on activationState — not on isPro and not on isWatchAppInstalled
   (pushSnapshot's :23 guard), because a wipe must reach a watch whose install state
   the phone may misreport.
2. 2. In WatchDataModel's two receivers (CaelynWatch/WatchDataModel.swift:60-65 and
   :67-72), treat a context carrying `cleared == true`, OR a context with no decodable
   ["snapshot"] Data, as an explicit clear: set `self.snapshot = nil` and call
   `WidgetDataStore.clear()` so the watch's own App Group copy (written once
   watch:W-01 lands) goes too. Today the else-branch is silently a no-op; that is the
   half that makes the stale value survive.
3. 3. Call `WatchBridgeService.shared.pushCleared()` from SecureWipeService step 4,
   immediately after `WidgetDataStore.clear()`
   (Caelyn/Services/SecureWipeService.swift:95), inside the same await-able step so
   the wipe does not return before the context is handed to WCSession.
4. 4. Move the Pro decision out of the transport (shared with watch:W-06):
   WidgetDataSync.swift:139-141 skips the watch entirely for non-Pro, so a lapsed
   subscriber's wrist is frozen on her last Pro snapshot with nothing able to
   overwrite it. The free/lapsed path must push a snapshot with isPro=false, never
   push nothing.
5. 5. Inject a `WatchBridging` protocol into SecureWipeService (one method:
   pushCleared()) so the wipe's contract is assertable without WCSession.
6. 6. Update docs/DEVICE_TEST_SCRIPT.md H5 so the empty state after a wipe is an
   asserted outcome rather than something that passes by accident on today's watch
   amnesia.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/WatchBridgeService.swift`, `CaelynWatch/WatchDataModel.swift`, `Caelyn/Services/WidgetDataSync.swift`, `docs/DEVICE_TEST_SCRIPT.md`

*Tests:* New: SecureWipeServiceTests with an injected WatchBridging spy asserting pushCleared()
is invoked exactly once during wipeEverything, and that it is invoked even when isPro
is false. New watch-side (or extracted-pure) test: a context dictionary with
cleared:true, and a context with no snapshot key, both drive snapshot to nil. Device
probe below is the only end-to-end proof (WCSession cannot run under XCTest).

---

### P1 (100)

#### ACC-02 — 24 Optional Sign in with Apple — AccountOfferSheet (the post-onboarding offer)

The 'Make Caelyn yours' sheet promises two things — Caelyn can use your name, and
'your history follows you: a private copy in your own iCloud means a new iPhone picks
up where you left off' — and then gives her exactly one button: Sign in with Apple.
Signing in does not turn iCloud sync on. She believes her history is backed up, loses
or replaces her phone months later, and nothing followed her.

**Root cause.** Each promise on the sheet has no affirmative control of its own. The copy describes
two independent features (AccountOfferSheet.swift:40 'do both, one, or neither';
:52-56 the iCloud card), but the only affirmative control is the Sign in with Apple
overlay button (:60-82), whose handler signIn() (:123-150) touches only AccountSession
and the preferred name. The sync preference lives in UserDefaults, is read exactly
once inside the container builder (Persistence.swift:103-124), and is written only by
AccountView.setSync (:257-272) and the two stand-down paths in CloudDataDeletion. The
offer sheet never reads or writes Persistence.syncEnabledKey at all — this is
precisely the failure Persistence.swift:80-84 names as 'the one lie a privacy-first
app can never ship'.

**Fix.**

1. 1. Give the iCloud promise its own affirmative control on the sheet — a second
   button or a toggle in the iCloud card — so one button can no longer stand for two
   promises.
2. 2. Do NOT reuse AccountView.setSync's enable path verbatim. setSync calls
   CloudDataDeletion.recordSyncConsentAndLiftTombstone() (AccountView.swift:264 →
   CloudDataDeletion.swift:175-179), whose CloudDeletionTombstone.clear() DELETES a
   record in her private CloudKit default zone (CloudDeletionTombstone.swift:117-124)
   that every other device reads at launch to stand its own sync down. Lifting it from
   a post-onboarding sheet on a fresh device would silently re-enable sync on devices
   where she had deliberately deleted the cloud copy.
3. 3. Split the extraction instead: `enableSyncPreference()` (writes
   Persistence.syncEnabledKey + recordSyncConsent) separate from `liftTombstone()`.
   The offer sheet calls only the former; AccountView keeps calling both, because
   there she is looking at a screen that tells her what the tombstone is.
4. 4. If a tombstone exists when she opts in from the offer, say so plainly in the
   sheet and route her to Account & iCloud rather than silently resolving it.
5. 5. Be honest about timing: the sync preference is read once at container build
   (Persistence.swift:103-124), so the copy must say the private iCloud copy starts at
   the next launch — not 'your history follows you' in the present tense.
6. 6. Update the footer 'You can set either of these up later in Settings' so it
   matches what the sheet actually offers.

*Files:* `Caelyn/Views/Settings/AccountOfferSheet.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Services/Persistence.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Services/Account/CloudDeletionTombstone.swift`

*Tests:* AccountOfferTests copy assertions still pass. Add: the offer's sync opt-in writes
Persistence.syncEnabledKey and records consent; it does NOT clear the tombstone. Add:
with a tombstone present, the offer shows the explanatory route instead of enabling
silently. The UI helper dismissAccountOfferIfPresent (CaelynUITests.swift:81-8x) must
be updated for the new control.

#### ACC-04 — 24 Account offer — RootView presentation latch vs AppLockGate

On the first launch after the 1.3 update, a woman with App Lock on sees the Face ID
prompt, the lock screen, and the 'Make Caelyn yours' sheet all at once. She can sign
in with Apple and set her name without ever unlocking the app. And if she is partway
through the sheet when the phone locks, the sheet stays up over the lock screen.

**Root cause.** RootView owns a presentation whose lifetime is wholly independent of the lock's
authorization state, in BOTH directions. RootView lives inside AppLockGate's ZStack
(CaelynApp.swift:31-38 → ContentView.swift:5); when locked, AppLockGate only applies
`.opacity(0)` and `.allowsHitTesting(false)` (:25-54) — a UIKit modal presented by a
child is unaffected by the presenter's opacity. (a) RAISE: `offerIsDue`
(RootView.swift:24-26) has no lock term and no way to get one, because AppLockGate's
`showLockScreen` is a private computed property (:79-87) exposed to no descendant; the
offer is raised 120 ms after launch whenever AccountOfferPolicy.isDue. (b) PERSIST:
AppLockGate re-locks on every transition out of .active (:61-69) and showLockScreen is
additionally true whenever scenePhase != .active (:86), yet nothing lowers
isOfferingAccount on lock — the latch is raise-only by design (RootView.swift:10-16).

**Fix.**

1. 1. Publish the lock state: add an EnvironmentKey `\.appIsLocked` and have
   AppLockGate set it from `showLockScreen` (AppLockGate.swift:79-87).
2. 2. Gate the raise: `offerIsDue = isLoaded && !appIsLocked &&
   AccountOfferPolicy.isDue(...)` (RootView.swift:24-26). The existing `.onChange(...,
   initial: true)` at :61-64 then fires on unlock, so the offer appears the moment she
   unlocks rather than being lost.
3. 3. Suspend without consuming on re-lock — this is the half the obvious fix omits.
   endAccountOffer() (RootView.swift:80-85) cannot be reused because it records
   hasSeenAccountOffer = true, which would permanently burn the offer. Add a separate
   `suspendAccountOffer()` that lowers isOfferingAccount WITHOUT setting the flag,
   called when appIsLocked becomes true.
4. 4. Add `isLocked:` as an explicit parameter to AccountOfferPolicy.isDue so the rule
   is unit-testable without a view host.
5. 5. Audit any other descendant presentation raised on a timer for the same shape
   (the mechanism, not the instance): a presentation raised by a child of AppLockGate
   must consult \.appIsLocked.

*Files:* `Caelyn/Views/RootView.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/App/ContentView.swift`, `Caelyn/Services/Account/AccountOfferPolicy.swift`

*Tests:* AccountOfferTests: isDue(..., isLocked: true) == false; and suspending the offer while
locked leaves hasSeenAccountOffer false so it is still due after unlock
(AccountOfferTests.swift:490-494 pins the default-false flag). UI probe needs a new
launch flag seeding an onboarded profile with lockEnabled=true, a PIN, and
hasSeenAccountOffer=false.

#### BC-01 — 36.i Predictions vs hormonal contraception

A woman who turns on Birth Control Mode and tells Caelyn she is on the pill is still
shown, every single day, when she is 'ovulating' and which are 'your most fertile
days, estimated' — on Home, on the calendar, on the year view, on her widget and on
her watch. On combined hormonal contraception she does not ovulate. It is a false
health statement, shown daily, by an app she just told the truth to.

**Root cause.** CycleModel — the single derivation every surface was refactored to read — has no
ovulation-suppression input. CycleModel.make reads only averageCycleLength /
averagePeriodLength / lastPeriodStart (CyclePrediction.swift:209-248), so
ovulationEstimate and fertileWindow (:302-314) and phase → .ovulation (:272-277 →
PredictionEngine.swift:350-367) are pure cycle arithmetic, and no consumer checks
profile.birthControlEnabled. The leak is wider than CycleModel: three surfaces bypass
it entirely and recompute ovulation from raw arithmetic — CycleRingView.swift:21
(`cycleLength - 14`), WidgetDataStore.swift:134-159 (phaseRaw/fertilityStatus) and
YearViewSection.

**Fix.**

1. 1. Add a derived predicate `var suppressesOvulation: Bool` on UserProfile:
   `birthControlEnabled && (birthControlMethod == .pill || .patch || .ring)`. Derived
   from existing fields — no new stored property, no schema change.
2. 2. Add `suppressesOvulation: Bool` to CycleModel (defaulted false) and set it in
   CycleModel.make from the profile.
3. 3. DO NOT make fertileWindow/ovulationEstimate return nil.
   CalendarMath.swift:132-134 binds predictedPeriodWindow, pmsWindow and fertileWindow
   in ONE `if let` chain — a nil fertileWindow would also delete her predicted-period
   and PMS markers. WidgetDataSync.swift:44 nests the PMS (:56-58) and period (:59-60)
   lines inside `if nextStart != nil, let fertile = cycle.fertileWindow` — nil would
   delete those from the widget too. Instead keep the values and gate every RENDERER
   on model.suppressesOvulation.
4. 4. Gate the renderers: Home headline + 'Your most fertile days, estimated.' hint
   (CyclePrediction.swift:39, HomeCopy.swift:60-61), Coming Up 'Fertile window:' event
   (HomeCopy.swift:108-117), hero legend, CycleRingView sage arc
   (CycleRingView.swift:21), Calendar .ovulation marker (CalendarMath.swift:132-134),
   Year view sage days (YearViewSection), WidgetDataSync 'Fertile window in N days'
   (WidgetDataSync.swift:44-60) and WidgetDataStore.fertilityStatus/phaseRaw
   (WidgetDataStore.swift:134-159).
5. 5. Make phase never return .ovulation when suppressed
   (PredictionEngine.swift:350-367) — fall through to the luteal/follicular label the
   arithmetic would otherwise give.
6. 6. Pass suppressesOvulation into the widget/watch snapshot so the two surfaces that
   do not read CycleModel cannot drift back.
7. 7. Leave `remindOvulation` stored but do not schedule the ovulation reminder while
   suppressed, and hide the toggle in RemindersView with a one-line explanation.
8. 8. Release-note it: users already in Birth Control Mode will see the fertile window
   disappear on the first launch after the update.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Views/Home/CycleRingView.swift`, `Caelyn/Views/Calendar/CalendarMath.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Views/Settings/RemindersView.swift`

*Tests:* New CycleModel tests: suppressed → phase never .ovulation, daysUntilOvulation nil/0.
New HomeCopy.comingUpEvents test: suppressed → no fertile-window event but the period
and PMS events survive. CalendarMath test: suppressed → no .ovulation marker but
predicted-period and PMS markers still present (this is the regression the nil
approach would have caused). WidgetDataStore.fertilityStatus test for suppressed.

#### BC-02, BC-09, BC-10 — 36.d/36.e Patch & ring start date — default, storage and method identity

A woman enables Birth Control, picks Patch, turns the reminder on, sees 'First patch
date: today' and leaves. She never gets a single patch reminder — not one, ever. The
date she saw was never actually saved, and every time she opens the app the schedule
resets to 'seven days from now'. If she later switches from patch to ring after a
doctor's visit, the screen shows 'First insertion date' over the day she first applied
a patch months ago, and her ring reminders land on the patch calendar. And a date set
near local midnight can shift by a day when she flies or when the clocks change.

**Root cause.** birthControlStartDate is an under-specified anchor in three separate ways. (a) NOT
PERSISTED ON ACCEPT: the picker displays `profile.birthControlStartDate ?? .now`
(BirthControlView.swift:95) but writes nothing unless she moves the wheel, and the
scheduler substitutes `profile.birthControlStartDate ?? today`
(NotificationService.swift:257) — so cycle day is `today - today = 0` on every sync,
the first candidate offset is always +7 (patch) or +21 (ring) from a moving today, and
since sync opens with cancelAll() (:166) and every foreground re-enters it
(CaelynApp.swift:71-74), the one pending reminder is pushed out again on each app
open. (b) NOT A CIVIL DAY: the picker stores an instant carrying the time-of-day of
.now, and the scheduler re-truncates it with the read-time Calendar.current on every
sync (:275, :300) — instant + read-time truncation is not a stored day, so a UTC-
offset change moves which day the anchor names. Related: `patchDays % 28` is not sign-
normalised, so a start date ahead of today yields -1 % 28 == -1 and candidates
[8,15,22,29]. (c) NOT TIED TO A METHOD: the date's meaning ('first patch applied' vs
'first ring inserted') is supplied entirely by birthControlMethod, and nothing keeps
them together — the picker's setter writes only the method
(BirthControlView.swift:45-48), and ProfileStore.merge resolves the method by recency
(:91-99) but the date by nil-ness (:87), so they can even arrive from different
devices.

**Fix.**

1. 1. Add two additive, defaulted properties to UserProfile: `var
   birthControlStartDayKey: Int = 0` and `var birthControlStartDateMethod:
   BirthControlMethod? = nil`. Both additive-with-default, same pattern as
   hkReadFertility (UserProfile.swift:19-23) — no schema version bump, CloudKit
   mirrors them, 1.3 devices ignore them.
2. 2. Persist the anchor the moment it is shown as accepted: when BirthControlView
   appears with method patch/ring, enabled, and a nil start date, write today's date +
   `CivilDay.key(for: today)` + the current method and save. The user sees today and
   today is what is stored.
3. 3. Writers set all three together: Date (display/back-compat, keeps
   ProfileStore.swift:87 merging), dayKey via CivilDay.key(for:) in the calendar she
   chose it in, and the method tag. Lazy backfill: when key == 0 and the Date is non-
   nil, derive the key once and save.
4. 4. sync() uses `CivilDay.days(from: startKey, to: CivilDay.key(for: today,
   calendar: cal))` instead of startOfDay arithmetic (NotificationService.swift:275,
   :300). This also removes the negative-modulo path, since the anchor is never in the
   future once it is persisted on accept.
5. 5. Remove the `?? today` fallback — but only AFTER step 2, or existing 1.3/build-15
   patch/ring users with a nil field get silence instead of wrong-silence. Scope the
   nil guard to patch/ring only (pill legitimately needs no anchor), and hoist it
   ABOVE the switch using `break`, not `return`: a bare `return` inside the case exits
   sync() entirely and is a landmine for any block appended after the birth-control
   block at :255-323.
6. 6. Method identity: when she changes the method to patch or ring and
   `birthControlStartDateMethod != newMethod`, do NOT silently rewrite the date (that
   destroys a correct anchor for someone who taps ring to read the blurb and taps
   back). Instead treat the anchor as unset for the new method, show the picker seeded
   to today, and persist on accept per step 2. Apply the same invariant in
   ProfileStore.merge: carry birthControlStartDate, its dayKey and its method tag as
   ONE unit from the same row.
7. 7. BirthControlView must label the field from `birthControlStartDateMethod`, not
   from the live method, until the new anchor is accepted.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Settings/BirthControlView.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Models/CivilDay.swift`

*Tests:* After extracting the pure schedule function (see the BC-05/06/07 item), add: nil
anchor → empty plan; anchor accepted today → first patch event at +7 and it does NOT
move when 'today' advances; an anchor key written with a Tokyo calendar and read with
a New York calendar produces identical offsets; an anchor ahead of today produces no
negative offsets. UpgradeAndDeviceMatrixTests profile-only upgrade should assert the
two new fields' defaults round-trip. ProfileStoreTests: date + dayKey + method tag
survive dedupe as a unit.

#### BC-03 — 36.c/36.e Birth-control reminder time vs quiet hours

She sets her pill reminder for 10:30 PM — the most common time to take it, right
before bed. Every reminder arrives at 7:00 the next morning instead, eight and a half
hours late, and the screen where she set the time never says so. A 6:30 AM pre-work
pill becomes 7:00 AM. For patch and ring, an evening reminder time slides the whole
change-day reminder to the day after.

**Root cause.** Quiet hours are enforced inside the shared primitive with no per-category opt-out:
scheduledFireDate(on:hour:minute:) always passes the chosen time through
shiftOutOfQuietHours (NotificationService.swift:392-397 → 400-411), which moves
22:xx/23:xx to 07:00 the NEXT day and 00:00-06:59 to 07:00 the same day. A policy
written for passive check-ins is being applied to a time-critical, user-chosen dose.
All three birth-control branches use it (:262-266, :289, :312). Second half of the
mechanism: BirthControlView's reminder section (:58-88) was written without the
quietHoursNote helper RemindersView gives all four of its pickers
(RemindersView.swift:55,71,89,104 → 255-270), so the shift is also undisclosed. The
codebase is internally contradictory here — the same branch already sets
interruptionLevel .timeSensitive (:270, :293, :316), i.e. 'allowed to pierce Focus',
while quiet hours silently defer it.

**Fix.**

1. 1. Add `respectsQuietHours: Bool = true` to scheduledFireDate(on:hour:minute:)
   (NotificationService.swift:392-397); when false, skip shiftOutOfQuietHours
   entirely.
2. 2. Pass `respectsQuietHours: false` for .birthControl (all three method branches)
   and for .medication. Leave every other category on the default, so no existing
   behaviour changes.
3. 3. Put the justification in a code comment next to the exemption: these are user-
   chosen dose times already classified .timeSensitive; deferring them defeats the
   reminder's only purpose.
4. 4. Add the quiet-hours footer to BirthControlView's reminder section, derived from
   the SAME quietHoursStart/End constants (:54-57) rather than hard-coded text — so a
   future change to the constants cannot make the copy lie. Since the exemption means
   no shift now, the footer should instead state that birth-control reminders are
   delivered at the chosen time even during quiet hours.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Settings/BirthControlView.swift`, `Caelyn/Views/Settings/RemindersView.swift`

*Tests:* No existing test covers scheduledFireDate/shiftOutOfQuietHours (grep). Add both
parameter values: respectsQuietHours true at 22:30 → 07:00 next day (pins current
behaviour for check-ins); false at 22:30 → 22:30 same day. Crucially also assert a
PATCH change-day with a 22:30 reminder time lands on the checkpoint day itself, not
checkpoint+1 — the day-late patch/ring slip is the sharpest harm and would otherwise
regress unnoticed. The priv-5 notification-leak test is unaffected.

#### BC-04 — 36.c Birth-control reminder toggle → notification permission

She said 'No reminders for now' during setup — which is exactly the person whose first
real reminder is her pill. Later she goes to Settings → Birth Control → Pill → turns
the reminder on → sets 8:00 PM. The switch reads on, the Settings row says '1 on', and
iOS never asks her for permission, so no notification ever arrives and nothing
explains why. The same silence applies if she declined the iOS prompt anywhere else.

**Root cause.** The notification-permission flow was never factored into a component; it is hand-
rolled inline in whichever screen happens to own a reminder toggle. RemindersView
holds it as four separate private members (@State authStatus :29, .task
refreshAuthStatus :113, handleToggle(turningOn:) :309-317, deniedBanner :182-203);
DailyLogForm re-implements a cut-down version (resyncReminders(requestPermission:)
:866-870 — request only, no status, no banner). BirthControlView was written as a pure
profile-field form (:58-88, save → syncFromLiveStore at :142-145) with none of it, and
NotificationService.sync fails silently by design — `guard authorizationStatus() ==
.authorized else { return }` (:168) returns Void, so a caller cannot tell 'scheduled'
from 'not allowed'.

**Fix.**

1. 1. Make sync honest first and let it drive the UI: `@discardableResult static func
   sync(...) async -> SyncOutcome` with `enum SyncOutcome { case scheduled(Int),
   notAuthorized, nothingToSchedule }`; replace the bare `return` at :168 with
   `.notAuthorized`, same at :352, and have syncFromLiveStore (:327-345) forward it.
   @discardableResult keeps all existing call sites compiling unchanged
   (CaelynApp.swift:74, HomeView.swift:460, SettingsView.swift:758,
   RemindersView.swift:154/304/316) — purely additive.
2. 2. Extract the permission UX into one reusable piece — a `ReminderPermissionGate`
   view modifier or small @Observable helper — holding authStatus, the request-on-
   first-enable behaviour, and the denied banner with 'Open iOS Settings'. Replace
   RemindersView's four inline members with it so there is exactly one implementation.
3. 3. Apply the gate to BirthControlView's reminder toggle: on turning on with
   .notDetermined, call NotificationService.requestAuthorization(); with .denied, show
   the banner instead of pretending the toggle took effect.
4. 4. Apply it to DailyLogForm's resyncReminders path too, so the third hand-rolled
   copy disappears.
5. 5. PERMANENCE: any future screen that owns a reminder toggle gets the gate by using
   the modifier; nothing else can produce a silently-on switch.

*Files:* `Caelyn/Views/Settings/BirthControlView.swift`, `Caelyn/Views/Settings/RemindersView.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`

*Tests:* Unit: sync returns .notAuthorized when the status is not authorized and .scheduled(n)
otherwise. UI: CaelynUITests.swift:553-569 currently toggles Birth Control Mode but
not the reminder — add a step that toggles the reminder and asserts either the
permission alert or the denied banner appears under the hermetic store.

#### BC-05, BC-06, BC-07 — 36.e Birth-control reminder scheduling horizon (pill / patch / ring)

The birth-control reminders quietly stop. A pill user who does not open Caelyn for a
week gets nothing from day eight onwards. A patch user receives at most one of her
four monthly change reminders unless she opens the app every week. A ring user can be
reminded to remove the ring and never reminded to put the new one in — the reminder
that restarts her contraception. Worst of all, opening the app on the morning the new
patch or ring is due deletes that day's reminder outright.

**Root cause.** The scheduler is a pull-based single-slot chain, not a plan. (a) Each sync opens with
`cancelAll()` (NotificationService.swift:165-166), so a sync is a complete
replacement, not an addition. (b) Every request is `repeats: false` (scheduleOneShot,
:413-425) — grep finds no `repeats: true` anywhere in the app — and the only resync
triggers are scenePhase == .active (CaelynApp.swift:71-74) and six in-app actions;
Info.plist:37-40 declares only remote-notification, there is no BGTaskScheduler. So
the horizon is literally 'until she next opens the app'. (c) Patch and ring `break`
after the first successful schedule (:297, :320), by design ('next event only',
comment at :277-278), so only ONE .birthControl request is ever pending for them. (d)
The wrap day is unrepresentable: cycle day is reduced to 0...27 by `% 28` (:276, :301)
while the event list is written in 1...28 ([7,14,21,28] at :281; [21,28] at :304), so
on day 28 ≡ 0 the wrap event evaluates as 28-0 = 28 instead of 0 and there is no same-
day candidate — combined with (a), a sync that morning cancels the correct reminder
and replaces it with one a week or three weeks later. (e) Pill schedules 7 dated one-
shots (0..<scheduleHorizonDays, :52, :259-273), a horizon written for passive check-
ins and reused for a contraceptive dose.

**Fix.**

1. 1. Extract the arithmetic into a pure, testable function:
   `BirthControlSchedule.events(method:startDayKey:todayKey:horizonDays:) -> [(dayKey:
   Int, event: BirthControlEvent)]`. sync() only submits what it returns. This is what
   makes every fix below permanent — the decision becomes data, testable without a
   notification centre.
2. 2. Express events as day-in-cycle in 0..<28 and compute `offset = (eventDay -
   cycleDay + 28) % 28` (+ 28k for further cycles). Patch: 0 = apply new patch, 7/14 =
   change, 21 = patch-free week. Ring: 0 = insert, 21 = remove. This removes the wrap-
   day hole structurally.
3. 3. Suppress the offset-0 apply/insert event when the anchor IS today (patchDays ==
   0 / ringDays == 0) — that event already happened when she set the date.
4. 4. Delete the `break` at :297 and :320 and schedule EVERY event in a horizon of at
   least two full cycles (patch ≈ 8 events, ring ≈ 4). iOS allows 64 pending requests
   and the app uses far fewer, so there is ample headroom. `scheduledFireDate` already
   returns nil for a past time (:396), so today's already-passed event needs no extra
   guard.
5. 5. Pill: replace the 7 dated one-shots with ONE repeating
   UNCalendarNotificationTrigger (hour+minute, repeats: true), id
   `caelyn.birthcontrol.daily`. Verified compatible: cancelAll() filters by
   `id.hasPrefix(category.rawValue)` (:171-178) so the id is purged by the existing
   cancel path — which also purges the stale dated `caelyn.birthcontrol.<yyyyMMdd>`
   requests left queued on upgrading 1.3 devices on the first foreground; and
   category(from:) matches by prefix (:124-130) so taps still route to .birthControl.
6. 6. Depends on the anchor item (BC-02/BC-09/BC-10): the plan function takes a start
   DAY KEY, so the anchor must be persisted and keyed first.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/BirthControlSchedule.swift (new)`, `Caelyn/Views/Settings/BirthControlView.swift`, `Caelyn/Info.plist`

*Tests:* New BirthControlScheduleTests (pure, no notification centre): patch from day 0 yields
[7 change, 14 change, 21 patch-free, 28 apply, 35 change, …]; ring from day 0 yields
[21 remove, 28 insert, 49 remove, 56 insert]; from day 28 ≡ 0 before the reminder hour
the plan INCLUDES an offset-0 event; pill yields one repeating spec, not seven dated
ones. Add an upgrade test that the stale dated ids are cancelled by prefix.

#### BC-12, ACC-18 — 36.e NotificationService.syncFromLiveStore + CaelynApp.reconcileAppleCredential — profile selection in the service layer

In the window after a second device finishes setting up (or after a restore), there
can briefly be two profile rows. The screens all edit the older one; the reminder
scheduler and the Apple-sign-in reconciler read whichever row the database hands back
first — systematically the other one. So the pill reminder she just switched on is not
scheduled, and nothing explains it. It fixes itself at the next launch, which makes it
look even more like gaslighting.

**Root cause.** Commit c2b96fa sorted the @Query in every view and added a launch-time dedupe
(RootView.swift:48-53) that deliberately keeps the OLDEST row
(ProfileStore.swift:29-32: 'the earliest row is the one her other devices have been
syncing against'), but six service-layer reads still use an unsorted
`FetchDescriptor<UserProfile>()` and take `.first`. Unsorted is not merely unspecified
— it is a systematic inversion in exactly the scenario that creates two rows: the
device that onboarded SECOND holds a locally-created row (newer createdAt, lower
rowid) and then receives the other device's row (older createdAt, higher rowid), so
the unsorted fetch returns the newer row while every view edits the older one. Dedupe
only runs in RootView's launch .task, so the divergence persists for the whole
session.

**Fix.**

1. 1. Add `ProfileStore.current(in:) -> UserProfile?`: fetch sorted by createdAt
   ascending, and call dedupe(in:) when it sees count > 1 so the divergence heals at
   the moment it is observed rather than at the next launch.
2. 2. Replace the unsorted `.first` at all SIX sites: NotificationService.swift:329,
   CaelynApp.swift:97 (reconcileAppleCredential — this is ACC-18, the one identity
   write path, and the only reason it is benign today is that dedupe happens to run
   first), HealthKitSync.swift:32, HealthKitSync.swift:43,
   HealthSyncService.swift:317, and CloudSyncCoordinator.swift:91 (the widget/watch
   snapshot rebuild, which runs at exactly the moment the duplicate row arrives).
3. 3. Call ProfileStore.dedupe(in:) inside
   CloudSyncCoordinator.reconcileArrivedRecords, so a duplicate arriving mid-session
   is collapsed when it arrives, not at the next cold start.
4. 4. PERMANENCE: make the sorted accessor the only documented way to reach the
   profile outside a @Query, and grep-assert in tests that no production file
   constructs a bare FetchDescriptor<UserProfile>().

*Files:* `Caelyn/Services/ProfileStore.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/HealthKitSync.swift`, `Caelyn/Services/HealthSyncService.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`

*Tests:* ProfileStoreTests: insert newer-then-older rows and assert current(in:) returns the
oldest and collapses the duplicate. Add a source-level assertion test that no file
under Caelyn/ builds an unsorted FetchDescriptor<UserProfile>(). No existing test
touches syncFromLiveStore.

#### EXP-02, EXP-03 — ExportService.generatePDF — drawClinicalSummary / drawCycleTimeline / drawInsightsSection (+ ExportView.generate's range filtering)

The PDF she hands her doctor prints numbers that were never measured. On a 'Last 3
months' export it says 'Average cycle length 28 days — Normal: 21-35 days' and 'Cycle
length variation ±0 days', where 28 is simply the number she typed during setup and ±0
is a placeholder — presented as findings. The same page draws a three-day bar on her
cycle timeline (a missed flow day in the middle of a period) and counts it as a
completed cycle, while the average on the line above deliberately excluded it. A
clinician reads a regularity profile that is partly fabricated and partly self-
contradicting.

**Root cause.** Two related failures of a single derivation. (1) THRESHOLD MISMATCH:
drawClinicalSummary gates itself on one threshold — `guard !cycles.isEmpty`
(ExportService.swift:205-206) — while the seven rows it prints depend on three
strictly higher ones inside PredictionEngine: ≥2 plausible cycles for
averageCycleLength (:117), ≥2 for averagePeriodLength (:123), ≥2 for
cycleLengthVariation (:137), ≥3 for irregularCycleStatus (:402). Below those,
PredictionEngine encodes 'not enough data' as an in-band magic value —
`clampCycleLength(profile.averageCycleLength ?? 28)` and literal `0` — carrying no
flag the renderer could check. (2) TWO CYCLE LISTS IN ONE FUNCTION: generatePDF
computes `let cycles = PredictionEngine.cycles(from: entries)`
(ExportService.swift:118, the faithful unfiltered reconstruction) and hands it to the
timeline (:127, bars at :287-299) and the 'Completed cycles in range' row (:226),
while drawClinicalSummary independently builds CycleModel.make (:207) whose cycles are
plausibleCycles (CyclePrediction.swift:216-217, floor 15 at
PredictionEngine.swift:40). Statistics come from the filtered list; the count and the
bars from the raw one. Aggravating: ExportView passes the RANGE-FILTERED entries
(ExportView.swift:274), so even above threshold the average is learned from fewer
cycles than Home used and the two disagree.

**Fix.**

1. 1. Build the CycleModel ONCE at the top of generatePDF, replacing the raw `cycles`
   local at :118, and thread `model` — not a bare array — to drawClinicalSummary,
   drawInsightsSection and drawCycleTimeline. This removes the duplicate
   CycleModel.make calls at :207 and :257 (two extra full reconstructions per report)
   and makes one type the single source for every section.
2. 2. Move the guards onto the filtered list: `guard !model.cycles.isEmpty` at :206
   and `model.cycles.count >= 1` at :287 — otherwise a range containing only
   implausible cycles still prints profile-seed averages as if measured.
3. 3. Add an explicit predicate `PredictionEngine.hasLearnedAverages(_ cycles:
   [Cycle]) -> Bool { plausibleCycles(cycles).count >= 2 }` so 'not enough data' stops
   being an in-band magic number.
4. 4. When it is false, render 'Not yet learned (your setting: 28 days)' and OMIT the
   variation row entirely — and suppress the `note` column with it. 'Normal: 21-35
   days' (:222) and 'Normal: 3-7 days' (:223) are what turn a placeholder into a
   verdict; they must go with the value, not be kept beside it.
5. 5. Pass the unfiltered @Query history as a separate `history:` argument so averages
   are learned from everything she has, while the entry table and notes stay range-
   filtered. Label the summary accordingly ('computed from your full history').
6. 6. Count row: 'Completed cycles in range' must count model.cycles (the plausible
   ones) so it matches the number behind the average printed above it.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* testPDFGenerationProducesData needs the new `history:` argument. Add: a PDF built from
1 cycle contains 'Not yet learned', contains neither '±0 days' nor 'Normal: 21-35
days'; a fixture with one 3-day gap-cycle produces no 3d bar label and a count equal
to the plausible-cycle count.

#### EXP-05 — ExportService.drawEntryTable / drawTableRow

On the 'Detailed Entries' page her doctor skims, the symptoms are cut off on exactly
the heavy days that matter. 'Cramps, Bloating, Fatigue, Headache, Back pain, Tender
breasts' is chopped after about 35 characters with no ellipsis and nothing to show
anything is missing. Pain types, medication, BBT, mucus, OPK, pregnancy tests and
sexual activity are not in the table at all.

**Root cause.** The entry table performs no text measurement anywhere — neither vertical nor
horizontal. drawTableRow builds `CGRect(x:, y: page.y, width: width - 6, height: 14)`
and calls `cell.draw(in:withAttributes:)` (ExportService.swift:512-520); UIKit lays
the string out with word wrapping inside that rect and CLIPS rendering to it.
smallFont is 9.5 pt (line 158) so the line height is ≈11.3 pt — one line fits, the
second is drawn outside the rect and discarded. The Symptoms column is 174 pt of
usable width (:380-382) while the cell joins every symptom plus every custom symptom
(:400-410). The row advance is a matching fixed 16 pt. Because nothing measures, the
layout is a hand-tuned constant that was never checked against content.

**Fix.**

1. 1. Measure every cell with `boundingRect(with: CGSize(width: width-6, height:
   .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading],
   attributes: attrs, context: nil)` and take the max height across the row as `rowH`.
2. 2. Give every cell an explicit NSMutableParagraphStyle with `.lineBreakMode =
   .byWordWrapping`, and use the SAME attributes dictionary for the measurement and
   for the draw — otherwise the measured height will not match what is rendered.
3. 3. Page-break on `page.y + rowH > contentBottom` before drawing, draw at `rowH`,
   advance `rowH + 2`.
4. 4. Fix the zebra fill with it: line 417 hard-codes `height: 16`; it must use the
   computed rowH or the striping will desynchronise from the rows.
5. 5. Re-draw the header row on each new page so a continued table is readable.
6. 6. Unrealized potential (same pass, low cost): add the fields the table silently
   omits — pain types, medication, BBT, mucus, OPK, pregnancy test, sexual activity —
   or at minimum state in a footnote which fields the table does not carry, so an
   omission is never silent.

*Files:* `Caelyn/Services/ExportService.swift`

*Tests:* No existing test breaks. Add the probe as a PDFKit text-extraction test asserting
every symptom and every custom symptom appears in the extracted text. Add a multi-page
case (60+ entries with long symptom lists) asserting the header appears on each page
and no row is clipped.

#### F-29-01, F-29-10 — 29 TTC fertility score / 40 — fertile window derivation across phone, Watch and widget

Caelyn tells her two different fertile windows at the same time. On Home, the
fertility gauge says "Low fertility today" while the sentence directly beneath it says
"In your fertile window — 3 days remaining". Her Watch and widget highlight different
days again. This happens to exactly the users Caelyn has learned the most about:
anyone whose luteal phase is not the textbook 14 days.

**Root cause.** The fertile window is derived in three independent places instead of being derived
once and handed around, and every secondary derivation falls back to a hardcoded
14-day luteal because the parameter carries a default rather than being required. (1)
`CycleModel.fertileWindow` (CyclePrediction.swift:308-313) is the real one and
correctly uses the learned `lutealLength`; HomeView already passes it into the TTC
engine (HomeView.swift:132-137) and into a sibling card (:248-249). (2)
`TTCDashboardCard` was handed the raw anchor `nextPeriodStart` instead of that window
(TTCDashboardCard.swift:5, HomeView.swift:228) and so re-derives it at
TTCDashboardCard.swift:38-39 via `PredictionEngine.fertileWindow(nextPeriodStart:)`,
whose `lutealLength` default of 14 (PredictionEngine.swift:253) silently substitutes
the population average instead of failing to compile. (3) `WidgetCycleMath` is a
second, independent copy of the cycle math that predates learned luteal and has no
luteal parameter anywhere: `fertilityStatus` hardcodes `ovulation = cycleLength - 13`
(WidgetDataStore.swift:153), `phaseRaw` hardcodes `cycleLength - 14` (:139) and
`upcomingStrings` hardcodes `nextStart - 14` (:184); WidgetSnapshot (:24-52) carries
no lutealLength for a builder to pass. Because the watch and widget recompute
unconditionally on every render (not only as a midnight fallback), patching only the
snapshot writer would be undone on the next read.

**Fix.**

1. Make the TTC card incapable of holding a window that disagrees with its own score:
   add `fertileWindow: ClosedRange<Date>?` to `TTCFertilityEngine.FertilityResult`
   (TTCFertilityEngine.swift:8-12), populated from the window the engine already
   computes at :24, and have TTCDashboardCard read `result.fertileWindow`. Delete the
   re-derivation at TTCDashboardCard.swift:38-39 and drop the now-unused
   `nextPeriodStart` parameter so no future edit can reintroduce it.
2. Add `var lutealLength: Int? = nil` to WidgetSnapshot (WidgetDataStore.swift:24-52)
   — Optional with a nil default, matching the
   anchorPeriodStart/periodLength/fertilityStatusRaw/hidePreview pattern at :42-51, so
   snapshots written by 1.3 build 15 still decode and a newer Watch paired with an
   older phone falls back rather than failing.
3. Have WidgetDataSync write `cycle.lutealLength` into the snapshot
   (WidgetDataSync.swift:33, :84).
4. Thread it through EVERY WidgetCycleMath entry point, not just fertilityStatus:
   `fertilityStatus(cycleDay:cycleLength:lutealLength:)` with `ovulation = cycleLength
   - lutealLength + 1`, `phaseRaw(...lutealLength:)` with `ovulation = cycleLength -
   lutealLength`, and `upcomingStrings(...lutealLength:)` with `ovulation = nextStart
   - lutealLength`. Default each parameter to 14 so existing call sites and old
   snapshots keep today's behaviour exactly.
5. Update `recomputed(for:)` (WidgetDataStore.swift:100-125) to pass
   `self.lutealLength ?? 14` into all three — this is the unconditional path and is
   what makes the fix stick.
6. Ship the Watch and widget targets together with the app; a mixed pairing falls back
   to 14, which is today's behaviour, not a regression.
7. Consider removing the `= 14` default from
   `PredictionEngine.fertileWindow`/`ovulationEstimate` (PredictionEngine.swift:253)
   so every future call site must state its luteal source. That single change is what
   prevents a fourth copy of this bug.

*Files:* `Caelyn/Views/Home/TTCDashboardCard.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* CaelynTests.testFertilityStatusMatchesDateBasedFertileWindow — add a learned-luteal
case (28-day cycle, luteal 11: app ovulation day 18, watch must agree).
CaelynTests.testWidgetCycleMathMatchesPredictionEngine — pass the same lutealLength to
both sides. Add: a snapshot JSON without the lutealLength key still decodes. Add a TTC
test asserting result.fertileWindow and result.score never disagree about whether
today is fertile.

#### F-29-04, PG-12 — 29 TTC fertility score + Home hero/teaching copy — late-period handling

When her period is late — the moment she is paying the most attention — Home
contradicts itself. The big card says "Day 2 of your period" and teaches "Day 2 —
estrogen and progesterone are at their lowest", while the prompt right underneath says
"Your period might be 2 days late". In TTC mode the same screen forecasts a brand-new
fertile window for a cycle that may not be happening, and logging a positive pregnancy
test changes nothing.

**Root cause.** Lateness is structurally erased from the two values every surface reads.
`currentCycleDay` wraps the elapsed-day count modulo cycleLength
(PredictionEngine.swift:169-177), so day 29 of a 28-day cycle becomes day 1;
`nextPeriodStart` advances past today in whole cycles (:180-194), so three days late
becomes a forecast a full cycle out; and `phase` classifies purely from the wrapped
number, returning `.menstrual` for any day ≤ periodLength (:350-366). The un-rolled
`expectedPeriodStart` was added precisely for lateness (:196-203) but feeds only
`isPeriodLate`/`daysLate` (CyclePrediction.swift:355-361) — a second, parallel
derivation that reaches exactly one consumer, `HomeCopy.comingUpEvents`
(HomeCopy.swift:93, passed at HomeView.swift:252). The rule was implemented per-
consumer instead of at the source, so the hero, header, ring, teaching line and TTC
card all read the lateness-blind pair.

**Fix.**

1. Fold lateness into the single derivation. In CycleModel (CyclePrediction.swift)
   expose `isLate` on the model itself and make the pair honest while late: `cycleDay`
   returns the unwrapped `days + 1` (not the modulo), and `phase` returns `.luteal`
   rather than `.menstrual`. Leave the raw `nextPeriodStart` untouched — calendar
   painting and daysLate arithmetic still need it.
2. Add `var forecastNextPeriodStart: Date? { isPeriodLate ? nil : nextPeriodStart }`
   and point every forward-looking surface at it: fertile-window copy, ovulation
   estimate, the TTC card, comingUpEvents. A forecast derived from a rolled-forward
   anchor is not a forecast.
3. Derive the TTC state in CycleModel, not in HomeView, so watchOS and any future
   surface inherit it: `enum TTCState { case scoring, late(days: Int),
   pregnancyTestLogged }`. When `.late`, TTCDashboardCard shows one sentence —
   consider a pregnancy test — and no gauge, no fertile-window line.
4. Clamp the ring marker: CycleRingView.swift:109 must become `min(1, Double(max(0,
   cycleDay - 1)) / Double(safeLen))`, or branch to a distinct past-expected position.
   Otherwise an unwrapped day 30 of 28 rotates the dot past 360° and back into the
   rose period arc, re-drawing the exact claim this fix removes.
5. Audit every phase/cycleDay consumer, not just the hero: HomeCopy.phaseHeadline
   (HomeCopy.swift:54-69), CycleSummaryService.phaseLead and dailyTeaching
   (CycleSummaryService.swift:104-124), HomeHeader's "Day N" (HomeHeader.swift:32-37),
   the calendar markers, and WidgetCycleMath if cycleDay semantics change for the
   widget.
6. Land this before the mode/staleness item: both change what `phase` may return, and
   lateness should be the single established rule first.

*Files:* `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Views/Home/HomeHeader.swift`, `Caelyn/Views/Home/TTCDashboardCard.swift`, `Caelyn/Views/Home/CycleRingView.swift`, `Caelyn/Services/CycleSummaryService.swift`

*Tests:* CivilDayTests.CaelynSaysOnlyWhatItKnowsTests — headline tests gain an isLate
parameter. Add a late-model test asserting cycleDay is unwrapped, phase is .luteal and
the headline no longer claims a period day. Add: the TTC card renders the late state
and no fertile-window line. WidgetCycleMath parity test if cycleDay semantics change
for the widget.

#### F-29-05, PG-17 — 29 TTC fertility score + Home hero / phase guide / teaching copy in Pregnancy, Postpartum and Birth-control modes

A newly pregnant woman still gets a daily fertility score, "Fertile window in 9 days",
a badge reading "Estimated ovulation window" and a teaching line about her LH surge —
sitting directly above her pregnancy week card. A woman on the pill is taught about an
ovulation Caelyn cannot place. Turning on pregnancy mode does not turn TTC off, and if
she turns TTC off on one device, a sync with her other device turns it back on.

**Root cause.** Two mechanisms compose. (1) Mode never became an input to the tutor layer:
`CyclePhase` is the sole axis for badge, headline, hint, teaching line and guide
(HomeCopy.swift:54-69, CyclePrediction.swift:31-44, CycleSummaryService.swift:104-124,
PhaseGuideView.swift:417-431), and CycleModel/PredictionEngine take `profile` only for
the numeric seeds — never the mode flags. HomeView renders the hero unconditionally
(HomeView.swift:157-164) and simply adds the mode cards beside it (:231-237); the TTC
gate (:227) checks `isPro && ttcEnabled` and nothing else; `ttcEnabled` is cleared
nowhere in the app (the pregnancy onChange at CycleSettingsView.swift:391-400 clears
only `postpartumEnabled`), and ProfileStore.merge ORs both flags
(ProfileStore.swift:69-70), so a merge resurrects a flag one device turned off. (2)
Prediction has no staleness ceiling: `currentCycleDay` wraps modulo cycleLength
(PredictionEngine.swift:176) with no upper bound on anchor age, so a nine-month-old
anchor still yields a confident phase — there is no `.unknown` escape hatch for "this
anchor can no longer describe reality".

**Fix.**

1. Give CycleModel the staleness ceiling (fixes mechanism 2 with no flag at all): in
   `CycleModel.make` (CyclePrediction.swift:209-248) treat an anchor older than a
   bounded multiple of her own cycle — e.g. `anchor + 2*cycleLength +
   2*max(variation,2) < today` — as expired; store `anchorIsStale` and have `phase`
   return `.unknown` and `nextPeriodStart`/`fertileWindow`/`ovulationEstimate` return
   nil in that state. This attacks the modulo wrap itself, so calendar markers
   (CalendarMath.swift:135-141), the year view (YearViewSection.swift:148) and the
   widget all inherit it.
2. Add a mode axis to the copy layer: pass a small `CycleContext { normal, pregnant,
   postpartum, birthControl }` derived from the profile flags into
   HomeCopy.phaseHeadline, CycleSummaryService.phaseLead/dailyTeaching, HomeHeroCard
   and PhaseGuideView, and write one short copy set per non-normal mode. A phase enum
   alone can never express "this teaching does not apply to her".
3. Gate the TTC card defensively at HomeView.swift:227: `purchase.isPro &&
   profile?.ttcEnabled == true && profile?.pregnancyEnabled != true`.
4. Clear `ttcEnabled` in the pregnancy onChange (CycleSettingsView.swift:391-400)
   alongside `postpartumEnabled`, with a comment stating the exclusivity rule.
5. Leave ProfileStore's OR merge alone — the additive merge is the Caelyn data
   principle — and instead enforce exclusivity at read time: a single
   `profile.effectiveMode` accessor that resolves conflicting flags in a fixed
   priority (pregnancy > postpartum > TTC) so a resurrected flag cannot produce
   contradictory UI on any device.
6. Suppress fertility language wherever it is spoken, not just on the card: nil out
   `daysUntilFertileWindowStart`/`fertileWindow` into HomeCopy.comingUpEvents
   (HomeView.swift:244-255, HomeCopy.swift:116) and apply the same suppression in
   WidgetDataSync.swift:53, or "Fertile window in N days" keeps appearing on the
   widget under her pregnancy card.

*Files:* `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Views/Education/PhaseGuideView.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Models/UserProfile.swift`

*Tests:* CivilDayTests headline tests gain a context parameter. Add phase × mode copy tests
(pregnant + .ovulation must not mention fertility). Add: an anchor 9 months old yields
.unknown and nil forecasts. ProfileStoreTests unchanged (the OR merge is deliberate);
add an effectiveMode test for both-flags-on.

#### F-29-06 — 29 TTC fertility score — scoring model

A positive ovulation strip — the strongest real-time evidence the app can hold —
cannot outvote Caelyn's calendar guess. On a day the calendar didn't predict, a
positive strip reads "Moderate"; even a positive strip plus egg-white mucus only
reaches "High". And on her predicted ovulation day with nothing logged, the card reads
"Moderate" too. The women most likely to buy test strips — irregular cycles — are told
"Moderate" on their actual peak day.

**Root cause.** Two mechanisms compound. (1) Flat additive scoring with no evidence hierarchy: every
signal is a fixed independent addend (TTCFertilityEngine.swift:22-70) and the calendar
estimate carries the single largest weight (+45 at :28), so an observation that
physiologically overrides a calendar guess cannot override it arithmetically. (2) The
four label bands (:73-80) were calibrated independently of the weight space they
partition: the maximum positional contribution (45) falls below the "High" cut (50),
so the predicted ovulation day alone can never read better than "Moderate"; and the
largest single observed signal (+30) cannot lift the out-of-window base (5) out of
"Moderate". The engine also sees only today's entry (:14-18), so it has no way to know
an LH test was positive yesterday or that a thermal shift has already happened.

**Fix.**

1. Widen the signature first — nothing else is implementable without it:
   `result(todayEntry:recentEntries:nextPeriodStart:lutealLength:confidence:)`, taking
   a trailing 7-day window of entries plus `cycle.confidence`. Both are already in
   hand at HomeView.swift:130-137. Pure computation; no stored data, no schema change.
2. Add explicit override rules that run before the additive sum: a positive LH test
   today or yesterday sets a floor of "High" (and "Peak" with fertile-quality mucus)
   regardless of calendar position; a confirmed thermal shift (see the wrist-
   temperature items) caps the score at "Low" because ovulation has passed.
3. Scale the positional weight by `cycle.confidence` — Home itself labels a calendar
   estimate low-confidence below 3 cycles, so the score should not weight it at 45 for
   a two-cycle user.
4. Re-fit the bands against the achievable weight space and assert the fit in tests:
   either raise the positional ceiling or lower the "High" boundary so the predicted
   ovulation day alone does not render "Moderate" next to a visible "+45". Add a test
   that enumerates every branch combination and asserts no band is unreachable and no
   obviously-peak combination lands below Peak.
5. Document the resulting hierarchy in the file header (observed > positional) so a
   future weight tweak has a stated rule to respect.
6. Build this on top of the ledger item (F-29-02) so each override and each addend is
   displayed with the delta it actually applied.

*Files:* `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/TTCDashboardCard.swift`

*Tests:* No existing tests exist for this engine (see F-29-09). Add table-driven tests:
positive LH outside the predicted window → at least "High"; predicted ovulation day
with nothing logged → not below "High"; confirmed post-shift day → "Low"; every band
reachable; low confidence reduces positional weight.

#### F-40-01 — 40 Wrist-temperature ovulation detection — series window

The Insights card tells her "your temperature rose around <date>" using a date from a
previous cycle — and for a woman who logs temperature by hand rather than wearing an
Apple Watch, it names a date from the very first cycle she ever logged, every single
time she opens Insights, forever.

**Root cause.** Three stacked mechanisms. (a) `WristTempOvulationEngine.detectShift` has no cycle-
boundary concept — there is no `cycleStart` parameter in its signature
(WristTempOvulationEngine.swift:32-33) — so it is a pure "find a biphasic shift
somewhere in this array" function whose correctness depends entirely on the caller
having clipped the array to one cycle, a contract stated only in a doc comment (:30).
(b) Neither caller honours it: InsightsView.swift:33-35 builds `bbtSeries` from every
entry with a basalTemperature across her whole history with no date filter at all, and
:128-131 substitutes a fixed `now − 40 days` window for the wrist fetch — a constant
chosen independently of her cycle length, so for any cycle shorter than ~34 days it
structurally always contains part of the previous cycle. (c) The loop returns at the
FIRST qualifying index (:40-52), so when the window does straddle two cycles the
earlier shift always wins.

**Fix.**

1. Add `cycleStart: Date?` to `detectShift(in:cycleStart:calendar:)` and drop every
   point before it at the top of the function. Keep returning the FIRST qualifying
   index within the bounded window — that is the medically correct answer (the first
   sustained rise after menses is the shift) and it preserves the existing contract.
2. Do NOT switch to a latest-match scan: in the existing fixture
   CaelynTests.swift:924-935 (testWristTempBiphasicShiftDetected) index 7 also passes
   the coverline test, so iterating from the end would change that test's expected
   date for no benefit.
3. At the call site (InsightsView.swift:318-322) pass `cycle.cycles.last?.start` — or
   the active cycle's anchor — instead of the −40-day literal, and apply the same
   bound to the manual `bbtSeries` fallback, which today has no bound whatsoever.
   Delete the 40-day constant: the window must be a function of her cycle, not a magic
   number in a view.
4. Render nothing when there is no cycle start to bound by, rather than scanning
   unbounded history.
5. Land this before the shift-as-marker item (F-40-07): "the confirmed shift for THIS
   cycle" has to be a well-defined value before anything consumes it.

*Files:* `Caelyn/Services/WristTempOvulationEngine.swift`, `Caelyn/Views/Insights/InsightsView.swift`

*Tests:* testWristTempBiphasicShiftDetected and testWristTempNoShiftOnFlatSeries keep passing
(single-cycle series). Add: a two-cycle series bounded to the second cycle reports no
shift while the unbounded call reports the first cycle's; a manual-BBT user with three
years of history gets a date inside her current cycle or nothing.

#### F-40-07 — 40 Wrist-temperature ovulation detection — unrealized potential

Caelyn works out the single strongest retrospective sign that she ovulated, then uses
it for one sentence and throws it away. Her "Your luteal phase — still learning" row
stays stuck unless she buys LH strips; the TTC card keeps saying "fertile window" for
days after her own temperature has confirmed ovulation is over; and an Apple Watch
user in her first cycle — who needs no cycle history for this to work — is not shown
the card at all.

**Root cause.** Ovulation-marker derivation is absent from the model layer for temperature entirely.
`learnedLutealLength` hard-codes LH positive/surge as its only marker predicate
(PredictionEngine.swift:266-288), so there is no seam for a second marker source; and
the only temperature consumer owns its own ad-hoc window inside a SwiftUI `.task`
(InsightsView.swift:318-322) rather than exposing a value the model can read. The
result is four independent missing wires — luteal learning, TTC scoring, calendar
marking, and source selection (InsightsView.swift:320 picks `wrist.isEmpty ? bbtSeries
: wrist`, so a woman who wears a Watch and also logs by hand has her hand-logged
readings silently discarded) — plus a Pro + ≥2-cycle gate (:54-57) that has nothing to
do with what the detection actually requires.

**Fix.**

1. Phase 0 (prerequisite): land the cycle-boundary fix (F-40-01) so "the confirmed
   shift for this cycle" is a defined value.
2. Phase A: move the detection out of the view into the model. Add
   `CycleModel.thermalOvulation: Date?` (or a small `OvulationMarker` type carrying
   date, source and confidence) computed from the bounded series, so every surface
   reads one value instead of each running its own `.task`.
3. Phase B: generalise `learnedLutealLength` from an LH-only predicate to a list of
   ovulation markers (LH positive/surge OR a confirmed thermal shift), keeping the
   existing 9–17 clamp and ≥3-cycle requirement. Prefer an LH marker over a thermal
   one within the same cycle; record which source was used so the Insights copy can
   say so.
4. Phase C: feed the marker into TTCFertilityEngine (via the widened signature from
   F-29-06) as the post-ovulation cap — a confirmed shift this cycle means the window
   has closed.
5. Phase D: merge the two sources instead of choosing one — union wrist and manual
   readings by day, preferring the wrist value where both exist, rather than
   `wrist.isEmpty ? bbtSeries : wrist`.
6. Re-gate the card on what it actually needs: enough temperature readings (baseline +
   1 + sustain) and Pro, not ≥2 completed cycles (InsightsView.swift:54-57). A first-
   cycle Watch user is precisely the target.
7. Note in Insights copy that the thermal marker is retrospective and observational,
   consistent with the existing disclaimer at InsightsView.swift:309.

*Files:* `Caelyn/Services/WristTempOvulationEngine.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Services/TTCFertilityEngine.swift`

*Tests:* testLearnedLutealLengthFromLHSignals unchanged (LH still wins). Add a thermal-marker
variant: three cycles with a confirmed shift and no LH produce a learned luteal. Add:
wrist and manual readings merge rather than one replacing the other. Add: the card
renders for a first-cycle user with enough readings.

#### HK-01 — HealthKitService.syncEntryToHealth — flow branch

Every time she touches a period day in Caelyn, Apple Health gets another copy of that
day's flow. Logging six symptoms on a period day leaves seven identical Caelyn entries
in Health; changing light to heavy leaves both. Other apps reading Health — Flo, Clue,
Natural Cycles, Apple's own Cycle Tracking — see duplicated and contradictory flow for
the same day.

**Root cause.** The two branches of syncEntryToHealth are asymmetric. The symptom branch calls
`deleteOwnSymptomSamples(on:)` unconditionally before appending
(HealthKitService.swift:362-366); the flow branch only deletes inside its `else` —
i.e. only when flow was cleared — and appends a fresh `makeFlowSample` otherwise
(:354-361). `makeFlowSample` (:509-522) builds a brand-new HKCategorySample with a new
UUID on every call, and `store.save` (:371) inserts rather than replaces, so there is
no 'one Caelyn sample per day per type' invariant anywhere. The write is also fired on
every single mutation: DailyLogForm.withEntry (DailyLogForm.swift:1001-1017) plus
HomeView.logMood/logPeriodToday/removePeriodLog (HomeView.swift:732,753,774,793) and
WatchBridgeService. The doc comment at HealthKitSync.swift:8-12 asserts delete-then-
rewrite for both paths, so the invariant was intended and simply not implemented on
the flow side.

**Fix.**

1. 1. Extract a pure, testable
   `HealthWritePlan.make(entry:isCycleStart:existingOwn:writeFlow:writeSymptoms:) ->
   (delete: [HKObject], save: [HKSample])` so the decision is unit-testable without an
   authorised HKHealthStore. This seam is shared by HK-04, HK-06, HK-09, HK-18 and
   HK-20 — land it first.
2. 2. Prefer the platform primitive over query-delete-save: stamp every written sample
   with `HKMetadataKeySyncIdentifier` derived from the civil day key plus the type
   (e.g. "caelyn.flow.\(entry.dayKey)", reusing CycleEntry.dayKey/CivilDay from
   37dddd7 so identity is timezone-stable) and `HKMetadataKeySyncVersion` from a
   monotonic counter (entry.updatedAt.timeIntervalSince1970 rounded to Int). HealthKit
   then replaces rather than appends, which removes the race between the delete query
   and the save entirely.
3. 3. Keep a `replaceOwnSamples(on:type:with:)` helper for the legacy path:
   1.3-build-15 users already have unkeyed duplicate samples in Health that no sync
   identifier will match, so the helper must still query by source bundle ID and
   delete them.
4. 4. Compare-and-skip: if the existing own sample for the day already carries the
   same value and metadata, write nothing. This makes the repeated-tap case (HK-13)
   free and stops the churn without needing a debounce.
5. 5. Add a one-time dedupe pass (reuse the existing Backfill machinery, run once on
   upgrade or offer it on the Apple Health screen) that collapses duplicate Caelyn-
   authored samples per day per type and recomputes cycle-start flags.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/HealthKitSync.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Home/HomeView.swift`, `CaelynTests/HealthSyncTests.swift`

*Tests:* No existing test covers it (HealthSyncTests:953-972 only asserts the local entry
survives). Add HealthWritePlan tests: identical existing own sample -> nothing
deleted, nothing saved; different value -> old deleted, one saved; flow cleared -> old
deleted, nothing saved; symptom unchecked -> its sample deleted.

#### HK-06 — HealthKitService.syncEntryToHealth / isCycleStart (HKMetadataKeyMenstrualCycleStart)

If she logs today's period first and then back-fills yesterday, Apple Health ends up
believing two periods started a day apart. Apple's Cycle Tracking (and every app
reading it) then shows phantom one-day cycles and shifted predictions, until she
happens to press Backfill in Caelyn's settings.

**Root cause.** `HKMetadataKeyMenstrualCycleStart` is derived state over the ordered pair (D-1, D) —
`isCycleStart` looks only one day backwards (HealthKitService.swift:604-609) — but it
is persisted as an immutable property of day D's sample (:355-357). Any write that
changes whether day X has flow therefore invalidates the flag already stored on X+1,
and the dispatcher has no invalidation step:
HealthKitSync.syncIfConnected/deleteFlowIfConnected act on exactly one calendar day
(HealthKitSync.swift:31-38, 42-53) and never touch the neighbour. The only code that
recomputes flags across history is backfillFlowToHealth, which is manual and three
screens away.

**Fix.**

1. 1. HARD PREREQUISITE: land HK-01's delete-then-rewrite (or sync-identifier replace)
   first. Today the flow-present branch only appends, so re-syncing day X+1 would
   leave the stale cycleStart sample AND add a new one — the fix would make Health
   worse. Ship them as one change.
2. 2. Put the dependency in the dispatcher, not in callers: after syncing day D,
   HealthKitSync also schedules a sync of D+1 whenever D's flow presence changed (and
   on the delete path too). Callers must not have to remember.
3. 3. Re-fetch entries inside HealthKitSync rather than reusing the caller's array:
   call sites hand in a @Query snapshot captured before the Task runs
   (DailyLogForm.swift:1015 `let snapshotEntries = allEntries`), which can already be
   stale by the time the neighbour is computed. Fetch by dayKey from the model context
   at execution time.
4. 4. Guard against an infinite chain: the neighbour sync must never itself schedule a
   further neighbour. Pass an explicit `cascade: false` on the neighbour call.
5. 5. Keep `isCycleStart` as the single definition of the flag and have the backfill
   path call it too (see HK-18) so the one-day and whole-history computations cannot
   disagree.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/HealthKitSync.swift`

*Tests:* New HealthWritePlan/dispatcher test: two consecutive flow days; syncing D-1 must mark
D as not-a-start. Second test: clearing D-1's flow must mark D as a start again.

#### HK-08 — HealthKitService.syncEntryToHealth (single mixed-type save) + WriteScope.symptoms all-or-nothing gate

Apple's permission sheet lets her share some things and not others — cramps yes, acne
no. Caelyn does not cope with that: if she declines even one symptom type she cannot
turn symptom writing on at all, and if she revokes one later, every write for that day
fails silently, including her period flow. Health quietly stops receiving anything
from Caelyn.

**Root cause.** Write consent is modelled as a stored, iCloud-OR-merged per-scope boolean on
UserProfile (`hkWriteFlow`/`hkWriteSymptoms`, ProfileStore.swift:53-58) while
HealthKit grants sharing per type and per device and never stops disclosing it — so
the flag can be true on a device that was never authorised for any symptom type. The
write path trusts the flag alone (HealthKitService.swift:354, 362),
`symptomSamples(from:)` applies no authorizationStatus filter (:567-602), and flow
plus up to 12 symptom/pain samples go into one transactional `store.save(samples)`
(:371), so a single unauthorised type fails the whole batch. The enable gate compounds
it: `canWrite(.symptoms)` requires allSatisfy over all 12 types (:163-166).

**Fix.**

1. 1. Stop treating the stored flags as consent. Keep hkWriteFlow/hkWriteSymptoms as
   intent ('she asked for this'), which keeps the additive OR-merge correct, and
   derive capability only from `store.authorizationStatus(for:)` at the moment of the
   write. This cannot drift across devices and needs no refresh hook.
2. 2. In syncEntryToHealth, filter every candidate sample by
   `store.authorizationStatus(for: sample.sampleType) == .sharingAuthorized` before
   building the batch.
3. 3. Issue independent saves — flow, then symptoms — so neither can fail the other.
   Do the same inside backfillSymptomsToHealth (batch per type, or filter before
   building) so one denied type cannot discard eleven authorised ones.
4. 4. Replace the allSatisfy gate at :163-166 with 'any type in the scope authorised'
   for enabling the toggle, and show which types are actually flowing in the Apple
   Health screen's status line (ties into HK-03/HK-07).
5. 5. Fold the authorization filter into HealthWritePlan.make (HK-01) so it is unit-
   testable and every write path inherits it.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`

*Tests:* testEachWriteToggleAsksOnlyForTheTypesItNeeds (CaelynTests:917) stays valid. Add a
HealthWritePlan test: unauthorised types are dropped from the plan, and the flow
sample is still planned and saved independently of the symptom batch.

#### HK-09 — HealthKitService.deleteOwnFlowSamples/deleteOwnSymptomSamples (instant-range identity) + HealthDataCatalog.observation day truncation

If she travels west — or just reinstalls Caelyn in a different timezone — days she
logged before the move can land on the wrong date. Apple Health keeps an orphaned
duplicate on the previous day, and after a reinstall or 'Bring my history' Caelyn can
file that sample a day earlier, creating a period day she never had and throwing her
cycle lengths off by one.

**Root cause.** The civil day is not carried on the sample. Write side: samples are written at
`entry.date` (the recording zone's midnight instant) with no day identity in metadata
(HealthKitService.swift:515-521), while the delete queries build a range predicate
from `Calendar.current.startOfDay(for: date)` (:385-393, :410-418) — and
CycleStore.dedupeSameDay re-files `entry.date` to the CURRENT zone's midnight at
launch (CycleStore.swift:50-53). After a westward move the range no longer contains
the old sample, so it is orphaned instead of replaced. Read side (this is what sets
the severity): `HealthDataCatalog.observation(from:)` truncates `sample.startDate` in
the current calendar (Health/HealthDataCatalog.swift:131), and fullImport sets
`acceptOwnSource: true`, so Caelyn re-imports its own sample onto the shifted day and
fills a new period day there.

**Fix.**

1. 1. Fix the missing delete-before-write first (HK-01): call
   deleteOwnFlowSamples(on:) unconditionally before appending, mirroring the symptom
   branch. Without that, metadata identity still leaves duplicates.
2. 2. Stamp every written sample with `CaelynDayKey: Int(entry.dayKey)` and
   `HKMetadataKeyTimeZone: TimeZone.current.identifier` in makeFlowSample and the
   symptom builders.
3. 3. Identify own samples with
   `HKQuery.predicateForObjects(withMetadataKey:allowedValues:)` on CaelynDayKey, OR-
   ed with the existing range+bundleID predicate as a legacy fallback — not replacing
   it. 1.3 users have unkeyed samples in Health, and a key-only predicate would
   silently stop deleting them forever.
4. 4. On read, resolve the day in priority order: CaelynDayKey, then
   HKMetadataKeyTimeZone applied to startDate, then today's calendar as the last
   resort (HealthDataCatalog.swift:131).
5. 5. Keep HealthSyncService's lookup keyed on dayKey
   (HealthSyncService.swift:343-348) and make sure it uses the resolved day from step
   4, not a re-truncated startDate.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/Health/HealthDataCatalog.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Services/CycleStore.swift`

*Tests:* testFlowSurvivesAWriteAndReadRoundTripIncludingSpotting (HealthSyncTests:617) and
testLateNightRecordLandsOnItsLocalDay (:436): add a case where the reading calendar's
zone differs from the writing zone and assert the day is preserved via metadata.
Catalog tests must build own-source samples that carry CaelynDayKey.

#### HK-12 — HealthKitSync.serialized + HealthKitService.syncEntryToHealth (live CycleEntry captured across awaits)

Tap a symptom chip and then quickly delete that whole day — the app can crash. The
same thing can happen when a log arrives from the Watch for a day she is deleting on
the phone.

**Root cause.** A live @Model reference (the CycleEntry), a live `[CycleEntry]` snapshot array and the
live UserProfile are captured into an unstructured Task and read after suspension
points, with no re-resolution and no validity guard anywhere in the codebase (grep for
isDeleted / persistentModelID / model(for:) across Caelyn/ returns nothing).
`HealthKitSync.serialized` awaits the previous task for the same day BEFORE calling
work() (HealthKitSync.swift:19-29), so for any sync that is not first in its day's
chain EVERY read inside syncEntryToHealth happens after a suspension — not just
`symptomSamples(from: entry)` at :366 reading after the await at :365. If the row was
deleted and saved in that window (LogView.swift:89-93), SwiftData traps with 'model
instance was invalidated because its backing data could no longer be found'.

**Fix.**

1. 1. Make the dispatcher boundary carry no @Model at all: change the entry point to
   `syncIfConnected(dayKey: Int, modelContext: ModelContext)`. dayKey is already the
   stable identity (CivilDay), so no PersistentIdentifier juggling is needed.
2. 2. Inside the task, after the serialization await, fetch the entry and the sibling
   entries fresh from the context by dayKey; if no row exists, take the delete path
   (remove Caelyn's own samples for that day) instead of trapping.
3. 3. Resolve the profile the same way — fetch it inside the task rather than
   capturing the live object.
4. 4. Pass only value types into HealthKitService: a small `DayWrite` struct (dayKey,
   flow, symptoms, pain, painTypes, isCycleStart, write flags) built on the MainActor
   before any await. This makes the write path pure enough to unit-test and
   permanently removes the class of bug rather than patching one read.
5. 5. Audit the other captures with the same shape (WatchBridgeService.handleIncoming,
   HomeView.logMood/logPeriodToday/removePeriodLog) and route them through the same
   dayKey entry point.

*Files:* `Caelyn/Services/HealthKitSync.swift`, `Caelyn/Services/HealthKitService.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Log/LogView.swift`, `Caelyn/Services/WatchBridgeService.swift`

*Tests:* Add a HealthKitSync test with an injected fake writer: schedule a sync for a day,
delete the row, run the queue — expect the delete path and no trap.

#### IMP-02 — 17 Import preview + undo + history (commit vs CloudKit same-day merge)

She logs a few days on her iPad, then imports years of Clue history on her phone
before the iPad's days have synced across. The imported values quietly replace what
she typed herself — the opposite of what the import screen promised — and if she later
presses Undo, those days are cleared entirely.

**Root cause.** Two mechanisms compose. (1) When the import runs on a device whose row for that day
has not yet arrived, `CycleStore.entry(for:)` inserts a NEW row
(CycleStore.swift:68-80), so the reconciler's rule-1 re-check is skipped entirely — it
is gated on `if let live = entry.value(for:)` (ImportReconciler.swift:332) and every
field on a fresh row is nil — and the import stamps `entry.updatedAt = .now` (:343).
(2) `CycleStore.merge` resolves every scalar conflict by updatedAt alone
(CycleStore.swift:94-108) and has no access to provenance; grep confirms no ledger
reference exists in CycleStore.swift, CloudSyncCoordinator.swift or RootView.swift. So
when dedupeSameDay runs on NSPersistentStoreRemoteChange
(CloudSyncCoordinator.swift:61-83), the import row wins because it is newer, and the
ledger claim still says importedValue == stored, so undo (ImportPlanner.swift:285-291)
clears her value.

**Fix.**

1. 1. Thread the calendar into `merge` (dedupeSameDay already has it,
   CycleStore.swift:28) and give ImportLedger a MainActor-isolated lookup — NOT
   nonisolated; the type is @MainActor at ImportLedger.swift:19-20 and loadIfNeeded()
   mutates state — e.g. `isImportOwned(dayKey:field:value:calendar:)`, or add an Int-
   keyed variant of claim(day:field:) so CycleStore need not round-trip through
   CivilDay.localDate and back into the "YYYY-MM-DD" form built at
   ImportLedger.swift:93-96.
2. 2. In merge, replace the blanket `pick` for each scalar with: if the newer side's
   value is import-owned and the older side's value is NOT, keep the older (hand-
   typed) value. Hand-typed always beats imported regardless of timestamp. Leave the
   array unions exactly as they are — the additive contract must not change.
3. 3. Keep the ledger honest after a merge: when an import-owned value loses to a
   hand-typed one, release that claim so a later Undo cannot clear a value Caelyn did
   not write.
4. 4. Stop the fresh-row blind spot at its source: in ImportReconciler.commit, when
   `CycleStore.entry(for:)` has just inserted a new row, record that fact and set
   updatedAt to the observation's recordedAt (or leave it at the row's createdAt)
   rather than .now, so an unsynced hand-logged row from another device is still
   newer.
5. 5. Document the resulting precedence in ICLOUD_ARCHITECTURE.md next to the
   additive-merge rule, since this is the first exception to 'newest updatedAt wins'.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/Import/ImportPlanner.swift`, `docs/ICLOUD_ARCHITECTURE.md`

*Tests:* CloudMigrationConflictTests and LocalFirstContractTests must still pass (array union
unchanged). Add the probe below. ImportSourceTests unaffected.

#### IMP-03 — 16 Import from 9 sources (generic CSV column resolution)

If she imports her own spreadsheet with a column like 'Pain intensity' or 'Period
day', Caelyn reads those numbers as period flow. Every day she rated her pain 1-5
becomes a bleeding day, which wrecks her cycle lengths, averages, predictions and
triggers the irregular-cycle banner — and the preview screen says 'N period days' with
no hint which column produced them.

**Root cause.** GenericTableSource resolves columns in two passes with first-claim-wins: an exact-name
pass, then a loose `header.contains(alias)` pass walked in aliases-array declaration
order with a shared `taken` set (GenericTableSource.swift:92-97, :99-106). Field
priority is therefore declaration order, not match quality, and `flow` is the first
claimable field while owning the most generic substrings in the vocabulary — bare
"period" and bare "intensity" (:18-19). Any header merely containing those is flow's,
and the field that genuinely owns the header is locked out because the index is
already in `taken`. Two amplifiers are part of the mechanism: ImportValues.flow maps
bare digits 1-5 to flow levels (ImportValues.swift:154-175), and PredictionEngine
treats any non-nil flow as a bleeding day (PredictionEngine.swift:58-61).

**Fix.**

1. 1. Replace both passes with a single scored resolution over the full (header x
   field) matrix: score every field against each unclaimed header by best alias match
   (exact > whole-word > substring, tie-broken by alias length), then assign each
   header to its highest-scoring field. Order-independence is what makes this
   permanent — with first-claim-wins intact, every future alias addition can re-break
   it.
2. 2. Tighten the vocabulary: remove bare "intensity" from flow's aliases and require
   "period" to match as a whole header or with a flow-ish qualifier ("period flow"),
   not as a substring of "Period day"/"Period length".
3. 3. Add negative guards for the known traps: a header matching "period day", "period
   length", "cycle day", "cycle length", "pain intensity" must never resolve to flow.
4. 4. Make bare numerics suspicious for flow: when a column resolved to flow contains
   only integers and the header did not match a flow alias exactly, report it as an
   unknown column rather than importing it, so the preview tells her the column was
   skipped.
5. 5. Surface provenance in the preview: show which source column produced the period
   days (ImportPlan already carries enough to name it), so a wrong resolution is
   visible before she confirms rather than after.

*Files:* `Caelyn/Services/Import/Sources/GenericTableSource.swift`, `Caelyn/Services/Import/ImportValues.swift`, `CaelynTests/ImportSourceTests.swift`

*Tests:* ImportSourceTests.testFlowSpellingsAcrossApps unchanged (numeric mapping stays valid
for an exact 'flow' column). Add the probe below.
testUnknownColumnsAreReportedAndOtherwiseIgnored may need a new assumption line for
the skipped-numeric case.

#### IMP-04 — 17 Import preview + undo + history (ImportLedger persistence)

If Caelyn cannot read its record of what came from where — most realistically because
that file is protected while the phone is locked — it carries on as though nothing had
ever been imported, and the next thing it saves overwrites the record with just that
one entry. Settings -> Imports then says 'Nothing imported yet', no import can be
undone any more, and every imported value is treated as something she typed, so re-
importing the same file reports it as disagreeing with her.

**Root cause.** loadIfNeeded sets `loaded = true` BEFORE attempting the read
(ImportLedger.swift:218-220) and returns silently on any failure, so an unreadable
file is indistinguishable from no file. `loaded` lives on the process-lifetime
singleton ImportLedger.shared (:66) and nothing in the app's lifecycle invalidates it
(resets exist only at :203 removeAll and :254 discardUnsavedChanges), so the empty in-
memory state persists for the rest of the process. save() guards only on `loaded`
(:239-240), so the next record/release writes a file containing only the new claims.
The file is written with .completeFileProtectionUnlessOpen (:242) — class B,
unreadable while the device is locked — and HealthSyncService.syncOnForeground can
reach its first ledger access seconds after .active (HealthSyncService.swift:313-323),
after she has pocketed the phone.

**Fix.**

1. 1. Replace the `loaded` Bool with a tri-state LoadState { unloaded, absent, loaded,
   unreadable(Error) }. Distinguish absent from unreadable with
   FileManager.fileExists(atPath:) BEFORE the read, not by the read's failure.
2. 2. .absent and .loaded both permit saving. .unreadable must not: have save() re-
   attempt the load first and no-op if it still cannot read, so an unreadable ledger
   is never replaced by an empty one.
3. 3. While .unreadable, the in-memory state must not be treated as an answer either.
   Add an isAuthoritative flag and have ImportReconciler.plan
   (ImportReconciler.swift:181) decline to reconcile at all rather than see claim ==
   nil for every field and classify every already-imported value as .keepUserValue —
   which at commit would release every claim (:356-359) and make the loss permanent
   even if the file later becomes readable.
4. 4. Have HealthSyncService.syncOnForeground skip the run when the ledger is not
   authoritative and retry on the next foreground (do not advance lastForegroundSync).
   A deferred sync costs a minute; a released claim is permanent.
5. 5. Surface it once rather than lying: if the ledger is still unreadable when she
   opens Settings -> Imports, say 'Caelyn couldn't read its import record on this
   device' instead of 'Nothing imported yet'.

*Files:* `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Views/Import/ImportHistoryView.swift`

*Tests:* No ImportLedger persistence test exists — add the probe below. Add a second case
asserting that an unreadable ledger makes ImportReconciler.plan produce no decisions
rather than a .keepUserValue decision per field. HealthSyncTests unaffected.

#### IMP-05 — 16 Import from 9 sources (date parsing)

A short list of period start dates from a US app — 01/05/2026, 02/03/2026, 03/01/2026
— is read as 1 May, 2 March, 3 January instead of 5 January, 3 February, 1 March.
Nothing on the preview says which order Caelyn assumed, so she cannot catch it before
confirming. Months of cycles land in the wrong place and the predictions that follow
look perfectly plausible.

**Root cause.** detectDateFormat returns on the FIRST format that parses every candidate (`if matches
== candidates.count { return formatter(format...) }`, ImportValues.swift:94) and
'dd/MM/yyyy' precedes 'MM/dd/yyyy' in the declaration order (:17-18), so MM/dd is
never scored against the column at all — the tie is not resolved badly, it is never
observed. The partial-match path at :95 uses strictly-greater, so first-seen also wins
every partial tie. The format list is asymmetric ('MM/dd/yy' exists, 'dd/MM/yy' does
not, :20). GenericTableSource records no parsed.assumptions line for the order chosen
(GenericTableSource.swift:72-77), and ImportPreview's caveats come only from
parsed.assumptions (ImportPreview.swift:191-193), so the preview cannot be refused on
that basis.

**Fix.**

1. 1. Change detectDateFormat's return type to DetectedDateFormat { formatter:
   DateFormatter, orderAssumption: String? } so the decision can travel with the
   result.
2. 2. Remove the 100%-match early return at ImportValues.swift:94 and score every
   candidate format to completion, so ties become visible. Keep first-wins for non-
   ambiguous formats — that is what stops a timestamp being truncated by a plainer
   prefix pattern (:66-69) — and detect specifically the day-first/month-first pair
   both scoring equally and both >= `required`.
3. 3. Add 'dd/MM/yy' to dateFormats so the two-digit-year case is symmetric with the
   existing 'MM/dd/yy'.
4. 4. Break a detected tie by an injected locale with a default —
   detectDateFormat(in:calendar:componentOrderLocale: Locale = .current) — never a
   direct Locale.current read inside the function. The injection is what makes the
   behaviour testable in both directions.
5. 5. When the tie was broken by locale, set orderAssumption ('Dates like 01/05/2026
   were read as month/day.') and have GenericTableSource append it to
   parsed.assumptions (GenericTableSource.swift:72-77) so ImportPreview shows it as a
   caveat and she can decline.

*Files:* `Caelyn/Services/Import/ImportValues.swift`, `Caelyn/Services/Import/Sources/GenericTableSource.swift`, `Caelyn/Services/Import/Sources/GenericJSONSource.swift`, `Caelyn/Services/Import/ImportPreview.swift`

*Tests:* ImportSourceTests.testAmbiguousDateColumnIsResolvedByTheWholeColumnNotRowByRow still
passes (13/04 disambiguates); testCommonDateFormatsAreAccepted unchanged. Add the
probe plus a matched pair — the same ambiguous column under a US locale and a GB
locale — asserting opposite readings and the matching assumption line in each.

#### IMP-07, IMP-06 — 16 Import from 9 sources (date column / date key selection)

An ordinary cycle spreadsheet laid out 'Day, Date, Flow' — where Day is cycle day 1,
2, 3 — is rejected with 'Caelyn couldn't find any dates in that file', with a real
Date column sitting right next to the one it picked. A file with a 'last_updated'
column keys every entry to when the row was last edited instead of the day she logged
it. And in JSON exports with more than one date-like key, which key wins can change
from one launch to the next, so the same file imports different days on different
tries and the duplicate detection stops working.

**Root cause.** Both readers choose the date column by header NAME with no value validation, and
resolve ties by an order that is not a preference ranking.
GenericTableSource.dateColumn returns `headers.firstIndex(where: {
dateNames.contains(header) || header.contains("date") })`
(GenericTableSource.swift:49-54) — FILE order, which contradicts the alias-preference
contract documented at :14-15 ('date' is listed before 'day', but a file with Day left
of Date picks Day) — and the loose substring test matches 'last_updated', 'date
created', 'due date'. The value-based chooser at :56-61 is unreachable once any header
matched by name, so parse throws .noDateFound at :65-70. GenericJSONSource.dateKey
iterates `sample.flatMap({ $0.keys })` (GenericJSONSource.swift:37) — native Swift
Dictionary order, seeded per process because the bridging cast at :18-19 materialises
a native dictionary element-wise — and returns on the first match (:42). The comment
at :63-67 fixed exactly this nondeterminism for field keys and not for the date key.

**Fix.**

1. 1. Write one candidate-collecting chooser per source, used by BOTH detect() and
   parse() (they already share the function — preserve that, or detection and parsing
   can disagree). Collect ALL candidates instead of returning the first: tier 1 exact
   alias matches, tier 2 contains("date") matches with
   'update'/'updated'/'modified'/'created'/'sync' excluded, tier 3 every remaining
   column or key.
2. 2. Order deterministically within a tier: for JSON sort keys lexicographically,
   never dictionary order; for CSV keep file order, which is at least stable across
   launches.
3. 3. Validate each candidate against the sampled body with detectDateFormat /
   isoDayPrefix and take the first that validates in that precedence order. Fall back
   to the existing full value scan only when none validates.
4. 4. Demote leading qualifiers, not just trailing ones. Verified against the real
   alias table (GenericTableSource.swift:17), these all pass today's filter:
   start_date, end_date, period_end_date, updated_date, date_updated, ovulation_date,
   next_date, timestamp, date_time. An exact alias must always outrank a qualified
   one. (Note 'created_at' does NOT pass — no 'date' substring, not an alias.)
5. 5. Make the loser visible: when a column was name-matched as a date and lost, or
   was name-matched and failed validation, record it in parsed.assumptions so the
   preview names the column that actually supplied the dates.
6. 6. Apply the same deterministic ordering to GenericJSONSource.rows(in:) (:24-30),
   which also iterates object.values unsorted when searching nested containers.

*Files:* `Caelyn/Services/Import/Sources/GenericTableSource.swift`, `Caelyn/Services/Import/Sources/GenericJSONSource.swift`, `Caelyn/Services/Import/ImportValues.swift`

*Tests:* ImportSourceTests.testReorderedColumnsAreReadByNameNotPosition and
testDuplicateHeadersKeepTheLeftmostColumn must still pass.
testAFileNamingTheSameThingTwiceImportsIdenticallyEveryTime should be extended with a
second date-like key. Add both probes below.

#### IMP-17 — 16 Import from 9 sources (Apple Health route)

If she taps 'Don't Allow' on Apple's Health permission sheet, Caelyn tells her
'Nothing new to bring over — from the cycle and fertility history already stored on
your iPhone', marks Health as Connected in Settings, and offers her nothing but
'Choose a different app'. She cannot tell a refused permission from an empty Health,
and the app's own state says it is connected, so the Bring-history rows never ask
again.

**Root cause.** Two mechanisms. (a) UserProfile.healthKitConnected (Models/UserProfile.swift:13)
carries three incompatible meanings at once — the consent record 'Apple's sheet was
shown', the read/write gate (HealthKitSync.swift:33/44,
HealthSyncService.swift:157/317, HealthKitService.swift:350), and the UI status string
(SettingsView.swift:440, HealthKitConnectView.swift:75) — and
BringHistoryModel.readAppleHealth sets it from requestReadAuthorization's completion
(BringHistoryModel.swift:159-175), the one signal that provably cannot distinguish
grant from denial (HealthKitService.swift:107-114). Its 'asked' semantics are correct;
its 'Connected' rendering is a claim the code cannot support. (b)
ImportPreview.nextStep returns nil for the .read route (ImportPreview.swift:106-115)
and sourceLine asserts the history exists (:139-140), so the one genuinely ambiguous
outcome is the one outcome with no path forward.

**Fix.**

1. 1. Stop asserting history exists. Change ImportPreview.swift:140 to describe the
   action, not the device: 'Caelyn asked Apple Health for your cycle and fertility
   history on this iPhone, and nothing came back.' That states the only fact in
   evidence and is true under both a denial and an empty Health, so no future state
   can make it wrong.
2. 2. Add a neutral pointer on that one outcome: in nextStep
   (ImportPreview.swift:106-115), for .read with summary.isEmpty, return a non-
   accusatory line naming where the decision lives ('Apple Health decides what Caelyn
   can see, in Settings -> Health -> Data Access & Devices'). It must stay neutral —
   the CaelynUITests banned-copy assertion (~400-416) forbids copy directing the user
   to grant access on decline — so review the exact wording against that test.
3. 3. Separate the two meanings of the boolean without changing what it gates: keep
   healthKitConnected as the consent/gate record it already is, and add one derived
   signal (e.g. healthSawAnyData, set true the first time a read returns a sample)
   used only by the status strings, so Settings can say 'Asked — nothing read yet'
   instead of 'Connected'.
4. 4. Do not try to re-ask: HealthKit will not re-present a sheet it has already
   shown. Keep the Bring-history Health rows available rather than hiding them once
   connected, so she can re-run the read after changing permissions in Settings.

*Files:* `Caelyn/Services/Import/ImportPreview.swift`, `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`, `Caelyn/Services/HealthKitService.swift`

*Tests:* BringHistoryFlowTests.testTheHealthRouteCopyNeverMentionsAFile, plus the CaelynUITests
banned-copy case at ~400-416 which the new nextStep text must satisfy. Add a case
asserting the empty-read copy does not claim history exists on the device, and one
asserting the Settings status string is not 'Connected' when nothing has ever been
read.

#### IMP2-01, IMP-12 — 17 Import preview + undo + history (Apple Health route)

Two failures at the same handover point. First: if the save fails and everything is
rolled back, the screen tells her 'Nothing was added — everything in that import is
already in Caelyn.' She believes three years of history came across when none of it
did, closes the sheet and never retries. Second: the Health import she ran during
onboarding — often the single largest write into a new log — and the one from Settings
-> 'Import now' never appear under Settings -> Imports and can never be undone, on a
screen that says every import she has made is listed.

**Root cause.** HealthSyncService.apply computes result.succeeded for its anchor gate
(HealthSyncService.swift:241-244) and then discards it by returning only
result.summary (:245), so its one caller invents a replacement:
BringHistoryModel.swift:215 fabricates CommitResult(succeeded: true) unconditionally,
and a rollback's empty Summary (changeCount == 0) falls straight through to the
'already in Caelyn' branch. The same boundary carries provenance as an optional with a
silent default — batchID: UUID? = nil at ImportReconciler.swift:311, mirrored on apply
at HealthSyncService.swift:234 — and the batchID originates in ImportPreview.batchID,
so only the two preview-owning routes can supply it and pair it with addBatch
(ImportPlanner.swift:245-255, BringHistoryModel.swift:201-214). The non-preview entry
points run (:261) and runInitialImport (:288) inherit nil with no compiler or runtime
signal.

**Fix.**

1. 1. Widen the return type: apply, run and runInitialImport all return
   ImportReconciler.CommitResult instead of Summary (HealthSyncService.swift:245,
   :261, :291). Stop projecting .summary at the boundary.
2. 2. Delete the fabricated CommitResult at BringHistoryModel.swift:215 and branch on
   the real one, so a rolled-back Health confirm reaches the same honest failure copy
   the file route already shows ('Caelyn couldn't save that import, so nothing was
   changed.').
3. 3. Branch HealthKitConnectView.runImport (HealthKitConnectView.swift:394-395) on
   succeeded before showing .success(...) — today a rollback shows a success banner
   there too.
4. 4. Replace the defaulted batchID with a non-defaulting enum parameter,
   ImportLedger.BatchIntent { case record(name: String), none(reason: Reason) }, on
   apply/run/runInitialImport, so no future route can inherit a silent nil. The
   incremental foreground sync (HealthSyncService.swift:321) passes .none(reason:
   .incrementalSync).
5. 5. Give ImportLedger a recordBatch(for:summary:) that owns the rule 'a user-visible
   import becomes a batch', and call it from the Settings 'Import now' route
   (HealthKitConnectView.swift:391-396) and the onboarding route
   (OnboardingSteps.swift:965).
6. 6. Land the screen's promise with the code: give the Settings -> Imports row a
   count detail (SettingsView.swift:500-506, currently detail: nil) so the list's
   completeness is visible at a glance.

*Files:* `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* HealthSyncTests callers that compare apply/run against a Summary need `.summary`
appended. New BringHistoryFlowTests case for a rolled-back Health confirm — it needs a
seam for a failing context.save() (an injectable context, or a model the save will
reject). New assertions that run and runInitialImport each add exactly one
ImportLedger batch. Note: imports already made before this ships cannot be
reconstructed and stay unlisted.

#### IMP2-03 — 17 Import preview + undo + history (undo exactness)

She imports Clue, then imports a corrected re-export of the same data. She doesn't
like the second one and undoes it — and instead of going back to what the first import
showed, those days go blank. The first import is still listed as undoable but now owns
nothing, so undoing it afterwards silently does nothing. The dialog she agreed to said
Caelyn would remove what this import added; what it removed was the first import's
data.

**Root cause.** ImportLedger.record keeps exactly one claim per day+field and overwrites the previous
one, dropping the displaced record entirely (ImportLedger.swift:130-154). Undo's only
available action is .clear (ImportPlanner.swift:284-292), so with the earlier claim
gone the field is emptied rather than restored. The collision is designed, not
incidental: ImportRecordID.make hashes source+day+field and excludes the value
precisely so a corrected re-export updates in place (ImportRecordID.swift:19-30) —
which also means the recency gate at ImportReconciler.swift:209-214 is short-circuited
by its own `claim.recordID != observation.recordID` condition and can never block a
same-source re-import.

**Fix.**

1. 1. Make the value persistable: `extension ImportObservation.Value: Codable {}` —
   synthesizable, every payload is already Codable
   (Caelyn/Models/Enums.swift:3,28,123,145,159,190,239).
2. 2. Add a flat snapshot type ImportLedger.Displaced { recordID, sourceBundleID,
   sourceName, batchID: UUID?, recordedAt: Date?, importedAt: Date, value:
   ImportObservation.Value, importedValue: String } and on Claim a `var displaced:
   [Displaced]?` — Optional, NOT a defaulted non-optional, so an existing 1.3 ledger
   still decodes (Claim already decodes forward-compatibly; recordedAt and batchID
   were added this way, ImportLedger.swift:39-43).
3. 3. In record(), when a claim is replaced, push the outgoing claim onto the new
   claim's displaced stack, newest first, capped at ~8 with the tail dropped so
   repeated re-imports cannot grow the file without bound.
4. 4. Give undo a second action besides .clear: .restore(value:). For each claim in
   the batch whose stored value still matches, if displaced.first exists and its batch
   is still in batchList, emit a restore that writes the displaced value and
   reinstates that claim with its own displaced tail; otherwise emit .clear as today.
5. 5. Handle .restore in ImportReconciler.commit alongside .fill/.update — it writes a
   value and records a claim, so it must use the same pendingClaims path and the same
   stale re-check against the live row (:320-345), or an undo could overwrite
   something she logged while the dialog was up.
6. 6. Make ImportHistoryView honest for the case restore cannot cover
   (ImportHistoryView.swift:62-64): a batch whose claims were all displaced by a later
   batch must not promise to remove what it added.

*Files:* `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/Import/ImportPlanner.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportRecordID.swift`, `Caelyn/Views/Import/ImportHistoryView.swift`, `Caelyn/Models/Enums.swift`

*Tests:* GlowEveTests.testUndoRemovesOnlyEveAndSparesLaterEdits,
GlowTests.testUndoRemovesOnlyGlowAndSparesLaterEdits,
NaturalCyclesTests.testUndoRemovesOnlyThisImportAndSpareLaterEdits and the
PeriodTrackerGPApps undo cases must keep passing unchanged (no displaced stack in
those scenarios). Add the probe, plus a decode test that a 1.3-era ledger JSON with no
`displaced` key still loads with full provenance.

#### IMP2-04, IMP-13, IMP-14 — 16 Import from 9 sources (Caelyn backup round trip)

The sentence she reads before restoring her own Caelyn backup says 'Everything comes
back exactly as you had it.' It doesn't. Every symptom's severity comes back as
'moderate' — including the severe months that were the reason she was tracking. Note
reminders don't come back at all. Notes come back only if that toggle happened to be
on when she exported. A custom symptom she named 'Jaw, neck tension' comes back as two
separate symptoms. And by default the file only holds the last three months. This is
the sentence someone reads before trusting a backup enough to wipe a phone.

**Root cause.** The owned CSV format is defined by three hand-maintained lists with nothing derived
from the model, and the guide's promise is a fourth independent artifact bound to none
of them: the header literal plus field-append block in ExportService.generateCSV
(ExportService.swift:67-93), CaelynExportSource.knownColumns defined circularly as
'what generateCSV writes today' (CaelynExportSource.swift:16-20), and the importer's
parse. symptomSeverity was added to CycleEntry in 214338a and the header literal
rewritten four days later in 89ab965 without it, and nothing failed — so
CaelynExportSource.swift:87 can only hardcode .symptomSeverity(2). Separately, multi-
value cells have no reversible encoding: names are accepted as unconstrained free text
(DailyLogForm.swift:557-563 trims whitespace only), joined with a bare ';' under
RFC-4180 cell escaping that protects the comma from the CSV grammar but not from the
list grammar (ExportService.swift:90,100-104), then read back through the tolerant
foreign-file splitter that splits on ';' '|' AND ',' (ImportValues.swift:350-354). And
ExportView.swift:10 defaults range to .last3Months, so the 'backup' is usually a
slice.

**Fix.**

1. 1. Make a backup actually be a backup first — no wording can be made true until it
   is. Add a distinct full-backup action in ExportView that pins range: .all and
   includeNotes: true instead of inheriting the .last3Months default at
   ExportView.swift:10.
2. 2. Close the column gaps in generateCSV and mirror them in
   CaelynExportSource.knownColumns + parse: a `symptom_severity` column written as
   `cramps:3;bloating:1;custom:jaw tension:2`, plus `note_reminder_rule`,
   `note_reminder_at`, `note_reminder_done`. Import with fallback 2 for older files
   and add a caveat line naming the loss for those files.
3. 3. Make the custom-symptom path carry a level, or the severity fix breaks ownership
   and undo: add `case (.customSymptom(let name), .symptomSeverity(let level))` to
   CycleEntry.apply before the catch-all at ImportReconciler.swift:497; change
   value(for: .customSymptom) at :472 to return
   .symptomSeverity(symptomSeverity["custom:\(name)"] ?? 2) so ledger and stored
   values speak one vocabulary; have clear at :521-523 drop the matching severity key.
4. 4. Establish the invariant 'a value never contains the separator' where values are
   created, not where they are read: in commitAddSymptom (DailyLogForm.swift:557-563)
   strip or reject ';' and '|' from the trimmed name, and apply the same rule to any
   other free-text value written into a list cell.
5. 5. On the owned format, stop using the tolerant splitter: in
   CaelynExportSource.swift:77-91 use raw.split(separator: ";") for custom_symptoms.
   Leave ImportValues.splitList untouched for foreign sources, where tolerance is
   correct.
6. 6. Export the custom-symptom catalog (UserProfile.customSymptoms), so restored
   names have a definition to render against — pairs with the DailyLogForm union fix
   (IMP-15).
7. 7. Bind the promise to the format permanently: derive knownColumns and the export
   header from one list, rewrite the ImportSourceGuide.caelyn.note sentence
   (ImportSourceGuide.swift:238-251) to state what the file actually holds, and add a
   test that fails when CycleEntry gains a persisted field absent from that list.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Services/Import/Sources/CaelynExportSource.swift`, `Caelyn/Views/Import/ImportSourceGuide.swift`, `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Services/Import/ImportValues.swift`

*Tests:* Extend ImportSourceTests.testCaelynExportRoundTripsEveryField to assert severity, note
reminders, and a custom name containing both ',' and ';'.
testNewerColumnsInACaelynExportAreReportedNotDropped updates as knownColumns grows.
Any case asserting imported symptoms arrive at severity 2 must change.
BringHistoryFlowTests.testGuideCopyStaysOutOfTechnicalLanguage and
testEverySourceGuideExplainsHowToGetTheFile still pass. Old exports must keep
importing — CaelynExportSource requires only a date column and reports unknown columns
as unmapped.

#### LC-02, LC2-08 — RootView.storeWarningBanner / Persistence.storeMode / demo-mode gating

Two faces of one wrong banner. If Caelyn ever has to fall back to memory-only storage,
it tells her it "started fresh" and to back up from Export — when in fact nothing she
logs that session will survive closing the app, and Export has nothing to export. And
because the banner is driven by a sticky saved flag rather than by what happened this
launch, an App Store screenshot run can come up with a red "Caelyn couldn't open your
saved data" alert across the top of the hero shot.

**Root cause.** The banner renders from a persisted, process-global boolean instead of the in-process
truth of how THIS launch's store opened. `Persistence.storeMode` is written at
Persistence.swift:140 (.recoveredFresh) and :148 (.inMemory) and read NOWHERE — a full
grep returns only the declaration (:93-94) and the two writes. Both branches set the
same boolean `storeFailedKey` (:141, :149), and RootView seeds `@State
showStoreWarning` straight from it (RootView.swift:8) with one fixed string for both
modes (:72-74, :98). Two consequences follow from that single substitution: (a) the
in-memory case gets copy that is false twice — the store is volatile, not fresh, and
ExportView disables Generate while filteredEntries is empty; (b) the flag outlives the
process that wrote it and is only ever cleared by the user tapping × or by a wipe — a
successful open never clears it — while `Persistence.live` is never even constructed
under --screenshot-mode / --screenshot-paywall / --ui-test-onboarding
(CaelynApp.swift:24-27, :67-71), so a previous real run's failure decides what a
capture run renders. `Persistence.isDemoStore` (:58-62) is the predicate that would
exclude those runs and was never wired here (the same leak class as commit d0b31aa).

**Fix.**

1. 1. Put the question in Persistence, next to the facts that answer it: `static var
   shouldWarnAboutStorage: Bool { guard !isDemoStore else { return false }; return
   UserDefaults.standard.bool(forKey: storeFailedKey) }` and `static func
   acknowledgeStorageWarning() { UserDefaults.standard.set(false, forKey:
   storeFailedKey) }`. No view reads the raw key again.
2. 2. Make the mode readable and render three distinct banners. `storeMode` is already
   internal `private(set) static` on an app-module type, so RootView can read it today
   with no access change — snapshot it into @State alongside the flag read at
   RootView.swift:8 rather than reading the static inside `body`, so the banner does
   not depend on static-evaluation timing. Ordering is already safe for that initial
   read because CaelynApp's syncCoordinator initializer touches Persistence.live at
   App-struct init.
3. 3. Write the three strings so they are not interchangeable: .ok → no banner;
   .recoveredFresh → today's copy (previous data kept aside, back up from Export);
   .inMemory → "Caelyn can't save to this iPhone right now. Anything you log will be
   lost when you close the app." and NO Export advice.
4. 4. Route the banner's × through `acknowledgeStorageWarning()`
   (RootView.swift:104-107).
5. 5. Do NOT clear storeFailedKey on a healthy open as a separate half-measure — step
   1's demo gate plus step 2's mode render is what makes the banner honest; a success-
   clears rule would hide a real recovered-fresh state from a user who has not yet
   seen it.
6. 6. Why permanent: the banner stops being a function of a flag that can outlive its
   cause and becomes a function of this launch's actual store mode, and the demo
   exclusion lives in the one predicate every capture-aware surface already uses.

*Files:* `Caelyn/Views/RootView.swift`, `Caelyn/Services/Persistence.swift`, `Caelyn/Views/Settings/ExportView.swift`

*Tests:* Add a unit test that each StoreMode maps to distinct, non-interchangeable banner copy
(assert the three strings differ and that the .inMemory copy contains no "Export").
Add a unit test that Persistence.isDemoStore is true for each of --screenshot-mode,
--screenshot-paywall and --ui-test-onboarding, and that shouldWarnAboutStorage is
false under each even with storeFailedKey set. Add a ScreenshotTests assertion that
the storage banner text is absent. No existing test asserts on the banner.

#### LC-05 — MainTabView.onChange(of: router.pendingCategory) / NotificationRouter

When she taps a Caelyn reminder while the app is closed — the most common way a
reminder gets tapped — it opens on whatever tab she was last on instead of the one the
reminder is about. Medication and birth-control reminders are supposed to land her on
the Log screen; she has to go find the field herself.

**Root cause.** Two halves of one mechanism. (a) Consumption is edge-triggered while the value is
level-set: `AppDelegate.didReceive` sets `NotificationRouter.shared.pendingCategory`
during launch (AppDelegate.swift:33-45, NotificationRouter.swift:27-29), but the only
readers are `.onChange` modifiers at MainTabView.swift:82-84 and :123-125 with the iOS
17 default `initial: false` — and MainTabView cannot exist yet, because RootView gates
it behind two dedupe passes and a 120 ms sleep (RootView.swift:46-60). Nothing reads
the pending value on appear; `consumePending()` (NotificationRouter.swift:31-35) was
written for exactly this and has no caller. (b) Clearing is coupled to the handler
running: `pendingCategory = nil` lives inside `handlePendingCategory`
(MainTabView.swift:146), so a value that never reaches the handler latches and can
fire later on an unrelated change.

**Fix.**

1. 1. Extract one `private func pendingRouting<V: View>(_ v: V) -> some View` (or a
   small ViewModifier) applied by BOTH `ipadLayout` and `iPhoneLayout`, so the two
   call sites cannot drift.
2. 2. In it: `.onChange(of: router.pendingCategory, initial: true) { _, _ in
   handlePendingCategory(router.consumePending()) }` — level-triggered, and reading
   through `consumePending()` instead of nil-ing inline at MainTabView.swift:146 moves
   the reset into the router, which makes the latch in (b) structurally impossible
   rather than incidentally fixed.
3. 3. Add a defensive drain independent of the observer: call
   `handlePendingCategory(router.consumePending())` from MainTabView's
   `.task`/`.onAppear`, so routing does not depend on observation timing at all.
4. 4. Remove the inline `pendingCategory = nil` at MainTabView.swift:146.
5. 5. Why permanent: the router becomes the only place the value is cleared, and the
   view reads the current level on appear rather than waiting for a transition it
   structurally cannot witness.

*Files:* `Caelyn/Views/MainTabView.swift`, `Caelyn/Services/NotificationRouter.swift`, `Caelyn/App/AppDelegate.swift`

*Tests:* No existing test covers routing. Add the hosted-view probe below as a regression test
(it fails on current code), plus a unit test that consumePending() returns the value
once and nil thereafter.

#### LC-06 — CloudSyncCoordinator.reconcileArrivedRecords (+ unsorted UserProfile fetches)

On a second device, the settings she just chose during setup — App Lock, her
reminders, her theme — vanish a few seconds later when her synced profile arrives, and
App Lock silently turns itself off mid-session. Everything comes back at the next
launch, with nothing to explain what happened.

**Root cause.** The "exactly one UserProfile" invariant has no enforcing accessor — only a repair
pass, and that pass is bound to a view's identity. `ProfileStore.dedupe` runs only in
RootView's launch `.task` (RootView.swift:44-53), which runs once per process because
RootView is never remounted (AppLockGate hides content with opacity at :28-29 rather
than removing it). Meanwhile the one mechanism that can create a second row MID-
SESSION — CloudKit delivery into the mirrored store (Persistence.swift:21, 105-109) —
is handled by a different pass that reconciles entries only:
`CloudSyncCoordinator.reconcileArrivedRecords` calls just `CycleStore.dedupeSameDay`
(CloudSyncCoordinator.swift:73-83). Compounding it, readers are split between two
selection rules with nothing pinning them together: sorted `@Query(sort:
\UserProfile.createdAt).first` in views versus unsorted `.first` in six service
fetches (including HealthKitSync.swift:32 and :43), so during the two-row window
different subsystems can read different profiles.

**Fix.**

1. 1. Introduce `LaunchPass.reconcile(in: ModelContext)` that runs
   `CycleStore.dedupeSameDay` then `ProfileStore.dedupe`, and make it the single entry
   point called by BOTH RootView's `.task` and
   `CloudSyncCoordinator.reconcileArrivedRecords`.
2. 2. Call it BEFORE `refreshDerivedSnapshot` so CloudSyncCoordinator.swift:91 builds
   the widget snapshot from the already-collapsed single row.
3. 3. Add `ProfileStore.current(in:)` returning the oldest-by-createdAt row, and
   replace all six unsorted `.first` fetch sites with it — including
   HealthKitSync.swift:32 and :43 — so services and screens select by the same rule
   even in the window before a reconcile lands.
4. 4. Audit for any other mid-session row creator (onboarding completing while an
   import is in flight) and route it through `ProfileStore.current(in:)` + insert-if-
   absent rather than a bare insert.
5. 5. Why permanent: the merge pass stops being owned by a view's lifetime and becomes
   part of the record-arrival contract, and every reader selects by one rule, so a
   transient second row can no longer change which profile a subsystem sees.

*Files:* `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Services/Health/HealthKitSync.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* ProfileStoreTests gains "the sync pass merges profiles" (probe below fails on current
code). Add a test that ProfileStore.current(in:) returns the oldest row when two
exist, and update any service test that relied on an unsorted first.

#### LC2-05 — Launch — cloud deletion guards (CloudDataDeletion.resolveOutstandingDeletion)

Once any one of her devices has deleted the iCloud copy, that device re-asserts the
deletion on every single launch and re-stamps it with today's date. So she can never
turn sync back on anywhere else: she enables it on the iPad, it appears to work, and
then it silently switches itself off again and destroys the copy she just built — with
nothing in the UI to explain why.

**Root cause.** Two independent mechanisms. (1) The re-assertion path IS the original deletion path:
`resolveOutstandingDeletion` (CloudDataDeletion.swift:157-167) delegates to
`deleteCloudCopy`, so re-ENFORCING a past decision also re-RECORDS it — both success
branches do `let deletedAt = Date()`, write it to `deletedAtKey` (:123-124, :136-137)
and call `CloudDeletionTombstone.write(deletedAt:)` (:130, :140) — and re-executes the
destructive zone delete (:121) against a zone another device may now legitimately own.
Because the recorded instant advances to today on every launch, it always out-ranks
another device's later deliberate consent in `CloudDeletionTombstone.verdict`'s
ordering. (2) The local latch `deletedAtKey` has exactly one retirement path — this
device's own sync toggle (AccountView.swift:265 → clearDeletionMarker, :172-175). No
remote signal can retire it, so a consent recorded on another device cannot stand it
down. Side cost: a CloudKit account-status call, two zone deletes and two record
writes on every launch of that device, forever.

**Fix.**

1. 1. Freeze the recorded instant: in both branches (CloudDataDeletion.swift:123 and
   :136) use `let deletedAt = (defaults.object(forKey: deletedAtKey) as? Date) ??
   Date()`. This restores the invariant `verdict`'s ordering depends on — the deletion
   instant is immutable once set, so no re-assertion can out-rank a later deliberate
   consent elsewhere.
2. 2. Make the tombstone write idempotent: skip `CloudDeletionTombstone.write` when
   the date already equals the one in `deletedAtKey`. With step 1 this is otherwise a
   no-op write; it saves the per-launch round trip.
3. 3. Separate re-assertion from deletion. Give `resolveOutstandingDeletion` its own
   path that does NOT call the full `deleteCloudCopy`: when `deletedAtKey` is set and
   sync is off, only verify the zone is absent (and only delete if it is present),
   never re-record and never re-write the tombstone. Destructive work must not be a
   side effect of enforcement.
4. 4. Give the latch a remote retirement path: when a fetched tombstone carries a
   `syncConsent` newer than the frozen `deletedAt`, clear `deletedAtKey`/`pendingKey`
   on this device. Today only AccountView.swift:265 can retire it, which is why one
   device vetoes all.
5. 5. Make the stand-down visible: when `honourRemoteDeletionIfNeeded` switches sync
   off, surface a one-time notice naming the reason, so the iPad's self-disabling sync
   is explicable rather than mysterious.
6. 6. Why permanent: the deletion record becomes immutable and the enforcement path
   becomes non-destructive and non-recording, so the three behaviours (record /
   enforce / consent) stop being the same code path.

*Files:* `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Services/Account/CloudDeletionTombstone.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* testADeletedCloudCopyIsNotAllowedToComeBackOnItsOwn and
testAPendingDeletionIsRetriedAtLaunch still pass (an outcome is still returned and the
marker still stands). testFreshConsentBeatsAnOlderTombstone must be re-checked against
the frozen date. Add testReAssertingADeletionDoesNotMoveTheRecordedDate (probe below)
and testRemoteConsentNewerThanTheFrozenDeletionRetiresTheLocalLatch.

#### LC2-06 — Store failure ladder (Persistence.live)

The one situation iCloud sync exists to survive — the copy on this phone going bad —
is the situation in which Caelyn does not use it. After a corrupt-store recovery the
app opens as a brand-new LOCAL-ONLY store even though sync is on, so nothing is pulled
down from her intact iCloud copy. She sees an empty history and a red error telling
her to start backing up, with no hint her data is recoverable — and many users will
re-onboard from scratch, turning a recoverable incident into permanent loss.

**Root cause.** Two mechanisms. (a) `cloudKitDatabase` is baked into the single `localConfig` constant
as `.none` (Persistence.swift:98) and every rung after step 0 reuses that constant, so
mirroring is a property of rung 0 rather than of the launch; step 3's in-memory last
resort is `.none` too. (b) The ladder conflates two independent questions — "can we
mirror?" and "is this file readable?" — into one ordered sequence: step 0 is
simultaneously the only mirrored attempt AND the only attempt against the OLD file, so
its `try?` (:109) cannot distinguish an iCloud-unavailability failure from a file
failure. A genuinely corrupt store therefore fails steps 0 and 1 for the same reason,
consumes the one mirrored rung, and reaches step 2, which preserves the file aside and
opens fresh with `.none`. `isSyncActive` is false for the whole session and the banner
(RootView.swift:96-99) gives advice for protecting data she may still have.

**Fix.**

1. 1. Hoist the decision out of the constant: `let cloudDB:
   ModelConfiguration.CloudKitDatabase = isSyncEnabled ? .private(cloudKitContainerID)
   : .none`, and build every rung's ModelConfiguration from it.
2. 2. Set `isSyncActive` and call `noteCloudCopyMayExist()` from whichever rung
   actually opens, not only from rung 0 (Persistence.swift:112-116).
3. 3. On the recovery rung (step 2), try the mirrored fresh store first; if it fails,
   fall back to `.none` AND leave `isSyncActive` false so `statusLine` keeps saying
   "Waiting to start" rather than claiming a cloud copy.
4. 4. The in-memory rung must stay `.none` and must force `isSyncActive = false`, so
   the UI never claims a cloud copy for a container that cannot have one.
5. 5. Add a fourth banner state on top of the LC-02/LC2-08 item: recovered-fresh-and-
   mirrored should say her iCloud copy is being restored, not that she should start
   backing up.
6. 6. Why permanent: mirroring becomes a property of the launch rather than of one
   rung, so no future rung added to the ladder can silently drop it.

*Files:* `Caelyn/Services/Persistence.swift`, `Caelyn/Views/RootView.swift`

*Tests:* CloudSyncSafetyTests.testTheSyncedStoreIsStillAnOnDiskLocalStore pins URL equality of
the two configurations and still holds. Add a test that, given isSyncEnabled, the
configuration used on the recovery rung is a `.private` one (extract the ladder's
configuration-building into a pure function so it is testable without opening a
store), and a test that the in-memory rung leaves isSyncActive false.

#### MODES-01, MODES-09, MODES-13 — 22 Irregular cycle mode · 28 Specialist modes — PCOS / Perimenopause

The Irregular, PCOS and Perimenopause switches change none of the numbers. A woman
with 50-day cycles is told her average is 45, that her period is twelve days late
every single month, and that she has "missed or skipped" periods; and in gentle mode
the Home screen warns that her 40-day cycles are "sometimes associated with conditions
like PCOS" while the in-app guide, in the same session, calls the exact same cycles
"In a common range".

**Root cause.** There is no seam through which any mode can reach the derivation. CycleModel.make
(/Users/smile/Desktop/caelyn/Caelyn/Models/CyclePrediction.swift:209-248, verified)
takes the profile but reads only averageCycleLength, averagePeriodLength and
lastPeriodStart, and the struct stores no profile reference and no posture field — so
every surface that consumes CycleModel is mode-blind by construction. The mode-
sensitive answers are all parameterless computed properties over pure functions with
no mode input: `confidence` (:262) is PredictionEngine.confidence(cycleCount:), a
switch on count alone; `irregularStatus` (:264) is irregularCycleStatus(from:)
(PredictionEngine.swift:397), whose thresholds are the literals 45 / 7 / 35 / 21
(:408-421, verified); `clampCycleLength` hard-codes `min(45, max(18, v))` (:131) and
is applied to both the learned mean and the fallback (:117, :119); `isPeriodLate`
fires at expected+1 day with no grace term and ignores the variation the model already
computed (CyclePrediction.swift:357-360, verified). Meanwhile TypicalRanges keeps a
SECOND, mode-aware copy of the same numbers (TypicalRanges.swift:40-55, 77-87), which
is why the banner and the guide can contradict each other about identical cycles. The
data-entry range is capped too — `Array(18...45)` in both CycleSettingsView.swift:12
and OnboardingSteps.swift:326 — so a PCOS user cannot even declare her real average.

**Fix.**

1. 1. Define one `CycleNorms { cycleLo: Int, cycleHi: Int, variationCap: Int,
   lateGrace: Int }` as the single source of the thresholds, with a static factory
   taking the profile's gentle / irregular / pcos / perimeno flags. Delete the
   duplicated literals from PredictionEngine.swift:408-421 and the parallel table in
   TypicalRanges.swift:40-55, 77-87 — TypicalRanges must take a CycleNorms instead of
   a bare `gentle` Bool.
2. 2. Open the seam: add `norms: CycleNorms` (and a `posture` enum if the copy needs
   it) to CycleModel, computed inside make() from the profile it already receives
   (CyclePrediction.swift:219-220), and stored on the struct. Permanent for the reason
   the type's own doc comment at :127-158 gives — one derivation that no future
   surface can bypass.
3. 3. Thread it: `CycleModel.irregularStatus` (:264) passes norms into
   `irregularCycleStatus(from:norms:)`; `clampCycleLength(_:norms:)` becomes
   `norms.cycleLo…norms.cycleHi` (90 for pcos/perimeno) and is consumed at
   PredictionEngine.swift:117 and :119; `confidence` takes the posture so
   irregular/perimenopause mode genuinely lowers it.
4. 4. Make both sides evaluate the SAME number so they cannot disagree: have
   irregularCycleStatus classify using the same windowed average TypicalRanges is
   shown, and add a test asserting that for any cycle set,
   `TypicalRanges.cycleLength(avg, norms:).status == .inRange` implies irregularStatus
   is not .longCycles/.shortCycles.
5. 5. Give lateness a grace term for EVERY user, not just the mode cohorts:
   `isPeriodLate = today > expected + max(variation, norms.lateGrace)`. This is the
   right default for anyone with a variable cycle and is what stops the "period 12
   days late" every month.
6. 6. Widen the data-entry range in both places (CycleSettingsView.swift:12 and
   OnboardingSteps.swift:326) to `18...norms.cycleHi`, so a PCOS user can state her
   real average.
7. 7. Honour the "and surfaces insights" half of the promise: gate an irregular-mode
   insight on irregularModeEnabled in PatternEngine.conditionInsights
   (PatternEngine.swift:393-425), or delete that clause from
   CycleSettingsView.swift:225. Narrow the perimenopause copy edit to the final clause
   of :265 only — the chips and insights it promises already work.
8. 8. Land MODES-03's ceiling first, or the relaxed cap and the excluded gap-cycle
   will be indistinguishable in test output.

*Files:* `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Services/TypicalRanges.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`, `Caelyn/Services/PatternEngine.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`

*Tests:* Add CycleModel norms/posture tests beside CaelynTests.swift:1398
(testNoIrregularityWarningFromAForgottenLog). Add a PCOS 55-day fixture asserting
average 55 and not late. Extend CaelynTests.swift:1034-1044 (TypicalRanges) and
:1398-1433 (irregularity) with the agreement invariant from step 4.
CaelynTests.swift:862-863 (averages) must be re-checked: any fixture relying on the 45
clamp changes. Widget parity tests (CaelynTests.swift:671, 684, 1301, 1342) are
unchanged unless periodWindowText's format changes.

#### MODES-02, MODES-12 — 28 Specialist modes — Pregnancy / Postpartum

While she is pregnant, Caelyn keeps telling her that her period is late — on the Home
screen, in the calendar, on her lock-screen widget and as push notifications — right
beside a "Week 14 · Trimester 2" card. And when she ends the mode, including after a
loss, the first thing she sees is "Caelyn hasn't seen your period this cycle" and a
predicted period shaded in from a months-old date.

**Root cause.** Life stage lives as two Bools on UserProfile
(/Users/smile/Desktop/caelyn/Caelyn/Models/UserProfile.swift:59, 62) and their only
consumers are the extra Home card (HomeView.swift:231-237) and the extra symptom chips
(DailyLogForm.swift:350-355). CycleModel.make (CyclePrediction.swift:209-248,
verified) never reads them, so cycle derivation is never suspended. The contradiction
is made permanent by the anchor, not merely by the outputs:
PredictionEngine.nextPeriodStart (:180-194, verified) rolls the stale pre-pregnancy
anchor forward indefinitely in a loop capped at 3650 iterations, so nextPeriodStart is
never nil, which keeps predictedPeriodWindow / ovulationEstimate / fertileWindow /
pmsWindow alive (CyclePrediction.swift:295-325) and keeps daysLate climbing without
bound. Ending the mode sets only the Bool (CycleSettingsView.swift:416-419) while the
dialog promises "Caelyn quietly returns to cycle tracking" (:422) — but there is no
"awaiting first period" state, so the anchor is still the last pre-pregnancy bleed and
isPeriodLate (CyclePrediction.swift:357-360) is immediately true with daysLate > 300.

**Fix.**

1. 1. Add a derived `lifeStage` to CycleModel, computed in make() from the profile —
   do not add a stored field here; the stored life stage is MODES-04/MODES-05's and
   this item must consume it.
2. 2. While the stage is pregnant or postpartum, treat the anchor as ABSENT at
   CyclePrediction.swift:224-233. That single change nulls nextPeriodStart,
   expectedPeriodStart, predictedPeriodWindow, ovulationEstimate, fertileWindow and
   pmsWindow, makes isPeriodLate false, and makes hasPrediction false — which silences
   Home, Calendar, Widget, Watch, Notifications and the PDF at once, because every
   consumer traced reads those six optionals plus `phase`.
3. 3. Add `CyclePhase.paused`. It is a new case in a type with exhaustive switches in
   at least HomeCopy.phaseHeadline (HomeCopy.swift:52-69), the ring/colour mapping and
   the widget copy — enumerate and handle every one, or the build breaks in places
   this list does not name. Set irregularStatus to .insufficient while paused.
4. 4. Apply the pause regardless of PurchaseService.isPro. A lapsed subscriber must
   not start receiving period predictions mid-pregnancy; this is correctness, not a
   premium feature (see MODES-06).
5. 5. Logged flow must still record normally — pause the derivation only, never a
   write. The local-first principle means nothing about a mode may block or discard a
   log entry.
6. 6. For the END of a stage, add an "awaiting first period" state rather than
   resuming from the old anchor: when a stage ends, the stored episode-end date (from
   MODES-04/05) becomes the floor, and the model stays in `.paused`/no-prediction
   until a new bleed is logged after that date. Then predictions restart from the new
   anchor.
7. 7. Reword the end-of-pregnancy dialog (CycleSettingsView.swift:422) to match:
   Caelyn waits for her next period rather than claiming to resume tracking
   immediately. This is the copy a woman sees immediately after a loss — write it
   accordingly.
8. 8. Cancel period and ovulation notifications on the transition into a paused stage,
   since NotificationService schedules from the model (it will now see nil, but the
   already-scheduled ones must be flushed by a sync).

*Files:* `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Views/Calendar/CalendarMath.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* New CycleModel lifeStage tests: pregnant profile → nextPeriodStart nil, isPeriodLate
false, fertileWindow nil, phase == .paused. Widget tests CaelynTests.swift:1301 and
:1342 need a pregnant-profile variant asserting no "Period in N days" line. UI test
CaelynUITests.swift:588-638 should assert the hero headline no longer contains "period
may start" after enabling pregnancy, and that after "I gave birth" plus turning
postpartum off there is no late prompt.

#### MODES-04, MODES-05 — 28 Specialist modes — Pregnancy / Postpartum / mutual exclusivity

Life-stage settings remember the wrong things and can contradict each other. A second
pregnancy opens on "Past your due date — switch to Postpartum" because the old due
date was never cleared; a second baby shows "26+ weeks postpartum · Recovery window
complete" on day one; and if she uses two devices she can end up pregnant and
postpartum at the same time, with both cards on the Home screen, or pregnant with a
fertility score beside it.

**Root cause.** Life stage is not a mode at all — it is three independent additive Bools plus two
Dates, with no setter, no invariant and no reader obligation. (a) The dates are
written only under an `== nil` guard on the ENABLE side (CycleSettingsView.swift:397,
411, 471) while all three episode-ending transitions mutate only the Bools (:409-414,
:417-418, and the raw `$profile.postpartumEnabled` toggle at :453 whose onChange at
:466-476 has no disable branch). Nothing in the codebase ever assigns nil to either
date, so the `== nil` guard can only ever be true on the very first episode and every
later enable silently inherits the previous episode's date. (b) Exclusivity lives in
two `.onChange` closures bolted to Toggles (:391-402, :466-476), two-parameter
onChange with no `initial:`, so they only run while that screen is on screen and
cannot repair a state they did not cause. ProfileStore.merge is a legitimate non-UI
writer and ORs the flags (ProfileStore.swift:70-71) — correct for additive data, fatal
for a mutually exclusive one — so deduping device A (pregnant) with device B
(postpartum) yields both true, and no onChange ever fires to fix it. TTC and birth
control are never made exclusive with pregnancy at all.

**Fix.**

1. 1. Make the stage stored truth, not a computed view over two Bools — a computed
   getter still has to answer "what is the stage when both are true", and the merge
   still has two fields to corrupt. Add `lifeStageRaw: String = "cycling"` and
   `lifeStageSetAt: Date?` to UserProfile, keeping pregnancyEnabled/postpartumEnabled
   as deprecated mirrors written ONLY by the new setter, so 1.3 clients and any
   unmigrated reader keep working.
2. 2. Add the single entry point `UserProfile.setLifeStage(_:)` taking an enum
   (`.cycling`, `.pregnant(due: Date)`, `.postpartum(birth: Date)`). It is the only
   writer of lifeStageRaw, the two mirror Bools and the two dates, and it sets
   lifeStageSetAt.
3. 3. CLEAR on the end transitions, do not re-seed on enable. `.cycling` clears both
   dates; `.postpartum(birth:)` clears pregnancyDueDate; `.pregnant(due:)` clears
   postpartumBirthDate. Ending an episode is already an explicit confirmed user action
   (the dialog at CycleSettingsView.swift:401-424), so clearing there is consent-
   backed. Do NOT adopt "on enable always write the default" — a user who toggles off,
   picks a dialog option, then re-enables within the same pregnancy would have her
   real due date silently replaced by today+280, which is a new data-loss path.
4. 4. Keep the `== nil` seed on enable, which is now correct because step 3 guarantees
   nil at the start of every episode; and show the date picker immediately on enable
   so the seeded default is visible and correctable.
5. 5. Make exclusivity structural: setLifeStage sets exactly one stage, and TTC must
   be made exclusive with pregnancy and postpartum in the same setter (today a
   pregnant user with TTC on sees "Fertile window in 23 days" beside the Pregnancy
   card, HomeView.swift:227-233).
6. 6. Fix ProfileStore.merge (ProfileStore.swift:48-79): replace the OR of the two
   Bools with newest-wins on lifeStageSetAt, resolving to a single stage. This is the
   one place in merge that must NOT be additive, and it needs a comment saying why,
   because the file's whole convention is union-on-purpose.
7. 7. Add a one-time migration in the same launch pass as ProfileStore.dedupe that
   derives lifeStageRaw from the legacy Bools, resolving a pre-existing both-true row
   deterministically (prefer postpartum, as the later stage) and stamping
   lifeStageSetAt from createdAt.
8. 8. Have HomeView.swift:227-237 and DailyLogForm.swift:339-357 switch on the single
   stage rather than testing the Bools independently, so two cards or two symptom sets
   become unrepresentable.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/PregnancyModeCard.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Settings/BirthControlView.swift`

*Tests:* ProfileStoreTests.swift:63-99 — add 'pregnancy on one row, postpartum on the other →
exactly one survives, the newer lifeStageSetAt wins' (the probe below asserts today's
broken behaviour). Add a migration test: a 1.3-shaped row with both Bools true
resolves to one stage. UI test CaelynUITests.swift:588-638 — after 'I gave birth',
turn pregnancy on again and assert the Home card says 'Week 0', not 'Past your due
date'. Add a HomeView assertion that the TTC card is absent while pregnant.

#### MODES-06 — 28 Specialist modes — Pro gate

If her subscription lapses while pregnancy mode is on, the whole specialist section
disappears from Settings — so she cannot record that she gave birth, cannot switch to
postpartum, and cannot turn the mode off — while the mode keeps shaping her app:
pregnancy symptom chips still appear in her log and pregnancy insights still show.

**Root cause.** The Pro gate is applied to section VISIBILITY, not to the act of ENABLING:
CycleSettingsView.swift:24-36 branches the entire specialist block on
`purchase.isPro`, and the codebase draws no distinction between "may turn on" and "may
see / turn off / transition". Because CycleSettingsView holds the ONLY writes to the
six mode flags, hiding it makes an already-true flag permanently unreachable. Two
things make that permanent rather than transient: nothing ever clears a mode flag
outside that view (no auto-retire on a passed due date, no lapse handler, no
onboarding path), and ProfileStore.merge ORs the flags (ProfileStore.swift:66-71), so
a flag can only ever be driven true by a merge, never false.

**Fix.**

1. 1. Render each specialist section whenever its OWN flag is true, independent of
   isPro, so the toggle's off path and the pregnancy-end dialog are always reachable.
   Show the locked/upsell row only when the flag is false, routing enable to the
   paywall.
2. 2. Decide each effect explicitly rather than by accident. Stay on regardless of
   Pro, because they are data continuity and correctness: the symptom chips
   (DailyLogForm.swift:339-357) and the prediction pause from MODES-02. Remain Pro-
   gated: the Home cards (HomeView.swift:227-237) and condition insights
   (PatternEngine.swift:393-432).
3. 3. Filter condition insights at the InsightsView call site
   (InsightsView.swift:110-114) rather than inside PatternEngine, so the engine stays
   a pure derivation and the Pro decision lives in one presentation layer.
4. 4. Land the single-setter item (MODES-04/MODES-05) first: with setLifeStage as the
   only writer, a lapse handler or an auto-retire becomes a one-line call instead of
   six flag writes scattered across a view.
5. 5. Correct the paywall card copy (CycleSettingsView.swift:496-530), which says the
   modes are "part of Caelyn Pro" while an already-enabled mode is still shaping her
   app.

*Files:* `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/PatternEngine.swift`, `Caelyn/Views/Insights/InsightsView.swift`

*Tests:* Add a UI test launching with --screenshot-mode plus the existing paywall-mode flag
(CaelynApp.swift:49 isPaywallMode) after seeding pregnancyEnabled, asserting the
Pregnancy toggle and the 'I gave birth' action are visible and tappable while not Pro.

#### MODES-07 — 22 Irregular cycle mode (auto-detection)

One unusually long cycle years ago labels her "irregular — infrequent periods, gaps
over 45 days" forever: the Home banner keeps returning, the perimenopause insight
never goes away, and every doctor PDF prints the irregular label two lines below a
"varies by about ±2 days" figure that contradicts it.

**Root cause.** irregularCycleStatus re-derives its own statistics inline from the FULL plausible
history — `let lengths = cycles.map(\.length)` and the `lengths.contains { $0 > 45 }`
test (/Users/smile/Desktop/caelyn/Caelyn/Services/PredictionEngine.swift:404-411,
verified) — instead of delegating to the accessors that already own the window
definition (averageCycleLength :115-120 and cycleLengthVariation :136-142, both
`usable.suffix(6)`). The 6-cycle window is duplicated-by-omission at the classifier,
so the classifier and the number printed beside it answer about different spans. It
latches forever rather than merely being wrong once because plausibleCycles has a
floor but no ceiling (:45-47), so a gap in logging is reconstructed as a legitimate
long cycle that enters history permanently and can never age out of an all-time
window. Separately, the progressive-shift branch uses `>= 7` while its comment says
`>7` (:428-436).

**Fix.**

1. 1. Land MODES-03's ceiling first. suffix(6) alone does NOT retire a gap-cycle that
   is still inside the last six — it only stops the forever-latch; the ceiling is what
   keeps the gap out of history at all.
2. 2. In irregularCycleStatus, after the `count >= 3` gate at
   PredictionEngine.swift:402, bind the classification window once: `let window =
   Array(cycles.suffix(6))`, and drive `lengths`, `avg` and the `> 45` test from
   `window`.
3. 3. Pass `window` explicitly into cycleLengthVariation rather than relying on it
   windowing internally, so the sharing is visible at the call site and a future
   change to one window cannot silently desynchronise the other.
4. 4. Leave the progressive-shift branch's slicing alone (it is already prior-3-of-
   suffix-6) and align `>= 7` with its comment, documenting which comparison is
   intended.
5. 5. Permanent because the window becomes a single bound local that every branch of
   the classifier reads, instead of three independent derivations over three different
   spans.
6. 6. Re-check the PDF: ExportService.swift:211-216 prints the irregular label next to
   the variation figure; after this change they are computed over the same six cycles
   and can no longer contradict each other.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/ExportService.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* CaelynTests.swift:1398-1433 (irregularity suite) — add the probe below.
CaelynTests.swift:826-829 unchanged. Add an invariant test: for any cycle set, the
label printed by ExportService and the variation printed beside it are derived from
the same six cycles.

#### MODES-08 — 23 Gentle mode

Gentle mode is offered to people new to periods, but it changes nothing at all until a
full cycle has been logged — which is exactly the group that has none. Even afterwards
it only softens two places, so the hardest copy she is most likely to see ("may
indicate hormonal fluctuation", "sometimes associated with conditions like PCOS",
"Caelyn hasn't seen your period this cycle") stays clinical.

**Root cause.** `gentleModeEnabled` has exactly ONE read site in the whole app —
/Users/smile/Desktop/caelyn/Caelyn/Views/Home/HomeView.swift:71 (grep returns only the
UserProfile.swift:75 declaration, the CycleSettingsView.swift:69-70 toggle get/set,
HomeView.swift:71 and the ProfileStore.swift:65 merge). That one read feeds only
CycleSummaryService.TeachingFacts.gentle (HomeView.swift:74-80), and TeachingFacts has
exactly two consumers, each independently gated on a completed cycle:
HomeView.swift:69's `guard phase != .unknown, !cycles.isEmpty else { return nil }`,
which makes PhaseGuidePersonal nil so HomeHeroCard falls back to the static, non-
gentle `phase.hint` (HomeHeroCard.swift:51; CyclePrediction.swift:31-44); and
CycleSummaryService.dailyTeaching's `facts.cycleCount >= 1` guard
(CycleSummaryService.swift:79). Everything else that speaks to her — the irregular
banner reasons (CyclePrediction.swift:89-102), the late prompt
(HomeView.swift:546-563), PatternsSection — never sees the flag because it never
reaches the derivation they read.

**Fix.**

1. 1. Land the CycleNorms seam (MODES-01/09/13) first, then add `gentle: Bool` to
   CycleModel alongside norms, read from the profile inside make(). Every surface
   already holds a CycleModel, so this is the one plumbing change that reaches all of
   them.
2. 2. Stop requiring a completed cycle in CycleSummaryService.dailyTeaching: replace
   the `facts.cycleCount >= 1` guard (CycleSummaryService.swift:79) with a cycleCount-
   aware branch. phaseLead (:104-123) needs nothing but phase and cycleDay and makes
   no claim about her history, so it is safe at cycleCount == 0; only the
   topPatternLine join (:98-100) must stay gated.
3. 3. Remove HomeView.swift:69's `!cycles.isEmpty` half of the guard so guidePersonal
   is built from phase alone; without step 2 this leaves the hero unchanged, so both
   are required.
4. 4. Add gentle variants for the copy she is most likely to see, driven from
   CycleModel.gentle: the static phase hints (CyclePrediction.swift:31-44), the
   irregular reason notes (:89-102 — "may indicate hormonal fluctuation" and the PCOS
   sentence), and the late prompt (HomeView.swift:546-563).
5. 5. Add gentle copy to the static PhaseGuide text (PhaseGuideView.swift:377+), which
   today has no gentle variant at all.
6. 6. Permanent because gentle stops being a view-local lookup and becomes a property
   of the derivation: a new surface that renders a CycleModel gets the gentle wording
   without having to know the flag exists.

*Files:* `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Views/Education/PhaseGuideView.swift`

*Tests:* Extend CaelynTests.swift:1066-1096 (gentle copy tests) to cover the phase hint, the
irregular reason note and the late prompt. Add a test that a gentle profile with zero
completed cycles still produces a non-nil dailyTeaching and a gentle hero hint.

#### MODES-10, MODES-11 — 28 Specialist modes — TTC

The one card a woman trying to conceive plans around contradicts itself and ignores
the most important signal there is. The line underneath can say "Fertile window in 3
days" while the gauge above it says she is fertile today, because the two use
different ovulation maths. And if her period is five days late — the single strongest
early sign of pregnancy — the card simply projects next month's fertile window and
tells her to wait three weeks; logging a positive pregnancy test changes nothing.

**Root cause.** The TTC path consumes a truncated projection of CycleModel and re-derives the rest.
(a) TTCDashboardCard recomputes `PredictionEngine.fertileWindow(nextPeriodStart:
next)` inline
(/Users/smile/Desktop/caelyn/Caelyn/Views/Home/TTCDashboardCard.swift:38-54, verified)
and omits the `lutealLength:` argument, so it silently falls back to the textbook
default of 14 (PredictionEngine.swift:253) — while HomeView passes the LEARNED luteal
(9-17) into TTCFertilityEngine.result next door (HomeView.swift:132-138). lutealLength
is not even a member of the card's API (TTCDashboardCard.swift:3-5), so the value
HomeView already holds (:57) cannot reach it. The default parameter is the enabling
mechanism: it lets a call site that forgets the personalisation compile and quietly
revert to the population average. (b) TTCFertilityEngine.result's signature
(TTCFertilityEngine.swift:14-18) admits only todayEntry, nextPeriodStart and
lutealLength, and is handed `cycle.nextPeriodStart` — the deliberately rolled-forward
prediction (PredictionEngine.swift:180-194). The lateness facts are not missing from
the model: the same CycleModel the view holds exposes expectedPeriodStart
(CyclePrediction.swift:289-293), isPeriodLate and daysLate (:351-361), and
HomeCopy.swift:93 already suppresses all forward projections when late. The engine
also reads Date.now internally (:26), so it cannot be tested with an injected clock,
and uses absolute BBT cut-offs 36.3/36.7 °C (:61-70) rather than her own coverline,
though WristTempOvulationEngine exists.

**Fix.**

1. 1. Delete the recomputation. Remove the `nextPeriodStart` input from
   TTCDashboardCard and the whole block at TTCDashboardCard.swift:38-54; give the card
   `fertileWindow: ClosedRange<Date>?` supplied from `cycle.fertileWindow` at
   HomeView.swift:228, so it can only ever render the window CycleModel already
   computed with the learned luteal (CyclePrediction.swift:309-314). Permanent because
   it removes the derivation rather than correcting its argument — there is no second
   computation left to drift.
2. 2. If the engine is also to be de-duplicated, pass it `fertileWindow` AND
   `ovulationEstimate` (CyclePrediction.swift:302-314) — a window alone loses the +45
   ovulation-day signal at TTCFertilityEngine.swift:25-28.
3. 3. Audit `PredictionEngine.fertileWindow`/`ovulationEstimate`'s `lutealLength: Int
   = 14` default. Either remove the default so every call site must state it, or
   rename it `populationDefaultLutealLength` so an omission is visibly a choice.
4. 4. Widen the engine signature and remove ambient time: `result(todayEntry:, today:
   Date = .now, fertileWindow:, ovulationEstimate:, expectedPeriodStart:,
   isPeriodLate:, daysLate:)`, deleting the internal Date.now read at
   TTCFertilityEngine.swift:26. The engine has zero tests today; this is what makes it
   testable.
5. 5. Add a `.possiblyPregnant` / `.late` result state that short-circuits cycle-
   position scoring whenever isPeriodLate (≥1 day) or today's `pregnancyTest == true`
   (DailyLogForm.swift:902-909), instead of scoring the next cycle's window. This
   mirrors the guard already at HomeCopy.swift:93, so Home stops contradicting itself.
6. 6. In that state, the card should suggest a test and offer a path into pregnancy
   mode via setLifeStage (MODES-04/05), rather than showing a fertile-window
   countdown.
7. 7. Replace the absolute BBT cut-offs (TTCFertilityEngine.swift:61-70) with her own
   coverline via WristTempOvulationEngine, falling back to the absolute values only
   when there is insufficient temperature history.

*Files:* `Caelyn/Views/Home/TTCDashboardCard.swift`, `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Log/DailyLogForm.swift`

*Tests:* No TTC tests exist. Add TTCFertilityEngineTests with an injected today: (a) learned
luteal 11 — the card's window and the engine's window are identical; (b) isPeriodLate
with daysLate 5 → result is .late/.possiblyPregnant and no fertile-window countdown is
produced; (c) today's pregnancyTest == true → same; (d) a card-input equality test
asserting the card receives cycle.fertileWindow rather than recomputing.

#### PE-01 — HomePatternInsight / PredictionEngine.mostFrequentSymptom / HomeView pattern card

On any ordinary day mid-cycle, Home tells her 'You often experience cramps at this
point in your cycle. That's your body's rhythm — not random.' She is nowhere near her
period. The symptom named is simply the one she has logged most in her whole history,
with no connection to where she is today — and the Insights tab, one tab over,
correctly places that same symptom in the period phase.

**Root cause.** Two mechanisms. (a) HomeView.swift:255-258 hands HomePatternInsight a phase-agnostic
all-time aggregate (PredictionEngine.mostFrequentSymptom,
PredictionEngine.swift:385-392) while the view's copy at HomePatternInsight.swift:18
asserts a phase-relative fact — the parameter list cannot express the claim the string
makes, so the two were free to drift. (b) The deeper mechanism: Home writes its own
pattern prose instead of rendering prose the engine derived. PatternInsight already
carries title/body/supportingValue/relatedPhase (PatternEngine.swift:27-34), each
written against the data that produced it; every hand-written pattern sentence in a
view is a claim with no data behind it.

**Fix.**

1. 1. Hoist PatternEngine.insights into HomeView's existing per-render Derived stash
   (the one added by a1ca071 at HomeView.swift:142) alongside derived.model, so the
   engine runs once per render.
2. 2. Pass the insight whose relatedPhase == cycle.phase into HomePatternInsight and
   render its own title/body. Delete the 'at this point in your cycle' copy path from
   HomePatternInsight.swift:15-19.
3. 3. When no insight matches the current phase, fall back to a phase-neutral line —
   but gate it on a real frequency floor mirroring PatternEngine.swift:379-381's
   `count >= 4`, so 'your most-logged symptom so far' is never printed for a symptom
   logged once and the word 'often' never appears without evidence. Below the floor,
   fall through to HomeCopy.emptyStatePatternMessage.
4. 4. Drop the 'That's your body's rhythm — not random' clause from the fallback; it
   should only ride along with an engine-derived phase insight, where it is true.

*Files:* `Caelyn/Views/Home/HomePatternInsight.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/PredictionEngine.swift`

*Tests:* New unit test: three cycles with cramps only on period days, today in the follicular
phase → the Home pattern text does not name cramps as 'at this point'. Check
ScreenshotTests.testStore* copy expectations still match.

#### PE-02 — CycleSummaryService.fallback / teachingFallback / InsightsView.summaryFacts / HomeCopy.phaseHeadline

Her period is three days late — the moment she is most anxious. Home's hero says, in
big type, 'Day 4 of your period'. The 'Your cycle in words' summary says she is in her
menstrual phase and her next period is expected in about 25 days. A small card below
says 'Your period might be 3 days late'. For Pro users the contradicting text is
presented as intelligence generated privately on her device.

**Root cause.** PredictionEngine.currentCycleDay wraps modulo cycleLength, so 31 days after a 28-day
anchor returns day 4; CycleModel.phase then classifies day 4 as .menstrual;
nextPeriodStart rolls forward past today so daysUntilPeriod becomes 25. The prose
structs cannot see lateness at all — CycleSummaryService.Facts and TeachingFacts
(CycleSummaryService.swift:15-23, :144-156) carry cycleDay/phaseName/daysUntilPeriod
and no lateness field — so every consumer that builds a sentence from them, including
the Foundation Models prompt, is structurally unable to know. Three consumers, not
two: HomeCopy.phaseHeadline (HomeCopy.swift:54-57) returns 'Day \(cycleDay) of your
period' and HomeHeroCard.swift:36 renders it as the headline.

**Fix.**

1. 1. Add `daysSinceAnchor: Int` (un-wrapped; nil/0 when there is no anchor) to
   CycleModel, and derive `var isOverdue: Bool { daysSinceAnchor >= cycleLength &&
   activePeriodWindow == nil }`. Branch on isOverdue, NOT on daysLate > 0 — otherwise
   the day where daysSinceAnchor == cycleLength still prints 'Day 1 of your period'.
2. 2. Carry daysSinceAnchor and daysLate into both CycleSummaryService.Facts and
   TeachingFacts as defaulted parameters (so existing call sites and
   testCycleSummaryFallbackProducesUsableText keep compiling).
3. 3. Branch on overdue at the top of fallback (CycleSummaryService.swift:52-56),
   teachingFallback, and both Foundation Models prompt builders (:144-156): omit cycle
   day, phase name and daysUntilPeriod entirely and say 'Your period is N days later
   than your usual \(cycleLength)-day cycle.'
4. 4. Fix HomeCopy.phaseHeadline (HomeCopy.swift:54-57) the same way, so the hero
   headline stops contradicting the late card at HomeView.swift:214/551.
5. 5. Make the Insights summaryFacts construction (InsightsView.swift:30-47) pass the
   new fields rather than cycleDay/phase verbatim.

*Files:* `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Services/PredictionEngine.swift`

*Tests:* testCycleSummaryFallbackProducesUsableText (CaelynTests.swift:946) gains a late-state
sibling asserting the text contains neither 'menstrual' nor 'day 4'.
testDailyTeachingFallback unaffected if the new TeachingFacts params are defaulted.
Add a HomeCopy.phaseHeadline test for the overdue case.

#### PE-03, PE-12 — PatternEngine.prePeriodMoodDip / pmsPredictorSymptom + PredictionEngine.adaptivePmsDaysBefore / CycleModel.pmsWindow

The number Caelyn shows as 'your PMS symptoms tend to start ~N days before your
period' is wrong in two ways at once. It ignores her most recent completed cycle — the
freshest evidence — and counts a period before she started tracking as a cycle where
nothing happened. And it is set by the single earliest tick in a two-week window, so
one 'fatigue' logged mid-cycle makes it say 13 days: the calendar turns purple for
half the month, and Home warns her PMS is coming two weeks early. The more diligently
she logs, the earlier and more wrong the number gets.

**Root cause.** Two mechanisms in the same window code. (1) WINDOW: all three detectors key the pre-
period window to a completed cycle's START rather than its END — prePeriodMoodDip
finds 'next cycle start' with `cycles.map(\.start).filter { $0 > day }.min()`
(PatternEngine.swift:176-191), while pmsPredictorSymptom (:276-289) and
adaptivePmsDaysBefore (PredictionEngine.swift:321-335) window on [cycle.start − N,
cycle.start − 1]. Because PredictionEngine.cycles emits only P−1 Cycles for P period
starts (PredictionEngine.swift:76-87), the newest period start exists only as a
cycle's END, so the newest fully-observed PMS window is invisible to all three, while
a pre-tracking window before cycles[0].start sits in pmsPredictorSymptom's denominator
(total = cycles.count). The correct in-repo precedent is symptomLeadTime
(PatternEngine.swift:313-319). (2) ESTIMATOR: adaptivePmsDaysBefore takes min(marker
day) over a 14-day window (PredictionEngine.swift:328-332) against a 12-item marker
set that includes fatigue, cramps and cravings — an EXTREMUM, so the per-cycle onset
is monotone non-decreasing in logging density and converges on the window edge for any
diligent logger. Averaging biased maxima at :337 compounds the bias, so more cycles
make Caelyn more confident in a number that is wrong in a fixed direction.

**Fix.**

1. 1. Add `Cycle.end(calendar:)` = start + length, and re-key every pre-period window
   to [end − N, end − 1] with the period day at end. This restores the newest
   completed cycle, removes the empty pre-history window, and aligns the 3-cycle
   threshold at PredictionEngine.swift:336 with the `cycles.count >= 3` promise at
   InsightsView.swift:99. Apply at PatternEngine.swift:176-191, :276-289 and
   PredictionEngine.swift:321-335.
2. 2. Set every denominator to the number of windows actually examined, not
   cycles.count.
3. 3. Decide the pre-first-period window explicitly rather than losing it silently: a
   user who migrated history from one of the nine import sources may legitimately have
   symptoms logged before her first flow day. Either include that window when it
   contains data, or document the exclusion in the function's doc comment — do not let
   it be a side effect.
4. 4. Replace the extremum with a persistence rule: onset = the start of the first RUN
   of >= 2 consecutive marker days inside the window, not the single earliest marker
   day. A lone mid-luteal fatigue log can then no longer move the number.
5. 5. Tighten the marker set used for onset detection, or weight it: fatigue, cramps
   and cravings are common outside PMS. Prefer the PMS-specific markers (bloating,
   tenderBreasts, acne, negative mood) for onset and keep the broader set only for
   presence detection.
6. 6. Use the median of per-cycle onsets rather than the mean
   (PredictionEngine.swift:337), so one anomalous cycle cannot drag the learned
   number.
7. 7. Keep the 2…14 clamp but verify the three downstream surfaces after the change:
   CycleModel.pmsWindow (CyclePrediction.swift:201-205, :316-321) painting the
   Calendar and Year view, HomeCopy's 'PMS may begin in N days'
   (HomeCopy.swift:95-100), and LearnedAboutYou (InsightsView.swift:200-207).

*Files:* `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Views/Home/HomeCopy.swift`

*Tests:* testSymptomLeadTimeCorrelation (CaelynTests.swift:870) must still pass. Add: the probe
below (newest completed cycle is seen); three cycles with markers on days −4…−1 plus a
lone fatigue on day −13 yields 4, not 13; a two-cycle history yields nil (threshold
honoured).

#### PE-04 — PatternEngine.cycleLengthTrend

She stops logging for three months, comes back, and Caelyn tells her 'Your cycles have
been getting longer — 28 to 55 days. This can be a sign of hormonal change worth
discussing with your doctor.' Nothing changed in her body; she just took a break from
the app. The same card also fires on an ordinary three-day shift that Caelyn's own
phase guide calls 'in a common range' — and it goes into the PDF she takes to the
appointment.

**Root cause.** Two mechanisms. (1) The 45-day plausibility ceiling exists in this codebase but lives
in consumers rather than in the data: clampCycleLength applies it to every displayed
average (PredictionEngine.swift:131) and irregularCycleStatus uses >45 as its skipped-
period test (:409), while plausibleCycles (:45-47) is deliberately a floor only.
cycleLengthTrend is the one consumer doing arithmetic on raw Cycle.length
(PatternEngine.swift:249-268, verified: `cycles.suffix(3).map(\.length)` with no
ceiling), so a logging-gap phantom cycle of 110 days enters the mean. (2) The effect
gate is `abs(delta) >= 3.0` with a hard-coded confidence of 0.7 and doctor-forward
copy, below the ±7 that irregularCycleStatus requires for a shift — so two surfaces
disagree about the same six cycles.

**Fix.**

1. 1. Promote the ceiling instead of re-implementing it: add
   `PredictionEngine.maximumPlausibleCycleLength = 45` next to
   minimumPlausibleCycleLength (PredictionEngine.swift:40) and have clampCycleLength
   (:131) and irregularCycleStatus's >45 test (:409) read that constant.
2. 2. Expose the bounded set as a SECOND accessor (e.g. `trendEligibleCycles`) rather
   than changing plausibleCycles itself — plausibleCycles feeds averageCycleLength and
   cycleLengthVariation, and dropping a 110-day cycle there would hide a genuine
   skipped period from the irregularity logic.
3. 3. Have cycleLengthTrend consume trendEligibleCycles, and require both halves
   (recent 3 and prior 3) to be fully populated from it after filtering, otherwise
   return nil.
4. 4. Raise the effect gate to agree with irregularCycleStatus (>= 7 days, or at
   minimum > TypicalRanges' in-range band) so the card cannot contradict the phase
   guide, and derive confidence from the size of the delta and the number of cycles
   rather than the constant 0.7.
5. 5. Soften the copy when the delta is modest: reserve 'worth discussing with your
   doctor' for the large-shift branch.

*Files:* `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/TypicalRanges.swift`

*Tests:* New: (1) six 28-day cycles plus one 110-day gap cycle produce no trend insight; (2)
[28,29,28] vs [31,30,31] produces none; (3) [27,28,27] vs [35,36,35] does, with
doctor-forward copy. Verify existing averageCycleLength/variation tests are unchanged
(plausibleCycles untouched).

#### PE-06, PE-08, PE-13 — PatternEngine.phaseSymptomCorrelation / energyCurve / painTrend + CycleAnalytics.mostCommonEarlyPeriodSymptom / averagePeriodPain + PatternsSection

Caelyn states things about her body with complete confidence from one or two logs.
Three nausea entries on consecutive days of a single cycle become 'Nausea peaks in
your Luteal phase — 100% of occurrences'. Four energy logs become 'Energy peaks during
your Follicular phase — a 1.5-point difference on average'. One pain log of 3 and one
of 7 become 'Period pain is getting worse — 3.0 to 7.0'. A single nausea entry becomes
'You often log nausea in the first days of your period'. A single pain rating of 7
becomes 'Your period pain averages 7.0' and, on Home, picks up 'worth talking to a
doctor about'. Nowhere does she see how many logs any of it rests on. And users with
very short cycles see 'Fatigue peaks in your Cycle phase', because the unknown phase
is being printed as if it were a real one.

**Root cause.** Sample adequacy is ad hoc per detector and then erased at the boundary. (a) The gates
count the wrong thing or nothing: phaseSymptomCorrelation's doc promises '>= 2 cycles'
but the code counts occurrences (total >= 3, fraction >= 0.4, count >= 2 —
PatternEngine.swift:139-152, verified) with no distinct-cycle tracking; energyCurve's
only gate is >= 2 raw logs per phase bucket (:229) with a 1.2-point effect gate (:236)
that is below the sampling noise of an n=2 mean on the 1-5 scale; painTrend's pain
gate is `!pains.isEmpty` inside the helper (:470) while the visible `cycles.count >=
6` (:356) gates cycles, not pain observations;
CycleAnalytics.mostCommonEarlyPeriodSymptom (:134-150) and averagePeriodPain
(:153-169) precondition only on 'any data exists'. (b) Sample size is encoded only
into `confidence` and NO consumer treats confidence as a precondition —
PatternInsightsSection renders regardless and ExportService never sees confidence at
all; the analytics functions return bare Symptom?/Double? so cardinality cannot even
reach a consumer. (c) CyclePhase.unknown (returned by PredictionEngine.phase for
cycleLength <= periodLength + 14, :355-357) is not excluded, and its displayName is
'Cycle'. (d) The loosest consumer is Home, not Insights: HomeView.guidePersonal gates
at `!cycles.isEmpty` (HomeView.swift:70) = one cycle and routes the n=1 pain mean
through TypicalRanges.pain (TypicalRanges.swift:91-97), where avg > 6 appends the
doctor clause.

**Fix.**

1. 1. Add a central `PatternEngine.Thresholds` enum holding every evidence floor in
   one place: phaseSymptom (>= 2 distinct cycles AND >= 3 occurrences), energy (>= 4
   logs per phase bucket AND >= 2 distinct cycles contributing to each of the high and
   low buckets), pain (>= 3 pain logs per side), earlyPeriodSymptom (>= 2 distinct
   cycles), periodPainAverage (>= 3 logs).
2. 2. Track distinct cycles, not just counts: in phaseSymptomCorrelation replace the
   `[Symptom: [CyclePhase: Int]]` accumulator with one that also carries `Set<Date>`
   of cycle.start values, and require the winning (symptom, phase) pair to clear both
   floors.
3. 3. Skip CyclePhase.unknown in phaseSymptomCorrelation and energyCurve, and never
   emit a sentence naming it.
4. 4. Make sample size part of the OUTPUT, not just the gate: add `sampleSize: Int`
   (and for energy, `cycleSpan: Int`) to PatternInsight and render it in
   supportingValue — '7 of 9 times · 3 cycles', '1.5 pts · 9 logs · 3 cycles', '3 → 7
   /10 · 6 logs'. This is what actually fixes the doctor PDF, which never sees
   confidence.
5. 5. Change the two CycleAnalytics signatures to carry cardinality:
   `mostCommonEarlyPeriodSymptom -> (symptom: Symptom, count: Int, cycles: Int)?` and
   `averagePeriodPain -> (average: Double, n: Int)?`, so no consumer can use the
   statistic without seeing its sample.
6. 6. Gate the consumers: PatternsSection (PatternsSection.swift:13-27) requires the
   thresholds and phrases the sample ('in 3 of your last 4 periods', 'across 5 logged
   days'); gate at HomeView.swift:86 BEFORE `.map { Int($0.rounded()) }` so a thin
   mean never reaches TypicalRanges.pain — this keeps TypicalRanges.pain(_ avg: Int?)
   intact and leaves CaelynTests.swift:1050-1053 passing unchanged.
7. 7. Derive painTrend's confidence from n instead of the hard-coded 0.65
   (PatternEngine.swift:373), and give every consumer one shared confidence floor from
   Thresholds.
8. 8. Soften 'getting worse' to a neutral framing with the numbers attached.

*Files:* `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Views/Insights/PatternsSection.swift`, `Caelyn/Views/Insights/PatternInsightsSection.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/TypicalRanges.swift`, `Caelyn/Services/PredictionEngine.swift`

*Tests:* New threshold tests for each detector (no existing test exercises energyCurve or
painTrend). The probe below for phaseSymptom. Add: same three logs spread over two
cycles DO produce the insight, with '2 cycles' in supportingValue; a short-cycle
(.unknown phase) history produces no phase sentence; single-log analytics return nil.
UI test testReturningUserDailyJourneyPersistsAcrossTabs asserts only the 'Patterns'
header and keeps passing.

#### PE-11 — TemperatureShiftCard / InsightsView.bbtSeries / WristTempOvulationEngine.detectShift

A woman trying to conceive opens Insights and reads 'Temperature shift detected — your
temperature rose around Mar 14, which usually follows ovulation.' It is October. The
date is from a year ago, picked out of her whole temperature history, and it is
phrased as if it happened this cycle.

**Root cause.** Two independent mechanisms; fixing one leaves the bug alive. (1) TemperatureShiftCard
receives its date bound and its fallback series as two unrelated parameters
(InsightsView.swift:128-131) and applies the bound only to the HealthKit query (:319),
so the `wrist.isEmpty ? bbtSeries : wrist` ternary at :320 silently substitutes an
UNBOUNDED all-history series (InsightsView.bbtSeries, :34-36, verified:
`entries.compactMap { e in e.basalTemperature.map { (date: e.date, temp: $0) } }` with
no window) for a bounded one — which happens whenever there is no Watch, Health is
denied, or she is on iPad. (2) WristTempOvulationEngine.detectShift scans ascending
and returns on the FIRST qualifying index (WristTempOvulationEngine.swift:30-53), so
it reports the OLDEST shift in whatever series it is handed, despite being documented
'for a single cycle'. Even the 40-day wrist window spans ~1.5 cycles.

**Fix.**

1. 1. Collapse the two parameters into one: TemperatureShiftCard takes a single
   DateInterval (or cycleStart: Date) and derives BOTH the HealthKit range and the BBT
   filter from it, so no future edit can window one source and not the other. Pass
   cycle.anchor from InsightsView:128 and render nothing when anchor is nil.
2. 2. Add `detectShift(in:cycleStart:)` returning the LATEST qualifying shift (scan
   and retain the last match, or iterate descending) as an OVERLOAD, so the existing
   testWristTempBiphasicShiftDetected and testNoShiftOnFlatSeries keep passing against
   the original.
3. 3. Filter the BBT fallback series by the same interval before handing it to the
   engine.
4. 4. Date the claim in the copy: 'around Mar 14' should read as a date within the
   current cycle, and if the detected shift is older than the current cycle the card
   must not render at all.

*Files:* `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Services/WristTempOvulationEngine.swift`

*Tests:* testWristTempBiphasicShiftDetected and testNoShiftOnFlatSeries unchanged (new
overload). Add the probe below, plus: with two shifts in one series, the cycle-scoped
overload returns the later one.

#### PG-01, PG-03, PG-04 — Phase Guide — "Is this normal?" table and Q&A (HomeView.guidePersonal → TypicalRanges / GuideQuestions)

The health panel that exists to answer "is this normal?" judges numbers that are not
hers. A woman with one real 44-day cycle who typed 28 during setup is told "Cycle
length 28 days ✓ In a common range" and "Yours average 28 days". A teenager whose
cycles really average 60 days is shown "45 days ✓ In a common range", because the
prediction clamp stops at 45. And a one-cycle user is told her cycles vary by "± 0
days" — a precision nobody could have.

**Root cause.** CycleModel exposes prediction-tuned numbers with no provenance, and the health-
assessment layer consumes them as if they were measurements. Three channels, one
mechanism: (1) `averageCycleLength`/`averagePeriodLength` fall back to the profile
seed below 2 plausible cycles (PredictionEngine.swift:115-127) — the number she typed
before logging anything — yet HomeView shows the panel from 1 cycle
(HomeView.swift:70) and passes those values straight in (:83-84); (2) the same
functions clamp to 18…45 and 1…12 at their single point of computation (:119, :126,
:131-132), destroying the unclamped mean so no layer downstream can see her real
average; (3) `cycleLengthVariation` returns a magic 0 for "fewer than 2 cycles"
(:136-142), CycleModel stores it non-optionally (CyclePrediction.swift:171, 241), and
HomeView.swift:85 assigns that Int into an `Int?` field — Swift's implicit promotion
turns the sentinel into `.some(0)` and permanently hides the `.learning` / "—"
branches TypicalRanges already implements (TypicalRanges.swift:80-83, :117).

**Fix.**

1. Split provenance at the lowest level, not at CycleModel. In PredictionEngine add
   `learnedCycleLength(of:fallback:) -> Int?` and `learnedPeriodLength(of:fallback:)
   -> Int?` returning the UNCLAMPED weighted mean, and nil below 2 plausible cycles.
   Redefine the existing `averageCycleLength`/`averagePeriodLength` as
   `clampCycleLength(learned ?? fallback)` so every prediction caller is byte-for-byte
   unchanged.
2. Add `learnedCycleLengthVariation(of:) -> Int?` returning nil below 2 plausible
   cycles, and keep `cycleLengthVariation` as `learnedCycleLengthVariation(of:) ?? 0`
   so irregularCycleStatus (PredictionEngine.swift:406-414) and every numeric consumer
   stay identical today.
3. Surface `learnedCycleLength: Int?`, `learnedPeriodLength: Int?`, `learnedVariation:
   Int?` and `cycleSampleSize: Int` on CycleModel alongside the existing clamped
   values (CyclePrediction.swift:169-171, populated in make at :219-241, defaulted in
   empty at :252). Derived only — no SwiftData schema change, safe for 1.3 build 15
   upgraders.
4. Point HomeView.guidePersonal (HomeView.swift:81-89) at the learned optionals and
   make PhaseGuidePersonal's fields genuinely optional end to end, so `TypicalRanges`'
   existing `.learning` branch becomes reachable for the first time in production.
5. Pass `learnedVariation` (nil, not 0) into GuideQuestions.forToday so the "varies"
   answer falls back to its existing "a few days" wording (TypicalRanges.swift:117)
   instead of printing "0 days".
6. Add `sampleSize` to `TypicalRanges.Frame` and render "from your last N cycles"
   beneath each row, so a judgement always states what it is based on. This is the
   part that makes the fix permanent: a future caller cannot hand the table a number
   without also declaring where it came from.
7. Gentle mode specifically: with the unclamped value, a real 60-day average now
   renders "60 days" with the gentle watch note instead of "45 days ✓". That is a
   correction, and the existing copy is already soft and provider-forward.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/TypicalRanges.swift`, `Caelyn/Views/Education/PhaseGuideView.swift`, `Caelyn/Views/Onboarding/OnboardingViewModel.swift`

*Tests:* CaelynTests.testTypicalRangesCycleLength — add seed-vs-learned and sampleSize cases.
New tests for CycleModel.learned* with 0 / 1 / 2 cycles. Add:
TypicalRanges.variation(nil).status == .learning. Add: a 60-day gentle average renders
"60 days" with .watch. testGuideQuestionsPhaseFirstAndProviderForward unchanged.

#### PG-02 — Phase Guide — cycle-to-cycle variation (PredictionEngine.cycleLengthVariation → TypicalRanges.variation / GuideQuestions / irregularCycleStatus)

A woman whose cycles run anywhere from 24 to 38 days — a two-week swing, which doctors
would call irregular — is told "✓ In a common range" by the one panel that exists to
answer that question, and the Q&A repeats it: "Yours vary by about 7 days." The
threshold is right; it is being compared against half the quantity it was written for.

**Root cause.** One step deeper than a unit slip: CycleModel exposes a SINGLE variation scalar
(CyclePrediction.swift:171, 241), and it is defined for the prediction UI as a HALF-
spread — `(max − min) / 2`, rounded (PredictionEngine.swift:134-142). The full
shortest-to-longest spread never leaves that function's local scope; `maxLen - minLen`
is divided away at :141. So every assessment layer downstream —
`TypicalRanges.variation` with its 7 / 9 caps (TypicalRanges.swift:77-87),
`GuideQuestions`' "varies" answer (:115-123), `PredictionEngine.irregularCycleStatus`'
`variation > 7` (:413-415) and the clinical PDF's "±N days" row — is forced to compare
the only number it has against a clinical threshold defined on the full range
(FIGO/ACOG: ≤7–9 days shortest to longest). A lossy model API with an ambiguously-
named value, not a single bad comparison.

**Fix.**

1. Add `CycleModel.learnedCycleSpread: Int?` = `max − min` over
   `plausibleCycles(...).suffix(6)`, nil below 2 plausible cycles — the same
   provenance shape as the learned* accessors from the PG-01 item, which should land
   first.
2. Change `TypicalRanges.variation` to take the SPREAD, keep the 7 / 9 caps unchanged,
   and render "varies by N days (shortest to longest)" rather than "± N days". The
   caps are correct; only the input was wrong.
3. Use the same spread in GuideQuestions' "varies" answer (TypicalRanges.swift:117,
   :122) so the prose and the table agree.
4. Fix the two sites carrying the identical mismatch, or this is an instance fix
   rather than a permanent one: `PredictionEngine.irregularCycleStatus`' `if variation
   > 7` (:413-415) must become `if spread > (gentle ? 9 : 7)` — note it currently has
   no gentle input at all, so the teen variant is missing there too — and the clinical
   PDF's variation row (handled in the EXP-04 item, which should follow this one).
5. Keep the ± half-spread for prediction windows on Home, where it is the correct
   quantity; rename it in code (e.g. `predictionHalfSpread`) so the two values can
   never again be mistaken for each other. The rename is what prevents recurrence.
6. Expect some live users to move from "in range" to "watch". The copy is already
   gentle and provider-forward, so this is a correction, not an alarm — but mention it
   in release notes.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/TypicalRanges.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* No existing test covers TypicalRanges.variation — add one: cycles of 24 and 38 produce
a 14-day spread and .watch, not .inRange. Add a gentle variant at the 9-day boundary.
If the irregular threshold changes, the CaelynTests irregular-status tests need the
new semantics.

#### PG-09 — Phase Guide / Home badge — PredictionEngine.phase ignores learned PMS onset

Caelyn shows her, proudly, that it has learned her PMS starts about 8 days before her
period — and then, for those first few days, labels her phase "Luteal" and teaches
"progesterone is rising, which tends to feel calmer" while she is already in it. The
app contradicts the very personalisation it is advertising, for up to 9 days a cycle,
for exactly the women who logged enough for it to learn.

**Root cause.** "PMS" has three independent definitions in shipping code with no single source of
truth. The date-range definition,
`PredictionEngine.pmsWindow(nextPeriodStart:daysBefore:)`
(PredictionEngine.swift:290-297), takes the parameter and is correctly fed the learned
value by `CycleModel.pmsWindow` (CyclePrediction.swift:316-321). The cycle-day
definition inside the classifier is a hard literal — `let pmsStart = max(1,
cycleLength - 4)` at PredictionEngine.swift:359 — and `phase`'s signature (:350) has
no pmsDaysBefore parameter, so no caller can supply the learned value even if it
wanted to. A third copy sits in `WidgetCycleMath.phaseRaw`
(WidgetDataStore.swift:139). Because the literal happens to equal the default (5 days
→ L−4), the definitions agree for unlearned users and diverge silently the moment
`adaptivePmsDaysBefore` returns anything else. `HomeCopy.comingUpEvents` then hides
the PMS row in that window (`daysUntilPMS > 0`, HomeCopy.swift:95), so nothing on
screen reconciles the contradiction.

**Fix.**

1. Add `pmsDaysBefore: Int = 5` to `PredictionEngine.phase`
   (PredictionEngine.swift:350) and compute `let pmsStart = max(1, cycleLength -
   pmsDaysBefore + 1)`. Note the `+ 1`: the window is L−P+1…L, so the existing L−4
   literal corresponds to P=5 and the default keeps CaelynTests.swift:106-107 green.
2. Have `CycleModel.phase` (CyclePrediction.swift:272-277) pass `pmsDaysBefore` — it
   already computes the learned value for pmsWindow.
3. Mirror the parameter in `WidgetCycleMath.phaseRaw` (WidgetDataStore.swift:134-141),
   add `pmsDaysBefore: Int?` to WidgetSnapshot (optional, nil default, same decode-
   safety pattern as the other recompute anchors), write it from WidgetDataSync
   (WidgetDataSync.swift:33) and pass it through `recomputed(for:)` — the recompute is
   unconditional, so a snapshot-only fix would be undone on the next widget render.
4. Derive both the window and the classifier boundary from one helper so they cannot
   diverge again: e.g. `PredictionEngine.pmsStartCycleDay(cycleLength:daysBefore:)`
   used by `phase`, `pmsWindow` and `phaseRaw` alike. That single derivation is the
   permanence argument.
5. Fix YearViewSection.swift:147, which calls pmsWindow with the default 5 instead of
   the learned value, so the year view agrees too.
6. Ship with the fertile-window item (F-29-01/F-29-10): it adds lutealLength to the
   same WidgetSnapshot and the same WidgetCycleMath signatures.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Views/Calendar/YearViewSection.swift`, `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Views/Education/PhaseGuideView.swift`

*Tests:* CaelynTests.testWidgetCycleMathMatchesPredictionEngine — pass the same pmsDays to
both. Any phase-boundary test asserting .pms at cycleLength−4 keeps passing on the
default. Add: with learned PMS = 8 on a 28-day cycle, days 21–24 classify as .pms and
the badge, teaching line and guide all agree. Add: a snapshot without the new key
still decodes.

#### PG-13 — Home hero / header / guide — PredictionEngine.phase returning .unknown for anchored users

A woman with months of logged cycles is greeted as a brand-new user for two-thirds of
every cycle: the ring is empty, the hint and legend vanish, the header drops "Day N"
and the headline reads "Welcome to Caelyn". It happens whenever her cycles are short
or her learned luteal phase is long — the people Caelyn has the most data about.

**Root cause.** `.unknown` carries two incompatible meanings — "no anchor at all"
(CyclePrediction.swift:273) and "anchored, but the fixed-luteal model cannot place
this day" (PredictionEngine.swift:353-357, the guard that returns .unknown for every
non-bleeding day when `cycleLength − lutealLength <= periodLength`) — and every Home
surface keys its brand-new-user empty state off the enum case rather than off
`CycleModel.hasPrediction` (CyclePrediction.swift:258). The second meaning is reached
by three independent arithmetic paths, not one: a short averaged cycle with the
default luteal 14 (clampCycleLength floors at 18, so cycle 18 with period ≥4, or cycle
21 with period ≥7, qualifies — and the codebase deliberately admits 15–20-day cycles
into statistics); a long LEARNED luteal, which the clamp allows up to 17
(PredictionEngine.swift:283); and the combination of both.

**Fix.**

1. In PredictionEngine.phase (PredictionEngine.swift:353-357) stop returning .unknown
   from that guard branch. Classify `.menstrual` for days 1…safePeriod, `.pms` for the
   last pmsDays, and `.luteal` for the remainder — making no
   `.ovulation`/`.follicular` claim, since ovulation genuinely cannot be placed.
   Reserve `.unknown` for `cycleLength <= 0` (:351) and for the no-anchor case
   (CyclePrediction.swift:273). This single change fixes every downstream surface at
   once.
2. Re-key the empty state off absence of an anchor at ALL sites, not just the hero:
   HomeHeroCard.swift:30, :46, :80; HomeCopy.swift:66-67; HomeHeader.swift:32-37;
   HomeView.swift:70 (guidePersonal). Use `cycle.hasPrediction`, which is the fact the
   empty state is actually about.
3. Mirror the same classification change in WidgetCycleMath.phaseRaw
   (WidgetDataStore.swift:134-141) so the widget and watch do not keep showing
   "unknown" where the app now shows luteal.
4. Land this FIRST among the phase items: the lateness item and the mode/staleness
   item both add reasons for phase to change, and .unknown must mean exactly one thing
   before either does.
5. Keep the no-ovulation-claim behaviour documented in the function's doc comment,
   which currently explains the old .unknown decision.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Views/Home/HomeHeader.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/WidgetDataStore.swift`

*Tests:* Phase tests that assert .unknown for short cycles must change. WidgetCycleMath parity
test. Add: cycle 21 / luteal 17 / period 5 on day 10 classifies .luteal, the hero
renders a ring and the header shows "Day 10"; a user with no anchor still gets the
welcome state.

#### PRIV-07 — 15 Delete all data · 11 duress PIN (watch snapshot)

After "Delete all data" — or after the duress PIN — her Apple Watch keeps showing her
cycle day, fertile window and period countdown. If her Pro subscription has lapsed, it
keeps showing them indefinitely. The duress promise that there is no sign anything was
deleted is false on her wrist.

**Root cause.** Two mechanisms compound, and neither is "the App Group wasn't cleared". (1) The
watch's copy is not storage on this device — it is a replica on another device fed by
a one-way push — so `wipeEverything`'s step 4 (SecureWipeService.swift:94-96:
`WidgetDataStore.clear()` + `reloadAllTimelines()`) structurally cannot reach it, and
`WatchBridgeService` exposes no clear or invalidate message at all
(WatchBridgeService.swift:20-26) — `pushSnapshot` is the entire outbound API. (2) The
one channel that can reach it is driven by an entitlement check inside a view
lifecycle rather than by the data: `WidgetDataSyncModifier.sync()` pushes only `if
PurchaseService.shared.isPro` (WidgetDataSync.swift:131-142) and runs only on
onAppear/scenePhase, so a lapsed-Pro user never gets a clearing push and a current-Pro
user gets one only when she next backgrounds the app.

**Fix.**

1. 1. Clear with a real snapshot, not a sentinel: push a normally-encoded
   `WidgetSnapshot` whose `anchorPeriodStart` is nil. Every shipped watch build
   already treats that as "no data" (WatchHomeView.displaySnapshot guards
   `base.anchorPeriodStart != nil`, WatchHomeView.swift:15), as does the iOS widget
   provider (CaelynWidgetProvider.swift:30, :54). No watchOS-side change and no
   version skew — it works on a watch app the user never updates. A `"cleared": true`
   flag may be added later as belt-and-braces but must never be the only signal.
2. 2. Make the clear unconditional and part of the wipe: in step 4 of wipeEverything,
   after `WidgetDataStore.clear()`, call a new `WatchBridgeService.pushCleared()` that
   is NOT gated on `isPro`. An entitlement may gate what data is sent; it must never
   gate removing data.
3. 3. Remove the `isPro` gate from the clearing path generally — in
   WidgetDataSync.sync(), when there is nothing to show, push the empty snapshot
   regardless of entitlement.
4. 4. Introduce a single `DerivedSnapshotPublisher` that rebuilds the snapshot, writes
   the App Group store, reloads widget timelines and pushes to the watch, and make the
   wipe, WidgetDataSyncModifier and CloudSyncCoordinator all call it — so the watch
   can never again be the one replica a state change forgets.
5. 5. Why permanent: the watch stops being an implicit consumer of a push that happens
   to run and becomes a named output of one publisher that every state change goes
   through, and the clear is independent of subscription state.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `CaelynWatch/WatchDataModel.swift`

*Tests:* None existing. Add a WatchBridgeService encoding test asserting the cleared payload
decodes to a snapshot with nil anchorPeriodStart, and a test that pushCleared is
reached from wipeEverything with isPro false. Manual two-device verification required
for the actual WCSession delivery.

#### PRIV-08 — 11 App Lock · 12 Hide app preview · 10 Paranoid Mode (widgets)

With App Lock on, anyone holding her unlocked phone can read "Day 14 · Ovulation
window · Period in 14 days" straight off the Home Screen widget without ever opening
Caelyn. With "Hide app preview" on, the app switcher is masked but the Home Screen
widget is not. The Privacy page's "Someone picks up my phone" answer is incomplete,
and the lock is bypassed by a widget.

**Root cause.** The widget target has no privacy-state input at all. `WidgetSnapshot` carries exactly
one visibility mirror, `hidePreview` (WidgetDataStore.swift:49-51), added for the
lock-screen families, and WidgetDataSync.swift:85 is its only writer — so masking
became a per-view `if` in two of five views (WidgetViews.swift:300, 332) instead of a
property of the snapshot every family must consult. SmallWidgetView / MediumWidgetView
/ LargeWidgetView never check it (WidgetViews.swift:54, 100, 178), and no widget knows
about `lockEnabled` because the snapshot has no such field. Separately, nothing in
CaelynWidget calls `privacySensitive()` (zero hits repo-wide), so the system never
redacts in the locked contexts the widget itself renders in — StandBy for systemLarge
and the accessory families.

**Fix.**

1. 1. Add `lockEnabled: Bool?` to `WidgetSnapshot` (WidgetDataStore.swift:49-51) and
   write it in WidgetDataSync.swift:85 alongside hidePreview. Swift's synthesised
   Codable init decodes an Optional stored property with `decodeIfPresent`, so an
   existing App Group blob written by build 15 decodes to nil rather than throwing —
   the same mechanism hidePreview already relies on.
2. 2. Make masking a property of the snapshot, not of a view: add `var shouldRedact:
   Bool { (hidePreview ?? false) || (lockEnabled ?? false) }` and have ALL five family
   views consult it, replacing the two ad-hoc `if`s at WidgetViews.swift:300 and :332.
3. 3. Define one redacted presentation (brand mark + neutral label, no day number, no
   phase, no countdown) used by every family, so the masked state cannot drift per
   size.
4. 4. Mark the data-bearing content `privacySensitive()` throughout CaelynWidget, so
   the system also redacts in StandBy and on the lock screen independently of Caelyn's
   own flags.
5. 5. Add widgets to Paranoid Mode's description and to the Privacy page's "Someone
   picks up my phone" answer, and have `enableParanoidMode()`
   (SettingsView.swift:522-563) force a snapshot refresh so the widget redacts
   immediately rather than at the next sync.
6. 6. Why permanent: the redaction decision becomes a computed property of the one
   object every widget family already renders from, so a sixth family cannot be added
   without it.

*Files:* `CaelynWidget/WidgetViews.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`

*Tests:* Add a WidgetSnapshot decode test proving a build-15 blob (no lockEnabled key) decodes
with lockEnabled == nil and shouldRedact == false. Add a test that shouldRedact is
true when either flag is set, and a snapshot test per family that the redacted
presentation contains no cycle day or phase string.

#### PRIV-09 — 13 Private notifications · 15 Delete all data

Turning on "Private notifications" changes future reminders but leaves this morning's
"Your period may start soon" sitting in Notification Center for anyone to read. And
after "Delete all data" or a duress wipe, Caelyn's reminders can still be listed on
the lock screen.

**Root cause.** `cancelAll()` is the single notification-cleanup contract for the entire app, and that
contract is DEFINED OVER the pending queue: it is built on
`getPendingNotificationRequests` (NotificationService.swift:140) and there is no call
to `removeDeliveredNotifications` / `removeAllDeliveredNotifications` anywhere in the
target. Every privacy-state transition delegates its whole notification cleanup to
that one routine — the Private toggle (SettingsView.swift:758 /
RemindersView.swift:281 → sync → cancelAll at :166), Paranoid Mode
(SettingsView.swift:553) and wipeEverything (SecureWipeService.swift:88-89) — so no
path in the app has any way to reach the delivered list.

**Fix.**

1. 1. Add `static func clearDelivered()` to NotificationService calling
   `UNUserNotificationCenter.current().removeAllDeliveredNotifications()`. Do NOT
   filter by identifier prefix: the notification centre is per-app, so removeAll is
   both safe and strictly better — no async round trip, and it automatically covers
   legacy `mavie.*` identifiers and any future identifier shape. (Prefix filtering
   remains necessary only for PENDING, where removal is by identifier.)
2. 2. Do NOT put it inside `cancelAll()`. `cancelAll()` is the first statement of
   `sync()`, which runs on ordinary reschedules; clearing her notification centre
   every time a reminder time changes is wrong. Call `clearDelivered()` explicitly
   from the three privacy transitions: the Private-notifications toggle,
   enableParanoidMode, and wipeEverything step 2.
3. 3. In wipeEverything, call it immediately after `await
   NotificationService.cancelAll()` so an interrupted wipe has already cleared the
   visible residue.
4. 4. Update the privacy copy so the Private toggle states that existing banners are
   cleared as well as future ones changed.
5. 5. Why permanent: the delivered list gets its own named operation owned by the
   privacy transitions rather than by the scheduler, so neither concern can silently
   absorb the other.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/RemindersView.swift`

*Tests:* Extract the pending-identifier prefix predicate into a pure function and add a test
for it. Add a test that enableParanoidMode and wipeEverything each invoke
clearDelivered (inject a protocol-backed centre), and that an ordinary reminder
reschedule does NOT.

#### PRIV-14 — 15 Delete all data · 10 Paranoid Mode · 11 duress · 14 Auto-erase (Persistence.live lifetime)

Every privacy action that involves iCloud is "it finishes when you reopen Caelyn" at
best. Caelyn cannot stop syncing, cannot detach from iCloud, and cannot destroy and
rebuild its own database file until the app is restarted — so after a wipe, the still-
live mirror can bring her history back within the same session.

**Root cause.** `Persistence.live` is a `static let` built exactly once per process
(Persistence.swift:96), and the mirrored-or-not decision is made at that single
construction. The code documents the consequence in three places
(SecureWipeService.swift:36-50; SettingsView.swift:508-517, :524-531). What converts
it from an inconvenience into an unkept promise is that the two SILENT wipe callers —
AppLockGate.swift:103-110 and AutoSweepService.swift:22-29 — take the `.thisDevice`
default and so write no deletion marker at all, meaning they have no next-launch
backstop the way the three visible callers do.

**Fix.**

1. 1. Replace the global with an `@Observable PersistenceController` exposing
   `current: ModelContainer` and `rebuild(mirrored: Bool)`, injected from CaelynApp
   and read through the environment by views.
2. 2. Convert the four direct global readers first — they would otherwise keep
   operating on the OLD, still-mirrored container and its retained mainContext after a
   rebuild: CaelynApp.swift:96 (reconcileAppleCredential),
   NotificationService.swift:328, WatchBridgeService.swift:57,
   Health/HealthSyncService.swift:316. Each must go through the controller or take an
   injected ModelContext. Until all four are converted, a "local-only" wipe cannot
   honestly claim the mirror is detached.
3. 3. Make CloudSyncCoordinator re-register its NSPersistentStoreRemoteChange observer
   against the new container on rebuild (CloudSyncCoordinator.swift:40-57); a stale
   observer on a torn-down container is a silent no-op.
4. 4. Rebuild is a full view-tree re-root, so verify on device that @Query views, in-
   flight sheets and the Watch bridge survive it; add a loading state for the rebuild
   window.
5. 5. Once (1)-(3) land, revisit the three dependents: the genuine local-only delete
   can be offered again (SecureWipeService.DeleteAllOffer), the duress/auto-erase
   paths can detach the mirror before wiping, and the store file can be unlinked and
   recreated (PRIV-13 layer 3).
6. 6. Why permanent: the container's mirrored-ness becomes a runtime property with an
   explicit transition, so privacy actions stop being promises deferred to the next
   launch.

*Files:* `Caelyn/Services/Persistence.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* DeletionModelTests.testTheSyncedStoreIsStillAnOnDiskLocalStore (~:675) stays.
testALocalOnlyDeleteIsWithheldWheneverACloudCopyMayExist (~:601) will need inverting
once the local-only path is truthful. Add a test that rebuild(mirrored:false) produces
a container whose configuration has cloudKitDatabase == .none and that the remote-
change observer is re-registered. Device testing with sync on/off transitions is
mandatory.

#### PRIV-15 — 10 Paranoid Mode page (Privacy promises)

With iCloud sync off, the Privacy page tells her "there is no copy of it anywhere
else" and "your data exists in exactly one place: this device", and the subpoena card
says there is nothing to hand over. For most users that is simply untrue: iPhone
backup is on by default and includes Caelyn's database, so a full copy of her history
is in her Apple Account's backup and can be compelled unless Advanced Data Protection
is on.

**Root cause.** The conditional copy is driven by a single predicate,
`CloudDataDeletion.cloudCopyMayExistNow` (CloudDataDeletion.swift:71-80), which
answers only "is there a copy CAELYN can reach?" — yet its false branch is worded as
an absolute about ALL copies (PrivacyTrustView.swift:30 "no copy of it anywhere else";
:110 "exactly one place"; the subpoena card at :86-90). The sentence overclaims past
the domain of the predicate that selects it, so no additional input can fix it — the
wording must be scoped to Caelyn-reachability. The overclaim is then actively ENFORCED
by DeletionModelTests (~:893-900), which asserts those two absolute strings must be
present. Note the product already states the backup fact correctly elsewhere
(iCloudSyncView.swift:151-152), so this is a scoping defect, not an unconsidered
state. The store is in Application Support and nothing marks it `isExcludedFromBackup`
(grep: zero hits).

**Fix.**

1. 1. Rescope the unsynced branch at PrivacyTrustView.swift:30 and :110 from "anywhere
   else" / "exactly one place" to "no copy anywhere Caelyn can reach", then name the
   backup path explicitly and attribute it to her Apple Account rather than to Caelyn.
2. 2. Apply the same rescoping to the subpoena card (:86-90) and, less urgently, to
   the "I lose my phone" answer (:114).
3. 3. Amend CaelynTests/DeletionModelTests.swift ~:893-900: replace the assertions
   that pin the two absolute strings with assertions that the unsynced copy (a)
   mentions the backup path and (b) still states that no Caelyn-reachable copy exists
   — so the test keeps guarding against overclaim without pinning the false claim.
4. 4. Fix iCloudSyncView.swift ~:199 ("it's the only copy of your history") with the
   same scoping.
5. 5. Optional and opt-in only, never default: offer a "Keep Caelyn out of iPhone
   backups" switch that sets `isExcludedFromBackup` on the store URL. Default must
   stay included — a local-first user expects a restore to bring her history back —
   and the UI must say plainly that a restore will then arrive empty.
6. 6. Why permanent: the sentence is bounded by the domain of the predicate that
   selects it, so adding a future copy location changes which claim is made rather
   than making a standing claim false.

*Files:* `Caelyn/Views/Settings/PrivacyTrustView.swift`, `Caelyn/Views/Settings/iCloudSyncView.swift`, `CaelynTests/DeletionModelTests.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* testWithNoCloudCopyTheStrongClaimsAreStillMade currently asserts 'no copy of it
anywhere else' and 'exactly one place' — rewrite to the new true strings.
testNoAbsoluteLocalOnlyClaimSurvivesOnceACloudCopyMayExist keeps as is. If step 5
ships, add a test that the exclusion flag round-trips on the store URL and defaults to
not-excluded.

#### PRIV-17, PRIV2-04 — 14 Auto-erase if inactive

The "erase everything if I don't open the app for N days" safety net works backwards
in the two situations it exists for: restoring her phone from a backup that is older
than her window erases her entire history the moment she opens Caelyn on the new
phone, with no prompt; and anyone holding a lost or stolen phone can keep the data
alive forever simply by tapping the icon now and then, because merely reaching the
lock screen — without ever unlocking — resets the clock.

**Root cause.** Every input to the sweep decision is restorable, mirrorable model data and none of it
is device-local: autoWipeEnabled, autoWipeAfterDays and lastActiveAt are plain stored
@Model properties (/Users/smile/Desktop/caelyn/Caelyn/Models/UserProfile.swift:78-80)
in the SwiftData store that Persistence.live opens at the default Application Support
location with no isExcludedFromBackup anywhere in the repo, so the decision is made
from the age of the restored bytes rather than from anything this install observed.
Separately, AutoSweepService.recordActivity
(/Users/smile/Desktop/caelyn/Caelyn/Services/AutoSweepService.swift:31-36, verified)
takes no reason and AppLockGate.sweepThenRecordActivity
(/Users/smile/Desktop/caelyn/Caelyn/Views/Main/AppLockGate.swift:91-95) stamps
unconditionally without reading isUnlocked — it is called from `.task` on appear (:55)
and from the `.active` branch (:70-71) before tryUnlock is even considered. "Can the
lock screen bar entry" is already a three-part predicate inside showLockScreen
(:79-87) that nothing names, so any second copy of it will drift.

**Fix.**

1. 1. Add a device-scoped install marker following AccountIdentityStore's existing
   Keychain pattern: a generic-password item with
   `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` holding the install's first-
   launch date. ThisDeviceOnly items are excluded from backups and do not restore to a
   new device, which is exactly the signal needed. UserDefaults and any @Model
   property cannot be used because both restore.
2. 2. Change `AutoSweepService.checkAndSweep` to take the marker and fail CLOSED on
   absent evidence: if the marker is absent (fresh install or restored device), re-
   stamp `lastActiveAt = now`, write the marker, and return without sweeping. A sweep
   may only run when this install has itself observed an earlier active session.
3. 3. Name the lock predicate once. Extract showLockScreen's capability test
   (AppLockGate.swift:81-83) into a single `LockStatus`/`canBarEntry` value shared by
   the gate and the sweep, so the fail-open case has exactly one definition (this is
   the same helper the App-Lock-inert item PRIV-11 needs — land them together or have
   PRIV-11 consume it).
4. 4. Split the stamp from the sweep and give recordActivity a reason:
   `recordActivity(profile:modelContext:reason:)` where reason is `.authenticated` or
   `.lockNotRequired`. AppLockGate must stamp only after a successful unlock (the
   `.correct` branch of verifyPIN, AppLockGate.swift:99-101, and the success path of
   tryUnlock), OR when the named predicate from step 3 says the lock cannot bar entry
   at all — not when `lockEnabled == false`. The lockEnabled==false keying is a data-
   loss path: a woman whose Face ID was disabled at the OS level and who never set a
   PIN uses Caelyn daily with no authentication step, hits neither branch, and gets
   wiped.
5. 5. Replace AppLockGate.swift:55 and :70-71's shared `sweepThenRecordActivity()`
   with a sweep-only call at those two points; the stamp now happens on the unlock
   paths only.

*Files:* `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/Account/AccountIdentityStore.swift`

*Tests:* Add to AutoSweepStateTests: an unauthenticated foreground leaves lastActiveAt
untouched; a sweep with no install marker re-stamps and does not wipe; a sweep with a
marker older than the window wipes. CaelynTests.testAutoSweepWindow
(CaelynTests.swift:993) tests only shouldSweep and is unaffected. Add an
UpgradeAndDeviceMatrixTests case for "restored backup, marker absent".

#### PRIV2-02, PRIV-10 — 11 App Lock PIN+biometrics (duress setup and PIN change)

Her emergency "duress" PIN — the one that is supposed to wipe everything if someone
forces her to unlock the app — can be silently switched off without her knowing:
changing her normal PIN to the same digits is accepted, and after that the duress PIN
just unlocks the app normally while Settings still says a duress PIN is armed. Setting
one up also quietly burns her limited unlock attempts, and if she happens to be in a
lockout it will even accept a duress PIN identical to her real one.

**Root cause.** PINService owns both hashes and the shared salt but exposes no pure equality
predicate, so the only comparison available to a caller is `verify()` — an
authentication routine that reads the lockout, calls registerFailure and resets
attempts (/Users/smile/Desktop/caelyn/Caelyn/Services/PINService.swift:55-68, :80-90).
The cross-secret invariant "primary ≠ duress" therefore lives in a view and is
enforced asymmetrically and unreliably: PINViews.swift:176 gates it on `mode ==
.duress` only, so the primary path (:190, `PINService.setPIN(pin)`) has no check at
all; and the one check that exists is written as `verify(pin) == .correct`, so every
non-.correct verdict — including `.lockedOut` from the early return at
PINService.swift:56-58 — is read as "different". Because verify compares primary
before duress (:61-66) a collision resolves to .correct and the duress branch becomes
unreachable, while `hasDuress` (:31) only asks whether the Keychain item exists, so
PINViews.swift:228-243 keeps offering "Remove duress PIN". setDuressPIN (:41-46) also
omits the resetAttempts() that setPIN performs (:37), so attempts spent during setup
are never returned.

**Fix.**

1. 1. In /Users/smile/Desktop/caelyn/Caelyn/Services/PINService.swift add one private,
   non-side-effecting helper and two public predicates — no lockout read, no
   registerFailure, no resetAttempts: `private static func matches(_ pin: String, _
   account: String) -> Bool { guard let salt = keychainData(Account.salt), let stored
   = keychainData(account) else { return false }; return hash(pin, salt: salt) ==
   stored }`, then `static func matchesPrimary(_ pin: String) -> Bool` and `static
   func matchesDuress(_ pin: String) -> Bool`.
2. 2. Make the setters failable and move the invariant into the service, so no future
   UI can violate it: `@discardableResult static func setPIN(_ pin: String) -> Bool {
   guard !matchesDuress(pin) else { return false }; … }` and the mirror in
   setDuressPIN guarding on matchesPrimary. This is the permanent fix: the invariant
   now lives with the data that defines it, not in one of two call sites.
3. 3. Add `resetAttempts()` to setDuressPIN (:41-46) so setup can never leave her with
   fewer unlock attempts than the UI advertises.
4. 4. Rewrite PINViews.swift:173-197 `handle` to use the predicates only: at `.enter`,
   `if mode == .duress, PINService.matchesPrimary(pin)` (and the new symmetric `if
   mode == .primary, PINService.matchesDuress(pin)`), showing "Your duress PIN must be
   different from your normal PIN." Then at `.confirm`, honour the Bool the setter
   returns and surface the same message rather than dismissing on a refused write.
5. 5. Make the Duress section honest: PINViews.swift:228-243 currently shows "Remove
   duress PIN" purely from `hasDuress`. Add a disarmed state — when `hasDuress` is
   true but a one-time reconciliation found the two stored hashes equal, show a
   warning row ("Your duress PIN is no longer armed — set a new one") instead of
   "Remove".
6. 6. One-time reconciliation for installs already in the collided state: the two
   hashes share a salt, so equal stored hashes means equal PINs and is directly
   detectable without the plaintext. On first launch after the fix, if the primary and
   duress Keychain blobs are byte-identical, delete the duress item and set a
   UserDefaults flag that drives the warning row in step 5. Never delete the primary.

*Files:* `Caelyn/Services/PINService.swift`, `Caelyn/Views/Main/PINViews.swift`

*Tests:* Add to the PIN tests near CaelynTests.swift:984:
testChangingThePrimaryPINToTheDuressPINIsRefused,
testSettingADuressPINDoesNotConsumeUnlockAttempts,
testDuressPINCannotEqualPrimaryEvenDuringLockout, and
testACollidedInstallIsReconciledOnFirstLaunch. CaelynTests.swift:984
(testPINHashIsDeterministicAndSaltSensitive) is unaffected by this item but will be
affected by the PIN-crypto item (PRIV-18/PRIV2-14) — land this one first.

#### PRIV2-05, PRIV-16 — 14 Auto-erase if inactive · 15 Delete all data (device / device+cloud)

Two sides of the same silence: when the auto-erase actually fires she is never told,
so coming back from five weeks away looks exactly like Caelyn losing two years of her
history; and when she taps "Delete all data", neither confirmation dialog mentions
that Caelyn will also delete every period and symptom entry it wrote into Apple Health
— which she may be relying on in other apps.

**Root cause.** wipeEverything's only parameter describing the operation is `Scope`
(/Users/smile/Desktop/caelyn/Caelyn/Services/SecureWipeService.swift:21-34, verified),
which models exactly one axis: this-device vs this-device-and-cloud. Two other axes
are therefore not values and cannot be inspected, varied or explained. (a) REACH: the
Apple Health step (:91-92, `await HealthKitService.deleteAllOwnSamples()`) sits
outside the parameter entirely — unconditional and untoggleable — while the consent
copy is generated solely from `deleteAllOffer` (SettingsView.swift:803-805, consumed
at :185 and :197), a pure function of mayHaveCloudCopy, so the dialog can only ever
describe the one axis Scope models. (b) REASON: wipeEverything was built to satisfy
the duress contract, where silence is a requirement (documented at
AppLockGate.swift:103-106 and SecureWipeService.swift:9-10), and
AutoSweepService.checkAndSweep (AutoSweepService.swift:22-29) adopts that whole
implementation for a purpose with the opposite requirement, returning Void and
recording nothing. Scope's own 1.3 history proves the precedent for a second axis
exists; it was simply never extended from "what gets wiped" to "why".

**Fix.**

1. 1. Replace the bare `Scope` with a `WipeReach` value carrying every axis: `local`
   (always true), `cloud: Bool`, `appleHealth: Bool`. Gate step 3
   (SecureWipeService.swift:91-92) on `reach.appleHealth` exactly as step 0 already
   gates on cloud. Default the parameter to everything so AppLockGate.swift:108
   (duress) and AutoSweepService.swift:27 keep today's total-erasure behaviour with no
   call-site change.
2. 2. Give WipeReach a `consentSentence` and render BOTH dialogs from it
   (SettingsView.swift:160 and :197-199) instead of the two hand-written literals.
   Permanent because the copy is derived from the same value that drives the
   behaviour: adding a future axis forces the sentence to change.
3. 3. Add a second parameter `reason: WipeReason` (`.duress`, `.autoSweep`,
   `.userRequested`). In the `.autoSweep` case only, write a UserDefaults marker (e.g.
   `caelyn.autoEraseFiredAt`) before returning. The marker-survives-the-wipe precedent
   holds: there is no removePersistentDomain anywhere, SecureWipeService.swift:113-127
   is an explicit allowlist, RatingService.reset clears three named keys, and
   HealthSyncAnchorStore sweeps only the `caelyn.hkAnchor.` prefix. Add the new key to
   the explicit NOT-cleared note beside CloudDataDeletion.deletedAtKey (:125,
   :131-133).
4. 4. Surface the marker as a dismissible banner, modelled on RootView's
   storeWarningBanner
   (/Users/smile/Desktop/caelyn/Caelyn/Views/RootView.swift:87-120), wording it as her
   own setting doing what she asked: "Caelyn erased everything because it hadn't been
   opened for N days — the 'Auto-erase if inactive' setting you turned on."
5. 5. The banner cannot be @State-initialised the way storeWarningBanner is
   (RootView.swift:8 reads its flag once in the @State initialiser, and RootView is
   constructed inside AppLockGate's content() closure during the same body pass that
   attaches the sweeping .task at AppLockGate.swift:27, :54 — so on the launch where
   the sweep fires the flag is written after the initialiser has already run). Read
   the marker in an `.onAppear`/`.task` on RootView, or publish it through an
   ObservableObject, and clear it when she dismisses.
6. 6. Never show this banner for `.duress` — that reason must remain indistinguishable
   from a brand-new install, which is why reason must be a parameter rather than
   inferred.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Views/Main/AppLockGate.swift`

*Tests:* DeletionModelTests.testALocalOnlyWipeClearsEveryRowAndAttemptsNoCloudDeletion and
testALocalWipeDoesNotForgetThatSheDeletedHerCloudCopy call
wipeEverything(modelContext:scope:) and must be updated for the new parameters. Add: a
.autoSweep wipe writes the marker and a .duress wipe does not; a wipe with
reach.appleHealth == false leaves Health samples alone; consentSentence names Apple
Health whenever reach.appleHealth is true.

#### PRIV2-06 — 11 App Lock PIN+biometrics (duress)

The duress PIN is supposed to erase everything invisibly so the person standing over
her sees nothing unusual. What actually happens is that the keypad vanishes and
"Caelyn is locked / Unlock with Face ID" comes back for the several seconds the wipe
takes — which reads unmistakably as a rejected PIN, and the Unlock button stays live
so he can tap it and hold the phone to her face.

**Root cause.** The gate's visible surface is derived from the very facts the wipe destroys, with no
state meaning "a wipe is running". showPINEntry
(/Users/smile/Desktop/caelyn/Caelyn/Views/Main/AppLockGate.swift:21-23) keys off
showingPINPad and PINService.isSet; showLockScreen (:79-87) keys off
hasOnboarded/lockEnabled (from @Query profiles, :5) and isUnlocked.
SecureWipeService.wipeEverything mutates three of those four inputs as it runs — the
profile rows at :84-86 and the Keychain at :99 — so the surface is whatever is left of
her secrets at each instant and the transition is uncontrolled by construction.
Compounding it, verifyPIN (:97) is not annotated @MainActor unlike its neighbours at
:91 and :118, so the Task at :107 cannot start until the main actor has already
rendered the intermediate state and `isUnlocked = true` at :109 runs off-main. The
wipe itself is unbounded in duration: HealthKitService.deleteAllOwnSamples
(SecureWipeService.swift:92) queries and deletes every sample Caelyn ever wrote across
every symptom type.

**Fix.**

1. 1. Annotate `private func verifyPIN` at AppLockGate.swift:97 with `@MainActor`,
   matching :91 and :118. This single line is the actual mechanism fix — everything
   after it is presentation.
2. 2. Add `@State private var isWiping = false`. Set it true at :106 before the Task;
   clear it in a `defer` inside the now-MainActor Task body.
3. 3. Add isWiping to the derivation with explicit precedence: while isWiping, force
   the overlay to stay up and force showPINEntry to stay TRUE, so the surface
   continues to show the PIN pad she just typed into rather than reverting to the
   LockScreen card. Do not let PINService.isSet going false (step 5 of the wipe) flip
   the gate mid-operation.
4. 4. Disable the unlock affordances while isWiping: the Unlock button at
   AppLockGate.swift:201-211 is rendered and enabled whenever canAuthenticate — gate
   it, and gate the PIN pad's submit, so nothing he taps does anything.
5. 5. Keep the visual identical to a normal in-progress unlock: no spinner captioned
   anything, no error text, no state change he could read as "something happened". The
   pad simply stops responding until the wipe completes and isUnlocked flips to true,
   at which point the app opens looking brand new.
6. 6. Re-verify the post-wipe landing: after :109 the profile rows are gone so
   hasOnboarded is false and showLockScreen returns false at the first guard, which is
   the intended fresh-install appearance. Assert this rather than relying on it.

*Files:* `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* AppLockGate has no unit coverage today. Add a UI test in CaelynUITests using --ui-
test-disable-device-auth plus a seeded PIN and duress PIN: enter the duress PIN and
assert that the string "Caelyn is locked" never appears and the Unlock button is not
hittable between submission and the onboarding screen.

#### PRIV2-07 — 10 Paranoid Mode page

She taps "Lock everything down", is told it cancels all reminders, and then gets a
Caelyn notification on her lock screen the same day — because note-to-self reminders
she attached to individual log entries come straight back the next time she opens the
app, and there is no switch anywhere that turns them off as a class.

**Root cause.** The purge was never durable state. cancelAll() is the first line of every sync()
(/Users/smile/Desktop/caelyn/Caelyn/Services/NotificationService.swift:166), so the
pending queue is wiped and rebuilt from policy on every resync; Paranoid Mode's
cancelAll() at SettingsView.swift:553 is therefore a one-shot flush, not a state
change. The real policy surface is "which flags does the rebuild consult", and note
reminders are absent from it: their policy lives in per-entry
CycleEntry.noteReminderRule, not in UserProfile, and syncFromLiveStore calls
scheduleNoteReminders unconditionally (NotificationService.swift:337-345, verified),
filtering only on `noteReminderRule != nil`, `!noteReminderDone`, a non-empty note and
a future fire date (:351-376). CaelynApp.swift:72-74 runs syncFromLiveStore on every
`.active` transition. The same asymmetry makes Settings lie in a second place:
remindersDetail's count array (SettingsView.swift:604-611) enumerates only the five
profile flags, so the row reads "Off" while note reminders fire.

**Fix.**

1. 1. Add `var noteRemindersEnabled: Bool = true` to
   /Users/smile/Desktop/caelyn/Caelyn/Models/UserProfile.swift. An inline-defaulted
   Bool is what SwiftData lightweight migration and CloudKit mirroring both require.
2. 2. Early-return in NotificationService.scheduleNoteReminders (:351) when the flag
   is false — pass it in from syncFromLiveStore (:337-345), which already holds the
   profile. Returning early also leaves the stored noteReminderAt values untouched, so
   nothing is lost and turning the class back on restores them.
3. 3. Set it false in enableParanoidMode (SettingsView.swift:546-553) beside the other
   five flags, so the single class-level policy surface now covers every reminder the
   rebuild can produce.
4. 4. Surface it in RemindersView as its own toggle ("Note-to-self reminders"),
   because today the only way to stop them is to open each entry individually, which
   she has no reason to know.
5. 5. Add it to the remindersDetail count array (SettingsView.swift:604-611), or the
   Settings row will keep saying "Off" while notes fire — the same enumeration bug in
   a second place.
6. 6. Upgrade caveat: because the field defaults to true, a user who already tapped
   Paranoid Mode in 1.3 keeps her note reminders on after this build. Either leave
   that (it preserves today's behaviour and is not a regression) or re-run the class-
   off write once for profiles whose five reminder flags are all false — decide
   explicitly and comment the choice.
7. 7. Correct the dialog copy at SettingsView.swift:427 to match what the code now
   actually does (this is where the P3 copy item PRIV-20's first half lands).

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/RemindersView.swift`, `Caelyn/Services/ProfileStore.swift`

*Tests:* No existing test schedules note reminders. Add one asserting that
scheduleNoteReminders schedules nothing when noteRemindersEnabled is false, and one
asserting enableParanoidMode leaves it false after a subsequent syncFromLiveStore.
CaelynTests.testPrivateNotificationsNeverLeakHealthTerms (:629) iterates
Category.allCases including .noteReminder and is unaffected. ProfileStore.merge needs
a rule for the new Bool — add a ProfileStoreTests case (an OR would resurrect
reminders Paranoid Mode turned off, so AND or newest-wins is required).

#### PRIV2-08 — 10 Paranoid Mode page

Tapping Paranoid Mode permanently destroys her entire import history — every Flo,
Clue, Natural Cycles or Caelyn-export import she made loses its record, Settings →
Data → Imports goes to "Nothing imported yet", and "Undo this import" is gone forever.
Nothing warns her, and it has nothing to do with privacy.

**Root cause.** enableParanoidMode calls HealthSyncService.forgetSyncState()
(/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/SettingsView.swift:541-543,
commented only as "Forget which values came from Health"), and forgetSyncState is the
only entry point to a store holding two unrelated kinds of state: it calls both
HealthSyncAnchorStore.removeAll() and ledger.removeAll()
(/Users/smile/Desktop/caelyn/Caelyn/Services/Health/HealthSyncService.swift:329-333,
verified). ImportLedger exposes no narrower bulk removal. The irreversibility is a
second, separable mechanism: removeAll()
(/Users/smile/Desktop/caelyn/Caelyn/Services/Import/ImportLedger.swift:199-206,
verified) clears claims, byRecord and batchList, deletes the backing file outright,
AND leaves `loaded = true` — so there is no reduced-copy save() and loadIfNeeded() can
never recover anything. Even a correctly scoped caller would be unrecoverable against
a mistake, because the ledger's only bulk operation is destructive-by-construction
rather than a filtered rewrite.

**Fix.**

1. 1. Add `func removeHealthProvenance()` to ImportLedger implemented as a FILTERED
   REWRITE, not a delete: keep every claim whose sourceBundleID begins with "import.",
   drop the rest, rebuild byRecord from the survivors, keep every batch still
   referenced by a surviving claim, then `save()`. Never remove the file.
2. 2. Use the discriminator the code actually guarantees. There is no single
   "HealthKit bundle ID" to filter on: health claims carry the ORIGINATING app's
   bundle id (HealthDataCatalog.swift:141, `sourceBundleID: source.bundleIdentifier` —
   for a user who writes to Health from Flo that is Flo's id, and it is what
   HealthSourceFilter matches on at HealthSyncService.swift:188 and :221). File-import
   observations are stamped `sourceBundleID = "import.\(source.rawValue)"`
   (ObservationBuilder.swift:21, used at :31), so the "import." prefix is the only
   reliable split.
3. 3. Change HealthSyncService.forgetSyncState (:329-333) to call
   removeHealthProvenance() instead of removeAll(). Its doc comment's promise —
   "nothing in her log is considered Caelyn-owned any more, so a later reconnect can
   only ever add" — is still satisfied, because that promise is about Health-sourced
   claims only.
4. 4. Keep ImportLedger.removeAll() but restrict it to SecureWipeService (where
   destroying the file IS the point) and to tests. Add a comment at
   ImportLedger.swift:199 saying so, and make save() able to write a reduced copy so a
   filtered rewrite is always possible.
5. 5. Permanent because the scoping now lives in the store that owns the taxonomy, not
   in each caller: a future caller asking to forget Health provenance physically
   cannot reach the file-import batches.

*Files:* `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Import/ImportHistoryView.swift`, `Caelyn/Services/Import/ObservationBuilder.swift`

*Tests:* HealthSyncTests uses ledger.removeAll() in setup (HealthSyncTests.swift:500, :515) and
is unaffected — it wants the broad behaviour. Add
testForgettingHealthProvenanceKeepsFileImportHistory (probe below) and a second
asserting that a Health-sourced claim IS dropped by the same call. Installs that
already ran Paranoid Mode or a Health disconnect have lost their batches and cannot
recover them: the fix is forward-only, say so in the release note.

#### PRIV2-11 — 11 App Lock PIN+biometrics

Deleting Caelyn and reinstalling it does not remove her PIN. A freshly installed app
shows "App PIN · On" for a PIN she never set in it — and, far worse, a duress PIN she
set months ago and thought she disposed of by deleting the app is still armed, so
typing what she now believes is her normal PIN wipes her new history without warning.

**Root cause.** Survival comes from the keychain ACCESS GROUP, not from the service name:
/Users/smile/Desktop/caelyn/Caelyn/Caelyn.entitlements declares no keychain-access-
groups, so every item lands in the default group (the app identifier) and iOS does not
purge an app's default access group when the app is deleted. Renaming kSecAttrService
would change nothing — it is an opaque label, not an isolation or lifetime boundary.
The actual defect is that nothing on first launch reconciles "no UserProfile has ever
existed in this install" against "PIN secrets are present": PINService.isSet and
hasDuress are pure Keychain presence checks
(/Users/smile/Desktop/caelyn/Caelyn/Services/PINService.swift:30-31, verified),
clearAll() is the only removal and is called from just two places (PINViews.swift:257,
SecureWipeService.swift:99), and SettingsView.swift:360-364 renders the row straight
from isSet while :355 enables the lock toggle on the same value.

**Fix.**

1. 1. Add a UserDefaults install-generation marker, e.g. `caelyn.keychainGeneration`.
   UserDefaults is correct here precisely because it is removed with the app, which is
   the signal the Keychain does not give.
2. 2. Gate the clear on ALL THREE conditions, or the first launch of this build will
   sign out and de-PIN every existing 1.3 user — "marker absent" is not "fresh
   install", it is "fresh install OR any build shipped before this fix", and that
   would be a P0 regression hiding inside a P1 fix. Clear only when: (a) the marker is
   absent, AND (b) the live store opened cleanly —
   `!UserDefaults.standard.bool(forKey: Persistence.storeFailedKey)`
   (Persistence.swift:48) — so a transient store failure is never mistaken for a fresh
   install, AND (c) a fetch finds zero UserProfile rows.
3. 3. When all three hold, call PINService.clearAll() (and the equivalent
   reconciliation for AccountIdentityStore if it has the same shape), then write the
   marker. When they do not all hold, write the marker WITHOUT clearing — that is the
   upgrade path for every existing install.
4. 4. Run this reconciliation in the same launch pass as ProfileStore.dedupe, before
   AppLockGate's gate evaluates, so Settings never renders a stale "App PIN · On".
5. 5. Permanent because it ties the secret's lifetime to the install rather than to
   the app identifier: no future Keychain item added to PINService can outlive a
   delete-and-reinstall, provided it is cleared by clearAll().

*Files:* `Caelyn/Services/PINService.swift`, `Caelyn/Services/Persistence.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* CaelynTests.testSecureWipeClearsSwiftData sets a PIN and asserts it is gone —
unaffected. Add to UpgradeAndDeviceMatrixTests: (a) marker absent + profile rows
present + clean store → PIN survives (the 1.3 upgrade case); (b) marker absent + zero
profiles + clean store → PIN cleared (the reinstall case); (c) marker absent +
storeFailedKey true → PIN survives.

#### PRIV2-12 — 15 Delete all data (device / device+cloud)

She taps the most consequential button in the app — delete everything here and in
iCloud — and the screen does not change. On a weak connection she waits, assumes it
failed, and taps through both confirmations again, so two wipes run at once; or she
backgrounds the app and iOS suspends it part-way, leaving the iCloud copy gone while
every row is still on the phone and nothing scheduled to finish.

**Root cause.** deleteAllData launches an unstructured, detached `Task {}` and returns
(/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/SettingsView.swift:807-823,
verified) — the view's @State block (:10-42) has no in-flight flag at all (isRestoring
at :41 is the StoreKit restore, unrelated), so there is no spinner, no disabled
control, no "Deleting…" label and no re-entry guard; Haptics.warning() at :822 fires
synchronously, making it a haptic-only acknowledgement. The first thing the task
awaits is the cloud half (SecureWipeService.swift:79-81 awaits
CloudDataDeletion.deleteCloudCopy before any local delete at :84-85), which is two
network round trips — `await CloudAccount.availability()` at
CloudDataDeletion.swift:106 then modifyRecordZones at :121. Second mechanism: the
outcome is reported by assigning to @State on a view that the wipe itself destroys
(the profile rows it reads are deleted at SecureWipeService.swift:84-86), so the
honest "your iCloud copy was not deleted" message can be lost exactly when it matters.
The correct pattern already exists in this codebase at AccountView.swift:33, 315, 320,
372, 377 (isDeletingCloud, a "Deleting…" title, and .disabled).

**Fix.**

1. 1. Add `@State private var isDeletingAll = false` to SettingsView and set it true
   before launching the task, false in a defer. Mirror
   AccountView.swift:33/315/320/372/377 exactly: change the row's label to "Deleting…"
   and apply `.disabled(isDeletingAll)`. The flag and the label are the same state, so
   this is also the re-entry guard.
2. 2. Gate the second dialog's presentation on `!isDeletingAll`
   (SettingsView.swift:170-200) so the confirmation path cannot be re-entered while a
   wipe is in flight.
3. 3. Move the outcome off the dying view: have wipeEverything persist the cloud
   outcome to a UserDefaults key alongside CloudDataDeletion's pendingKey/deletedAtKey
   whenever `cloudOutcome?.didDelete == false`, and surface it from RootView, which
   already owns a durable banner for exactly this class of honest message
   (storeWarningBanner, RootView.swift:73, 87-120). Clear the key when she dismisses
   it.
4. 4. Make the task structured enough to survive a background: either wrap the body so
   the cloud half records its own completion in CloudDataDeletion's pending journal
   before the local half starts (it already has pendingKey), or begin a UIApplication
   background task around the sequence. The local half must be resumable — this is the
   same journal the crash-resume item (PRIV-24) needs, so land that item's marker
   alongside.
5. 5. Permanent because the in-flight fact becomes view state that gates every entry
   point, and the outcome becomes durable state owned by a view that outlives the wipe
   — neither depends on the user staying on the screen.

*Files:* `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* DeletionModelTests exercises SecureWipeService directly and never goes through the
view. Add a unit test that a failed cloud half writes the durable outcome key, and a
UI test asserting the row reports "Deleting…" and is not tappable twice.

#### PRO-01, PRO-04 — 29 TTC fertility score / 31 Full year view

Caelyn learns her real cycle, then two Pro screens quietly ignore what it learned: the
TTC card's headline score says she is fertile today while the line underneath says the
window starts in three days, and the year grid paints fertile, PMS and period days on
different dates from the Calendar tab one swipe away.

**Root cause.** PredictionEngine.fertileWindow and ovulationEstimate carry a default `lutealLength:
Int = 14` (PredictionEngine.swift:245-260), and pmsWindow defaults to 5 days
(PredictionEngine.swift:292-297). A default-valued personalisation parameter makes
personalisation opt-in and its omission silent — the compiler cannot flag it. So
TTCDashboardCard.swift:39 (`PredictionEngine.fertileWindow(nextPeriodStart: next)`,
verified at HEAD) compiles cleanly while asking for a generic 14-day model, sitting
next to a score TTCFertilityEngine computed with the learned luteal HomeView passed in
(HomeView.swift:132-138). The same shape in YearViewSection: :34 rebuilds its own
CycleModel, extracts only .nextPeriodStart and throws the model away (the comment on
:32-33 claiming 'same derivation as every other surface' is true of that one scalar
only), then MiniMonthView.dotColor at :144-152 rebuilds all three windows from
`profile?.averagePeriodLength ?? 5` and the two engine defaults — while
CalendarMath.swift:133-135 uses cycle.predictedPeriodWindow / cycle.pmsWindow /
cycle.fertileWindow (CyclePrediction.swift:285-316). TTCFertilityEngine.result repeats
the hazard with its own `lutealLength: Int = 14` (TTCFertilityEngine.swift:17).

**Fix.**

1. 1. Remove the `= 14` defaults from PredictionEngine.fertileWindow
   (PredictionEngine.swift:254) and ovulationEstimate (:245), the `= 5` default from
   pmsWindow (:292), and the `= 14` default from TTCFertilityEngine.result (:17). This
   is the permanent half: it converts a silent wrong answer into a compile error at
   every present and future call site.
2. 2. TTCDashboardCard: replace `nextPeriodStart: Date?` with `fertileWindow:
   ClosedRange<Date>?` and delete the PredictionEngine call at
   TTCDashboardCard.swift:39. Pass `fertileWindow: fertileWindow` from
   HomeView.swift:228 (already computed at HomeView.swift:127). Also inject `today:`
   so the card is testable without the wall clock (it reads .now at :38, as does the
   engine at TTCFertilityEngine.swift:26).
3. 3. YearViewSection: compute the three windows once in InsightsView from its
   existing `cycle` and thread them down as values — `YearViewSection(entries:profile:
   predictedWindow:pmsWindow:fertileWindow:isPro:onUpgrade:)`. profile is still needed
   for firstDayOfWeek.
4. 4. Delete the second CycleModel.make at YearViewSection.swift:34 and the three
   PredictionEngine calls at :145-148, leaving dotColor to test membership in the
   three passed-in ranges.
5. 5. Audit the remaining call sites after step 1 stops compiling and pass the learned
   values from CycleModel at each one.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Views/Home/TTCDashboardCard.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Insights/YearViewSection.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* No TTC or YearView tests exist. Add: parity test asserting the TTC card's window ==
CycleModel.fertileWindow for a learned luteal of 11; parity test asserting YearView's
three windows == CalendarMath's for entries yielding pmsDaysBefore 3 / luteal 11. Any
existing PredictionEngine test that omitted lutealLength must now pass it explicitly.

#### PRO-02 — 32 PDF export

She generates the PDF for her doctor. It prints 'Average cycle length 28 days' and
'Cycle regularity: Insufficient data' — the textbook default, labelled as hers — while
the app in her hand says 34 ± 6 and 'Irregular'.

**Root cause.** Two mechanisms compound. (1) One `entries` parameter at ExportService.generatePDF
(ExportService.swift:109-133) serves two incompatible roles: the range slice for the
entry table, notes and symptom chart, and the full history that whole-history
statistics require. ExportView.swift:274 passes filteredEntries, so
drawClinicalSummary (:206) and drawInsightsSection (:256) build CycleModel.make over
the slice and drawCycleTimeline renders the slice's cycles. The default range is Last
3 months, which commonly holds exactly one completed cycle. (2) The section's
admission guard and its statistics disagree about what 'enough data' means:
ExportService.swift:204 guards on raw `cycles` being non-empty, while
PredictionEngine.averageCycleLength/averagePeriodLength return the profile fallback
when fewer than 2 plausible cycles are present (PredictionEngine.swift:115-127), and
that fallback is the onboarding seed (CyclePrediction.swift:217-221,
`profile?.averageCycleLength ?? 28`). So one cycle admits the section and prints a
seed as a measurement.

**Fix.**

1. 1. Split the parameter: `ExportService.generatePDF(history: [CycleEntry],
   rangeEntries: [CycleEntry], profile:range:includeNotes:)`. `history` (all entries)
   feeds drawClinicalSummary, drawInsightsSection and drawCycleTimeline;
   `rangeEntries` feeds drawEntryTable, drawNotes, drawSymptomBarChart and the 'days
   with data' row. ExportView.swift:274 becomes `generatePDF(history: entries,
   rangeEntries: filteredEntries, …)`.
2. 2. Better form: pass the caller's CycleModel in directly so the summary is
   literally the object Insights renders, and delete both in-function CycleModel.make
   calls (ExportService.swift:206, :256) so no future edit can re-derive from the
   wrong set.
3. 3. Close mechanism (2): make the summary seedless. Either have the clinical summary
   read a non-fallback accessor that returns nil below 2 plausible cycles, or raise
   the guard at ExportService.swift:204 to require the same >= 2 threshold
   PredictionEngine uses. When there is not enough data, print 'Not enough data yet' —
   never a number.
4. 4. Label the ranges in the PDF so a clinician can tell them apart: 'Statistics: all
   recorded history (<first date> – <last date>). Entries listed: <selected range>.'

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* CaelynTests.swift:392 (generatePDF smoke test) keeps passing after the signature
change (update the call). Add a PDFKit text-extraction test asserting the summary
shows the all-history average, not the seed, and a second asserting 'Not enough data
yet' when history holds one cycle.

#### PRO-03 — Paywall + restore + lapse (specialist-mode gates)

A subscriber who turned on Pregnancy mode and later let her subscription lapse cannot
turn it off — the switch is gone — while pregnancy symptoms keep appearing in every
log and a perimenopause or PCOS 'insight' permanently occupies one of her five free
insight slots.

**Root cause.** Specialist mode is modelled as a single stored capability flag
(UserProfile.swift:54-63) rather than as (stored user intent x live entitlement), and
there is no derivation point between the flag and its consumers — so every call site
must independently remember to check purchase.isPro. Six consumers read the flags
directly (HomeView.swift:227/231/235, DailyLogForm.swift:341-353,
PatternEngine.swift:398/415/423, ExportService.swift:254-257); only HomeView's three
cards remembered. That is a distributed-invariant failure: adding a gate at each site
reproduces the bug at the next consumer added. Compounding it, the off-switch is co-
located with the upsell inside the same `if purchase.isPro` branch in
CycleSettingsView (:24-36), so losing the entitlement removes the only way to record a
change of intent.

**Fix.**

1. 1. Add one derivation: `ProModes.effective(profile:isPro:)` returning the set of
   modes that may affect behaviour. Never mutate the stored flags — re-subscribing
   must restore her setup, and ProfileStore's additive union stays correct.
2. 2. Route every consumer through it: DailyLogForm.visibleSymptoms (:339-356),
   PatternEngine.insights (add an isPro / effective-modes parameter; condition gating
   at :392-433), ExportService.drawInsightsSection (:254-257), HomeView (:227/231/235)
   and CycleSettingsView (:24-36).
3. 3. TRAP to avoid: DailyLogForm.swift:380 renders chips from visibleSymptoms while
   selected state comes from entry?.symptoms (:367). If the effective set simply drops
   the pregnancy/perimeno symptoms, anything she logged while Pro stays stored on the
   entry with no chip — invisible, unremovable data. Union visibleSymptoms with the
   symptoms already present on the entry being edited so every stored value remains
   visible and removable.
4. 4. Separate the off-switch from the upsell: in CycleSettingsView, when !isPro and a
   mode flag is true, show a plain 'Turn off <mode>' row outside the locked section.
   'I gave birth' must be reachable without re-subscribing.
5. 5. Add a source-scan test (same shape as SignInWithAppleComplianceTests) that fails
   when any view or service reads a specialist flag off UserProfile without going
   through ProModes.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/ExportService.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Insights/PatternInsightsSection.swift`

*Tests:* PatternEngine tests passing a profile with condition modes need the new isPro argument
(default true keeps them green). Add: lapsed profile with perimenoEnabled yields no
condition insight when isPro == false; DailyLogForm test that a stored pregnancy
symptom remains visible/removable after lapse.

#### PRO-07 — Paywall + restore + lapse (Watch Pro feature)

On a free user's Apple Watch, Caelyn says 'Open Caelyn on your iPhone to sync' forever
and never mentions that the watch needs Pro — even though the paywall sells it. And
after a subscription lapses the watch keeps showing the last Pro data, counting days
forward from a frozen date, so it states a confidently wrong cycle day and phase for
weeks.

**Root cause.** Two mechanisms compound. (1) Entitlement is enforced by withholding the
WatchConnectivity transport — `if PurchaseService.shared.isPro {
WatchBridgeService.shared.pushSnapshot(snapshot) }` (WidgetDataSync.swift:139-141,
verified at HEAD) — instead of by the isPro flag the snapshot already carries and that
no watch code reads. Silence is therefore overloaded: the watch cannot distinguish
'not entitled' from 'nothing changed'. (2) The watch has no durable local copy and
never reads WCSession.default.receivedApplicationContext; WidgetDataStore.read() on
watchOS always returns nil because the App Group container is per-device and no
watchOS code ever writes it (WatchDataModel.swift:6, 14, 57). updateApplicationContext
(WatchBridgeService.swift:20-26) persists the last value on the system side, so after
a lapse the watch recomputes days from a stale anchorPeriodStart with nothing to
invalidate it.

**Fix.**

1. 1. Remove the isPro gate at WidgetDataSync.swift:139-141 so the snapshot is always
   pushed; the snapshot already carries isPro.
2. 2. Also push from CloudSyncCoordinator.refreshDerivedSnapshot
   (Account/CloudSyncCoordinator.swift:95-102), which today refreshes the widget but
   not the watch.
3. 3. In WatchDataModel.activate(), after WCSession.default.activate(), seed from
   WCSession.default.receivedApplicationContext (decode the 'snapshot' key) and
   persist every received snapshot into the watch's own UserDefaults, reading that as
   the startup value instead of WidgetDataStore.read() — which is dead code on watchOS
   and should be removed there.
4. 4. In WatchHomeView (:14-17, :53-71), branch on snapshot.isPro: when false, show a
   short 'Caelyn Pro unlocks the watch — upgrade on your iPhone' state instead of the
   misleading 'Open Caelyn on your iPhone to sync'.
5. 5. Add staleness handling: carry the snapshot's generation timestamp and, past a
   threshold (e.g. 7 days with no update), stop printing a computed 'Day N · phase'
   and show 'Not updated since <date>' instead of a number derived from a frozen
   anchor.

*Files:* `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `CaelynWatch/WatchDataModel.swift`, `CaelynWatch/WatchHomeView.swift`

*Tests:* WidgetSnapshotBuilder tests (CaelynTests.swift:1301, 1342) unaffected. Add a
WatchHomeView model test for isPro gating and a staleness test asserting no day/phase
is rendered past the threshold.

#### REM-01, REM-02 — NotificationService.scheduleNoteReminders + NoteReminder.fireDate + HomeView.dueNoteReminders / DailyLogForm.noteReminderControl

She writes herself a note — 'ask the doctor about the cramps' — and sets it to come
back 'when my period starts'. The lock-screen nudge arrives and says 'You left
yourself a note. Tap to see it.' She taps, and the note is nowhere: the Home card that
was supposed to reveal it has already vanished. Next cycle the same empty nudge
arrives again, and the cycle after that, and she can never mark it done. And if she
ever said No to notifications, the whole thing is dead on arrival — no nudge, no card,
no hint — while the form still promises 'Reminds you when your next period is
predicted to start'.

**Root cause.** scheduleNoteReminders is simultaneously the resolver and the deliverer of cycle-
relative note reminders, and the single field noteReminderAt is both the schedule and
the only record of due-ness. Two mechanisms follow. (a) NoteReminder.fireDate has one
nil return channel for three distinct meanings — 'no prediction yet'
(NoteReminder.swift:53,61 guards), 'the chosen date is past' (:50), and 'this cycle
rule's moment has already arrived' (via scheduledFireDate's `shifted > now ? shifted :
nil`, NotificationService.swift:396). scheduleNoteReminders cannot tell them apart, so
at NotificationService.swift:368-371 it writes 'already due' nil over the only due-
ness record; Home's filter (noteReminderAt <= now, HomeView.swift:111-120) then stops
matching, and the next day PredictionEngine.nextPeriodStart rolls a full cycle forward
(PredictionEngine.swift:186-193) so the field is re-armed into the future and the
'fires once' reminder repeats forever. (b) `guard await authorizationStatus() ==
.authorized else { return }` at NotificationService.swift:352 sits ABOVE the
resolution loop, and syncFromLiveStore:340 is its only caller, so for a denied user
noteReminderAt is never written at all. .date rules escape both because DailyLogForm
writes their date directly.

**Fix.**

1. 1. Split the function in two.
   `resolveNoteReminders(entries:context:nextPeriodStart:now:)` — pure of
   UNUserNotificationCenter, no authorization check, saves changed dates; and
   `scheduleNoteNotifications(entries:isPrivate:)` behind the existing `.authorized`
   guard. syncFromLiveStore (NotificationService.swift:340-345) calls resolve
   unconditionally and schedule only when authorized.
2. 2. Change NoteReminder.fireDate (NoteReminder.swift:41-67) to return a three-case
   enum instead of Date? — `.scheduled(Date)` / `.alreadyDue(Date)` / `.unresolvable`
   — so the caller can distinguish 'nothing to schedule' from 'the moment has passed'.
   Keep a thin `fireDate(...) -> Date?` shim returning the date for .scheduled only,
   so testNoteReminderFireDate and DailyLogForm's call sites compile unchanged.
3. 3. In resolveNoteReminders, never write nil or a future date over an already-due
   one: only assign entry.noteReminderAt when the current value is nil or still in the
   future. Concretely replace NotificationService.swift:368-371 with `if rule !=
   .date, case .scheduled(let fire) = resolution, (entry.noteReminderAt ??
   .distantFuture) > now, entry.noteReminderAt != fire { entry.noteReminderAt = fire;
   changed = true }`. On `.alreadyDue(let d)` write d once if noteReminderAt is nil.
   This freezes the reminder in the due state until noteReminderDone is set, which is
   the only thing that should clear it (HomeView.swift:457-461 markNoteReminderDone).
4. 4. Give scheduleNoteReminders/resolveNoteReminders an injectable `now: Date = .now`
   (it currently reaches `.now` implicitly at :364 and again at :372) so the whole
   guard is unit-testable against an in-memory ModelContext with no notification
   centre.
5. 5. In DailyLogForm, read the authorization status when the note-reminder control
   appears (DailyLogForm.swift:828-871). When denied, keep the rule selectable but
   change the footnote from 'Reminds you when…' to 'Notifications are off — this will
   appear on your Home screen instead', which is now true because step 1 makes the
   Home card work without authorization.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/NoteReminder.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Log/DailyLogForm.swift`

*Tests:* Keep testNoteReminderFireDate (via the Date? shim). Add, against an in-memory
ModelContainer: resolve() does not nil a past noteReminderAt on the fire day;
resolve() does not overwrite a past noteReminderAt once nextPeriodStart has rolled a
cycle; resolve() runs and writes a date while authorization is .denied; .beforePeriod
whose 2-days-before has passed resolves to the period day exactly once.

#### REM-03, REM-04 — CaelynApp scenePhase handler + OnboardingViewModel.complete + every store write path (DailyLogForm.withEntry, HomeView.logPeriodToday/logMood, LogView delete, WatchBridgeService.handleIncoming, ImportReconciler, HealthSyncService, CloudSyncCoordinator)

Two faces of one problem. A brand-new user turns on 'Daily check-in' during
onboarding, puts the phone down, and gets nothing that day — the reminders only start
working after she closes and reopens the app. And for everyone else, anything she logs
during a session is invisible to the reminder schedule until the next time she opens
the app: she logs her mood at 8am, and the evening 'How are you feeling today?' nudge
— which the code deliberately tries to suppress once she has checked in — arrives
anyway. Same for logging her period: the 'your period may start soon' reminder keeps
pointing at the old prediction.

**Root cause.** The notification schedule is a derived projection of the store whose only pull trigger
is the `.active` branch of the single scenePhase handler (CaelynApp.swift:72-85) — a
moment that by construction precedes the session's edits — and whose only other
refreshes are eight hand-placed pushes on Settings and note-reminder controls
(SettingsView:758, BirthControlView:144, RemindersView:154/304/316, HomeView:457,
DailyLogForm:866). syncFromLiveStore (NotificationService.swift:327-333) reads
profile/entries/todayEntry synchronously, so the suppression decisions at :175-179
(mood logged) and :195-198 (medication logged) and the CycleModel-derived
period/ovulation dates are all frozen at foreground time. No data write path pushes a
resync, so the convention 'every writer pushes' is unenforced — and
OnboardingViewModel.complete(in:) (OnboardingViewModel.swift:104-132) is the one
writer of all four remind* flags that runs AFTER the pull trigger already fired and
bailed on the empty-profile guard (NotificationService.swift:329).

**Fix.**

1. 1. Add `static func scheduleResync()` to NotificationService: a debounced (≈0.5s)
   Task that coalesces rapid calls into one `await syncFromLiveStore()`. Hold the
   pending Task in a static var and cancel/replace it.
2. 2. Call scheduleResync() from the seven write funnels rather than relying on future
   authors: DailyLogForm.withEntry (DailyLogForm.swift:998-1018),
   HomeView.logPeriodToday (739-775) and logMood, LogView's delete (88-96),
   WatchBridgeService.handleIncoming (56-69), ImportReconciler's commit,
   CloudSyncCoordinator.reconcileArrivedRecords (after dedupeSameDay, alongside
   refreshDerivedSnapshot — the existing 'store changed' hook), and at the COMPLETION
   of HealthSyncService.run (not at syncOnForeground entry, so an incremental import's
   writes are visible).
3. 3. In OnboardingFlow.swift:54-57, change the DoneStep closure to `vm.complete(in:
   modelContext); NotificationService.scheduleResync()`. Safe because
   syncFromLiveStore re-reads the live store (so it sees the just-inserted profile)
   and sync's own authorization guard (NotificationService.swift:168) makes it a no-op
   when she denied or enabled nothing.
4. 4. Add the `.background`/`.inactive` branch to CaelynApp.swift:72-85 (modelled on
   WidgetDataSync.swift:126-128) so a session that ends without another foreground
   still leaves a correct schedule.
5. 5. Guard against the HealthKit race: CaelynApp:74 and :79 currently run the
   notification sync and the Health import concurrently; sequence them, or let step
   2's completion-time resync be the authoritative one.

*Files:* `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Onboarding/OnboardingFlow.swift`, `Caelyn/Views/Onboarding/OnboardingViewModel.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Log/LogView.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/HealthSyncService.swift`

*Tests:* Unit-test the debounce (N rapid scheduleResync calls → one syncFromLiveStore). Pending
notifications are not observable from UI tests; add a `--dump-pending-notifications`
launch argument that writes getPendingNotificationRequests to a file for the
orchestrator's serial run, then assert in an onboarding UI test that the check-in
request exists before the app is ever backgrounded.

#### REM-06 — NotificationService.cancelAll as used by SecureWipeService, Paranoid Mode and the Private-notifications toggle

She uses 'Delete all data', or types the duress PIN, or turns on Paranoid Mode — and
the banners Caelyn already delivered ('Your period may start soon', 'Ovulation
window') are still sitting in Notification Center and on the lock screen for anyone
who swipes down. The one wipe that is supposed to leave no trace leaves health words
on the screen.

**Root cause.** Delivered notifications are a storage location Caelyn has never modelled. cancelAll
(NotificationService.swift:138-152) calls removePendingNotificationRequests only, its
own doc comment (:132-137) scopes it to 'every pending Caelyn notification', and
SecureWipeService's storage-location checklist (SecureWipeService.swift:3-14) lists
item 2 as 'Pending local notifications' — so the wipe's definition of complete never
included the delivered store. removeAllDeliveredNotifications /
removeDeliveredNotifications appear zero times in the repo: no call site forgot a
call, the call exists nowhere.

**Fix.**

1. 1. Add a distinct `static func clearDelivered() async {
   UNUserNotificationCenter.current().removeAllDeliveredNotifications() }` to
   NotificationService — do NOT put it inside cancelAll. cancelAll is on the hot path
   (called by sync at :166, which runs on every foreground, after every log save, and
   on every reminder edit), so folding it in would erase a 09:00 medication nudge from
   Notification Center at 09:02 the moment she opened the app for an unrelated reason.
2. 2. Call clearDelivered() from the four places where erasure is the intent:
   SecureWipeService (next to the cancelAll at :88-89), the duress-PIN path in
   AppLockGate.swift:103-110, enableParanoidMode (SettingsView.swift:544-553), and the
   Private-notifications toggle (SettingsView.swift:752-760) — where only the
   descriptive ones matter, but removing all is simpler and harmless since the privacy
   switch is a deliberate act.
3. 3. Add 'Delivered notifications (Notification Center)' as item 3 in
   SecureWipeService's storage-location checklist comment
   (SecureWipeService.swift:3-14) so the next person auditing the wipe sees the
   location enumerated.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Main/AppLockGate.swift`

*Tests:* Not unit-testable (UNUserNotificationCenter is a system singleton). Assert the call
exists via a source-grep test in the privacy test file (same technique as commit
9776951's audit test): SecureWipeService and enableParanoidMode must mention
clearDelivered. Cover the real behaviour in the orchestrator's serial runtime probe.

#### REM-07 — SettingsView.enableParanoidMode + NotificationService.scheduleNoteReminders

She turns on Paranoid Mode. The app tells her reminders are off now. The next time she
opens Caelyn, her note-to-self reminders quietly re-arm, and 'Caelyn reminder — You
left yourself a note. Tap to see it.' is back on her lock screen.

**Root cause.** Reminder enablement has a split source of truth. Five of the six notification
categories are gated by a flag on UserProfile that sync checks
(NotificationService.swift:174/194/218/240), but .noteReminder is the only category
whose enablement lives on the entity (CycleEntry.noteReminderRule,
CycleEntry.swift:57). enableParanoidMode is a profile-level operation
(SettingsView.swift:546-556) so it can flip five flags and has no reachable state for
the sixth; scheduleNoteReminders is invoked from syncFromLiveStore outside the flag-
checked region (:340-345) with no gate of its own. cancelAll therefore clears the
queue once and the very next foreground rebuilds it.

**Fix.**

1. 1. Add `var noteRemindersSuppressed: Bool = false` to UserProfile — NOT a default-
   true `noteRemindersEnabled`. A default-true flag would force `dst && src` in
   ProfileStore.merge, breaking the invariant that all 28 bools at
   ProfileStore.swift:52-79 are `||` under the comment 'Something she had to turn on
   stays on'; a later reader would 'fix' it back to `||` and silently reopen this bug.
2. 2. Merge it the same way as its neighbours: `dst.noteRemindersSuppressed =
   dst.noteRemindersSuppressed || src.noteRemindersSuppressed` in ProfileStore.merge's
   first block (around ProfileStore.swift:60).
3. 3. Set it true in enableParanoidMode alongside the other five flags
   (SettingsView.swift:546-553).
4. 4. Gate the scheduler: in syncFromLiveStore (NotificationService.swift:340-345),
   skip the scheduleNoteNotifications half when profile.noteRemindersSuppressed. Keep
   the resolve half running (see REM-01) so the Home due-cards still work — the
   suppression is about the lock screen, not about losing her notes.
5. 5. Add a 'Note reminders' row to RemindersView (near the existing rows at :42-110)
   bound to the inverse of the flag, so she can turn them back on without hunting.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Settings/RemindersView.swift`

*Tests:* ProfileStoreTests gains the new field in its merge coverage. UI test
testPrivacyControlsAndDeleteAllDataJourney asserts the new toggle reads off after
Paranoid Mode. New unit test: with noteRemindersSuppressed true, resolve still writes
noteReminderAt but no request is scheduled.

#### REM-09 — NotificationService.scheduledFireDate / shiftOutOfQuietHours as applied to .medication and .birthControl

She takes her pill at 22:30 every night and asks Caelyn to remind her at 22:30. Caelyn
cannot do it: quiet hours silently move the reminder to 07:00 the next morning — nine
hours after the dose that is supposed to be taken at the same time daily. Birth-
control users get no footnote warning them at all.

**Root cause.** Quiet hours are a property of the scheduler rather than of the category.
scheduledFireDate (NotificationService.swift:392-397) applies shiftOutOfQuietHours to
every caller with no way to decline, so there is no respectsQuietHours dimension and a
dose time the user set explicitly is overridden by a policy written for passive
nudges. (The 'suppress today's skips tomorrow morning's' effect is a consequence of
the shifted date landing on the next civil day, not of an identifier collision —
offsets 0…6 at 22:30 produce seven distinct dateSuffix values,
NotificationService.swift:422/427-431.)

**Fix.**

1. 1. Add `respectsQuietHours: Bool = true` to scheduledFireDate
   (NotificationService.swift:392) and apply shiftOutOfQuietHours only when true.
2. 2. Pass false from the medication loop (NotificationService.swift:199-203) and all
   three birth-control branches (:262-266, :289, :312). Leave check-in, period,
   ovulation and the cycle-relative note rules on the default.
3. 3. Re-check the day-skip arithmetic in the medication/birth-control loops once the
   shift is gone: with the fire date now on the intended day, the 'suppress today's if
   already logged' comparison at :195-198 compares like with like.
4. 4. Fix the stale doc: NoteReminder.swift:7 says note reminders respect quiet hours,
   but the .date rule returns chosenDate unshifted (:50-52). The behaviour is right
   (her explicit time wins) — correct the comment, and add the same 'your chosen time
   is used exactly' footnote to BirthControlView (BirthControlView.swift:58-88), which
   has none today.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/NoteReminder.swift`, `Caelyn/Views/Settings/RemindersView.swift`, `Caelyn/Views/Settings/BirthControlView.swift`

*Tests:* No scheduledFireDate/shiftOutOfQuietHours tests exist today. Add: respectsQuietHours
true shifts 22:30 → 07:00 next day and 06:00 → 07:00 same day; respectsQuietHours
false returns 22:30 on the given day; a past unshifted time still returns nil.

#### REM-10 — NotificationService.sync period/ovulation branches vs Pregnancy / Postpartum modes

She is pregnant and has switched Caelyn to Pregnancy Mode. Every cycle, for nine
months, her lock screen still says 'Your period may start soon' and 'Ovulation
window'.

**Root cause.** Two mechanisms compound. (a) NotificationService.sync has no life-stage predicate —
remindPeriodStart and remindOvulation are the only gates (:214, :239) — and the
CycleModel it is handed is itself mode-blind (CyclePrediction.swift:209-248 never
reads the profile's mode flags). (b) The reason it recurs instead of going quiet is
PredictionEngine.nextPeriodStart's forward-rolling `while nextStart < t` loop
(PredictionEngine.swift:186-193): it advances a stale pre-conception anchor past today
without bound, so there is always a future 'next period' to announce.

**Fix.**

1. 1. Add a computed property to UserProfile: `var cycleRemindersSuppressed: Bool {
   pregnancyEnabled || postpartumEnabled }` (UserProfile.swift:58-63 holds the flags).
   Computed, so no stored property and no schema change — 1.3(15) stores migrate
   untouched, and the predicate is unit-testable where `sync` is not.
2. 2. Wrap the whole `if let nextPeriod = cycle.nextPeriodStart { … }` block
   (NotificationService.swift:213-253) in `if !profile.cycleRemindersSuppressed`.
   Leave dailyCheckIn, medication, birthControl and note reminders untouched — a
   postpartum user still wants her medication reminder.
3. 3. Make Home agree: HomeHeroCard still renders the period prediction in these modes
   (HomeView.swift:231-237 only adds a card). Apply the same predicate to the hero's
   prediction line so the scheduler and the screen say the same thing.
4. 4. Add a resync when the mode toggles are flipped in Settings (they are profile
   writes; this lands free once REM-03's scheduleResync exists), otherwise the
   already-queued period reminders survive until the next foreground.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* New unit test over the pure predicate: pregnancyEnabled or postpartumEnabled →
suppressed; neither → not. Plus a sync-level test once sync takes an injectable
scheduler, asserting no .periodUpcoming/.ovulation request is built for a pregnant
profile.

#### SYNC-03, SYNC2-05 — Cloud deletion

Once she has deleted her iCloud copy she can never reliably turn sync back on. Any
other device of hers that opens later 'honours' the old deletion, stamps a brand-new
deletion time on top of the change of mind she just made, destroys the fresh copy and
silently switches its own sync off — with no notice. And even on one phone, every
launch for the rest of the app's life re-runs the whole deletion: six network round
trips, two tombstone writes, and a deletion timestamp that creeps forward each time so
it permanently outruns every other device.

**Root cause.** deleteCloudCopy() is one unparameterised function discharging two different jobs:
AUTHORING a deletion (stamping deletedAtKey and publishing a tombstone with a fresh
`Date()` — CloudDataDeletion.swift:123-130 and :136-140) and ENFORCING one (removing
the zone, :121). Both callers that need only enforcement — resolveOutstandingDeletion
(:158-168) and honourRemoteDeletionIfNeeded (:192-203) — therefore re-author as a side
effect, with a monotonically advancing timestamp, so the published deletion time
always outruns every device's recorded consent and the fixed point the design assumes
does not exist. CaelynApp.swift:60 then :63 runs the two guards back to back, so a
device fetches and 'honours' the tombstone it wrote seconds earlier (verdict returns
.honourDeletion for both nil and older consent, CloudDeletionTombstone.swift:67-74).
Consent is recorded only by the device whose toggle was flipped
(AccountView.swift:265), so no device has shared authority to stand down.

**Fix.**

1. 1. Split the function by role: `enforceCloudDeletion()` (zone removal only, no
   marker, no tombstone) and `authorCloudDeletion()` (= enforce + stamp deletedAtKey +
   publish tombstone). Point CloudDataDeletion.swift:167 and :201 at the enforce-only
   version; only AccountView's delete button authors.
2. 2. Make the stamp stable even where it is written: hoist `let deletedAt =
   (defaults.object(forKey: deletedAtKey) as? Date) ?? Date()` above the `do` and use
   it on BOTH exits (:123 and :136). It must be unconditional, not zoneNotFound-only —
   the async modifyRecordZones reports per-zone failure in deleteResults rather than
   throwing, so the success path is the likelier one for an already-deleted zone.
3. 3. Teach resolveOutstandingDeletion to consult the tombstone before acting:
   `.absent` -> clear deletedAtKey and pendingKey and stand down (this self-heals
   every device that only ever followed); `.present(t)` where t == the locally stored
   deletedAtKey -> this device authored the deletion in force, do nothing at all;
   `.present(t)` newer than local consent -> enforce only; `.unreachable` -> keep re-
   asserting as today.
4. 4. Give a device the ability to recognise its own tombstone: have
   verdict(tombstone:localConsent:) return .noAction when the tombstone equals the
   value this device authored, so the launch pass can never honour itself.
5. 5. Reword the stand-down copy at AccountView.swift:291-296. A follower device must
   not say 'You deleted your iCloud copy' — she did not do it there — and must say
   what happened to sync on this device.
6. 6. Permanent because it removes the advancing quantity and the role conflation
   rather than one of the two places the timestamp advances; after it, the deletion
   state has a fixed point that both devices converge on.

*Files:* `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Services/Account/CloudDeletionTombstone.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* DeletionModelTests.testADeletedCloudCopyIsNotAllowedToComeBackOnItsOwn must inject
tombstone state (.unreachable keeps re-asserting, .absent stands down).
DeletionModelTests:189-230 cover resolveOutstandingDeletion in isolation and still
pass — the gap is that nothing covers the two guards running in SEQUENCE, so add that.
New CrossDeviceDeletionTests case: a follower never writes a tombstone newer than the
one it read. Extracting the CloudKit calls behind a TombstoneStore protocol is
required to make any of this testable.

#### SYNC-04 — Cloud deletion

She taps 'Delete my iCloud copy' and reads 'permanently deleted'. For the rest of that
session — and iOS can keep an app alive for days — the still-running iCloud connection
can rebuild the zone and upload her entire history again. The guarantee she was given
only becomes true at a cold start nobody told her she needed, and unlike turning sync
on or off, this screen never mentions reopening the app.

**Root cause.** Deletion finality requires the mirror to be detached, but Persistence.live is a
`static let` built once at launch with no in-process teardown
(Persistence.swift:96-121), so flipping syncEnabledKey (CloudDataDeletion.swift:116)
changes only what the NEXT launch builds. The code knows this — its own comments admit
'a live mirroring delegate can recreate a zone it is still attached to' (:33-38) and
compensate with the launch-time guard (:151-156, CaelynApp.swift:57-63) — while the UI
asserts present-tense finality. The honesty bug is structural rather than a copy slip:
Outcome.message is a parameterless computed property (:206-219) with no access to
Persistence.isSyncActive, so there is no seam at which the truth could be injected.

**Fix.**

1. 1. Change Outcome.message to a function `message(mirrorStillAttached: Bool)`
   (CloudDataDeletion.swift:206-219) and call it with Persistence.isSyncActive. The
   .deleted case then reads: 'Your iCloud copy has been deleted. Reopen Caelyn to
   finish disconnecting this iPhone from iCloud — until then nothing new is kept there
   for long, and Caelyn re-checks every time you open it.'
2. 2. Do NOT reuse needsRelaunchNotice for this: it renders inside syncCard with text
   hard-coded to 'Reopen Caelyn to finish switching this on.'
   (AccountView.swift:231-238) — the wrong sentence in the wrong card.
3. 3. Fix the second, longer-lived falsehood on the same screen: the stand-down line
   at AccountView.swift:291-296 and the confirmation message at :364-369, which both
   describe a settled state while the mirror is still attached.
4. 4. The permanent fix is a rebuildable container: make Persistence.live a
   `private(set) static var` with a `rebuild(mirrored:)` that closes and reopens the
   SAME store file un-mirrored, and call it after a successful deletion. That
   configuration is exactly what the next launch already opens, so nothing new is
   being risked — the risk is in the SwiftData teardown, which needs a device test
   opening mirrored then local on one file.
5. 5. If step 4 is deferred, step 1 must ship: the message is the only thing standing
   between her and a false guarantee.

*Files:* `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* DeletionModelTests.testNoDeletionMessageLeaksAFrameworkError — messages become
parameterised, extend it. New: 'deleted-while-mirrored message says reopen'. A
rebuildable container needs a new Persistence test opening mirrored then local on the
same file URL.

#### SYNC-05, SYNC-07, SYNC-08, SYNC-09, SYNC-13, SYNC-14, SYNC-01 — 38 Backup status / 26 Private iCloud sync

Caelyn tells her where her health data is, and on every screen it guesses. The Backup
screen says her history is in her iCloud when all that happened is that the app opened
— it has never checked whether an upload succeeded, whether she is still signed in to
iCloud, or whether her storage is full — and three lines further down the same screen
says her data 'never leaves this device'. If she turns sync off mid-session the screen
says everything now stays on the phone while entries keep uploading until she reopens
the app, under a notice telling her she is switching sync ON. If the mirrored store
failed to open she is told to 'wait' forever, with no way out. If a deletion fails the
toggle still shows on while the stored setting has already gone off. And a device that
opened the mirrored store without ever reaching iCloud is told a copy exists that it
can delete.

**Root cause.** Three different questions are all answered from two launch-time booleans, and each
screen picks whichever it likes. (a) Persistence.isSyncActive is a one-way latch set
exactly once inside the container closure (Persistence.swift:115) and recording only
'the mirrored store is the one that opened'; a mirrored container opens with no iCloud
account, no connectivity and nothing uploaded. (b) The one signal that reports export
success, quota, account and schema failures —
NSPersistentCloudKitContainer.eventChangedNotification — is observed nowhere in the
repo (grep returns zero matches; the only mentions are prose comments). (c) Failure of
the open is not persisted at all: Persistence.swift:123 only logs, so 'she asked and
has not relaunched' and 'this launch tried and failed' are the same two bits, which is
why statusLine infers 'Waiting to start.' for both (AccountView.swift:249-255). (d)
AccountView caches the preference in @State syncOn (:22) and nothing re-reads it, so a
.failed deletion that already wrote syncEnabledKey=false leaves the toggle on
(:371-380 branches on outcome.didDelete, a statement about the zone, as a proxy for
'the preference changed'). (e) BackupInfoView branches on isSyncActive at
iCloudSyncView.swift:45, :48, :71, :74 for a question whose correct predicate already
exists and is documented as the single owner — CloudDataDeletion.cloudCopyMayExistNow
(:62-79) — while its FAQ and note (:143-162, :184-202) and file header (:3-18) are
unconditional text from before sync existed. (f) CloudAccount.availability() is polled
on one screen's .task (AccountView.swift:56) and never fed into any backup claim, so
account state and reported sync state drift apart for a whole launch. (g) mayExistKey
is set on container open (Persistence.swift:115-119) although its own contract
(CloudDataDeletion.swift:50-54) says it must only be set when something could have
uploaded.

**Fix.**

1. 1. Observe the real event. In CloudSyncCoordinator — already built only for the
   live store (CaelynApp.swift:24-27), already owning a NotificationCenter observer
   (CloudSyncCoordinator.swift:38-50), already started at launch — add an observer for
   NSPersistentCloudKitContainer.eventChangedNotification. On an event with type ==
   .export, endDate != nil and succeeded == true, record `caelyn.cloudLastExportAt`.
   On failure, record `caelyn.cloudLastErrorKind` storing ONLY the classified case
   name, never a CKError description (CloudSyncCoordinator.swift:~105-112 already
   forbids raw codes reaching the screen).
2. 2. Move noteCloudCopyMayExist() out of Persistence.live entirely and set it from
   that first successful export instead — the flag then means what its doc says. Leave
   `isSyncActive = true` at Persistence.swift:115 as is; it honestly records which
   store opened.
3. 3. Persist the failure. In the fall-through branch at Persistence.swift:123, write
   `caelyn.syncOpenFailedAt`; clear it in the success branch next to :115. Expose
   `Persistence.syncOpenFailed` beside isSyncActive with the same 'read this, not the
   preference' doc rule. Now three states are three states.
4. 4. Build ONE pure function — `SyncReport.make(preference:active:openFailed:lastExpo
   rtAt:lastErrorKind:availability:cloudCopyMayExist:)` — returning a small value with
   the status sentence, whether a relaunch is pending and in which DIRECTION, and
   whether a backup claim is justified. Purity is not the point; the point is that it
   cannot be called without passing every input, which makes today's early-return
   impossible to write.
5. 5. Replace the Bool needsRelaunchNotice with `enum RelaunchDirection { case
   turningOn, turningOff, none }` and give the off-direction its own sentence; the
   current hard-coded 'Reopen Caelyn to finish switching this on.'
   (AccountView.swift:231-238) is shown in both directions today. The missing status
   cell (preference false, active true) must read something like 'Turning off finishes
   when you reopen Caelyn. Until then, changes still go to your private iCloud.'
6. 6. Render from the report in all three places: AccountView.statusLine (:249-255)
   and the relaunch notice; SettingsView's Backup row (:480); BackupInfoView headline,
   status card, promises, FAQ and note (iCloudSyncView.swift:45-50, 71-76, 143-162,
   184-202). Use cloudCopyMayExistNow — not isSyncActive — for 'could anything of hers
   be in iCloud', so the screen has one owner for that question rather than a fourth
   opinion. Stop interpolating availability.message into the failure sentence.
7. 7. Delete the @State copy of the preference: make syncOn a computed
   `Persistence.isSyncEnabled` with the toggle binding's setter calling setSync, so no
   second copy exists to drift after a .failed deletion. At minimum, re-read the
   preference after the delete Task regardless of outcome instead of branching on
   didDelete (AccountView.swift:376).
8. 8. Rewrite the stale absolutes on BackupInfoView: the FAQ 'No. It never leaves this
   device' (:155-158), the note 'the only copy of your history that exists outside
   this device' (:195), the move-to-new-iPhone answer that prescribes CSV only
   (:145-148), and the file header (:3-18) claiming the app ships with no CloudKit
   entitlement and no toggle — all untrue since 1.3 (Caelyn.entitlements:15-22).
9. 9. Feed CloudAccount.availability() into the report and observe account changes
   (CKAccountChanged / the coordinator's availability poll at
   CloudSyncCoordinator.swift:140-160) rather than reading it once, so a signed-out
   device says 'sync is paused — everything is still on this iPhone' instead of
   'backed up to your private iCloud'. Do NOT build the LocalSafetyCopy/restore
   machinery from SYNC-01's original text: it is a second authority over her history
   on an unproven premise and cuts against the store being the only source of truth.
10. 10. Keep the two predicates pointed in opposite safe directions on purpose: the
   pessimistic cloudCopyMayExistNow answers 'is there a copy to delete' (so
   DeletionModelTests.swift:447-457 keeps passing unchanged), and the strict
   lastExportAt answers 'are you backed up'.

*Files:* `Caelyn/Services/Persistence.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Views/Settings/iCloudSyncView.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* New table tests for SyncReport.make covering all preference x active x openFailed x
availability combinations, including the (false, true) cell nothing covers today. New
AccountSyncCopy tests — AccountTests has no coverage of statusLine or
needsRelaunchNotice at all. Extend the PrivacyCopyTruthfulnessTests pattern (which
already guards PrivacyTrustView) to BackupInfoView's headline, status card, FAQ and
note. DeletionModelTests.testTheMarkerTracksTheStoreOpeningNotThePreference becomes
'the marker tracks the first successful upload'.

#### SYNC-10, SYNC2-09 — Cloud deletion

Two problems with the same switch. A deletion she makes on her phone is only noticed
by her iPad the next time that iPad is cold-started — which on iOS can be days — and
even then only after two network calls that can hang when she is offline. Meanwhile
every single launch of every install, including the large majority who have never
touched sync and are told on the Backup screen that nothing is uploaded anywhere,
makes a request to Apple on her behalf; and a brand-new phone restored into the same
Apple Account opens to a card about a deletion she never performed there, offering to
delete a copy that does not exist.

**Root cause.** The deletion-honouring path is a pull with exactly one trigger and no precondition.
Both guards exist only as statements inside the WindowGroup's un-keyed `.task`
(CaelynApp.swift:60 and :63), which on iOS runs once per process, placed after `await
loadProducts()` and `await reconcileAppleCredential()`; the scenePhase .active hook
(:72-85) re-runs the credential check and Health sync but not the guards, and nothing
else re-asks — there is no CKSubscription, and CloudSyncCoordinator's remote-change
observer never consults the tombstone. In the other direction,
honourRemoteDeletionIfNeeded's first act is an unconditional CloudKit record fetch
with no guard on isSyncEnabled, isSyncActive, cloudCopyMayExist or anything else —
even though only a device that opens the mirrored store can recreate the zone the
honour path exists to prevent (Persistence.swift:103-119), so on a sync-off device the
whole check is inert by construction.

**Fix.**

1. 1. Extract both guards into one `@MainActor func runDeletionGuards() async`.
2. 2. Call it as the FIRST statement of the live branch of CaelynApp's .task, ahead of
   loadProducts() and reconcileAppleCredential(), alongside syncCoordinator?.start().
3. 3. Also call it from the scenePhase == .active hook (CaelynApp.swift:72-85), rate-
   limited to once per foreground via a stored timestamp, so a device left running for
   days still honours a deletion made elsewhere.
4. 4. Inside it: always `await CloudDataDeletion.resolveOutstandingDeletion()`
   (already a no-op unless deletionIsPending || cloudCopyWasDeleted,
   CloudDataDeletion.swift:159), but call honourRemoteDeletionIfNeeded() only when
   CloudDataDeletion.cloudCopyMayExistNow is true.
5. 5. Put the same guard as an early return inside honourRemoteDeletionIfNeeded itself
   (CloudDataDeletion.swift:192), so no future caller can reintroduce the
   unconditional fetch. cloudCopyMayExistNow is the right expression: it already ORs
   isSyncEnabled, isSyncActive, cloudCopyMayExist and deletionIsPending, and already
   excludes the demo store, so every case the mechanism was built for still runs —
   only a device with no preference, no mirrored open and no marker skips it, and that
   device cannot recreate a zone.
6. 6. Extract the .task body into a testable `LaunchSequence` so the ordering can be
   asserted rather than reviewed.

*Files:* `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* DeletionModelTests.swift:186-205 pins that signing in does not switch sync on and that
resolveOutstandingDeletion re-asserts — those stay. New: the early return (nothing
covers it today); new: a second foreground within the rate-limit window does not re-
run the guards. An App-level sequencing test only once the task body is extracted.

#### SYNC-11 — 26 Private iCloud sync

Data arriving from her other device during the first seconds after launch is not
tidied up — a duplicate day can sit visible until the next sync event, a second copy
of her profile can persist for the whole session, and while that is true the widget
and Watch may be built from the wrong one of the two profiles.

**Root cause.** Three independent mechanisms in one path. (1) The remote-change observer is registered
as the third statement of a sequential branch whose first statement is an unbounded
network await (CaelynApp.swift:53-55), and start() only registers — it never sweeps
what already arrived, so the interval from store load to registration has no listener
and no cold-start backstop regardless of ordering. (2) reconcileArrivedRecords runs
CycleStore.dedupeSameDay but not ProfileStore.dedupe
(CloudSyncCoordinator.swift:73-83) — it was written against the one model that had a
dedupe pass when it was authored. (3) refreshDerivedSnapshot takes
`FetchDescriptor<UserProfile>()` unsorted and calls .first (:91) — the exact coin-flip
that c2b96fa removed elsewhere — and CaelynApp.swift:97 and
NotificationService.swift:329 do the same.

**Fix.**

1. 1. Move `syncCoordinator?.start()` to the first statement of the non-screenshot
   branch of CaelynApp's .task, before `await PurchaseService.shared.loadProducts()`
   (CaelynApp.swift:53).
2. 2. Have start() schedule one reconcile immediately after registering the observer,
   reusing the existing remoteChangeArrived() coalescing path so the 400 ms settle
   window still applies (CloudSyncCoordinator.swift:38-50, :60-68). This is the load-
   bearing part: ordering alone leaves the store-load-to-first-.task interval unswept,
   and a self-trigger closes it permanently because it stops depending on when
   registration happens relative to the import.
3. 3. Add ProfileStore.dedupe to reconcileArrivedRecords
   (CloudSyncCoordinator.swift:73-83) alongside CycleStore.dedupeSameDay, and include
   its count in the merged total.
4. 4. Introduce one `ProfileStore.current(in:)` that fetches sorted by createdAt and
   route every profile read through it: CloudSyncCoordinator.swift:91,
   CaelynApp.swift:97, NotificationService.swift:329. Remove the unsorted
   `FetchDescriptor<UserProfile>().first` pattern from the codebase so no new caller
   can reintroduce the coin flip.

*Files:* `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Services/NotificationService.swift`

*Tests:* ProfileStoreTests: add a test for ProfileStore.current ordering (two profiles, assert
the oldest createdAt wins deterministically). New CloudSyncCoordinator test: start()
performs one reconcile without waiting for a notification.

#### SYNC2-04 — 26 Private iCloud sync

She connects Apple Health on her iPhone. Her iPad — which has never shown her a Health
permission sheet and has no permission at all — now says 'Apple Health: Connected',
runs a Health sync every time she opens it, and tries to write her period days into
Health. The same thing happens with the app lock and hide-preview switches: device
settings that the architecture document explicitly lists as 'must NOT sync' travel to
every device anyway.

**Root cause.** There is no exclusion mechanism of any kind. docs/ICLOUD_ARCHITECTURE.md:71-80 defines
class B — local/device-specific, must not sync — and names healthKitConnected, the
hkRead*/hkWrite* toggles, lockEnabled and hidePreview, but all of them are plain
stored properties on UserProfile (UserProfile.swift:10-23), UserProfile is in
Persistence.schema (Persistence.swift:21) and SwiftData mirroring is all-or-nothing
per model. Grepping for @Transient and @Attribute returns nothing. The deeper
mechanism is that healthKitConnected is being used as two incompatible things at once
on ONE mirrored row — her INTENT ('I want Caelyn and Apple Health connected') and a
DEVICE FACT ('this hardware has HealthKit authorization') — so no sync rule can be
right for both. ProfileStore.merge's `dst.healthKitConnected = dst.healthKitConnected
|| src.healthKitConnected` (ProfileStore.swift:52-59) only makes the duplicate-row
path sticky as well.

**Fix.**

1. 1. Separate intent from device fact. Keep the mirrored UserProfile field as INTENT
   ('she wants Health connected'), and add a device-local record of authorization in
   UserDefaults (never mirrored), written only by the device that actually completed
   the permission flow.
2. 2. The gate at HealthSyncService.swift:316-320 and the Settings row at
   SettingsView.swift:440 must read `intent AND this device is authorized`, not the
   mirrored boolean alone.
3. 3. HKHealthStore.authorizationStatus(for:) alone is NOT a sufficient authority and
   must not be the whole fix: HealthKit never discloses READ authorization — the code
   says so twice (HealthKitService.swift:103-108 and the comment at
   HealthKitConnectView.swift:331-335) and authorizationStatus answers only for SHARE
   types (canWrite, HealthKitService.swift:163-166). Use it for the WRITE side; for
   the READ side use the device-local 'this device completed the permission sheet'
   flag plus the existing read probe.
4. 4. Make the write side fail closed: a device with no share authorization must not
   attempt a Health write even when hkWriteFlow arrived from another device.
5. 5. Do the same separation for lockEnabled and hidePreview — a lock configured on
   one device must not silently lock, or silently unlock, another.
6. 6. First landing changes no schema: the properties stay and are simply no longer
   trusted as device truth. Note for later — CloudKit Production will not allow the
   fields to be removed, so a future release can only stop reading them, not delete
   them.
7. 7. Update docs/ICLOUD_ARCHITECTURE.md:71-80 so the class-B list describes an
   implemented rule rather than an intention.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Services/Health/HealthKitService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `docs/ICLOUD_ARCHITECTURE.md`

*Tests:* HealthSyncTests exercises syncOnForeground's gate via profile.healthKitConnected and
needs a stub for the new local-authorization check. ProfileStoreTests assertions on
OR-merged HealthKit booleans change meaning — the OR stays correct for intent, but the
tests must stop treating it as 'connected'. New: an unauthorized device with intent
true performs no Health read and attempts no Health write.

#### SYNC2-06 — 26 Private iCloud sync

She deletes her iCloud copy. Later she taps the sync switch on — to read what it says,
or by accident — and taps it straight back off. Those two taps she immediately
reversed have quietly thrown away the only record telling her other devices to stay
away, and the next time her iPad opens it uploads her whole history back into iCloud.

**Root cause.** recordSyncConsentAndLiftTombstone() fires on the PREFERENCE WRITE
(AccountView.swift:265 -> CloudDataDeletion.swift:180-184), clearing deletedAtKey and
pendingKey locally and firing `Task { await CloudDeletionTombstone.clear() }` — but
the only moment a new cloud copy can actually exist is the mirrored open on the NEXT
launch (Persistence.swift:113-121). The irreversibility is structural: the tombstone
is a single-valued, delete-to-revoke record used as the sole carrier of a cross-device
decision (its only mutators are the write at CloudDataDeletion.swift:130/140 and the
clear at CloudDeletionTombstone.swift:114-122), so 'she changed her mind' is only
expressible by destroying the other devices' only input, and setSync(false) writes no
inverse because the local flags that could re-derive it were cleared in the same call.

**Fix.**

1. 1. Preferred permanent form: never delete the shared record. Make it monotonic —
   retain `deletedAt` and add `reinstatedAt`, and have verdict honour a deletion only
   when deletedAt > reinstatedAt. Turning sync on then WRITES a value instead of
   destroying one, and turning it straight back off is expressible rather than
   unrecoverable.
2. 2. If delete-to-revoke is kept for this release: defer the clear to the moment a
   copy can exist. Call it from the mirrored-open site (Persistence.swift:113-117) via
   `Task { @MainActor in await CloudDeletionTombstone.clear() }` — that closure is
   non-isolated and CloudDeletionTombstone is @MainActor.
3. 3. Give setSync(false) an inverse: keep a local shadow of the last authored
   deletedAt in a new UserDefaults key and restore deletedAtKey from it when she turns
   sync off again before any mirrored open. Leave mayExistKey absent so
   showCloudCopyCard (AccountView.swift:357-362) comes back with the 'You deleted your
   iCloud copy' line and the delete button, rather than the card vanishing entirely.
4. 4. Land after the role-split item so the restored marker is not immediately re-
   authored with a fresh timestamp by the launch guards.

*Files:* `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Services/Account/CloudDeletionTombstone.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* DeletionModelTests.swift:540-557 asserts recordSyncConsentAndLiftTombstone sets a
consent date and clears the marker — it stays true. New: lifting without a mirrored
open leaves the tombstone in place; toggling on then off restores the local marker and
the card.

#### SYNC2-08 — Cloud deletion

Caelyn tells her the iCloud copy is permanently deleted before it knows whether the
one message that tells her other devices about it was ever delivered. If that message
fails — she goes offline between the two steps, CloudKit throttles, or the record type
is missing in production — her iPad recreates the zone and uploads her entire history
again, and nothing anywhere describes the deletion as unfinished, because the marker
that would have retried it was already cleared.

**Root cause.** A type-level loss of the result. CloudDeletionTombstone.write is declared `async ->
Void` (CloudDeletionTombstone.swift:91) and catches every error into log.error
(:97-99), so whether the cross-device half of the deletion succeeded is information
that exists inside write and is destroyed at the return boundary. The caller cannot
branch on it even if it wanted to. Compounding it, deleteCloudCopy removes pendingKey
(CloudDataDeletion.swift:125 and :138) BEFORE calling write (:130 and :140), so the
one durability mechanism that would have retried the tombstone no longer covers it,
and both exits return outcomes whose didDelete is true and whose message claims
permanence (:206-227).

**Fix.**

1. 1. Change CloudDeletionTombstone.write to `-> Bool`, returning true only after
   modifyRecords succeeds (CloudDeletionTombstone.swift:91-100). This is the permanent
   half: any future failure mode of that write becomes reportable by construction
   instead of being destroyed at the return.
2. 2. Reorder both exits so `defaults.removeObject(forKey: pendingKey)` happens AFTER
   the write and only when it returned true (so :125 moves below :130, and :138 below
   :140).
3. 3. Add `case deletedLocallyButNotPublished` to Outcome with honest copy: the copy
   in iCloud is gone from this device's point of view, but her other devices have not
   been told yet and Caelyn will finish next time it can reach iCloud. didDelete stays
   true (the zone really is gone) but the message must not claim the cross-device half
   is done.
4. 4. Update the exhaustive switches that a new case breaks: Outcome.message and
   Outcome.didDelete (CloudDataDeletion.swift:206-227) and the result rendering at
   SettingsView.swift:816.
5. 5. Confirm the CaelynCloudDeletion record type exists in the CloudKit PRODUCTION
   schema — it is hand-written, not SwiftData-generated, and
   docs/ICLOUD_ARCHITECTURE.md:114 lists only the CycleEntry and UserProfile mirrors.
   If it is missing in Production, every tombstone write fails silently today.

*Files:* `Caelyn/Services/Account/CloudDeletionTombstone.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `docs/ICLOUD_ARCHITECTURE.md`

*Tests:* DeletionModelTests.swift:106-120 asserts the outcome and that sync ends up off; a
third outcome case forces the exhaustive switches to be updated. New: a failing
tombstone write leaves pendingKey set and returns the unpublished outcome; a
succeeding one clears it.

#### T1-01 — 3 Cycle prediction / 5 Home / 6 Calendar

When her period is late — which is routine — Home tells her she is bleeding. Two days
late reads as 'Day 3 of your period', in the period colour, with the ring and the
header and the widget and the Watch all agreeing, directly underneath a card saying
'Your period might be 2 days late'. Once she is late by more than her period length
the headline flips again to a fresh new cycle, and the calendar starts painting a
fertile window for a cycle that has not begun.

**Root cause.** Cycle day is computed as `(daysSince % cycleLength) + 1`
(PredictionEngine.swift:170-177), so the day silently wraps past the end of the
expected cycle instead of continuing to count, and phase is then classified from the
wrapped number with `day <= periodLength -> menstrual`
(PredictionEngine.swift:180-194, CyclePrediction.swift:266-277). Nothing in the
classification consults whether a period is late or whether flow is actually logged.
There is a SECOND, independent wrap site no CycleModel change can reach:
WidgetSnapshot.recomputed(for:calendar:) re-derives the day on the widget and Watch
across midnight without the app running — `let newCycleDay = (daysSince % safeLen) +
1` (WidgetDataStore.swift:92) — then reclassifies with WidgetCycleMath.phaseRaw (:103,
134-147) and regenerates accent, tint, fertility and upcoming strings (:108-123), with
no access to entries and therefore no way to evaluate the active period window.

**Fix.**

1. 1. Add `wrap: Bool = true` to PredictionEngine.currentCycleDay
   (PredictionEngine.swift:169-177) rather than removing the wrap:
   CaelynTests.swift:128-133 testCurrentCycleDayWraps asserts the result stays within
   1...28 for a 45-day-old anchor and would otherwise fail. Have CycleModel.cycleDay
   pass `wrap: !isPeriodLate`. (testCycleDayIsTheSameNumberOnEverySurface,
   CaelynTests.swift:1333-1345, is unaffected: its fixture is day 30 of a learned
   33-day cycle, where isPeriodLate is false.)
2. 2. When the period is late, phase must not be .menstrual unless flow is actually
   logged in the active period window — classify from the real window, not from the
   arithmetic day.
3. 3. Watch the ordering trap in phaseHeadline: the late branch must be evaluated
   before the phase branch, or the 'Fresh-energy phase' headline wins again for a
   long-late cycle.
4. 4. Suppress the predicted fertile and PMS windows while late (fertileWindow nil),
   so the calendar stops painting a cycle that has not started.
5. 5. Carry the late state into the widget snapshot — store isPeriodLate and daysLate
   — and make WidgetSnapshot.recomputed refuse to re-derive the day or reclassify the
   phase when the stored snapshot says she is late; it should carry the app's answer
   forward instead. Without this the widget and Watch keep contradicting Home even
   after the app is fixed.
6. 6. Keep the late card's own copy unchanged; the point is that the rest of the
   screen stops disagreeing with it.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Components/CycleRingView.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* CaelynTests.testCurrentCycleDayWraps (CaelynTests.swift:128) still holds against the
raw engine function if wrap defaults to true. Add CycleModel late-fixture tests:
cycleDay unwrapped, phase != .menstrual, fertileWindow nil, headline is the late one.
Add a WidgetSnapshot test: recomputed on a late snapshot does not reclassify to
menstrual.

#### T1-02, T1-07 — 5 Home / 3 Cycle prediction

Two corrections she will reasonably try, and neither works. 'I forgot to log for four
days — it actually started Saturday': she taps Change date, picks the earlier day,
saves, and the row still says the later date. Nothing moved. Move it later instead and
the screen contradicts itself — the header counts from one day while 'Day 5 of your
period' counts from another. And when she taps the red 'Remove period log' because she
logged a period by mistake, only today is cleared: the earlier days of the streak
stay, the start does not move, and if she had ever used Change date or Settings to set
a start, that invisible setting keeps driving her predictions forever because no
delete path clears it.

**Root cause.** Period start has two sources of truth and the editing paths write the wrong one. The
anchor is `max(loggedStreakStart, profile.lastPeriodStart)`
(CyclePrediction.swift:226-234), monotone upward in the seed, so writing
profile.lastPeriodStart can never pull the start EARLIER — the seed write at
HomeView.swift:714 is dead code for every backward move. The only lever that could
move it earlier is the flow streak, and the single row movePeriodStart inserts
(HomeView.swift:710-713) does not join the existing streak once the gap exceeds
sameStreakGapTolerance of 2 (PredictionEngine.swift:30, :209-224). In the forward
direction the seed wins the anchor while activePeriodWindow, dayInPeriod, cycles and
periodRecap keep reading the untouched flow streak (CalendarMath.swift:177-187), so
one screen shows two starts. Symmetrically, removePeriodLog (HomeView.swift:718-733)
is written against todayEntry only while the sheet that hosts it displays a streak
start days earlier (:614, :628-630), and nothing in the app ever clears
profile.lastPeriodStart (CycleSettingsView.swift:193-201 only writes it).

**Fix.**

1. 1. Move the operations out of the view into CycleStore so they are testable and
   have one definition: `CycleStore.movePeriodStart(to:in:calendar:)` and
   `CycleStore.removePeriodWindow(_:in:calendar:)`.
2. 2. Moving EARLIER must fill a contiguous run, not one day: for every day in
   [newDay, oldStart) that has no flow, create it via CycleStore.entry(for:) so the
   gap from newDay to oldStart is zero and the tolerance is never consulted. Filling
   only the endpoint reproduces the bug for any move of three or more days.
3. 3. Choose the fill value deliberately. `.unspecified` contradicts its own contract
   (Enums.swift:9-12 says nothing in the app ever sets it from a tap); either relax
   that comment in the same change or fill with `.light` and say so in the sheet.
4. 4. Moving LATER must trim: clear flow on the days between the old start and the new
   one, so the streak start and the anchor agree. Fire the existing
   HealthKitSync.syncIfConnected for each cleared day — it already deletes the HK flow
   sample when flow is nil (HealthKitService.swift:354-360).
5. 5. Stop writing profile.lastPeriodStart from Change date (HomeView.swift:714). The
   seed is documented as 'what she told Caelyn before she had logged anything'
   (CyclePrediction.swift:152-158); an edit made against logged flow is not that.
6. 6. Make 'Remove period log' mean what it says: clear flow across
   cycle.activePeriodWindow (not just todayEntry), day by day through
   CycleStore.entry(for:in:calendar:), each with updatedAt = .now and the HealthKit
   sync call.
7. 7. Give every removal path a way to clear the seed: when the removal empties the
   window that the seed points into, set profile.lastPeriodStart = nil. Without this
   the anchor stays on an invisible value she has no UI to reach.
8. 8. Land the seed-cutoff item (T1-03) alongside, so any seed left on an older
   profile is at least harmless for past dates.

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Views/Calendar/CalendarMath.swift`

*Tests:* No existing test covers movePeriodStart or removePeriodLog (both private to HomeView)
— extraction to CycleStore is what makes them testable. Add: earlier-by-4 gives anchor
== newDay and activePeriodWindow starting at newDay; later-by-2 gives one start on
every surface; remove clears the whole window and the anchor falls back to the
previous cycle; remove clears a seed that pointed into the removed window.
ProfileStoreTests' 11 lastPeriodStart references are unaffected — the merge rule for
the seed is unchanged.

#### T1-04 — 1 Daily log

In German, French, Spanish, Italian, Portuguese, Dutch, Russian and every other comma-
decimal language, she cannot record her temperature at all. The number pad gives her a
comma, the app says 'Enter a value between 35.0 and 42.0°C' for a perfectly valid
reading, and the field resets when she leaves it.

**Root cause.** The field uses .decimalPad, which shows the locale's separator, but the value is
parsed with `Double(text)`, which only accepts '.'. The deeper mechanism is that the
parse is duplicated at three sites — the validation hint at DailyLogForm.swift:669 and
:670 and the commit at :1105 — against a single locale-invariant formatter at :60-62,
so there is no one place where the field's spelling is defined; that absence is why
the keyboard and the parser can disagree, and why the hand-written test mirror
(DailyLogDraftTests.swift:117-133) stays green while the shipping field rejects valid
input.

**Fix.**

1. 1. Add one `TemperatureText` helper owning both parse and format, and route :669,
   :670, :1105 and :60-62 through it. The stored value stays a °C Double.
2. 2. Harden the parser or it becomes worse than the bug: a NumberFormatter(.decimal,
   locale: .current) in de_DE treats '.' as the GROUPING separator, so number(from:
   '36.5') can yield 365. Set usesGroupingSeparator = false and isLenient = false, and
   reject any input containing a grouping separator before falling back.
3. 3. Order the attempts: (1) the locale formatter; (2) if that fails, swap the locale
   separator for '.' and try Double; (3) fail. Never let step 2 accept a string that
   step 1 parsed to a different number.
4. 4. Keep the 35.0-42.0 range check after parsing, and make the inline hint render
   the bounds through the same formatter so the hint itself is shown with her
   separator.
5. 5. While here, consider accepting Fahrenheit input for US users and converting on
   store — currently every reading from an °F thermometer must be converted by hand.

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`, `CaelynTests/DailyLogDraftTests.swift`

*Tests:* DailyLogDraftTests mirrors tempText and commitBasalTemp by hand (lines 56-58, 118-133)
and must mirror the new helper instead. Add testCommaDecimalTemperatureIsAccepted
under de_DE and testTemperatureRoundTripsThroughTheLocaleFormatter, plus a negative
test that '36.5' in de_DE is never read as 365.

#### T1-05 — 1 Daily log

She is partway through writing a private note, a call comes in, she switches apps —
and later iOS quietly shuts Caelyn down. The note is gone. Nothing warned her; the
keyboard was still up and she never left the screen.

**Root cause.** The form's only durability boundary is an explicit commit (commitNote,
commitMedication, commitBasalTemp at DailyLogForm.swift:1079/1088/1097), and every
trigger for those is a view-local signal: focus loss (:135-143), unmount (:130-134),
medication onSubmit (:937), keyboard Done clearing focus (:152-158). No process-exit
signal is wired to a commit — DailyLogForm never reads scenePhase (the only readers
are CaelynApp.swift:9, AppPreviewMask.swift:6, AppLockGate.swift:6,
WidgetDataSync.swift:121), CaelynApp's handler acts only on .active
(CaelynApp.swift:72-85), and AppDelegate has no background or terminate hook.
Backgrounding neither unmounts the form nor moves focus (AppLockGate.swift:61-76 hides
rather than removes), so no existing trigger fires.

**Fix.**

1. 1. Add `@Environment(\.scenePhase)` to DailyLogForm and commit on the way out:
   `.onChange(of: scenePhase) { _, phase in if phase == .background { commitNote();
   commitMedication(); commitBasalTemp() } }`.
2. 2. Use `.background` specifically, NOT any non-active phase. commitBasalTemp's
   invalid-input branch (DailyLogForm.swift:1111-1116) resets the field to the stored
   value, so a transient .inactive (Notification Centre, Control Centre, the app
   switcher, a permission alert) while she is mid-typing '36.' would silently discard
   the partial entry. The note and medication commits are seed-guarded and idempotent;
   the temperature one is not.
3. 3. The more permanent form: make commitBasalTemp leave an unparseable draft alone
   rather than resetting it, so no commit trigger can ever destroy in-progress input,
   and the commit becomes safe to fire from any phase.
4. 4. Rely on the existing idempotence rather than adding a guard:
   testCommittingTwiceWritesOnlyOnce (DailyLogDraftTests.swift:319) already pins it.

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`, `CaelynTests/DailyLogDraftTests.swift`

*Tests:* DailyLogDraftTests: add testLeavingToTheBackgroundCommitsOnce using the existing
harness, and a test that an unparseable temperature draft survives a commit rather
than being reset.

#### T1-06 — 5 Home

The 'Log Period' button on Home deletes today's period if one is already logged. The
label never changes, so a double-tap nets nothing, and a single tap after logging from
the Log tab, the Watch or an import silently erases the day — including deleting it
from Apple Health — with only a small buzz to mark it.

**Root cause.** Two mechanisms. (a) HomeQuickActions is a stateless struct whose four titles and icons
are compile-time constants (HomeQuickActions.swift:12-35) while the action it invokes
is state-dependent (HomeView.swift:741-756), so the undo-by-toggle has no channel to
reach the label — and QuickActionButton reuses that static title as its only
accessibility label (QuickActionButton.swift:48), hiding the state from VoiceOver
users too. (b) The destructive branch was deliberately stripped of its bookkeeping
(comment at HomeView.swift:745-749: the captured-anchor dance was removed because 'the
anchor follows the flow that remains'), which is true and is exactly what makes the
deletion consequential — the anchor can jump back a whole cycle.

**Fix.**

1. 1. Pass `periodLoggedToday: Bool` into HomeQuickActions, sourced from the same
   `todayEntry?.flow != nil` that loggedFlowToday already computes
   (HomeView.swift:107), so all three surfaces derive from one value.
2. 2. Drive the title from it ('Period logged · Undo'), the icon from it (drop.fill ->
   checkmark.circle.fill), and add an optional accessibilityValue / isToggle trait to
   QuickActionButton so the state reaches VoiceOver — QuickActionButton.swift:48
   exposes only the title today.
3. 3. Prefer routing the second tap to `showingLogSheet = true` rather than deleting
   in place, leaving removal to the Log tab's flow pills where the delete-draft-seed
   fix (1fa4408) already lives — one destructive path instead of two.
4. 4. If the in-place undo is kept, it must be explicit (confirmation or an undo
   affordance), and it must still fire HealthKitSync.syncIfConnected so the Health
   sample is removed consistently (HealthKitService.swift:354-360).

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeQuickActions.swift`, `Caelyn/Components/QuickActionButton.swift`, `Caelyn/Services/HealthKitService.swift`

*Tests:* No unit test covers it. Add a UI test asserting the label changes after one tap and
that flow is still present after a second tap (or that undo is explicit), plus a
VoiceOver-label assertion.

#### T1-09 — 9 Onboarding / 3 Cycle prediction

During setup the 'when did your last period start' picker is pre-filled with a date
seven days ago. If she skims past it without touching it and without ticking 'I'm not
sure', Caelyn records that invented date as her answer — and if she also imported her
history from Apple Health, the invented date overrides her real one for the whole
first cycle. The switchers the import feature exists for are the people this hits.

**Root cause.** OnboardingViewModel.lastPeriodStart is a non-optional Date pre-loaded with now-7d
(OnboardingViewModel.swift:11), so 'she stated a date' and 'the control was never
touched' are the same value in the same storage, and every consumer — complete()
(:117), adopt() (:143), firstPrediction (OnboardingSteps.swift:841) — is forced to
read it as an answer because no other reading is representable. That violates the
invariant the anchor design documents at CyclePrediction.swift:152-158: the seed is
'what she told Caelyn before she had logged anything'.

**Fix.**

1. 1. Change the view model to `var statedLastPeriodStart: Date?` where nil means
   unanswered.
2. 2. Have LastPeriodStep bind the picker through a local non-optional @State with its
   own display default, writing into the optional on change — so touching the picker
   is what creates an answer.
3. 3. notSureLastPeriod then becomes just one way of reaching nil, and complete(),
   adopt() and firstPrediction collapse to `statedLastPeriodStart ??
   importedLastPeriodStart`.
4. 4. Prefer the Optional over a parallel `didChooseLastPeriod` Bool: a flag is a
   convention three existing consultation sites can each forget, whereas an Optional
   makes the compiler refuse to let the unanswered case be read as an answer.
5. 5. Make DoneStep's 'Next period around …' line absent rather than invented when
   nothing was stated and nothing was imported.

*Files:* `Caelyn/Views/Onboarding/OnboardingViewModel.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* Add OnboardingViewModel tests: untouched picker -> lastPeriodStart nil; untouched plus
an Apple Health import -> importedLastPeriodStart wins; an explicit choice -> her
date. ProfileStoreTests' calls into complete() are unaffected as long as the optional
defaults to nil.

#### T1-10 — 8 Local-first storage / 5 Home

Immediately after she updates the app, the widget and the Watch can show a nonsense
cycle day — sometimes 'your period may start today' when it is nowhere near — because
the widget is built from her history a fraction of a second before the app has
finished labelling which calendar day each old entry belongs to, and an unlabelled
entry currently reads as a date in the year 1.

**Root cause.** An unkeyed row (dayKey == 0, which is every row on the first launch after upgrading
from 1.3) maps through CivilDay.localDate(for: 0) to .distantPast
(CivilDay.swift:44-45), and .distantPast is well-formed for every comparison the
readers make: it survives `filter { $0 <= cutoff }` (PredictionEngine.swift:62, :215),
loses `max(logged, seed)` to the stale onboarding seed (CyclePrediction.swift:230) so
the anchor still looks plausible, and `currentCycleDay` keeps the result inside
1...cycleLength because it wraps with `% safeLen` (PredictionEngine.swift:170-176).
There is no value a reader can inspect to tell 'not yet keyed' from '1 January, year
1'. The window exists because WidgetDataSyncModifier.sync() runs synchronously in
onAppear (WidgetDataSync.swift:123-129) while CycleStore.dedupeSameDay's backfill runs
in RootView's async .task (RootView.swift:44-60).

**Fix.**

1. 1. Make the fallback the stored-instant reading, not a new guess: `dayKey > 0 ?
   CivilDay.localDate(for: dayKey, calendar: calendar) : calendar.startOfDay(for:
   date)`. That is exactly what 1.3 (15) computed for the same row, so an unkeyed row
   reads the way it has always read and the backfill becomes a no-op change of
   representation rather than a visible move.
2. 2. CycleEntry.day (CycleEntry.swift:25-33) hardcodes `.current`. Add the calendar-
   taking helper and make it the one the ~29 call sites adopt, or make(calendar:) is
   silently bypassed again — the exact defect fixed in 060c36d.
3. 3. Remove .distantPast as a sentinel from CivilDay.localDate(for:) — return an
   Optional (or precondition on key > 0) so no reader can consume it silently. Every
   call site then has to say what it does with 'not keyed'.
4. 4. Close the ordering window: run the dedupe/backfill pass before the first widget
   snapshot of the launch. Either move the pass to the same synchronous point
   WidgetDataSyncModifier uses, or have the modifier skip its first write until a flag
   set by the pass is true. Step 1 makes this a belt-and-braces measure rather than
   the fix.

*Files:* `Caelyn/Models/CivilDay.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Services/WidgetDataSync.swift`

*Tests:* CivilDayTests (lines 164-176 cover the backfill): add 'a dayKey-0 row's day equals
startOfDay(date)'. New WidgetSnapshotBuilder test: key-0 rows produce the same
snapshot as backfilled rows. The onAppear-vs-task ordering itself is not unit-
testable; assert instead that the snapshot is order-independent.

#### T2-02 — 3 Cycle prediction / 5 Home / 6 Calendar

Caelyn learns her actual cycle — when she really ovulates, when her PMS really starts
— and then four of its own screens ignore what it learned and use textbook numbers
instead. The ring on Home paints the green ovulation arc on different days than the
Calendar paints the fertile window; the 'today' dot can sit inside the green arc while
the line underneath says 'Fertile window in 3 days'; the Calendar shows nine lavender
PMS days while Home's badge says something else. The widget and Watch never show the
personalised phase at all.

**Root cause.** The learned values exist and are used by the model — CycleModel learns a personal
luteal length of 9-17 days (CyclePrediction.swift:197-199) and a personal PMS onset of
2-14 days (:203-205), and ovulationEstimate, fertileWindow and pmsWindow all use them
(:302-321), with CalendarMath.dayState painting from those windows
(CalendarMath.swift:133-143). But four other surfaces hardcode the textbook constants
and were never routed to the learned ones: CycleRingView.ovulationDay = cycleLength -
14 and pmsStart = cycleLength - 4 (CycleRingView.swift:21-22),
PredictionEngine.phase's `pmsStart = max(1, cycleLength - 4)`
(PredictionEngine.swift:359) which drives Home's header, hero headline, background
tint and badge, and WidgetCycleMath.phaseRaw / fertilityStatus. The widget case is
worse than drift: recomputed(for:) is applied unconditionally to every timeline entry
including the `date: now` one (CaelynWidgetProvider.swift:42 and :57,
WatchHomeView.swift:16), overwriting phaseRaw, phaseName, phaseIcon, accent and tint
from WidgetCycleMath (WidgetDataStore.swift:103-111), so the learned phase the app
wrote at WidgetDataSync.swift:68 is discarded on the very first render.

**Fix.**

1. 1. Give CycleModel one derived `ovulationCycleDay` = cycleLength + 1 - lutealLength
   (matching the date maths at PredictionEngine.swift:245-248) and `pmsStartCycleDay`
   = cycleLength + 1 - pmsDaysBefore, and make those the single definition.
2. 2. Add `pmsDaysBefore: Int = 5` to PredictionEngine.phase and use `max(1,
   cycleLength - pmsDaysBefore)` at PredictionEngine.swift:359; CycleModel.phase
   (CyclePrediction.swift:272-277) passes the learned value.
3. 3. Have CycleRingView take ovulationCycleDay and pmsStartCycleDay as inputs rather
   than computing cycleLength - 14 and cycleLength - 4 (CycleRingView.swift:21-22,
   30-32). Resolving the off-by-one convention centrally in step 1 is the point —
   plumbing the luteal length alone still leaves the ring and the grid one day apart.
4. 4. Make the widget carry the app's answer instead of re-deriving it: either write
   ovulationCycleDay and pmsStartCycleDay into the snapshot and have WidgetCycleMath
   consume them, or stop recomputed() overwriting phase fields altogether and have it
   advance only the day count. Today it discards the personalised phase on first
   render, same day, not just across midnight.
5. 5. Add a cross-surface parity test as the permanent guard: for a fixture whose
   learned luteal is not 14, the ring's ovulation day, the Calendar's painted
   ovulation day, and the widget's phase must name the same day.

*Files:* `Caelyn/Components/CycleRingView.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Views/Calendar/CalendarMath.swift`, `Caelyn/Services/WidgetDataSync.swift`

*Tests:* WidgetCycleMathTests asserts parity between WidgetCycleMath.phaseRaw and
PredictionEngine.phase and needs the new parameter threaded through; any test calling
PredictionEngine.phase(forCycleDay:periodLength:cycleLength:) picks up the defaulted
argument unchanged. Add the cross-surface parity test from step 5.

#### T2-03 — 8 Local-first storage

On a phone set to the Thai or Japanese calendar — which is the default for those
regions — Caelyn files every entry under a day number built from the Buddhist or
Imperial year. Nothing lines up afterwards: entries land outside any cycle, the
calendar grid comes up blank, predictions are nonsense, and if she ever switches her
region calendar every entry written before the switch is orphaned. Two phones in two
regions file the same day differently and will not merge.

**Root cause.** dayKey is a persisted, CloudKit-mirrored IDENTITY derived from a display-locale
setting. CivilDay.key(for:calendar:) packs
`calendar.dateComponents([.year,.month,.day])` as year*10000 + month*100 + day with
`Calendar.current` as the default (CivilDay.swift:32-35), and Calendar.current follows
Settings > General > Language & Region > Calendar, so 'year' is the era/BE year: 1
June 2026 keys as 25690601 under Buddhist and 80601 under Japanese.
CivilDay.localDate(for:) rebuilds DateComponents with year/month/day and no .era
(CivilDay.swift:44-52), so the Japanese round-trip has nothing to say which era year 8
belongs to and resolves to an ancient date. Every other CivilDay entry point defaults
to .current too.

**Fix.**

1. 1. Inside CivilDay.key, localDate, key(_:offsetBy:) and days(from:to:), take ONLY
   `calendar.timeZone` from the argument and do all component arithmetic in a private
   `static let civil = Calendar(identifier: .gregorian)` carrying that time zone —
   mirroring what ExportService.swift:63 already does. This removes the input (the
   locale-chosen calendrical system) rather than patching a caller, so the key means
   one thing on all eighteen calendars, across sync peers, and after any future region
   change.
2. 2. It is behaviour-neutral for the Gregorian install base, because local midnight
   is identical in both calendars for the same time zone — so this can land without
   touching anyone's existing keys.
3. 3. Add a repair for devices that already wrote non-Gregorian keys: inside the same
   launch pass, any dayKey whose year component is outside a sane CE window (say <
   1900 or > 2200) is re-derived from the row's stored `date` under the Gregorian
   calendar with the device's time zone. Make it idempotent and run it before the key
   is used for any lookup.
4. 4. Make the doc contract at CivilDay.swift:18-19 literally true by stating that the
   key is always Gregorian yyyyMMdd regardless of the device calendar.
5. 5. Land this in the same release as the dayKey backfill correction, and before it
   in the launch pass order, so the backfill never writes a non-Gregorian key that
   step 3 then has to undo.

*Files:* `Caelyn/Models/CivilDay.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Services/CycleStore.swift`

*Tests:* CivilDayTests only varies the time zone via travel(to:) today; add a case pinning
Calendar(identifier: .buddhist) and one pinning .japanese, asserting the key is
20260601 and that localDate round-trips. No existing assertion should change.

#### T2-08 — 9 Onboarding

During setup she switches on 'Daily check-in', Caelyn asks for permission to send
notifications and she grants it — and then nothing is scheduled. The 8pm reminder she
just asked for does not arrive that evening, or any evening, until she has closed and
reopened the app at least once. The person who sets a reminder is precisely the person
who will not think to do that.

**Root cause.** Two halves. (a) The notification schedule is derived from a UserProfile row that does
not exist until onboarding's final tap: NotificationService.syncFromLiveStore opens
with `guard let profile = ... else { return }` (NotificationService.swift:328-329), so
every pre-completion trigger — including the cold-launch scenePhase -> .active at
CaelynApp.swift:72-74 — is a guaranteed no-op, not merely an already-consumed one. (b)
RemindersStep requests authorization and nothing else (OnboardingSteps.swift:622-629)
and OnboardingViewModel.complete writes the preferences onto the new profile and saves
(OnboardingViewModel.swift:104-133) with no scheduling call, so onboarding is the one
moment that creates the state the scheduler reads and the one moment nothing re-reads
it.

**Fix.**

1. 1. Call the scheduler from OnboardingFlow's completion closure: `{ vm.complete(in:
   modelContext); Task { await NotificationService.syncFromLiveStore() } }`
   (OnboardingFlow.swift:56-58).
2. 2. Put it in the VIEW closure, not inside vm.complete. complete is called directly
   by four unit tests (ProfileStoreTests.swift:159, 179, 200, 214) against an in-
   memory context, while syncFromLiveStore hard-codes Persistence.live.mainContext
   (NotificationService.swift:328) and touches UNUserNotificationCenter — moving it
   into the model would make those tests write to the live store.
3. 3. Guard it the way the Settings screens do (RemindersView.swift:154, :304) so a
   denied authorization is handled identically rather than scheduling into a void.
4. 4. Permanent form: have the scheduler be driven by profile creation as well as
   profile change, so any future first-profile path gets scheduling without
   remembering to call it — but the closure call above is what must ship now.

*Files:* `Caelyn/Views/Onboarding/OnboardingFlow.swift`, `Caelyn/Views/Onboarding/OnboardingViewModel.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* None existing; the scheduler's pure parts are already covered independently of who
calls them. Add a view-model-level test only if the completion closure is extracted;
otherwise this is verified by a device run (set a daily check-in in onboarding,
confirm a pending request exists before any backgrounding).

#### watch:W-01 — Watch companion (WatchDataModel.activate / didReceiveApplicationContext)

watchOS routinely shuts the Caelyn watch app down in the background. Every time she
raises her wrist and opens it again, it has forgotten everything and tells her "No
cycle data yet — Open Caelyn on your iPhone to sync". The phone may have sent the data
an hour ago. For a Pro subscriber who paid for the watch feature, the main thing she
bought is missing on most launches unless she picks up her phone.

**Root cause.** Nothing on watchOS persists the snapshot, and the copy the system already keeps is
never read. The decoded snapshot lives only in an in-memory @Published property
(CaelynWatch/WatchDataModel.swift:6, assigned at :63 and :70). WidgetDataStore.write
has only iOS call sites (WidgetDataSync.swift:137, CloudSyncCoordinator.swift:100), so
the watch's own per-device App Group suite that WatchDataModel reads at :6/:14/:57 is
permanently empty — the read is there, the write never happens. Meanwhile
WCSession.default.receivedApplicationContext does survive termination, and there are
zero occurrences of it anywhere in CaelynWatch/; didReceiveApplicationContext only
fires for newly-arrived context and never redelivers on a later launch.

**Fix.**

1. 1. In both receivers — didReceiveApplicationContext
   (CaelynWatch/WatchDataModel.swift:60-65) and didReceiveMessage (:67-72) — call
   WidgetDataStore.write(snap) after every successful decode, so the watch's own App
   Group suite holds the latest copy.
2. 2. In activate() / session(_:activationDidCompleteWith:) (:9-15), when
   WidgetDataStore.read() returns nil, fall back to decoding
   `WCSession.default.receivedApplicationContext["snapshot"] as? Data` and write that
   through as well, so even a fresh install after an OS restore recovers the system's
   surviving copy.
3. 3. Render from the persisted value at first body evaluation, not only from a push:
   WatchHomeView.displaySnapshot (CaelynWatch/WatchHomeView.swift:13-17) already reads
   model.snapshot, so seeding model.snapshot in init/activate is sufficient.
4. 4. Honour the clear contract from watch:W-03: a context with cleared == true, or
   with no decodable snapshot, must call WidgetDataStore.clear() on the watch suite
   and set snapshot = nil. Persistence without this turns a privacy leak that
   currently evaporates on relaunch into one that survives it.
5. 5. Reword the empty state (CaelynWatch/WatchHomeView.swift:53-71): once a snapshot
   always arrives (watch:W-06), "Open Caelyn on your iPhone to sync" is only correct
   for a genuinely never-synced watch.

*Files:* `CaelynWatch/WatchDataModel.swift`, `CaelynWatch/WatchHomeView.swift`, `Caelyn/Services/WidgetDataStore.swift`, `CaelynWatch/CaelynWatch.entitlements`, `docs/DEVICE_TEST_SCRIPT.md`

*Tests:* No watch target test bundle exists. Extract a tiny pure `SnapshotCache`
(read/write/clear over an injectable UserDefaults suite) and test it from CaelynTests:
write-then-read round-trips, clear empties, a malformed blob reads as nil rather than
throwing. Update docs/DEVICE_TEST_SCRIPT.md H1/H2 expectations, which currently encode
the amnesia as correct.

#### watch:W-04 — Watch companion (CaelynApp.task -> WatchBridgeService.activate / pushSnapshot)

Two things go wrong because the phone turns on its watch connection too late and never
tries again. First, on a cold launch the phone builds its snapshot and tries to send
it before the connection is ready, so the send is dropped and nothing replaces it —
the watch stays stale even though she just opened the phone app. Second, when she logs
from her wrist while the phone app is closed, iOS wakes the phone app in the
background to receive it, but the wake-up creates no window, so the connection is
never turned on at all and her log sits in a queue until she next opens Caelyn
herself.

**Root cause.** Activation is late, conditional and unrepeatable. activate() is called from a `.task`
on WindowGroup content (CaelynApp.swift:45-65), after an awaited StoreKit
loadProducts() — so it is delayed by a network round trip, and a background launch
(which creates no scene) never runs it at all;
AppDelegate.application(_:didFinishLaunchingWithOptions:) (AppDelegate.swift:11-17)
does nothing of the kind. pushSnapshot hard-returns unless activationState ==
.activated and isWatchAppInstalled (WatchBridgeService.swift:21-23, read and
confirmed), and session(_:activationDidCompleteWith:) is an EMPTY STUB
(WatchBridgeService.swift:30, verified) — so there is no replay when activation
finally lands. A second, independent gate fires at the same instant: sync() reaches
the bridge only inside `if PurchaseService.shared.isPro`
(WidgetDataSync.swift:139-140), and purchasedProductIDs starts empty and is filled
asynchronously (PurchaseService.swift:28, :37, :109), so a paying user's first launch
pushes are gated out twice over.

**Fix.**

1. 1. Call WatchBridgeService.shared.activate() synchronously and FIRST in
   AppDelegate.application(_:didFinishLaunchingWithOptions:)
   (Caelyn/App/AppDelegate.swift:12-16), guarded by !Persistence.isDemoStore so
   --screenshot-mode stays hermetic (d0b31aa). Remove the call from
   CaelynApp.swift:54. This covers background launches, which create no scene, and
   removes the StoreKit dependency from the critical path.
2. 2. Give WatchBridgeService `private(set) var lastSnapshot: WidgetSnapshot?`.
   pushSnapshot ALWAYS stores into it, and pushes only when the session state allows
   (WatchBridgeService.swift:20-26).
3. 3. Implement session(_:activationDidCompleteWith:) (currently the empty stub at
   :30) to hop to the MainActor and replay lastSnapshot exactly once. Add
   sessionWatchStateDidChange for the case where the watch app is installed after the
   phone app launched (today isWatchAppInstalled is sampled once per push attempt with
   no retry).
4. 4. Remove the isPro transport gate at WidgetDataSync.swift:139-141 and carry the
   tier in the payload instead (this is the same change as watch:W-06; the two must
   ship together or free users get the Pro dashboard).
5. 5. Put WCSession behind a `WCSessionProviding` protocol so the store-then-replay
   logic is testable without a real session.

*Files:* `Caelyn/App/AppDelegate.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/PurchaseService.swift`

*Tests:* New WatchBridgeServiceTests with an injected WCSessionProviding: pushSnapshot before
activation stores lastSnapshot and sends nothing; the activation callback replays it
exactly once; a second activation does not re-send. No existing test touches this
file.

#### widgets:W-01, watch:W-02 — Widgets + Watch companion (WidgetSnapshot.recomputed / WidgetCycleMath)

Caelyn learns the real length of her luteal phase from her LH tests and learns when
her PMS actually starts, and the app's Home screen uses those learned numbers. The
widget on her home screen and the ring on her watch do not — they quietly fall back to
a textbook 14-day luteal phase and a 5-day PMS window. So on the same afternoon Home
can say "Ovulation window, fertile June 12-17" while the widget and the watch say
"Follicular" and show no fertile window at all. For someone trying to conceive, the
number on her wrist can be several days wrong.

**Root cause.** WidgetSnapshot (Caelyn/Services/WidgetDataStore.swift:24-52, read and confirmed:
fourteen non-optional fields plus four optional recompute anchors, and no luteal or
PMS parameter among them) cannot carry the learned values, so the shared math has
nothing to use: WidgetCycleMath.phaseRaw hardcodes ovulation = cycleLength - 14
(:137), fertilityStatus hardcodes cycleLength - 13 (:154), upcomingStrings hardcodes
ovulation = nextStart - 14 (:179) and PMS = nextStart - 5 (:192). Both consumers
render recomputed(...) unconditionally and never the builder's own fields
(CaelynWidget/CaelynWidgetProvider.swift:42, 47, 57;
CaelynWatch/WatchHomeView.swift:14-17 — verified: displaySnapshot always returns
base.recomputed(for: .now)), so the personalised values WidgetSnapshotBuilder derives
from cycle.phase / cycle.daysUntilPMS are overwritten on every render. The builder is
wrong at source too: WidgetDataSync.swift:82 calls the default-model fertilityStatus
helper, so the fertile dot is on the 14-day model before the recompute even touches
it.

**Fix.**

1. 1. Add two optional fields to WidgetSnapshot
   (Caelyn/Services/WidgetDataStore.swift, in the recompute-anchors block at :39-51 so
   the existing additive-optional convention is preserved): `var lutealLength: Int? =
   nil` and `var pmsDaysBefore: Int? = nil`.
2. 2. Set them in WidgetSnapshotBuilder.build from cycle.lutealLength and
   cycle.pmsDaysBefore (Caelyn/Services/WidgetDataSync.swift:65-86, the same
   initialiser that already writes cycleLength/periodLength).
3. 3. Thread them through every WidgetCycleMath entry point — phaseRaw
   (WidgetDataStore.swift:134-147), fertilityStatus (:153-159), upcomingStrings
   (:165-201) — and through recomputed(for:) (:83-125), which must pass
   `self.lutealLength` and `self.pmsDaysBefore` down.
4. 4. Give the new parameters NO default value in WidgetCycleMath. A Swift default is
   exactly how the drift happened; forcing every call site to name the value makes the
   next omission a compile error rather than a silently wrong health number. Resolve
   nil to 14/5 once, at the single point where the snapshot's optionals are unwrapped
   inside recomputed(for:).
5. 5. Fix the builder's own write: WidgetDataSync.swift:82 must stop calling the
   default-model helper — pass `lutealLength: cycle.lutealLength` (or derive the
   status from cycle.fertileWindow / cycle.ovulationEstimate against today). Without
   this the watch's fertility dot stays on the 14-day model even after step 3.
6. 6. Confirm hidePreview, isPro and the new fields all survive the `var s = self`
   copy in recomputed(for:) (WidgetDataStore.swift:105-124) — the copy is the
   mechanism that keeps non-day-sensitive fields alive and must keep doing so.

*Files:* `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `CaelynWidget/CaelynWidgetProvider.swift`, `CaelynWatch/WatchHomeView.swift`

*Tests:* Extend CaelynTests.testWidgetCycleMathMatchesPredictionEngine
(CaelynTests/CaelynTests.swift:671) with a lutealLength loop 9...17. Extend
testFertilityStatusMatchesDateBasedFertileWindow with a luteal != 14 case. Add a
recompute-invariance test: for a personalised CycleModel, build(...).recomputed(for:
today) must equal the builder's own phaseRaw/fertilityStatusRaw (today it does not).
The parity assertions at CaelynTests.swift:1301-1306 and :1342-1345 must be moved onto
the recomputed snapshot, not the raw builder output.

#### widgets:W-02, watch:W-10 — Widgets + Watch companion (WidgetSnapshot.recomputed / phase classification)

When her period is late, Home says "Your period might be 2 days late" and offers to
mark today as day one. At the same moment the widget on her home screen and the ring
on her watch confidently announce that she is on day 2 or 3 of her period, in the
menstrual phase, with the next period about 25 days away. It is the one moment she
most wants a glance to be right — a possible pregnancy, or an irregular cycle — and
the glance is confidently wrong. If she stops opening the app, the widget keeps
inventing phases indefinitely.

**Root cause.** Two layers, and both must be fixed or the contradiction merely inverts. (a) Phase
classification takes no bleeding evidence:
PredictionEngine.phase(forCycleDay:periodLength:cycleLength:lutealLength:)
(PredictionEngine.swift:350-366) and its mirror WidgetCycleMath.phaseRaw
(WidgetDataStore.swift:133-146) classify on the wrapped cycle-day index alone, so days
1...periodLength past the expected start are "menstrual" by construction whether or
not a single flow entry exists — meaning the snapshot leaves the phone already stamped
menstrual. (b) WidgetSnapshot has no representation of lateness at all
(WidgetDataStore.swift:24-52 — verified: the only anchors are anchorPeriodStart,
cycleLength, periodLength), so recomputed(for:) wraps the day with (daysSince %
safeLen) + 1 (:92), classifies it menstrual (:142), and rolls nextStart forward a
whole cycle (:95-101), while WidgetSnapshotBuilder sits one property away from
cycle.isPeriodLate / cycle.daysLate (CyclePrediction.swift:344-361) and never
serialises them.

**Fix.**

1. 1. Add one derived value to CycleModel — `displayPhase: CyclePhase` — returning
   .unknown (or a new .late case) when `isPeriodLate && !isInActivePeriodWindow`,
   leaving the raw `phase` untouched so the fertile-window and PMS index math is
   unaffected. Point HomeHeader, HomeHeroCard/HomeCopy.phaseHeadline and
   WidgetSnapshotBuilder at displayPhase. This is the half the original finding
   omitted; without it the phone's own hero still says "Day 2 of your period".
2. 2. Add `var daysLate: Int? = nil` to WidgetSnapshot
   (Caelyn/Services/WidgetDataStore.swift:39-51).
3. 3. Compute it INSIDE recomputed(for:) as `max(0, days(from: day0 + safeLen, to:
   today))` — derived per timeline entry, never frozen, so it advances with the pre-
   built midnight entries without the app running. Mirror it in
   WidgetSnapshotBuilder.build from cycle.daysLate for parity.
4. 4. Do NOT change cycleDay or daysUntilPeriod. The parity assertions at
   CaelynTests/CaelynTests.swift:1302-1304 and the midnight-advance tests at :683-695
   depend on them, and leaving them alone makes the whole change additive with zero
   existing test edits.
5. 5. In recomputed(for:), when daysLate > 0 suppress the menstrual classification:
   phaseRaw becomes the late/unknown state and upcomingStrings must not emit a "Period
   in N days" line computed off the rolled-forward nextStart.
6. 6. Render it: SmallWidgetView (CaelynWidget/WidgetViews.swift:59-95) and
   AccessoryRectangularView (:352-379) show "Period may be N days late";
   WatchHomeView's phaseRing and stats row (CaelynWatch/WatchHomeView.swift:39-47)
   show the same rather than restarting the ring at day 1.

*Files:* `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Models/CyclePrediction.swift`, `CaelynWidget/WidgetViews.swift`, `CaelynWatch/WatchHomeView.swift`, `Caelyn/Views/Home/HomeCopy.swift`

*Tests:* New: anchor = today-30 with cycleLength 28 and no flow entries ->
CycleModel.isPeriodLate == true, daysLate == 2, and recomputed(...).daysLate == 2 with
phaseRaw != "menstrual". New: CycleModel.displayPhase != .menstrual while
CycleModel.phase stays unchanged (so the fertile/PMS math is provably untouched).
Existing testRecomputeDaysUntilPeriodNonNegativeAcrossTimeZones must keep passing
unchanged — that is the signal that step 4 was honoured.

#### widgets:W-03 — Widgets (SmallWidgetView / MediumWidgetView / LargeWidgetView — hidePreview + privacySensitive)

She turned on the privacy setting that means "nothing about my cycle on the lock
screen". It works on the two small lock-screen widgets and nowhere else. Her phone
charging on the nightstand in StandBy — which shows home-screen widgets on a LOCKED
phone — displays "MENSTRUAL · 3 · Period in 25d" to anyone in the room. And because no
Caelyn view is marked as privacy-sensitive, iOS's own system setting for hiding lock-
screen widget content has nothing to redact, so her system-level choice is ignored
too.

**Root cause.** Not a plumbing failure — the data is present and simply unread by three of five views.
hidePreview is set at WidgetDataSync.swift:85, persisted, and survives
recomputed(for:) because that method does `var s = self` and never touches it
(WidgetDataStore.swift:105-124). But the masking decision was implemented per-view in
the two accessory families only: AccessoryCircularView
(CaelynWidget/WidgetViews.swift:300, :320) and AccessoryRectangularView (:332).
SmallWidgetView (:54-96), MediumWidgetView (:100-174) and LargeWidgetView (:178-283)
never read it. Separately, a repo-wide grep for .privacySensitive() returns zero uses,
so the platform's own redaction path — the only mechanism that covers surfaces Apple
adds later — is not opted into anywhere.

**Fix.**

1. 1. Hoist the masking decision OUT of the individual views and into
   CaelynWidgetEntryView (CaelynWidget/CaelynWidgetProvider.swift), the one place
   every family passes through: when entry.snapshot.hidePreview == true, select the
   masked view for the family. One decision point means a future sixth family cannot
   be forgotten.
2. 2. Keep the existing hand-drawn mask for the accessory families
   (WidgetViews.swift:303, :334-339). Do NOT let .privacySensitive() replace it there
   — system redaction renders grey placeholder shapes, which on
   accessoryCircular/accessoryRectangular reads as a broken widget, whereas the drop +
   "Caelyn" mask reads as deliberate.
3. 3. Give the home-screen families (small/medium/large) their own masked variants in
   the same visual language: brand mark, no cycle day, no phase name, no countdown.
4. 4. ADDITIONALLY apply .privacySensitive() to the data-bearing subviews of all five
   families. This is belt-and-braces for surfaces the explicit flag cannot know about
   — StandBy, and whatever Apple ships next — and it is what makes iOS's Face ID &
   Passcode -> Lock Screen Widgets setting actually take effect for Caelyn.
5. 5. Verify the mask survives recomputed(for:) by asserting hidePreview is still set
   on the recomputed snapshot in each timeline entry (the `var s = self` copy at
   WidgetDataStore.swift:105 is what guarantees it; a test pins the guarantee).

*Files:* `CaelynWidget/WidgetViews.swift`, `CaelynWidget/CaelynWidgetProvider.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* WidgetKit redaction cannot be unit-rendered. Add a view-selection test:
CaelynWidgetEntryView picks the masked variant for EVERY family when hidePreview is
true (inject the family through the environment). Add a snapshot-field test:
recomputed(for:) preserves hidePreview. Add a manual StandBy line to
docs/DEVICE_TEST_SCRIPT.md.

#### widgets:W-05, watch:W-09 — Widgets + Watch companion (WidgetSnapshotBuilder.build anchor / WidgetSnapshot.recomputed)

She flies from Tokyo to Honolulu. Her phone correctly still says cycle day 10, because
the app now remembers which calendar day each entry belongs to. The widget and the
watch say day 11 — and the phase and fertile window shift with it — until she next
opens the app. Flying the other way shows a day behind. This is exactly the timezone
bug that was just fixed on the phone; the fix never reached the snapshot format.

**Root cause.** The snapshot's day identity is an INSTANT frozen at build time, while the phone's is a
CIVIL KEY re-derived at every read. PredictionEngine.mostRecentPeriodStart maps every
flow entry through CivilDay.localDate(for: $0.dayKey, calendar:)
(PredictionEngine.swift:214), so the phone's anchor is recomputed from the stored
yyyyMMdd key in whatever zone she is in. WidgetSnapshotBuilder copies the resulting
Date verbatim into anchorPeriodStart (WidgetDataSync.swift:31, :82), JSONEncoder's
default .deferredToDate serialises it as an absolute instant with no civil-day
identity (WidgetDataStore.swift:251), and recomputed(for:) re-truncates it with
`cal.startOfDay(for: anchor)` using the READER's current calendar
(WidgetDataStore.swift:86). Tokyo-midnight 1 Sep is 31 Aug 15:00 UTC, whose startOfDay
in New York is 31 Aug — one extra day in daysSince. Every pre-built midnight timeline
entry carries the shifted number, so it persists until the app foregrounds.

**Fix.**

1. 1. Add `var anchorDayKey: Int? = nil` (yyyyMMdd) to WidgetSnapshot
   (Caelyn/Services/WidgetDataStore.swift:39-51).
2. 2. Write it in WidgetSnapshotBuilder.build as `CivilDay.key(for: cycle.anchor)`
   (Caelyn/Services/WidgetDataSync.swift:80-83). It is stamped in the zone the phone
   is actually in — the same zone whose dayKey produced the anchor — so the key equals
   the entry's stored dayKey by construction.
3. 3. In recomputed(for:) derive day0 from `CivilDay.localDate(for: key, calendar:
   cal)` when anchorDayKey is non-nil, falling back to `cal.startOfDay(for:
   anchorPeriodStart)` when nil so 1.3 snapshots keep today's behaviour until the app
   writes once.
4. 4. CORRECTION to the filed fix: CivilDay.swift lives at
   Caelyn/Models/CivilDay.swift, NOT Caelyn/Services/CivilDay.swift. Adding the wrong
   path to the widget/watch `sources:` lists in project.yml (the widget block at
   project.yml:176-180 and the watch block at :214-218, both of which currently pull
   in only Caelyn/Services/WidgetDataStore.swift) produces a missing-file failure on
   the next `xcodegen generate`. CivilDay is pure Foundation — no SwiftData, no
   SwiftUI — so it does compile cleanly in both extension targets.
5. 5. Every downstream value (cycleDay, phase boundaries, nextStart, fertile window,
   countdown) follows from day0, so no other call site changes.

*Files:* `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Models/CivilDay.swift`, `project.yml`

*Tests:* Add a cross-calendar test: build the snapshot with a Tokyo calendar, recompute with a
Honolulu (or New York) calendar at the same instant -> cycleDay must match the Tokyo
value. Extend the existing testRecomputeStableAcrossTimeZones to build with one
calendar and recompute with another (today it uses one calendar for both, which is why
it passes).

#### widgets:W-06, watch:W-05 — Widgets + Watch companion + Local-first storage (snapshot refresh funnel)

She logs the first day of her period from her watch. The entry is saved on the phone —
but the watch ring, every widget, and her scheduled "period expected" notification all
keep showing the old cycle until she opens the phone app and then leaves it. Same
story when a change arrives from her other device over iCloud: the phone's own widgets
update, but the watch paired to that phone is never told. On an iPad in Stage Manager,
where the app simply stays open, the widgets beside it never update at all.

**Root cause.** Snapshot refresh is bound to one view's lifecycle rather than to the data. A repo-wide
grep for the three snapshot primitives returns exactly three production call sites:
WidgetDataSync.swift:132-141 (fired only from .onAppear and .onChange(of: scenePhase),
verified at :123-131), CloudSyncCoordinator.swift:95-101, and
SecureWipeService.swift:95-96. pushSnapshot has exactly ONE caller in the whole app
(WidgetDataSync.swift:140). There is no ModelContext.didSave observer and no
BGTaskScheduler anywhere outside CaelynTests, so nothing couples a write to a refresh.
Consequently every write path that is not "foreground then background the phone app"
leaves derived state stale: WatchBridgeService.handleIncoming saves the entry and
syncs HealthKit (WatchBridgeService.swift:56-70, read and confirmed) and then stops;
CloudSyncCoordinator.refreshDerivedSnapshot rebuilds the local store but never calls
pushSnapshot (CloudSyncCoordinator.swift:88-102); and no path reschedules
notifications after a watch-originated log.

**Fix.**

1. 1. Create `@MainActor enum DerivedState { static func refresh(context:
   ModelContext) }` as the single funnel: fetch profile via ProfileStore.current(in:)
   (the sorted accessor from T2-10 — CloudSyncCoordinator.swift:91 currently fetches
   unsorted, a latent mismatch with WidgetDataSync.swift:121's sorted @Query) and
   entries -> WidgetSnapshotBuilder.build -> WidgetDataStore.write ->
   WidgetCenter.shared.reloadAllTimelines() ->
   WatchBridgeService.shared.pushSnapshot(snapshot) -> Task { await
   NotificationService.syncFromLiveStore() }.
2. 2. Move the Pro decision INSIDE the funnel and express it as data, not as silence:
   always push, with snapshot.isPro set correctly (see watch:W-06). Never `if isPro {
   push }`.
3. 3. Call DerivedState.refresh from WatchBridgeService.handleIncoming after
   context.saveOrLog() (WatchBridgeService.swift:65), from
   CloudSyncCoordinator.reconcileArrivedRecords/refreshDerivedSnapshot
   (CloudSyncCoordinator.swift:88-102, replacing its hand-rolled build+write), and
   from SecureWipeService as a `clear()` mode that also calls pushCleared()
   (SecureWipeService.swift:93-96 — its comment "force widgets/watch to refresh" is
   factually wrong today; there is no watch call in that file).
4. 4. Replace the lifecycle trigger with a data trigger so in-session edits are
   covered: observe ModelContext save notifications (or debounce off the modifier's
   existing @Query of profiles/entries at WidgetDataSync.swift:121-122) and call the
   funnel, keeping .onAppear/scenePhase as belt-and-braces. Debounce at ~400ms to
   match CloudSyncCoordinator's settle interval so a burst of merges produces one
   rebuild.
5. 5. Keep WidgetDataSyncModifier as a thin caller of the funnel so there is one
   implementation, not two.

*Files:* `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* New: saving a CycleEntry through a live-style container results in a WidgetDataStore
snapshot whose anchor equals CycleModel.anchor (inject a UserDefaults suite). New: a
simulated incoming watch payload invokes the funnel exactly once (inject the bridge
and widget side-effects behind a protocol). Existing WidgetDataSync tests unaffected.
Update docs/DEVICE_TEST_SCRIPT.md H3, whose "Watch home refreshes to show new data"
expectation is currently unmeetable.

---

### P2 (72)

#### ACC-03 — 24 Optional Sign in with Apple — AppleSignInService.credentialState / AccountSession.reconcile

She opens Caelyn in airplane mode, or on a flaky connection, and is silently signed
out. Settings flips back to 'Optional', the account rows vanish, and she has to
authorise with Apple again. Her history is never touched, but the account looks
unreliable — the one thing the design says must never happen.

**Root cause.** credentialState(for:) is the single boundary where Apple's (CredentialState, Error?)
pair exists, and it projects the pair onto `state` alone — the completion closure is
`{ state, _ in` (AppleSignInService.swift:56). The 'we have no answer' information is
destroyed before any decidable type sees it, even though AppleCredentialState has a
dedicated .unknown case whose entire purpose is 'couldn't reach Apple'
(AppleSignInOutcome.swift:28-30), and the doc comment at :50-53 promises 'Returns
.unknown on any error'. When Apple reports an error alongside .notFound (the only non-
optional value it can pass when it has no answer; widely reported offline and in the
simulator), the map yields .notFound → .signOutLocally → AccountSession.signOut
(:79-90): Keychain cleared, accountLinked=false. This runs at every launch and every
foreground (CaelynApp.swift:52-64).

**Fix.**

1. 1. Make the mapper error-first and total, so it is correct regardless of which
   state accompanies the error — do not special-case .notFound: `init(state:error:) {
   guard error == nil else { self = .unknown; return }; switch state { case
   .authorized: .authorized; case .revoked: .revoked; case .notFound: .notFound; case
   .transferred: .unknown; @unknown default: .unknown } }`.
2. 2. Use it at AppleSignInService.swift:56 — `continuation.resume(returning:
   AppleCredentialState(state: state, error: error))` — so the pair is never projected
   lossily again.
3. 3. Keep the @unknown default mapping to .unknown rather than to a sign-out:
   CredentialState is NSInteger-backed and could gain cases, and the safe failure for
   an unrecognised value is 'no answer', never 'revoked'.
4. 4. Update the doc comment at :50-53 to describe what the code now does.

*Files:* `Caelyn/Services/Account/AppleSignInService.swift`, `Caelyn/Services/Account/AppleSignInOutcome.swift`, `Caelyn/Services/Account/AccountSession.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* New AccountTests case for the mapper (see probe).
testAnUnknownCredentialStateLeavesHerSignedIn and testNotFoundIsTreatedLikeRevoked
remain valid. Final confirmation needs a device: sign in, enable airplane mode,
relaunch, assert still signed in.

#### ACC-05 — 25 Preferred name — AccountView.nameCard seeding

She opens Account & iCloud in airplane mode. The name field is blank even though she
has a name. She starts typing — and a second later her text is replaced by the old
name. It looks like the app lost or ignored what she typed.

**Root cause.** Two independent defects in one statement. (1) nameDraft's only store-backed seed
(AccountView.swift:58) sits AFTER an unrelated `await CloudAccount.availability()` in
the same .task (:55-56) — a CKContainer.accountStatus() out-of-process call that can
take seconds when cloudd is slow, iCloud is signed out, or the device is offline — and
its @State default is the literal "" (:24), so there is no correct pre-await value to
render. (2) Independently of ordering, the assignment at :58 is unconditional: no
focus or dirty-draft guard, so any re-seed, however fast, overwrites in-progress
typing. Fixing only the ordering leaves the clobber. Note: isSignedIn is NOT part of
this — line 20 initialises it synchronously from the Keychain.

**Fix.**

1. 1. Move the local seed ahead of every suspension point: make `nameDraft =
   AccountSession.nameFieldDraft(for: profile)` the first statement of the .task (or
   an .onAppear).
2. 2. Move `availability = await CloudAccount.availability()` into its own separate
   .task so an iCloud round trip can never sequence a local read.
3. 3. Guard the assignment: `if !nameFieldFocused { nameDraft = ... }` so no present
   or future re-seed can clobber typing. This is the half that makes the fix
   permanent.
4. 4. Make the Save button's enabled condition (:104) compare against the committed
   value rather than a possibly-unseeded draft, so a blank pre-seed state cannot
   present Save as meaningful.
5. 5. Optional but valuable: extract an AccountScreenState struct so seeding order
   becomes unit-testable instead of needing a device.

*Files:* `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Services/Account/AccountSession.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`

*Tests:* None existing. If AccountScreenState is extracted, unit-test that the name draft is
populated before any async availability result is applied and that an applied re-seed
is skipped while the field is focused. Otherwise verify on device offline.

#### ACC-06 — 25 Preferred name — PreferredNameStep.subtitle

She types her own name into the 'What should Caelyn call you?' field and the line
underneath immediately says 'Apple suggested this — change it to whatever you'd
actually like to be called.' Apple suggested nothing; she just typed it. It reads as
an app that does not know where its own information came from, which undercuts the
whole point of asking.

**Root cause.** The prefill's provenance IS passed in but is consumed rather than retained:
init(prefill:) writes it straight into `@State private var name`
(PreferredNameStep.swift:17, :23-26) and keeps no property for it. subtitle (:83-87)
is a computed property whose only available input is therefore the live field text,
which the TextField (:45) mutates on every keystroke — so the copy is driven by 'is
there text in the field now?' instead of 'was this seeded from Apple?'. Two reachable
cases: prefill == "" because Apple withholds the name on every authorization after the
first (AccountSession.swift:43-46), and prefill drawn from her own existing
preferredName, which namePrefill prefers (:117-123).

**Fix.**

1. 1. Add `let suggestedByApple: Bool` to PreferredNameStep and thread it through
   NamePrompt (:116-119; its `id` can stay the prefill string).
2. 2. Compute it at both call sites from the actual source:
   `profile.appleSuggestedName != nil && profile.preferredName == nil` —
   AccountOfferSheet.swift:137 and AccountView.swift:201.
3. 3. Hoist the copy into `static func subtitle(suggestedByApple: Bool) -> String` so
   it is unit-testable without a view host.
4. 4. Prefer the explicit flag over re-testing the prefill string with
   PersonalName.usable: namePrefill blends two sources, so the string alone cannot
   tell them apart — only the caller knows.

*Files:* `Caelyn/Views/Settings/PreferredNameStep.swift`, `Caelyn/Views/Settings/AccountOfferSheet.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Services/Account/AccountSession.swift`

*Tests:* New PreferredNameStepTests: subtitle(suggestedByApple: false) never mentions Apple;
subtitle(suggestedByApple: true) does. Add a call-site test that a profile with
preferredName set but no Apple suggestion yields false.

#### ACC-07 — 25 Preferred name — PersonalName.usable / AccountView.saveName / PreferredNameStep.confirm / AccountOfferSheet

She types 'Alexandria Catherine Jones', taps Save, and the field empties. No message,
no explanation — and underneath it still says 'Leave this empty and Caelyn just says
…'. Caelyn goes on greeting her namelessly and never asks again. Twenty-six characters
is over an invisible 24-character limit; so are many double-barrelled and non-Latin
names.

**Root cause.** Two coupled mechanisms. (a) PersonalName.usable returns String?
(PersonalName.swift:24-44), discarding WHICH of six checks rejected the input — empty,
address-like, control characters, no letter, over maxLength 24 (:15) — so no caller
can distinguish 'she wants no name' from 'this name was refused, for this reason'. (b)
The write path then launders that refusal into a recorded choice:
AccountSession.setPreferredName (:103-106) writes preferredName = usable(raw) AND sets
hasConfirmedPreferredName = true in the same step, and the callers immediately re-seed
the visible field from the committed value (AccountView.swift:125-138 →
nameFieldDraft, AccountSession.swift:136-139). (b) is what makes it permanent: it
erases her text, marks the question answered, and fires Haptics.success()
(AccountView.swift:137) over a failure. Neither TextField enforces a length limit.

**Fix.**

1. 1. Replace the lossy Optional with a verdict: `PersonalName.check(_:) -> Verdict`
   (.ok(String), .empty, .tooLong, .looksLikeAddress, .noLetter,
   .hasControlCharacters); keep `usable = { check($0).value }` so existing callers
   compile.
2. 2. Render reason-specific copy in both previews (AccountView.swift:94-102 and
   PreferredNameStep.swift:45-54) instead of the single nameless-greeting state —
   'Names can be up to 24 characters', not silence.
3. 3. Clamp both TextFields in onChange so the over-length case is prevented rather
   than punished.
4. 4. Gate the commit: saveName (AccountView.swift:132-138) and
   PreferredNameStep.confirm (:99-102) must NOT call setPreferredName, must NOT latch
   hasConfirmedPreferredName, and must NOT fire Haptics.success() on a verdict that is
   neither .ok nor .empty.
5. 5. Split setPreferredName so committing a value and marking the question answered
   are separable — this is the mechanism fix; while they are one step, any future
   caller re-creates the bug.
6. 6. Apply the same change at the third call site, AccountOfferSheet.swift:89-95,
   where a rejected name also silently answers the question.

*Files:* `Caelyn/Services/Account/PersonalName.swift`, `Caelyn/Services/Account/AccountSession.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Views/Settings/PreferredNameStep.swift`, `Caelyn/Views/Settings/AccountOfferSheet.swift`

*Tests:* AccountTests testAVeryLongNameIsDeclinedRatherThanWrappingTheHeader still passes. Add
Verdict tests (see probe) and a commit-gate test: a rejected name leaves
hasConfirmedPreferredName false and leaves the typed text in the field.

#### BC-08 — 36.g Notification content for .birthControl

Every birth-control notification says the same thing: 'Don't forget your birth control
today.' A ring user who removed her ring a week ago gets that on day 28 and has to
work out whether it means put the new one in. A patch user cannot tell a change day
from the start of her patch-free week. The screen promised 'Caelyn will remind you to
remove (day 21) and reinsert (day 28)'.

**Root cause.** The event identity is destroyed one level above the content function, so adding a
parameter alone is not enough. (1) content(for category:isPrivate:) switches on the
Category only (NotificationService.swift:79, .birthControl at :105-110) and returns a
fixed title/body pair; there is no method or event parameter and scheduleOneShot
(:413-425) has nowhere to pass one. (2) The scheduler already knows the event and
throws it away: the patch/ring compactMaps (:279-286, :300-309) map checkpoints to
bare Int offsets, discarding which checkpoint produced each one, and the identifier
`caelyn.birthcontrol.<yyyyMMdd>` (:421-422) carries no event kind, so even the tap
router cannot recover it. BirthControlMethod.reminderBody (Enums.swift:230-236) exists
with exactly the right strings and is referenced nowhere in the repo.

**Fix.**

1. 1. Introduce `enum BirthControlEvent { case takePill, changePatch, patchFreeWeek,
   applyPatch, removeRing, insertRing }`.
2. 2. Stop discarding the checkpoint: the pure plan function (BC-05/06/07 item)
   returns (dayKey, event) pairs — patch 7/14 → .changePatch, 21 → .patchFreeWeek,
   0/28 → .applyPatch; ring 21 → .removeRing, 0/28 → .insertRing; the pill loop →
   .takePill. This is why this item is blocked by the plan extraction.
3. 3. Add `detail: BirthControlEvent?` to scheduleOneShot, makeContent and
   content(for:isPrivate:detail:) and write per-event bodies.
4. 4. Either delete BirthControlMethod.reminderBody or route the per-event copy
   through it so there is one home for the strings — leaving dead code that describes
   behaviour the app does not have is how the next author gets misled.
5. 5. Keep the private-notification variant for every new body: the isPrivate branch
   must stay generic ('Caelyn reminder' / 'Tap to log.') for all six events.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Models/Enums.swift`, `Caelyn/Views/Settings/BirthControlView.swift`

*Tests:* CaelynTests.swift:333-341 (unique titles per category) unaffected.
CaelynTests.swift:629-638 (the priv-5 leak test) MUST be extended to cover all six
event details — every new body needs the private-mode assertion. Add a per-event body
test asserting day 21 and day 28 ring notifications differ.

#### BC-11 — 36.j ProfileStore.merge of reminder times (birth control + every other reminder hour/minute)

She sets her pill reminder for 9:00 PM. After a sync race or a restore leaves two
profile rows, the next launch merges them and the reminder quietly moves to 8:00 AM —
the factory default from the other row. This is exactly the 'my settings changed on
their own' failure the dedupe was written to prevent.

**Root cause.** merge() is a hand-written field-by-field fold with no exhaustiveness check against the
model — Swift raises no error for a @Model property the merge forgets — and the keeper
row is chosen by createdAt age alone (ProfileStore.swift:29-32). Its 'these always
hold a value, so there is nothing to prefer but recency' block (:91-99) lists only
averageCycleLength, averagePeriodLength, firstDayOfWeek, theme, birthControlMethod and
autoWipeAfterDays. birthControlReminderHour/Minute and every other reminder
hour/minute, periodReminderDaysBefore and privateNotifications
(UserProfile.swift:43-51, 69-70 — all 1.2-era, predating the merge) are untouched, so
the keeper's defaults survive and the duplicate's chosen values are deleted with its
row. Every future UserProfile property inherits the same silent omission.

**Fix.**

1. 1. Add the missing always-valued fields to the recency block:
   birthControlReminderHour/Minute, the dailyCheckIn / medication / period / ovulation
   hours and minutes, and periodReminderDaysBefore.
2. 2. Do NOT add privateNotifications with a 'true wins' OR. Its model default is
   already true (UserProfile.swift:12) and SettingsView.swift:752-756 /
   RemindersView.swift:215 let her deliberately turn it off; an OR would make that
   choice unrevertible across any dedupe and re-hide her notification content on every
   launch while two rows exist — the same bug pointed the other way.
3. 3. Better rule for all of them — a default-aware fold: for a field that always
   holds a value, the row whose value DIFFERS from the model default wins; when both
   differ, the more recently active row (lastActiveAt) wins. This handles
   privateNotifications correctly too.
4. 4. PERMANENCE: add a test that enumerates UserProfile's stored properties
   (reflection or a hand-maintained list asserted against Mirror) and fails when a
   property is absent from merge, so the next added field cannot be silently
   forgotten.

*Files:* `Caelyn/Services/ProfileStore.swift`, `Caelyn/Models/UserProfile.swift`

*Tests:* ProfileStoreTests.testTheNewerAnswerWinsForSettingsThatAlwaysHoldAValue
(ProfileStoreTests.swift:104) gains assertions for the reminder hours. Add the probe
case, a privateNotifications=false-survives-dedupe case, and the exhaustiveness test
from step 4. Coordinate with the ACC-15 item — both edit merge().

#### EXP-01 — ExportService.generateCSV / drawEntryTable / drawNotes / filterEntries — the entry.date mirror

If she changes time zone while Caelyn is still running in the background — a flight,
or the clocks changing — and then exports without relaunching, the dates in the CSV
and PDF can be off by one day, and the same PDF can show a period starting on two
different dates. The Insights and summary cards have the same stale window.

**Root cause.** NOT a root cause in ExportService. `entry.date` is a maintained mirror of
CivilDay.localDate(for: dayKey) in the current zone — rewritten for every row on
launch at CycleStore.swift:44-51 and set from the key on every write at :76-77 — so
reading `date` through a current-zone formatter normally yields the stored civil day
and agrees with PredictionEngine. The real (smaller) mechanism is that this
normalisation is LAUNCH-SCOPED: RootView's .task runs once per process
(AppLockGate.swift:27-29 keeps the subtree alive through lock/unlock) and
CaelynApp.swift:72-82 does not re-run it on foreground, so a process that survives a
time-zone move keeps a stale `date` mirror until the next cold start — and every
`.date` reader, not just export, sees it.

**Fix.**

1. 1. Close the mirror's staleness at source: observe
   NSSystemTimeZoneDidChangeNotification (or re-run CycleStore.dedupeSameDay from
   CaelynApp.swift's scenePhase == .active branch, which already runs four other
   reconciliations) so the `date` mirror is re-filed to its key whenever the zone
   changes, not only at launch.
2. 2. This single fix covers every reader at once — DataStatusCard.swift:29,
   InsightsView.swift:35, MonthSummaryCard.swift:13,19, the widget snapshot and the
   export — which is why it is the permanent fix rather than patching ExportService.
3. 3. Cheap defence in depth (optional): have ExportService read
   CivilDay.localDate(for: entry.dayKey) directly when dayKey > 0, falling back to
   entry.date when it is 0 (pre-1.3 rows before the launch dedupe has run). Read-only;
   safe on upgrade from build 15.
4. 4. Apply the same dayKey-first rule to the range cutoff filter
   (ExportService.swift:49-53) so a boundary day is not dropped when the device has
   moved west of where the entry was logged.
5. 5. Depends on the calendar-pinning item: dayKey must be calendar-independent before
   it is trusted as the export's date source.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/ExportService.swift`, `Caelyn/Views/RootView.swift`

*Tests:* None break. Add: the mirror is re-filed when the default time zone changes without a
relaunch; the CSV prints the stored day under a different default time zone; the
range-filter boundary holds under a westward zone change.

#### EXP-04 — Export — clinical PDF (ExportService.drawClinicalSummary)

The PDF she hands her doctor judges her against different numbers than the app does.
The app tells a woman with 2-day periods "in a common range"; the PDF prints "Normal:
3–7 days" next to her 2 days. And if she is a teenager using gentle mode, the wider
ranges the app promised her are silently dropped from the report.

**Root cause.** drawClinicalSummary renders its reference ranges as string literals
(ExportService.swift:222-224: "Normal: 21–35 days", "Normal: 3–7 days", and a
`variation > 7` literal) even though `profile` is in scope (declared :204, passed
:125). TypicalRanges — the app's single source for these bounds (21–35 / 45 gentle,
2–7, cap 7 / 9 gentle) — is never consulted, so neither the canonical numbers nor
`gentleModeEnabled` reach the PDF. The same duplication exists one layer down: the
"Cycle regularity" row's text comes from PredictionEngine.irregularCycleStatus, whose
7 / 45 / 35 / 21 thresholds (PredictionEngine.swift:406-425) are also hardcoded and
gentle-blind, so fixing only ExportService leaves that row contradicting the rest of
the page.

**Fix.**

1. In drawClinicalSummary (ExportService.swift:204-230) add `let gentle =
   profile?.gentleModeEnabled ?? false` and build three Frames:
   `TypicalRanges.cycleLength(avgCycle, gentle: gentle)`, `.periodLength(avgPeriod,
   gentle: gentle)`, `.variation(variation, gentle: gentle)`.
2. Replace each row's literal note with that Frame's `.typical` text, keeping the
   app's "Typical:" wording rather than "Normal" — "Normal" is a stronger clinical
   claim than the app makes anywhere else.
3. Replace the `variation > 7 ? "Consider evaluation if persistent" : nil` literal
   (:224) with a check on the Frame's `status`: print the Frame's own `.watch` text
   when status is `.watch`, nil otherwise. Do not invent new provider-forward wording.
4. Give PredictionEngine.irregularCycleStatus a `gentle: Bool = false` parameter and
   source its 7 / 45 / 35 / 21 bounds from the same TypicalRanges constants, then pass
   gentle from CycleModel. Extract the four bounds as `TypicalRanges` static constants
   so there is exactly one place a number can be edited — that is what makes this
   permanent rather than a one-time text sync.
5. Land after the variation-semantics item (PG-02): that item changes what `variation`
   means inside irregularCycleStatus, and doing both at once avoids touching those
   thresholds twice.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Services/TypicalRanges.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/UserProfile.swift`

*Tests:* No existing test breaks. Add: generatePDF text contains "Typical: 2–7 days"; a gentle-
mode profile with a 40-day average yields "Typical: 21–45 days" and no watch note. Add
an irregularCycleStatus gentle-variant test.

#### EXP-06, EXP-07 — Export/Import — Caelyn CSV round trip (ExportService.generateCSV ↔ CaelynExportSource.parse)

Restoring her own Caelyn backup on a new phone quietly rewrites her history: every
symptom she marked severe or mild comes back as moderate, and a custom symptom she
named "Joint pain, knees" comes back as two separate symptoms, "Joint pain" and
"knees". Re-importing onto the same phone also reports a false conflict on every
single symptom.

**Root cause.** The Caelyn file format has no single definition — generateCSV decides how a column is
written and CaelynExportSource independently decides how to read it, so each column's
meaning is re-invented on the read side. Two concrete instances: (a) the symptom
columns are name-only (ExportService.swift:80, :87) and the parallel `symptomSeverity`
dictionary (CycleEntry.swift:41-43) is never serialised, so the reader fabricates a
value it has no basis for — `.symptomSeverity(2)` at CaelynExportSource.swift:87 —
making "severity unknown" indistinguishable from a real moderate and feeding
ImportReconciler's conflict rules a value the file never contained
(ImportReconciler.swift:461-464, :485-487). (b) The writer joins lists with ';' and
RFC-quotes the cell (ExportService.swift:90, escape() at :100-104), while the reader
hands the unquoted cell to the generic tolerant splitter built for other apps' files,
`ImportValues.splitList`, which splits on ';' '|' AND ','
(ImportValues.swift:350-354). Underneath (b) sits the deeper defect: the joined list
uses ';' as a delimiter and escape() never escapes ';' (it quotes only , " \n), so a
name containing ';' is unrepresentable in the file at all.

**Fix.**

1. Add a `symptom_severity` column to generateCSV's header set
   (ExportService.swift:67-71) and write it from `entry.symptomSeverity`, filtered to
   the symptoms actually logged on that day and including `custom:` keys — e.g.
   `cramps:3;bloating:1;custom:jaw ache:2`. Pass it through the existing `escape()`.
   Omit any symptom whose severity is absent rather than writing 2, so "unknown" stays
   a distinct state in the file.
2. Add `symptom_severity` to `knownColumns` (CaelynExportSource.swift:16-20) and parse
   it into a `[String: Int]` per row. For a listed symptom present in that map emit
   `.symptomSeverity(level)`; for one absent from it (an old file) emit the existing
   `.present`-style observation, NOT `.symptomSeverity(2)`. Remove the hardcoded 2 at
   :87 entirely — that literal is the mechanism.
3. Where the reconciler needs a level for a symptom whose severity is unknown, resolve
   it at apply time from the existing stored value, falling back to 2 only if there is
   none. This is what stops a re-import reporting a conflict on every symptom.
4. Split `custom_symptoms` on ';' only (a small local splitter in
   CaelynExportSource.swift:89), not `ImportValues.splitList`. Leave `pain_types` and
   `symptoms` on splitList: those are enum raw values and
   `PainType`/`Symptom(rawValue:)` rejects a fragment, so tolerance there costs
   nothing.
5. Close the unrepresentable-name hole at the writer: in generateCSV, replace ';'
   inside each custom symptom name with ',' (or percent-escape it) before joining, so
   no name can ever be split by its own delimiter. Needed for the live 1.3 cohort,
   whose names were never validated.
6. Add one shared predicate — e.g. `UserProfile.isValidCustomSymptomName(_:)`
   rejecting ';' and empty/whitespace names — and use it for BOTH `addSymptomDisabled`
   and `commitAddSymptom` (DailyLogForm.swift:551-566), so the disabled state and the
   commit guard cannot drift and a future second entry point inherits the rule.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Services/Import/Sources/CaelynExportSource.swift`, `Caelyn/Services/Import/ImportValues.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Models/CycleEntry.swift`

*Tests:* ImportSourceTests.testCaelynExportRoundTripsEveryField — set severity 3 on one symptom
and 1 on another, assert both survive. Add a round-trip test for the custom symptom
"Joint pain, knees" (one symptom, not two). Add: importing a pre-severity file leaves
existing severities untouched and reports no conflicts.
CaelynTests.testCSVHeaderRowMatchesIncludeNotes must learn the new column.

#### EXP-08 — Export/Import — custom symptom vocabulary (CaelynExportSource.parse → ImportPlanner.commit)

After moving to a new phone and importing her backup, her old days still show "jaw
tension" in exports and the PDF — but the Log screen has no "jaw tension" chip any
more. She cannot log it again without typing the name from scratch, and with a five-
name limit she may not be able to at all. The restore looks complete everywhere except
the one screen she uses daily.

**Root cause.** The import pipeline has no vocabulary for writing anything but a CycleEntry column.
Every case of `ImportObservation.Field` addresses an entry property, and
`value(for:)`, `apply(_:to:)` and `clear(_:)` are all methods on the entry
(ImportReconciler.swift:460-525; the custom case at :497-499 only appends to
`loggedCustomSymptoms`). `ImportPlanner.commit` (ImportPlanner.swift:235-260) never
fetches UserProfile. So no source *can* express "this name belongs in her picker",
regardless of what the file contains. The export side compounds it: the CSV carries no
profile section at all, so a name she created but never logged is not even in the file
to restore.

**Fix.**

1. Export side: add a trailing profile line to the Caelyn CSV — e.g. `# caelyn-profile
   custom_symptoms=a;b;c` — written from `profile.customSymptoms`. This changes
   `generateCSV`'s signature (ExportService.swift:59) to take `profile:`; update the
   two call sites and the ExportService tests. Use the same ';'-escaping rule as the
   round-trip item so a name cannot split itself.
2. Have CaelynExportSource.parse read that comment line (ignore it in every other
   source; CSVReader already tolerates it as an unmatched row — verify, and skip rows
   beginning with '#').
3. Import side: add a profile-level observation kind so the pipeline can express the
   write at all — e.g. `ParsedImport.profileCustomSymptoms: Set<String>` carried
   alongside the entry observations. A one-off field is enough; a full parallel Field
   enum is not warranted.
4. In ImportPlanner.commit, after ImportReconciler.commit, fetch UserProfile and union
   those names into `profile.customSymptoms`, preserving existing order and stopping
   at the 5-name cap (UserProfile.swift:36-37). Union only — never replace — so the
   merge stays additive per the Caelyn data principle.
5. Backstop for files written before step 1: also union the distinct `custom:` names
   observed across imported rows, so an old export still restores the vocabulary for
   names she actually logged.
6. Record the names added in the undo ledger so Undo Import removes exactly the ones
   it added and no name she created herself.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Services/Import/Sources/CaelynExportSource.swift`, `Caelyn/Services/Import/ImportPlanner.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Log/DailyLogForm.swift`

*Tests:* ImportSourceTests: after a full round trip, `profile.customSymptoms` contains the
restored name and the Log picker query returns it. Add: a name created but never
logged survives the round trip. Add: importing 6 names into a profile that already has
2 stops at the cap and adds no duplicates. Add an undo test asserting only the
imported names are removed.

#### F-29-02 — 29 TTC fertility score — displayed signal list

The card that exists to explain her score shows numbers that do not add up to it. She
sees "Fertile window · +30" with a green tick and a gauge reading 15, with nothing
telling her that her negative strip and dry mucus took 15 points off.

**Root cause.** Two defects in the same place. (1) `signals` is a hand-maintained subset of the
branches that mutate `score`: six of the eleven score-mutating branches append nothing
— the +5 and +10 positional fallbacks (TTCFertilityEngine.swift:33-35, :36-38), LH
`.negative` −5 (:46), mucus `.creamy` +5, `.sticky` −5 and `.dry` −10 (:55-57). (2)
Each delta is written twice — once as arithmetic and once baked into the display
string ("· +30") — so the two can disagree with no compiler help. The card then
renders every entry with `checkmark.circle.fill` in successSage
(TTCDashboardCard.swift:27-35), so even a listed penalty would read as a positive.

**Fix.**

1. Introduce a single ledger and remove every direct `score +=`: `struct Contribution
   { let label: String; let delta: Int }`, `var ledger: [Contribution] = []`, and one
   `func add(_ label: String, _ delta: Int) { ledger.append(.init(label: label, delta:
   delta)); score += delta }`. Every one of the eleven branches calls `add`. This is
   what makes the fix permanent — a score mutation without a matching entry becomes
   impossible to write.
2. Drop the "· +30" suffixes from the labels; the view formats `delta`, so a sign typo
   in a string can no longer contradict the arithmetic.
3. Expose `contributions: [Contribution]` on FertilityResult (keep `signals` as a
   computed compatibility shim only if something else reads it) and render it in
   TTCDashboardCard with the icon and colour chosen from the sign of `delta`: a tick
   in successSage for positive, a minus-circle in a muted/warning tone for negative.
4. Add an invariant test: for every combination of branches,
   `ledger.map(\.delta).reduce(0,+)` equals the unclamped score. Assert the clamp
   separately so a clamped score is visibly explained as clamped rather than silently
   mismatching its own list.
5. Land this before the scoring-model item (F-29-06) so the new override rules are
   displayed correctly from the start.

*Files:* `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Views/Home/TTCDashboardCard.swift`

*Tests:* No existing tests. Add: sum of contribution deltas equals the unclamped score for
every branch combination; a negative contribution renders with a non-success icon; the
clamped case is labelled.

#### F-29-03 — 29 TTC fertility score — BBT scoring

The fertility score judges her temperature against fixed numbers rather than against
her own usual temperature. A woman who naturally runs warm (36.72 on an ordinary pre-
ovulation morning) is docked 15 points and told "post-ovulation" on her actual
ovulation day — her card can never reach Peak. A woman who runs cool keeps being
nudged toward "fertile" after her window has closed.

**Root cause.** The thresholds are absolute population constants with no per-user baseline and no gate
at all: `bbt >= 36.7 → −15 "post-ovulation"`, `36.3..<36.7 → +8 "pre-shift (fertile
range)"` (TTCFertilityEngine.swift:61-70). Normal follicular oral BBT spans roughly
36.1–36.7 between individuals, so the branch taken is decided by her constitution
rather than by where she is in her cycle. There is no cycle-day, phase or history
gate, so the comparison is applied on every day of the cycle including menstruation.
The app already owns the per-user machinery — the baseline mean and coverline inside
`WristTempOvulationEngine.detectShift` (WristTempOvulationEngine.swift:41-43) — and
does not use it here, partly because the engine is handed only today's entry (:14-18)
and so has no history to form a baseline from.

**Fix.**

1. Take the widened signature from F-29-06 (`recentEntries:`), so the engine has the
   trailing readings a baseline requires.
2. Reuse `WristTempOvulationEngine.detectShift` rather than reimplementing a coverline
   — one definition of "thermal shift" app-wide is the real permanence argument, and
   it stops Insights and the TTC card ever disagreeing about whether she has ovulated.
3. Note that detectShift cannot answer the "rising today" case as written: it requires
   baseline + 1 + sustain days and only confirms a *sustained* rise. For the same-day
   signal, expose the baseline mean and coverline from the engine (see F-40-04, which
   needs the same value) and score today's reading relative to them: at/above
   coverline → post-ovulation penalty; meaningfully below → the pre-shift bonus.
4. Replace both absolute constants with those relative comparisons. Where there is no
   baseline (fewer than 6 readings), contribute nothing rather than guessing — an
   absent signal is honest; a population guess is not.
5. Gate the post-ovulation penalty on cycle position as a second safety: never apply
   it during menstruation.

*Files:* `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Services/WristTempOvulationEngine.swift`

*Tests:* No existing tests. Add: a warm-baseline user (ordinary readings 36.70–36.75) is not
penalised on her ovulation day; a cool-baseline user (36.10–36.20) does not receive
the fertile-range bonus after her shift; with fewer than 6 readings the BBT section
contributes 0.

#### F-29-11 — Phase Guide — ovulation tips copy (PhaseGuideView)

The Phase Guide tells her "If avoiding pregnancy: use protection from 5 days before
ovulation" — contraceptive timing advice keyed to Caelyn's own estimate, in an app
whose App Store listing says it must not be used as contraception.

**Root cause.** Not simply copy written in ignorance of the positioning — the positioning is
internalised in code and applied on comparable surfaces (InsightsView.swift:309
"Observational only — not a medical or contraceptive method";
WristTempOvulationEngine.swift:10 the same). The mechanism is structural: Phase Guide
tips are a hardcoded `[String]` literal (PhaseGuideView.swift:418-432) rendered
verbatim by an unfiltered ForEach (:127-152), inside a sheet that carries no
disclaimer anywhere — its content ends at hormoneNote (:104-106) and the file has no
footer. So the one surface that gives timing instructions is the one surface with no
disclaimer context, and nothing stops the next tip from doing the same.

**Fix.**

1. Rewrite PhaseGuideView.swift:428 to keep the physiology and carry the house
   framing, e.g.: "Sperm can survive up to 5 days, so the days before ovulation carry
   pregnancy risk — Caelyn's fertile window is an estimate for awareness, not a
   contraceptive method." Do not simply delete the line; the sperm-survival fact is
   genuinely useful.
2. Give PhaseGuideView the disclaimer footer it is the only comparable surface to
   lack, mirroring InsightsView.swift:309, so every present and future fertility-
   timing tip is read in context instead of relying on each tip policing itself.
3. Grep the full tip library and any other hardcoded copy array for "avoid",
   "protection", "prevent" and "contraception" and apply the same treatment, so this
   is a rule rather than one string edit.
4. Check the wording against docs/APP_STORE_DESCRIPTION.md:69, docs/ASC_PASTE.md:114
   and docs/APP_STORE_LISTING.md:375 so the app and the listing say the same thing —
   this is also an App Review 1.4.1 health-claim exposure, not only an internal
   inconsistency.

*Files:* `Caelyn/Views/Education/PhaseGuideView.swift`, `docs/APP_STORE_DESCRIPTION.md`, `docs/ASC_PASTE.md`, `docs/APP_STORE_LISTING.md`

*Tests:* Add a copy-guard unit test: no string in the Phase Guide tip library contains
contraceptive-instruction phrasing ("use protection", "avoid pregnancy" as an
instruction), and the guide sheet renders a disclaimer.

#### F-40-02 — 40 Wrist-temperature ovulation detection — confirmation rule

One disturbed night — a late bedtime, a glass of wine, a cold — can make Caelyn
announce a temperature shift that a fertility-awareness instructor would not confirm.
And for someone who logs temperature only every few days, a "shift" can be declared
across readings weeks apart, as if they were consecutive mornings.

**Root cause.** Two mechanisms. (a) The confirmation rule is an ad-hoc statistic rather than the
published sympto-thermal rule: coverline = arithmetic MEAN of the prior six readings +
0.2 °C, with three array positions at or above it
(WristTempOvulationEngine.swift:26-28, :40-45). Because it is a mean, a single warm
night inside the baseline window LOWERS the bar instead of raising it —
TCOYF/Sensiplan draw the coverline above the HIGHEST of the preceding six. (b) The
scan has no notion of calendar adjacency: `byDay` collapses readings to one per day
(:35-37) and the loop then walks array indices only, so six readings spread over
thirty days are treated as six consecutive mornings.

**Fix.**

1. Replace the statistic with a named clinical rule and state in the doc comment which
   variant is implemented and why: coverline = max of the six preceding readings + 0.1
   °C, with the rule-of-thumb exclusion (if one of the six sits ≥0.15 above the next
   highest, drop it and extend the window by one day), and require three readings at
   or above the coverline with the third ≥ coverline + 0.1 (Sensiplan) or all three
   above (TCOYF) — pick one and cite it.
2. Make day adjacency part of the computation, not an assumption: after building
   `byDay`, iterate a dense day axis (CivilDay / date arithmetic) rather than array
   indices, and require the six baseline days and the three confirming days to be
   within a bounded gap (e.g. no gap >2 days, at least 5 of the 6 baseline days
   present). Return .none otherwise.
3. Keep the existing confidence calculation but recompute the lift against the new
   coverline.
4. Verify the existing fixture still passes: in testWristTempBiphasicShiftDetected the
   baseline max is 36.33 → coverline 36.43, below the 36.58 rise, so it should remain
   detected under max+0.1.
5. Call out in release notes that shift confirmation became stricter — some users will
   stop seeing a card they previously saw, and that is the correction.
6. Sequence after the cycle-boundary fix (F-40-01): both rewrite the same scan loop.

*Files:* `Caelyn/Services/WristTempOvulationEngine.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* testWristTempBiphasicShiftDetected and testWristTempNoShiftOnFlatSeries must still
pass. Add: one disturbed night inside the baseline does NOT confirm; readings 5 days
apart do NOT confirm; a clean consecutive-day rise DOES confirm.

#### F-40-03 — 40 Wrist-temperature ovulation detection — HealthKit consent

If she connected Apple Health once and later tapped Disconnect inside Caelyn, Caelyn
still reads her sleeping wrist temperature from Health and still shows it on the
Insights screen, every time she opens it. Nothing leaves her phone, so no data escapes
— but it contradicts the in-app promise that a toggle she turned off means Caelyn
stops looking.

**Root cause.** Consent state is never plumbed to the series consumer. Caelyn's read toggles are
enforced inside HealthSyncService, which is the only component that receives a
`UserProfile` (HealthSyncService.swift:73-83 states the rule and applies it to
flow/symptoms/fertility). `TemperatureShiftCard` is a leaf view constructed with only
`windowStart` and `bbtSeries` (InsightsView.swift:126-131, :290-295) and calls
`HealthKitService.fetchWristTemperatures` from its own `.task` (:318-322); that
function guards only on `isAvailable` (HealthKitService.swift:202-205). Note the
finding's framing correction: excluding wrist temperature from
`enabledTypes`/`syncedSampleTypes` is correct — that set gates the merge pipeline and
wrist temp has no day field to land in (HealthDataCatalog.swift:108-114, pinned by
HealthSyncTests.swift:784-797) — so the gap is the missing consent channel to the
view, not a missing catalogue entry. Because the iOS-level grant persists after an in-
app Disconnect, there is nothing for Disconnect to clear.

**Fix.**

1. Preferred, no-schema fix: pass `profile` into `TemperatureShiftCard` (already
   available at the call site as InsightsView.profile, InsightsView.swift:11) and
   short-circuit the `.task` before the fetch on `profile?.healthKitConnected == true
   && profile?.hkReadFertility == true`.
2. Clear `result` when the gate is closed, so a card already rendered disappears after
   Disconnect instead of persisting in @State.
3. Stronger: move the gate into the service — give `fetchWristTemperatures` a required
   consent parameter, or add `HealthSyncService.canReadWristTemperature(for:)` and
   guard inside it — so a future call site cannot forget it. The view-level guard
   alone repeats the mistake one layer up.
4. Fix the Connect screen's promise either way: the "Read fertility signals" subtitle
   says "Temperature" (HealthKitConnectView.swift:146-151) while governing nothing of
   the sort. Either make that toggle genuinely govern the wrist read (the step above)
   or correct the subtitle.
5. Only if product wants a separate switch: add `hkReadWristTemperature: Bool = false`
   to UserProfile — an additive property with an inline default, CloudKit-compatible,
   same pattern as hkReadFertility — plus the ProfileStore merge rule. Default false
   means existing connected users must opt in once; weigh that against reusing
   hkReadFertility.

*Files:* `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Services/Health/HealthDataCatalog.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`

*Tests:* HealthSyncTests.testEveryRequestedReadTypeHasSomewhereToLand currently exempts wrist
temperature — extend it to assert the wrist read is consent-gated instead of exempt.
Add: with healthKitConnected false the card performs no fetch and renders nothing.
ProfileStoreTests gains a merge case only if the new flag is added.

#### F-40-04 — 40 Wrist-temperature ovulation detection — BBTChart threshold line

The temperature chart draws a line at 36.4 °C labelled "Threshold" under the subtitle
"rise signals ovulation" — the same line for everyone. A woman whose normal pre-
ovulation temperature is 36.5 sees every single reading above the "threshold" and
concludes she has already ovulated; one who runs cooler sees her genuine post-shift
plateau straddling it. A population average is presented as a personal signal.

**Root cause.** Two mechanisms compound. (a) A population constant occupies a slot that requires a
per-subject derived value: InsightsCharts.swift:276 hard-codes `RuleMark(y: 36.4)`,
and `BBTChart`'s only input is `[BBTPoint]` (:260) — it has no channel through which a
user-derived coverline could arrive, so the constant is not a stale value but the only
value the type can express. (b) The derived value is structurally non-exportable: the
coverline at WristTempOvulationEngine.swift:43 is computed per candidate index inside
detectShift's scan loop and discarded at the `return` on :51, so `Result` cannot carry
it even if the chart asked.

**Fix.**

1. Add `coverline: Double?` (and the baseline mean) to
   `WristTempOvulationEngine.Result` and populate it at the point of return, so the
   value the detector used is observable.
2. Source-match the line to the plotted series — this is the load-bearing correction.
   TemperatureShiftCard prefers HealthKit wrist temperature and falls back to logged
   BBT (InsightsView.swift:320-322), whereas BBTChart plots ONLY manually logged
   basalTemperature (CycleAnalytics.swift:113-120). Handing the card's coverline to
   the chart would overlay a wrist-derived line on an oral-BBT series — two
   measurement sites offset by several tenths of a degree, which is worse than the
   constant. Compute the chart's coverline from the same manual series it plots.
3. Add `coverline: Double?` as a BBTChart input and draw the RuleMark only when it is
   non-nil; label it "Your coverline", not "Threshold".
4. When there is no coverline (fewer than 6 readings), draw no line at all and soften
   the subtitle — no line is more honest than a population line.
5. Delete the 36.4 constant so it cannot be reinstated.

*Files:* `Caelyn/Views/Insights/InsightsCharts.swift`, `Caelyn/Services/WristTempOvulationEngine.swift`, `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Views/Insights/InsightsView.swift`

*Tests:* No existing tests. Add a Result.coverline assertion to the biphasic fixture. Add: with
5 readings the chart receives nil and draws no rule mark; with enough readings the
coverline is derived from the manual series, not the wrist series.

#### FD-1, FD-2 — 45 First day of week

She sets her week to start on Monday. The Calendar tab obeys; every date picker in the
app — 'When did it start?', onboarding's last period, cycle settings, birth-control
start, note reminders — still starts weeks on Sunday. Picking her period start off a
grid shifted by one column sets the wrong date. And a user in a Friday-first locale is
told in Settings that her week starts Sunday, with no Friday option to choose.

**Root cause.** firstDayOfWeek has no single source of truth; it is a raw Int that each consumer
interprets for itself. (a) It is modelled as a parameter threaded from two view roots
into CalendarMath.daysGrid(firstDayOfWeek:) / weekdaySymbols(firstDayOfWeek:)
(CalendarMath.swift:44-52, 67-75), each mutating a throwaway local Calendar. SwiftUI's
DatePicker builds its grid from the \.calendar environment value, which nothing in the
app ever sets (zero hits) — the natural injection root, ThemedContentView
(CaelynApp.swift:104-121, verified: it applies only preferredColorScheme), does not.
(b) The value is enumerated by hand in two places that only know 1/2/7: firstDayLabel
maps everything else to 'Sunday' (SettingsView.swift:779-786, verified) and
FirstDayOfWeekPickerSheet lists only three rows (SettingsPickerSheets.swift:83-87),
while onboarding seeds Calendar.current.firstWeekday (OnboardingViewModel.swift:112),
which is 6 in some locales. (c) Clamping was added to one CalendarMath entry point
only: weekdaySymbols applies max(1,min(7,…)) at :70-72, daysGrid assigns
cal.firstWeekday = firstDayOfWeek raw at :47-48 (verified) — so a corrupt or synced
0/8 shifts the cells while the headers stay clamped.

**Fix.**

1. 1. Add one helper — `CalendarMath.clampedFirstWeekday(_:) -> Int` (max 1, min 7) —
   and use it in daysGrid (CalendarMath.swift:47) as well as weekdaySymbols, so grid
   cells and headers can never disagree.
2. 2. In ThemedContentView (CaelynApp.swift:104-121) derive `var cal =
   Calendar.current; cal.firstWeekday =
   CalendarMath.clampedFirstWeekday(profiles.first?.firstDayOfWeek ??
   Calendar.current.firstWeekday)` and apply `.environment(\.calendar, cal)` beside
   .preferredColorScheme. The fallback MUST be Calendar.current.firstWeekday, not the
   model default of 1 — using 1 would newly break Monday-locale users during the pre-
   profile window (RootView.swift:18-20, 30-36) that behaves correctly today.
3. 3. Leave every explicit Calendar.current in CycleEntry.dayKey, CivilDay and
   PredictionEngine untouched. The injected calendar is a presentation concern only;
   day-key derivation must not start reading an environment value.
4. 4. Replace firstDayLabel (SettingsView.swift:779-786) with
   `Calendar.current.standaloneWeekdaySymbols[clamped - 1]` so any of the seven values
   names itself.
5. 5. Have FirstDayOfWeekPickerSheet (SettingsPickerSheets.swift:83-87) list all seven
   weekdays (or 1/2/7 plus the current value when it differs), driven by the same
   helper, so label and picker can never diverge again.

*Files:* `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/Calendar/CalendarMath.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/SettingsPickerSheets.swift`, `Caelyn/Views/Onboarding/OnboardingViewModel.swift`, `Caelyn/Views/RootView.swift`

*Tests:* Existing testWeekdaySymbolsRotateByFirstDayOfWeek is unaffected. Add
testDaysGridClampsOutOfRangeFirstWeekday (probe), a label test for value 6 (Friday),
and a hosting test asserting a .graphical DatePicker under .environment(\.calendar,
mondayCal) renders Monday first.

#### HK-03, HK-07 — HealthKitSync.syncIfConnected / HealthKitService.syncEntryToHealth failure handling; HealthKitConnectView.writeStatusNote / refreshWriteStatus

When a write to Apple Health fails — most commonly a log made on the Watch while the
iPhone is locked in her pocket, since Health's database is unreadable then — the day
never reaches Health and never will, because nothing retries it and nothing records
that it failed. The Apple Health screen keeps saying everything is fine: its status
line only reports permissions, and even that only refreshes when the screen first
appears, so revoking access in iOS Settings and coming back shows a stale 'all good'.

**Root cause.** The write path is error-discarding end to end. Both delete queries swallow the
HKSampleQuery error and the HKHealthStore.delete error
(HealthKitService.swift:393-402, :429-436); the save reduces its failure to a log line
and a Bool (:373-378); the Bool is @discardableResult (:348) and the sole production
caller discards it (HealthKitSync.swift:36). So the failure signal is produced and
dropped one frame later — not merely unpersisted, but unobserved. With no stored
outcome anywhere in the tree, no surface could render it and no retry could be driven,
and the only automatic re-entry into sync on foreground (CaelynApp.swift:73-80) runs
the READ direction only (HealthSyncService.swift:313-321, mode .incremental).
Separately, HealthKitConnectView's only honest line is computed from
authorizationStatus via canWrite (:289-297) and refreshWriteStatus() runs only in
onAppear (:60), so it is both the wrong signal and a stale one.

**Fix.**

1. 1. Make the write path report instead of swallow: have
   deleteOwnFlowSamples/deleteOwnSymptomSamples return success/failure (propagating
   the errors currently dropped at :393-402 and :429-436), and have syncEntryToHealth
   return a result distinguishing 'nothing to do', 'wrote', 'delete failed', 'save
   failed'. Without this a journal cannot tell a healed day from a half-applied one,
   and the locked-device case (delete no-op + save committed = duplicate samples)
   would be journalled as success.
2. 2. Stop discarding the result at HealthKitSync.swift:36: on failure, record the
   dayKey plus the failure kind in a journal.
3. 3. Store the journal and a `lastHealthWriteFailure` timestamp in UserDefaults (or
   the app group), keyed by dayKey — not on UserProfile — so there is no SwiftData
   schema change and no migration for live 1.3(15) installs. Clear entries on a
   successful re-sync of that day.
4. 4. Drain the journal on foreground: extend the existing hook at
   CaelynApp.swift:73-80, which today runs only the read sync, to re-attempt the
   journalled days when the device is unlocked and the relevant types are authorised
   (gate on capability per HK-08, not on the stored flag).
5. 5. Replace writeStatusNote's authorization-only text
   (HealthKitConnectView.swift:289-297) with a line driven by the journal: 'N days
   haven't reached Health yet' with a button that drains the journal, reusing the
   existing Backfill machinery rather than inventing a second recovery path. Keep the
   permission text as a separate line.
6. 6. Refresh on scenePhase .active, not just onAppear (:60), so revoking access in
   iOS Settings and returning updates the screen.
7. 7. Clear the journal in SecureWipeService and in forgetSyncState.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/HealthKitSync.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* New: journal records on failure, clears on success, drain re-syncs the recorded days.
New view-model-level test for the status note text given journal state.
HealthSyncTests.testLocalEntrySurvivesWhenHealthKitCannotWrite (:953) stays valid and
should additionally assert the day is journalled.

#### HK-04 — HealthKitService.backfillFlowToHealth / backfillSymptomsToHealth

Pressing 'Backfill' can empty everything Caelyn ever put into Apple Health. It deletes
all of Caelyn's existing samples first and only then tries to write the new ones; if
that write fails for any reason, the screen shows an error and her Caelyn history is
simply gone from the Health app, recoverable only by fixing permissions and pressing
Backfill again — which she has no reason to think will help.

**Root cause.** The destructive step and the fallible step share no transaction and no precondition,
and the destructive step's result is discarded. deleteAllOwnFlowSamples runs at
HealthKitService.swift:230 before the save at :253, same order for symptoms at
:319-335; deleteAllOwnSymptomSamples (:291-315) fans out one independent, error-
swallowing delete per HK type (`store.delete(ours) { _, _ in … }` at :308, same at
:281) while `store.save(samples)` (:331) is a single all-or-nothing batch across all
11 types. Any per-type asymmetry — most reachably one type switched off in Settings >
Health > Data Access — fails the whole save after the deletes have already landed.
(Note the finding's stated path is slightly off: HKHealthStore.delete needs the same
sharing authorization as save, so a fully revoked scope deletes nothing; the reachable
case is partial revocation.)

**Fix.**

1. 1. Make the swap the invariant: one `replaceOwnSamples(type:newSamples:)` helper
   per HK type that (a) queries Caelyn-authored samples of that type and keeps their
   UUIDs, (b) `try await store.save(newSamples)`, (c) only on success deletes the
   previously-fetched objects. The new copy exists before the old copy is removed, per
   type, so no partial failure can leave Health emptier than it started. Share this
   helper with HK-01.
2. 2. Per-type, not per-scope: WriteScope.symptoms spans 11 types (:149), so a scope-
   wide guard would block the whole backfill for one denied type. Run the replace
   independently per type and report which types succeeded.
3. 3. Stop discarding delete errors at :281 and :308 — collect them and include them
   in the result so the view can say what actually happened.
4. 4. Change HealthKitConnectView.runBackfill (:369-385) to report a per-type outcome
   ('Updated flow and 10 of 11 symptom types') instead of a single after-the-fact
   error string.
5. 5. Reuse the same plan seam as HK-01 so backfill and single-day sync cannot drift
   in what 'Caelyn's own sample for this day' means.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`

*Tests:* Add HealthWritePlan tests for the backfill plan: order is save-then-delete; a
precondition failure produces no delete; one unauthorised type does not suppress the
other ten.

#### HK-05 — HealthSyncService.forgetSyncState -> ImportLedger.removeAll (HealthKitConnectView.disconnect, SettingsView.enableParanoidMode)

Tapping 'Disconnect' on Apple Health — or turning on Paranoid Mode — also erases the
history of every file she ever imported. Her Clue CSV from last week vanishes from
Settings > Import History and can no longer be undone, and because Caelyn forgets it
imported those values they now look like ones she typed, so re-importing the same file
reports 'already in Caelyn' and refuses to update them. Nothing in the copy warns her.

**Root cause.** ImportLedger is shared by Apple Health and file imports, but forgetSyncState
(HealthSyncService.swift:329-333) calls ledger.removeAll(), which drops every claim,
every byRecord index entry and the whole batchList and deletes the file
(ImportLedger.swift:199-206). forgetSyncState was written when the ledger held only
Health provenance; when file imports were added (dd485a4) they reused the ledger and
removeAll was never scoped. File claims already carry a clean discriminator —
sourceBundleID 'import.<source>' (ObservationBuilder.swift:21).

**Fix.**

1. 1. Add `ImportLedger.removeHealthState()`: call loadIfNeeded() first so a ledger
   not yet read this session is scoped rather than ignored; remove claims where
   `!sourceBundleID.hasPrefix("import.")`; remove batches where sourceID ==
   ImportSourceID.appleHealth.rawValue; rebuild byRecord; then save().
2. 2. save() must now write a possibly-empty file rather than relying on file
   deletion, since the file may still need to hold file-import state.
3. 3. Point HealthSyncService.forgetSyncState (:329-333) at removeHealthState()
   instead of removeAll().
4. 4. Keep the full wipe where it belongs: SecureWipeService.swift:104 reaches the
   ledger only via forgetSyncState(), so change it to call
   ImportLedger.shared.removeAll() explicitly (keeping forgetSyncState() for the
   anchors and lastForegroundSync) — otherwise scoping the disconnect also weakens the
   wipe.
5. 5. Decide Paranoid Mode deliberately (SettingsView.swift:535-543): if it is meant
   to erase all provenance, call removeAll() there explicitly and say so in the copy;
   if not, use removeHealthState().

*Files:* `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* HealthSyncTests.testForgettingSyncStateReleasesEveryClaim (:509) must become 'releases
every Health claim and keeps file-import claims and batches'. Add a BringHistory undo-
after-disconnect test. Add a SecureWipe test asserting the ledger is fully empty
afterwards.

#### HK-10 — HealthKitConnectView.runImport -> HealthSyncService.run(.fullImport) / apply

The same feature behaves differently depending on which button she presses. 'Bring my
history from Health' in the Apple Health settings screen imports immediately with no
preview, cannot be undone afterwards, and does not mention types it could not read —
while the identically-named flow from the main Settings screen previews everything,
records the import, and offers Undo. Worse, if the write fails and is rolled back, the
settings version reports 'Nothing new to bring over' in a success banner.

**Root cause.** Two mechanisms. (1) Wrong entry point: HealthKitConnectView.runImport (:391-396) calls
HealthSyncService.run(mode: .fullImport), which is documented at
HealthSyncService.swift:247-249 as being for paths that are NOT user-confirmed
(background catch-up, onboarding). A Settings button is a user-confirmed path. run
previews and applies in one step (:250-262) and forwards no batchID, so commit gets
batchID: nil and no undoable Batch is recorded; unreadableTypes are dropped on this
path too. (2) Lost success flag: apply returns only result.summary and discards
result.succeeded (:229-246), so a rolled-back save produces an empty Summary, which
ImportCopy.importResult renders as 'Nothing new to bring over'
(ImportCopy.swift:39-44) inside a success banner. BringHistoryModel additionally
fabricates success at :213.

**Fix.**

1. 1. Replace HealthKitConnectView.runImport() with presenting BringHistoryView() — as
   SettingsView.swift:517-519 already does — ideally pre-routed to Apple Health. One
   path, one set of guarantees: preview, batch, undo, unreadableTypes caveat.
2. 2. Change HealthSyncService.apply to return ImportReconciler.CommitResult instead
   of Summary (:229-246); have run either propagate it or keep .summary for its
   genuinely unattended callers (background catch-up, onboarding).
3. 3. Delete the fabricated success at BringHistoryModel.swift:213 and use the real
   CommitResult, so a rolled-back commit renders as a failure.
4. 4. Make ImportCopy.importResult require an explicit success flag rather than
   inferring success from a non-error summary, so an empty-but-failed result can never
   render as 'Nothing new to bring over'.
5. 5. Surface unreadableTypes on every user-confirmed path, not only BringHistory.

*Files:* `Caelyn/Views/Settings/HealthKitConnectView.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/Services/Import/ImportCopy.swift`

*Tests:* BringHistoryFlowTests cover the model; add a test that apply surfaces a failed commit
as a failure (not as an empty success), and a test that the Settings entry point
produces a Batch that appears in Import History.

#### HK-14, HK-11 — HealthKitReader.readChanges error handling / readAll + commitAnchors; HealthSyncAnchorStore

Two faults in the same bookmark. After restoring her phone from a backup onto a new
device, Caelyn can permanently stop picking up what other apps write to Health —
quietly, with no message, until she disconnects and reconnects. And after an
onboarding import or 'Bring my history', the bookmark is never written at all, so the
next time she opens the app Caelyn re-reads years of Health data from scratch, which
stalls the screen on a long history.

**Root cause.** The anchor has no provenance and no invalidation point: its lifecycle is exactly two
transitions — advance-on-commit (HealthKitReader.swift:74-79) and forget-everything-
on-disconnect (HealthSyncAnchorStore.swift:31-36, called only from
forgetSyncState:329) — with no per-type remove, no validity check and no
device/install scoping. HKQueryAnchor is opaque and bound to the local HealthKit
database, and UserDefaults is restored from backup onto a device whose Health database
differs, so a rejected anchor is caught, the type appended to unreadableTypes, and the
bad anchor KEPT (:57-71) — the error path has no vocabulary for 'this anchor is the
problem'. The foreground path then discards unreadableTypes entirely
(HealthSyncService.swift:313-322). The same missing transition shows up again on the
full path: readAll uses HKSampleQuery and never populates ReadResult.anchors (:36-51),
so commitAnchors skips every type via `guard let anchor … else continue` (:73-79) and
the comments at HealthSyncService.swift:226-228 and :290 describe an advance that
never happens; correctness survives only because the ledger marks the re-read samples
.duplicate.

**Fix.**

1. 1. Add `HealthSyncAnchorStore.remove(for: HKSampleType)` — one removeObject(forKey:
   key(for:)) — the missing transition.
2. 2. In readChanges' catch (HealthKitReader.swift:65-68): if the anchor passed at :61
   was non-nil, remove it for that type, log the fallback, and retry the query once
   with anchor: nil. If the retry also fails, append to unreadableTypes as today. A
   failure with an already-nil anchor is not retried, so this cannot loop: a type
   whose error is unrelated to the anchor settles into one attempt per sync, exactly
   as now.
3. 3. Implement readAll via fetchAnchored(type:, anchor: nil) (:104-123): identical
   sample set, plus a real newAnchor per type, so commitAnchors after a full import
   actually advances and the first foreground afterwards is genuinely incremental.
   Keep the 'never advance for filtered routes' rule in apply().
4. 4. Scope anchors to the install: store a device/install UUID alongside them and
   discard all anchors when it does not match, so a restored backup starts clean
   instead of stalling.
5. 5. Stop discarding unreadableTypes on the foreground path
   (HealthSyncService.swift:313-322) — at minimum log them, and feed them into the
   Apple Health screen's status line alongside the write journal (HK-03/HK-07).

*Files:* `Caelyn/Services/Health/HealthKitReader.swift`, `Caelyn/Services/Health/HealthSyncAnchorStore.swift`, `Caelyn/Services/Health/HealthSyncService.swift`

*Tests:* None existing. Add reader tests behind a fake-store seam: a rejected anchor is removed
and the query retried with nil; readAll returns one anchor per type and commitAnchors
persists them; a mismatched install id discards stored anchors.

#### HK-15 — ImportLedger / HealthSyncAnchorStore across devices with iCloud sync on

With two devices, imported values behave differently on each. A value Caelyn imported
from Flo on her iPhone looks hand-typed on her iPad: if Flo later deletes or corrects
it, the iPhone updates and the iPad does not — and because syncing only ever adds, the
iPad's stale copy comes back to the iPhone. She is never told this.

**Root cause.** A replication-scope mismatch. The data is mirrored but the provenance describing it is
not: ImportLedger is a single JSON file in Application Support
(ImportLedger.swift:4-18, :66, :239-247, :260-265) holding both claims and the undo
batchList (:181-197), and HealthSyncAnchorStore writes to UserDefaults.standard rather
than NSUbiquitousKeyValueStore (HealthSyncAnchorStore.swift:18-26), while the
CycleEntry rows they annotate are mirrored by cloudKitDatabase: .private
(Persistence.swift:98-110). So on the second device ImportReconciler finds no claim
and takes .keepUserValue (ImportReconciler.swift:189-195) — both the 'source deleted
means clear' and the 'update from own source' promises hold only on a single-device
setup. CycleStore.merge's additive union (CycleStore.swift:84-93) is not the cause; it
is the (deliberate) reason the stale copy propagates back.

**Fix.**

1. 1. Phase 1 — be honest, and wider than 'values can come back'. State both halves on
   the Apple Health screen and in docs/ICLOUD_ARCHITECTURE.md: on a second device
   Caelyn keeps an imported value even if the other app removes it, AND that device
   will decline a later correction from the same app, because it cannot tell that
   value from one she typed.
2. 2. Phase 2 (the permanent fix) — model the claim as `@Model ImportClaim` with all
   properties defaulted and optional-safe for CloudKit, so provenance replicates
   alongside the data it describes. The claim is keyed on the HealthKit sample UUID,
   which Health's own iCloud sync preserves, so the same claim resolves on either
   device.
3. 3. Keep the undo batchList local or replicate it too, deliberately — decide and
   document which, since an undo applied on one device and not the other is its own
   inconsistency.
4. 4. Leave anchors device-local on purpose (they are bound to the local HealthKit
   database; see HK-14) and say so in the same doc, so the asymmetry is a recorded
   decision rather than an oversight.
5. 5. Do not change CycleStore.merge's union for this — the additive contract stands;
   IMP-02's provenance-aware scalar rule is the only merge change, and Phase 2 is what
   makes it work across devices.

*Files:* `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/Health/HealthSyncAnchorStore.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Services/Persistence.swift`, `docs/ICLOUD_ARCHITECTURE.md`

*Tests:* LocalFirstContractTests / CloudMigrationConflictTests remain the authority. Add a two-
context test documenting that a .clear on one context does not survive the merge, so
the behaviour is pinned rather than discovered.

#### IMP-08, IMP2-10 — 17 Import preview + undo + history (preview copy / summary)

When a file agrees with what she already logged, the preview tells her the opposite:
'N values in this file differ from what you wrote — Caelyn is keeping yours.' On a
second device, where the import record doesn't exist, that is the normal case, and
this is the exact line the design calls the reason anyone trusts an import. Worse, the
same card can say both things at once: the headline 'Everything in this file is
already in Caelyn' sitting directly above a line saying the file disagrees with her in
N places.

**Root cause.** ImportReconciler.plan decides .keepUserValue on provenance alone — 'no live ledger
claim matching the stored value' (ImportReconciler.swift:189-195) — and never compares
observation.value.ledgerValue with stored.ledgerValue. Value equality is computed only
after that guard (:198, :216), i.e. only for import-owned fields, so for a hand-
entered field the agree/disagree distinction is never computed anywhere in the
pipeline. summarize therefore has one bucket, and the copy sites read that single
count in two incompatible ways: as 'the file disagrees with you'
(ImportPreview.swift:156-160, ImportCopy.swift:51-53) and as 'the file has nothing to
offer' (ImportPreview.swift:94-95, ImportCopy.swift:40-43,
BringHistoryView.successDetail, ImportService.swift:98-103).

**Fix.**

1. 1. Compare before choosing the action at ImportReconciler.swift:190-195: `let
   agrees = observation.value.ledgerValue == stored.ledgerValue` -> new action
   .alreadyMatches when agrees, .keepUserValue otherwise. Both still commit nothing.
2. 2. Both cases must still release a stale claim — extend the existing release at
   :356-360 to cover .alreadyMatches. Missing this would leave a dead claim behind and
   let a later sync mistake her value for Caelyn-owned, which is a P0 regression
   introduced by a careless split.
3. 3. Apply the same comparison in the commit-time stale re-check (:332-338), so a
   value she logged while the preview was open that happens to match the file is
   counted as agreement, not as a disagreement Caelyn protected her from.
4. 4. Split Summary into agreedWithUser and keptUserValue, and populate both in
   summarize.
5. 5. Rewire the copy so one number can never be read two ways: headline keys on
   agreedWithUser, safetyLine keys on keptUserValue, and each says nothing when its
   own count is zero. Update ImportService.Result.keptYourValue and
   BringHistoryView.successDetail ('Your own entries were left untouched') to the same
   split.

*Files:* `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportPreview.swift`, `Caelyn/Services/Import/ImportCopy.swift`, `Caelyn/Services/ImportService.swift`, `Caelyn/Views/Import/BringHistoryView.swift`

*Tests:* ImportSourceTests.testFileNeverOverwritesSomethingSheLogged (keptUserValue == 2,
genuinely differing — still passes),
testUnspecifiedNeverOverwritesAnIntensitySheChose,
testValueLoggedWhilePreviewIsOnScreenSurvivesTheCommit.
BringHistoryFlowTests.testAFileAlreadyFullyImportedOffersNoSecondImport asserts on the
headline and needs a differing-values case added alongside. Add the probe.

#### IMP-09 — 16 Import from 9 sources (cross-source conflict)

Someone consolidating two apps imports Clue (which records light / medium / heavy) and
then Flo (which only records that a period happened that day). Every overlapping day
loses its intensity and shows as 'Not recorded'. Import them in the other order and it
works fine. Undoing the Flo import does not bring Clue's values back — the days just
go blank.

**Root cause.** The reconciler holds two contradictory tie-break policies for the same situation.
Within one batch (ImportReconciler.swift:150-159) a tie keeps the FIRST observation
seen — `observation.recordedAt > existing.recordedAt` is strictly-greater, so an equal
timestamp is superseded. Across batches the takeover guard is `observation.recordedAt
< previouslyRecordedAt` (:209-214) — strictly-LESS — so an equal timestamp falls
through to the value comparison at :215-219 and emits .update. File observations all
receive recordedAt = the normalized day (ObservationBuilder.swift:33-36), so two files
always tie; FloSource emits .flow(.unspecified) for every period day
(FloSource.swift:89-92) while Clue carries real intensities
(ClueSource.swift:31-33,100-113). The cross-batch rule is an accident of a guard
written for HealthKit sample clocks.

**Fix.**

1. 1. Make the cross-batch tie agree with the in-batch rule. At
   ImportReconciler.swift:209-214 replace the strictly-older guard with: if
   claim.recordID != observation.recordID and (claim.recordedAt == nil ||
   observation.recordedAt <= previouslyRecordedAt), the sitting import-owned value
   stands. First-wins, matching :150-159.
2. 2. State the reversal in the comment: folding `claim.recordedAt == nil` into 'the
   existing value stands' deliberately contradicts the comment at :206-208, which
   currently lets a newer record win over a pre-recordedAt ledger. The conservative
   direction is correct here but must not be slipped in silently.
3. 3. Do not special-case .unspecified as a bolt-on to the existing fall-through —
   implement the tie as a tie. First-wins then protects every richer earlier value,
   not only flow intensity.
4. 4. Add the separate invariant that makes it safe in both orders: an import must
   never downgrade a known value to the same field's 'present but unspecified'
   variant. When the incoming value is unspecified and the sitting value is specific,
   emit .duplicate regardless of recency.
5. 5. Count the richer-vs-poorer skips so the preview can say 'N days already had a
   more detailed value', instead of them vanishing into the duplicate count.

*Files:* `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ObservationBuilder.swift`, `Caelyn/Services/Import/Sources/FloSource.swift`, `Caelyn/Services/Import/ImportPreview.swift`

*Tests:* ImportSourceTests.testSameRecordsArrivingInTwoDifferentFilesAreNotDuplicated is
unaffected (same source -> same recordID). HealthSyncTests tie-break cases must be
reviewed for equal-timestamp expectations — some may currently rely on last-wins. Add
the probe, and its mirror (Clue after Flo) to prove the outcome no longer depends on
order.

#### IMP-10 — 17 Import preview + undo + history (undo exactness)

She imports a file, taps a symptom off by mistake, then taps it back on. Later she
undoes that import — and the value she deliberately put back is deleted with it, even
though the success screen promised 'Anything you'd edited since is still here.' The
same happens if she changes an imported flow to heavy and then changes it back to what
the import said.

**Root cause.** Ownership is inferred from value equality at the next reconcile instead of being
released when she writes. ImportLedger.swift:17-18 documents a 'moment of release'
that no code implements: the only releases live inside ImportReconciler.commit
(:334-338, :357-359), and nothing in DailyLogForm or CycleStore touches the ledger on
a user save (no ImportLedger reference exists outside Import/ and Health/). Undo then
clears any claimed field whose stored value currently equals the imported value
(ImportPlanner.swift:284-292), and equality cannot distinguish 'never touched' from
'edited away and restored'.

**Fix.**

1. 1. Add ImportLedger.releaseClaims(touchedBy entry: CycleEntry, calendar:) that
   walks the claims on entry.dayKey and releases each whose entry.value(for:
   field)?.ledgerValue != claim.importedValue (a nil stored value counts as a mismatch
   -> release), then save().
2. 2. Create the user-save funnel the fix assumes exists: CycleStore.commitUserEdit(_
   entry: CycleEntry, in context: ModelContext) that sets updatedAt = .now, calls
   releaseClaims(touchedBy:), and saveOrLog().
3. 3. Route EVERY user write through it, not just DailyLogForm.swift:998-1018
   withEntry and WatchBridgeService: HomeView.swift:718-734 removePeriodLog and its
   sibling quick-log writes, DayDetailSheet, and any widget or App Intent write path.
   Grep for context.save() adjacent to a CycleEntry mutation and convert each one.
4. 4. Keep the release value-aware, not field-aware. Releasing every claim on a day
   she merely opened would throw away provenance for fields she never changed and
   break legitimate undo.
5. 5. Once IMP2-03's displaced stack exists, a release must also discard that field's
   displaced tail, so an undo can never restore a value underneath one she now owns.

*Files:* `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Main/HomeView.swift`, `Caelyn/Services/WatchBridgeService.swift`

*Tests:* BringHistoryFlowTests.testUndoKeepsAnythingSheEditedAfterTheImport and
ImportSourceTests.testUndoLeavesAnythingSheEditedAfterTheImport must both still pass.
DailyLogDraftTests may need the ledger hook stubbed. Add the probe.

#### IMP-11 — 17 Import preview + undo + history (ledger lifecycle)

She disconnects Apple Health, or turns on Paranoid Mode, and Settings -> Imports
becomes 'Nothing imported yet'. The Clue import she made yesterday can no longer be
undone, and because those values are now treated as hers, re-importing the same file
reports them all as disagreeing with what she wrote.

**Root cause.** removeAll() (ImportLedger.swift:199-206) is the ledger's ONLY reset primitive and its
granularity is the entire store — it clears claims, byRecord and batchList and deletes
the backing file. No source-scoped eviction exists (no removeAll(where:), no
removeBatches(sourceID:)). HealthSyncService.forgetSyncState (:326-333), whose
legitimate scope is one subsystem, therefore has no way to express a partial reset and
necessarily takes everything, and it is called from HealthKitConnectView.disconnect
(:364) and SettingsView.enableParanoidMode (:543) as well as SecureWipeService (:104,
where whole-store is correct). The sharing of one ledger between Health and file
imports is deliberate and documented (ImportLedger.swift:6) — the missing piece is
scoped removal.

**Fix.**

1. 1. Add ImportLedger.removeAll(where sourceBundleID: (String) -> Bool) and
   removeBatches(sourceID:), keeping byRecord consistent as entries are dropped.
2. 2. Have forgetSyncState drop only claims whose sourceBundleID is not prefixed
   'import.' and only batches with sourceID == 'appleHealth'.
3. 3. forgetSyncState MUST call ledger.save() after a scoped prune. Today removeAll()
   deletes the file so no save is needed and none of the three call sites performs one
   (HealthKitConnectView.swift:364 and SettingsView.swift:543 only call
   modelContext.saveOrLog()); an in-memory-only removal would be silently discarded
   and the Health claims would reappear on the next loadIfNeeded.
4. 4. Leave SecureWipeService.swift:104 on the whole-store removeAll() — a wipe is
   exactly the case where everything should go.
5. 5. Settle and state the Paranoid Mode intent (SettingsView.swift:541-543): if it
   now preserves file-import history, say so in the copy; if the product decision is
   that it should also clear it, keep removeAll() there and say that instead.

*Files:* `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* HealthSyncTests may assert forgetSyncState empties the ledger — narrow those to Health
claims only. Add the probe, plus a case asserting the pruned ledger survives a reload
from disk (i.e. that save() was called).

#### IMP-15 — 16 Import from 9 sources (custom symptoms)

After moving to a new phone and restoring her backup, the symptoms she named herself —
'jaw tension' — show up in her exports and in counts, but there is no chip for them on
the day's log, so she cannot see or tap them. She assumes they were lost, re-creates
them, and often ends up with a near-duplicate that differs only in spacing or case.

**Root cause.** Two mechanisms. (1) The import pipeline treats CycleEntry.loggedCustomSymptoms as
self-describing: ImportReconciler.apply appends the per-day fact (:497-498) and
neither commit path (ImportReconciler.swift:307-380, ImportPlanner.swift:235-258) ever
touches UserProfile.customSymptoms, so the catalog that makes a name actionable is
never populated. (2) Independently, DailyLogForm derives the chip row from the catalog
alone (`customNames = profile?.customSymptoms ?? []`, DailyLogForm.swift:367, iterated
at :391-399) while deriving the severity list from the entry (:369, :455-457) — two
sources of truth for one set.

**Fix.**

1. 1. Fix the view first — one edit at DailyLogForm.swift:367: build the chip row from
   the UNION of profile?.customSymptoms and entry?.loggedCustomSymptoms, deduped case-
   insensitively with the catalog's spelling winning and catalog names ordered first.
2. 2. That single edit covers all three reachable orphan sources at once: CSV import,
   a CloudKit merge that unions loggedCustomSymptoms (CycleStore.swift:112) onto a
   device whose profile lacks the definition, and removeCustomSymptom's own orphans
   (DailyLogForm.swift:1046-1055).
3. 3. Keep the five-custom-symptom gate on the ADD button keyed to the CATALOG count,
   not the union, so an orphan rendered from an entry cannot block her from adding a
   new definition.
4. 4. Then fix the importer: on commit of a CaelynExportSource import, add any unknown
   name from loggedCustomSymptoms to UserProfile.customSymptoms, matching case-
   insensitively against existing entries so a restore cannot create 'Jaw tension'
   alongside 'jaw tension'.
5. 5. Respect the free-tier cap: if adopting names would exceed it, adopt up to the
   cap and leave the remainder as union-rendered orphans (still visible and
   toggleable) rather than dropping them silently.

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/Import/Sources/CaelynExportSource.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportPlanner.swift`, `Caelyn/Services/CycleStore.swift`

*Tests:* Extend the ImportSourceTests Caelyn round-trip to assert profile.customSymptoms
contains the restored name with its original spelling. Add a DailyLogForm-level test
that an entry carrying an orphan logged custom symptom renders a toggleable chip, and
one that the ADD-button cap counts catalog entries only.

#### IMP-16 — 16 Import from 9 sources (file identification)

The most likely mistake on the Clue route — tapping the downloaded .zip in Files
instead of the measurements.json inside it — gets a dead-end 'Caelyn doesn't recognise
that file yet'. The app already contains the right message ('If it came out of another
app as a zip, unzip it first…') but no code path can ever reach it. Picking a PDF or a
photo gets the same generic answer.

**Root cause.** Two mechanisms. (a) ImportPayload.decodedText() includes .isoLatin1 in its fallback
chain (ImportPayload.swift:29-35), and ISO-8859-1 is a total function over bytes — all
256 values map to a scalar — so `text` is non-nil for every non-empty file and the
'not text at all' contract documented at :24 is never satisfied (.windowsCP1252 behind
it is dead code). Binary therefore enters the detectors as garbage text, where each
detector's only job is to decline (.no); identify has no third outcome for 'this is
not a text document' and falls through to `throw .unsupported` at
ImportPlanner.swift:88. (b) .unreadable, which carries the zip hint
(ImportSource.swift:112-120), can only be thrown by a parser AFTER a successful
detection, which for a zip never happens.

**Fix.**

1. 1. Add a non-lazy ImportPayload.kind computed from data.prefix(8): PK\x03\x04 /
   PK\x05\x06 / PK\x07\x08 -> .zip; %PDF -> .pdf; \x89PNG, \xFF\xD8\xFF, GIF8,
   RIFF…WEBP -> .image; 'SQLite format 3\0' -> .database; else a byte-histogram test
   (any 0x00 in the first 4 KB, or >10% of bytes outside printable ASCII plus common
   UTF-8 continuation ranges) -> .binary; else .text.
2. 2. Throw before the detector loop, right after the isEmpty guard at
   ImportPlanner.swift:62: .compressed for .zip (carrying the existing unzip hint),
   and a new .notText for the rest, with copy naming what it looks like ('That looks
   like a PDF. Caelyn reads the data file an app exports, not a printed copy.').
3. 3. Remove .isoLatin1 and .windowsCP1252 from decodedText's chain, or run them only
   after the kind sniff has already returned .text, so the contract documented at
   ImportPayload.swift:24 becomes true instead of aspirational.
4. 4. Make the zip message route-aware where it costs nothing: on the Clue route, name
   the file she is looking for ('measurements.json').

*Files:* `Caelyn/Services/Import/ImportPayload.swift`, `Caelyn/Services/Import/ImportPlanner.swift`, `Caelyn/Services/Import/ImportSource.swift`, `Caelyn/Views/Import/ImportSourceGuide.swift`, `Caelyn/Views/Import/BringHistoryView.swift`

*Tests:* ImportSourceTests.testBinaryFileIsUnsupportedNotMisread changes its expectation from
.unsupported to the new case for PNG. Add the probe, a PDF case, and — importantly — a
UTF-16 CSV case proving the sniff does not reject real text that is not UTF-8.

#### IMP2-05 — 17 Import preview + undo + history (privacy footer)

On the screen where she hands over four years of reproductive history, Caelyn says
'Your file is read on this iPhone. Nothing is uploaded, and Caelyn has no server to
upload it to.' That line is still on the success card at the moment the entries the
import just created are being copied into her private iCloud database — the sync she
turned on in Settings. The file genuinely isn't uploaded; the history is. This is the
one place in the import flow where the app's own disclosure rule is contradicted.

**Root cause.** privacyFooter makes an absolute, app-wide claim ('Nothing is uploaded') inside a
sentence whose subject is a file read, and it renders unconditionally beneath every
phase because it sits after the switch inside the same VStack
(BringHistoryView.swift:35-56, 337-350). It consults model.isHealthRoute (:341) but
never Persistence.isSyncActive, so the sentence cannot vary with the only state that
determines whether it is true — and it would still be wrong if it were correctly
phase-scoped, because the claim is about the app's upload behaviour rather than about
this file.

**Fix.**

1. 1. Split the sentence into a phase-scoped clause about the FILE and a sync-
   conditional clause about the DATA.
2. 2. Derive the second clause from Persistence.isSyncActive, not isSyncEnabled —
   Persistence.swift:64-68 and :80-84 are explicit that the preference records what
   she asked for while isSyncActive records what actually opened; a toggle set but a
   container that fell through to local (:123) must not claim a cloud copy.
3. 3. Do NOT leave the current sentence unchanged on
   .choosingSource/.reading/.confirming. With sync on it is true of the file but is
   read as a statement about the import she is about to make. Use 'Your file is read
   on this iPhone and never sent anywhere.' in those phases.
4. 4. On the success card with sync active, add 'These entries sync to your private
   iCloud, like everything else in Caelyn.' With sync off, keep the stronger original
   sentence — it is true then, and the difference she can see is the disclosure doing
   its job.

*Files:* `Caelyn/Views/Import/BringHistoryView.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* Add an assertion pairing the footer text against Persistence.isSyncActive, alongside
the existing DeletionModelTests sync-disclosure cases.
BringHistoryFlowTests.testGuideCopyStaysOutOfTechnicalLanguage is unaffected.

#### IMP2-06 — 16 Import from 9 sources (Clue route)

A Clue export that records 'spotting' under its period category becomes a full
bleeding day in Caelyn, which invents a period start and distorts every cycle length
after it. A Clue entry whose value Caelyn cannot read at all does exactly the same
thing, and she is never told a row was skipped. Caelyn is careful about this
everywhere else — the generic CSV reader carries a comment explaining precisely why
spotting must never become flow.

**Root cause.** ClueSource's period branch has exactly two outcomes — a recognised intensity from a
four-entry allowlist, or .flow(.unspecified) (ClueSource.swift:99-117) — and no third
route for 'this category entry is not a full bleeding day' or 'I could not read this'.
Bleeding is therefore inferred from the presence of type:"period" rather than from a
recognised state, and PredictionEngine.swift:60 treats any non-nil flow as bleeding,
so any value in that field manufactures a period start. Separately, options(from:)
returns [] for any value shape that is not {"option": …} or an array of them
(:199-208), and [] lands in the same fallback with no unmapped note recorded.
ClueSource's own `spotting` TYPE obeys the rule correctly (:115-117 ->
.symptom(.irregularBleed)), as does GenericTableSource (:146-151) and
ImportValues.flow.

**Fix.**

1. 1. Add a Clue-local lesser-bleeding recognition step to the period branch, keyed on
   exact option names as every other Clue mapping is: an option normalising to
   'spotting', 'very_light' or 'trace' writes .symptom(.irregularBleed) with
   .symptomSeverity(1) — reusing the exact call at ClueSource.swift:116 — and writes
   nothing into .flow.
2. 2. An option that ImportValues.isExplicitlyNoFlow recognises ('none', 'no', '0')
   writes nothing at all.
3. 3. Do not route any of this through ImportValues.flow. Keeping the flow field nil
   is what actually prevents the invented period start (PredictionEngine.swift:60);
   reclassifying inside the flow field would not.
4. 4. Distinguish 'unreadable value shape' from 'unknown intensity word': when
   options(from:) returns [] for a period entry, skip the row, increment
   parsed.rowsSkipped and record an unmapped note, instead of writing .unspecified.
5. 5. Always say something: every option that reaches the genuinely-unknown fallback
   should append a line to parsed.assumptions naming the word, so the preview
   discloses what Caelyn guessed.

*Files:* `Caelyn/Services/Import/Sources/ClueSource.swift`, `Caelyn/Services/Import/ImportValues.swift`, `Caelyn/Services/Import/ImportPreview.swift`

*Tests:* ImportSourceTests.testClueKeepsAPeriodDayItCannotNameTheIntensityOf MUST keep passing
unchanged — 'some_new_level' is still an unrecognised word and must still yield
.unspecified. Review the Clue spotting case near ImportSourceTests:808. Add both
probes.

#### IMP2-07 — 16 Import from 9 sources (Caelyn export dating)

She flies west without relaunching the app (iOS keeps apps alive for days), then
exports. Every day in the file is written a day earlier than she logged it. If she
later restores that backup — moving phones, recovering — her whole history lands a day
early: period starts, cycle boundaries, the temperature chart, everything shifted.

**Root cause.** entry.date is a cache of the civil day that is only valid while TimeZone.current
equals the zone it was normalised in (by CycleEntry.init, CycleStore.entry(for:) or
CycleStore.dedupeSameDay — which runs only from RootView.task at launch and from
CloudSyncCoordinator on a remote change). ExportService re-derives the day from that
cache rather than from the authoritative dayKey: generateCSV formats entry.date with a
formatter whose timeZone defaults to TimeZone.current (ExportService.swift:59-77),
filterEntries compares `$0.date >= cutoff` (:44-54), and the PDF entry table
(:400-410) and Notes section (:418-442) do the same. The import side IS dayKey-safe,
so the shifted file re-imports faithfully as shifted.

**Fix.**

1. 1. Format the CSV date column from the integer key so it cannot depend on
   TimeZone.current, Calendar.current or Locale by construction: String(format:
   "%04d-%02d-%02d", key/10_000, (key/100)%100, key%100) at ExportService.swift:77.
2. 2. Apply the same at the PDF entry table (:403) and in Notes (:418-421, :442) —
   carry dayKey through the tuple rather than e.date, then render via
   CivilDay.localDate(for:) through the existing pdfDateFormatter("MMM d") so month
   names still localise.
3. 3. Make filterEntries compare dayKeys against a cutoff dayKey rather than instants
   (:44-54), so the range boundary moves with the civil day too.
4. 4. Do not claim this removes the last instant-derived reader — other consumers of
   entry.date remain at HEAD (the dayKey sweep in 37dddd7/9776951 converted the
   identity, lookup and prediction paths, not every consumer). Fix ExportService now
   and keep the audit of the rest as separate work.
5. 5. Add a calendar parameter to generateCSV (defaulted) so the behaviour is testable
   without overriding TimeZone.current process-wide.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Models/CivilDay.swift`

*Tests:* No existing test pins export dates across a timezone change — CivilDayTests covers the
model, not ExportService. Add the probe (a Tokyo-normalised entry exported under a New
York calendar), which requires generateCSV to gain the calendar parameter from step 5.

#### IMP2-13 — 16 Import from 9 sources (Clue instructions)

Clue's instructions tell her 'Keep the password Clue shows you — you'll need it', then
send her to the Files app's Uncompress, which has no password prompt, and no later
step ever uses the password. If the archive really is encrypted, she has requested an
export, waited for the email, and hit a wall with a three-day download link expiring.
Clue is the richer of the two file routes — the only source that brings symptoms,
moods, energy, discharge and temperatures across in one file.

**Root cause.** A doc-to-copy transcription promoted an unexplained fact into an imperative.
docs/IMPORT_FORMATS.md:56-59 records two facts in adjacent sentences (Clue shows a
password; iOS Files can uncompress the zip in place) and never says what the password
is for; ClueSource.swift:5-7 carries the pair forward, also without a purpose; the
step list at ImportSourceGuide.swift:201-218 was written from that record and turned
the purposeless fact into a directive with a consequence attached, creating an
obligation the product cannot discharge — 'password' appears exactly once in the
entire Swift source.

**Fix.**

1. 1. Replace step 3 with a sentence that states the fact without promising a later
   use: 'Clue may show you a password — note it down before you leave the screen.'
2. 2. Move the use into step 5, where it would actually occur: 'The download is a zip.
   Touch and hold it in Files and choose Uncompress. If it asks for a password, that's
   the one Clue showed you.' This is correct under both of the states the repo cannot
   currently distinguish, so it does not wait on step 3.
3. 3. Resolve the underlying fact: obtain a real Clue export, record in
   docs/IMPORT_FORMATS.md whether the archive is encrypted, and if it is, add the
   route Files cannot provide (a third-party unarchiver, or doing it on a computer) as
   an explicit step.
4. 4. Add a cheap structural guard: a test asserting that no guide step mentions an
   artefact which no later step of the same guide uses.

*Files:* `Caelyn/Views/Import/ImportSourceGuide.swift`, `Caelyn/Services/Import/Sources/ClueSource.swift`, `docs/IMPORT_FORMATS.md`

*Tests:* BringHistoryFlowTests.testEverySourceGuideExplainsHowToGetTheFile and
testGuideCopyStaysOutOfTechnicalLanguage check shape, not coherence — add the
dangling-artefact assertion from step 4 alongside them.

#### LC-07 — CaelynApp WindowGroup .task launch sequence

On a slow or flaky connection, Caelyn can show the same day logged twice after a sync,
and a Pro user's Apple Watch shows yesterday's numbers after launch — because the app
waits for an App Store products lookup to finish before it starts listening for synced
records or talking to the Watch.

**Root cause.** Two independent mechanisms. (1) Observer registration is launch-ordered rather than
dependency-ordered, and nothing backstops it: `Persistence.live` opens the mirrored
container during App-struct init (CaelynApp.swift:24-27 → Persistence.swift:96-107),
while the `.NSPersistentStoreRemoteChange` observer is only registered after `await
PurchaseService.shared.loadProducts()` (CaelynApp.swift:53-55 →
CloudSyncCoordinator.swift:40-50). NotificationCenter does not replay, and
`CycleStore.dedupeSameDay` has no other app-code call site (grep: only
CloudSyncCoordinator.swift:75 and tests), so notifications posted in that gap are lost
permanently, not merely late — the duplicate day stays visible until the next remote
change or a relaunch. (2) `loadProducts` awaits `Product.products(for:)`
(PurchaseService.swift:106-109), a network call that can take many seconds on a poor
connection, and the credential reconcile plus both cloud-deletion checks
(CaelynApp.swift:56-63) queue behind it for no reason.

**Fix.**

1. 1. Hoist the local, dependency-free work ahead of every await in the WindowGroup
   `.task`: `syncCoordinator?.start(); WatchBridgeService.shared.activate()` first.
2. 2. Run the network pieces as independent child tasks — `async let` for
   `loadProducts()` and `reconcileAppleCredential()`; keep the two cloud-deletion
   checks ordered only relative to each other.
3. 3. Add the backstop that ordering alone cannot provide: have
   `CloudSyncCoordinator.start()` call `reconcileArrivedRecords()` once, immediately
   after registering the observer, so records that arrived between container open and
   observer registration are still reconciled. Ordering cannot close that window
   because the container opens before the `.task` exists at all.
4. 4. Have WatchBridgeService cache the last snapshot and push it from
   `activationDidCompleteWith`, so a Watch that activates after the push attempt still
   gets current data.
5. 5. Why permanent: the sequence is driven by what each step actually depends on, and
   the one unclosable window is covered by a single reconcile-on-start rather than by
   hoping the notification arrives late enough.

*Files:* `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/PurchaseService.swift`

*Tests:* None existing. Add a unit test that CloudSyncCoordinator.start() runs a reconcile pass
immediately (inject a spy context). Add a test that WatchBridgeService pushes its
cached snapshot on activation completion (inject the WCSession state).

#### LC-08 — project.yml build metadata (cross-cutting release)

Nothing in this audit can be shipped until this is fixed: the app says build 16 while
the widget and watch bundles still say 15, and App Store Connect rejects the upload
with ITMS-90473 — the exact mismatch the project file's own comment warns about.

**Root cause.** The three numbers are not peers maintained by hand — the app target's version is
DERIVED and auto-tracks a bump, while the two embedded targets' are FROZEN LITERALS
that structurally cannot track it. Parsed from the generated pbxproj: the Caelyn app
target has GENERATE_INFOPLIST_FILE = YES alongside INFOPLIST_FILE, so
CURRENT_PROJECT_VERSION (project.yml:24) flows into its Info.plist; CaelynWidget and
CaelynWatch have INFOPLIST_FILE with NO GENERATE_INFOPLIST_FILE, so their plists carry
whatever literal project.yml:182 and :221 wrote ("15"). A bump to the app can never
propagate.

**Fix.**

1. 1. In project.yml:182-183 (CaelynWidget) and :221-222 (CaelynWatch), replace the
   literals with build-setting references: `CFBundleVersion:
   "$(CURRENT_PROJECT_VERSION)"` and `CFBundleShortVersionString:
   "$(MARKETING_VERSION)"`.
2. 2. Regenerate the project so CaelynWidget/Info.plist and CaelynWatch/Info.plist
   carry the `$(...)` tokens rather than `15` / `1.3`.
3. 3. Verify in a built .app that the embedded .appex and the Watch app resolve to the
   same CFBundleVersion as the host before the next upload.
4. 4. Why permanent: it deletes the duplicated literal rather than correcting today's
   value — after it, project.yml:24 is the only place a build number exists for the
   iOS app and both embedded bundles, so a bump cannot desynchronise them.

*Files:* `project.yml`, `CaelynWidget/Info.plist`, `CaelynWatch/Info.plist`, `Caelyn.xcodeproj/project.pbxproj`

*Tests:* New test only: EmbeddedBundleVersionProbe (below), run against a built app so the
resolved plists are inspected rather than the templates.

#### LC-09 — CaelynApp.onOpenURL / IncomingImportFile.init?(openedAt:)

She taps "Open in Caelyn" on a tracker export from Files or Mail and nothing happens
at all — no screen, no message — if the file is empty or hasn't downloaded yet. She
concludes the import feature is broken. With a large file, the app visibly freezes
while it reads.

**Root cause.** The only construction site for this route is a FAILABLE initializer, so the type
system itself forces the boundary to express "could not read" as `nil` — a value that
carries no reason. `IncomingImportFile.init?(openedAt:)`
(BringHistoryView.swift:480-485) erases the difference between unreadable and empty
before any view exists, and the call site `if let` at CaelynApp.swift:43 has nothing
left to render. This is not a forgotten `else`: there is no payload to branch on. The
flow itself already knows how to explain exactly these cases (BringHistoryModel.read
reports "That file is empty." / "Caelyn couldn't read that file.",
BringHistoryModel.swift:100-119) and a picked file reaches a visible `.failed` state
via model.readFile — the doc comment at :478-479 claims parity that does not exist.
Separately, `Data(contentsOf:)` runs synchronously on the main thread.

**Fix.**

1. 1. Make the boundary total rather than failable: replace `init?(openedAt:)` with a
   non-failable initializer carrying an outcome, e.g. `enum Payload { case
   bytes(Data); case unreadable }`, and drop the `if let` at CaelynApp.swift:43 so the
   sheet ALWAYS presents.
2. 2. Do NOT substitute empty `Data` on a read failure — BringHistoryModel.read
   (:102-105) would then say "That file is empty." for a file that is merely un-
   downloaded, which is worse support copy than silence. Route `.unreadable` to the
   message that already exists for it in readFile ("Caelyn couldn't open that file.
   Try choosing it again…").
3. 3. Move the read off the main thread: perform the `Data(contentsOf:)` in a
   detached/background task and present the sheet in a loading state until it
   completes.
4. 4. Handle the iCloud-not-downloaded case explicitly with
   `startDownloadingUbiquitousItem` plus a "downloading" state, rather than treating
   it as unreadable.
5. 5. Why permanent: the type stops being able to represent "failed with no reason",
   so every future boundary caller is forced to render something.

*Files:* `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/Import/BringHistoryView.swift`, `Caelyn/Views/Import/BringHistoryModel.swift`

*Tests:* BringHistoryFlowTests gains "an empty incoming file reaches the failed state" and "an
unreadable incoming file reaches the failed state with the open-failure message". The
probe below demonstrates today's silent drop.

#### MC-1 — 43 Home mood check-in

She taps the daily check-in notification, Caelyn opens on Home — and the thing it
reminded her about is far below the fold with nothing scrolling to it. By the time she
could find it, the highlight has already finished. The retention loop is effectively
'open the app'.

**Root cause.** Two mechanisms. (1) The notification routing contract maps category to tab only
(MainTabView.swift:131-132): dailyCheckIn sets highlightedCategory = .dailyCheckIn and
the tab to .home, and there is no category-to-anchor mapping, so nothing moves Home's
ScrollView — HomeView.swift:144 has no ScrollViewReader. HomeMoodCheckIn is the ~15th
child of Home's VStack (HomeView.swift:144-260, card at :239-242), off-screen on every
iPhone. (2) Home's VStack is eager, not lazy, so the off-screen card still runs
onAppear (HomeMoodCheckIn.swift:75-77) and sets pulseFlag the moment Home is built;
the .repeatCount(3) x 0.6s animation (:72) finishes at ~1.8s while invisible, and
onChange(of: isHighlighted) at :78-80 waits for a false-to-true edge that never
arrives. So even a user who scrolled there inside the 2.5s window would find a
finished, static ring.

**Fix.**

1. 1. Wrap Home's ScrollView (HomeView.swift:144) in a ScrollViewReader and put
   `.id(HomeAnchor.moodCheckIn)` on the mood card.
2. 2. Add a category-to-anchor map read from
   @Environment(\.highlightedNotificationCategory), and scrollTo the anchor when the
   category arrives.
3. 3. Re-arm the pulse explicitly AFTER the scroll completes rather than relying on
   onAppear — change HomeMoodCheckIn.swift:75-80 so the animation is driven by an
   explicit trigger, since onAppear burns it off-screen.
4. 4. Rebase the 2.5s clear in MainTabView.swift:149-152 to start counting after the
   scroll completes, or let the card clear it once it is genuinely on screen. A wall
   clock started at tap time will keep expiring before she sees anything.
5. 5. Apply the same anchor mechanism to the other notification categories so the next
   one added does not reproduce this.

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeMoodCheckIn.swift`, `Caelyn/Views/MainTabView.swift`

*Tests:* No existing test. Add a UI test: launch with a seeded daily-check-in deep-link
argument and assert the 'Mood options' element is hittable within 1 s.

#### MC-2 — 43 Home mood check-in / Home write paths

She taps a mood on the Home card and it does not seem to stick — Home shows one thing,
the Log tab another — because the app can quietly create a second entry for the same
day. And tapping to remove today's period from Home can silently do nothing at all.

**Root cause.** Uniqueness-for-today is enforced by a funnel (CycleStore.entry(for:in:),
CycleStore.swift:61-80, fetch-by-dayKey or create) introduced in 7450e05 alongside the
removal of .unique for CloudKit mirroring — but Home's write paths were never routed
onto it. logMood (HomeView.swift:777-786), logPeriodToday (:739-763) and
movePeriodStart (:699-712) each resolve today from the @Query snapshot (`entries.first
{ $0.dayKey == … }`) and insert a new CycleEntry directly when absent. DailyLogForm
was explicitly moved off that pattern because 'resolving the day from the @Query array
… is a read of a snapshot that is only as fresh as the last render'
(DailyLogForm.swift:999-1006). Notably movePeriodStart WAS revisited after the funnel
existed — a665abb rewrote :706 to match on dayKey — and still left the snapshot read,
which is why a per-site reminder is not a fix.

**Fix.**

1. 1. Add `CycleStore.entryIfExists(for:in:)` — a fetch-by-dayKey that never creates.
   It is load-bearing, not optional polish: the toggle-off branches need a real read.
2. 2. Route logMood (HomeView.swift:777-786) and logPeriodToday's create branch
   (:739-763) and movePeriodStart (:699-712) through CycleStore.entry(for:in:).
3. 3. Fix the fourth offender the finding did not list: removePeriodLog
   (HomeView.swift:718-726) resolves today the same way at :721. It cannot duplicate,
   but on a stale snapshot it silently no-ops while Haptics.selection() fires and
   saveOrLog() runs — the exact 'delete doesn't delete' shape 1fa4408 fixed in
   DailyLogForm. Route it through entryIfExists and make the no-match case explicit.
4. 4. Use entryIfExists for logPeriodToday's toggle-off branch (:741-752) and
   logMood's toggle (:780) so a toggle never creates a row.
5. 5. Add a comment at CycleStore.entry(for:in:) naming it the only sanctioned way to
   resolve today's row, and add a source-scan test that fails on any
   `modelContext.insert(CycleEntry(` outside CycleStore.
6. 6. Verify the 1fa4408 draft-seed fix still holds wherever Home and the form now
   share the same row.

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* Add a CycleStore test proving the bypass creates 2 rows and the funnel 1 (probe).
HomeView is untestable in unit tests; the fix moves the behaviour into the tested
service. Add a removePeriodLog-equivalent service test asserting a missing row is
reported, not silently ignored.

#### PE-05, REM-19 — PatternEngine.cycleDay(for:in:) / CycleAnalytics.daysLogged / bbtSeries / painSeries / InsightsView.bbtSeries / NotificationService.scheduleNoteOneShot id

After she travels, or when an entry arrives from her other device, two of Caelyn's
pattern detectors can place the same day in a different cycle phase than the rest of
the app does — one says ovulation, the other says follicular. The regression test
added for the timezone fix reports everything clean, because it only looks for one
exact phrase.

**Root cause.** PRIMARY: PatternEngine.cycleDay(for:in:) (PatternEngine.swift:437-441) compares a
value in instant space — calendar.startOfDay(for: entry.date) — against Cycle.start
values built in dayKey space by PredictionEngine.swift:61 (CivilDay.localDate(for:
$0.dayKey, calendar:)). The two spaces coincide only while the reading calendar equals
the writing calendar, so any cross-timezone read puts the entry on the wrong cycle
day. Call sites: PatternEngine.swift:131 (phaseSymptomCorrelation) and :222
(energyCurve), both verified. SECONDARY: the commit 9776951 audit test matches only
the literal strings `startOfDay(for: entry.date)` and `startOfDay(for: $0.date)`, so a
helper whose parameter is named `date` passes while doing exactly what the audit
forbids — which is also why CycleAnalytics.daysLogged (:117), bbtSeries/painSeries and
InsightsView.bbtSeries (:34-36) and the note-reminder identifier
(NotificationService.swift:373 → dateSuffix(for: entryDay), :427-431) all still key
off the raw instant. Exposure: a CloudKit entry from another timezone carries that
device's midnight in `date` until dedupeSameDay normalises it.

**Fix.**

1. 1. Change the signature to `cycleDay(for entry: CycleEntry, in cycles: [Cycle],
   calendar: Calendar)` and compute `CivilDay.localDate(for: entry.dayKey, calendar:
   calendar)` inside. The helper can then no longer be handed a bare instant, and both
   sides of the `day >= cycle.start` comparison come from CivilDay.localDate — the
   invariant that was actually broken. Update PatternEngine.swift:131 and :222.
2. 2. Fix the stale calendar as its own change: delete `static let calendar`
   (PatternEngine.swift:66) and thread the calendar from CycleModel through
   insights(from:cycle:profile:) into every detector, so the engine and the model
   always agree on the zone.
3. 3. Key the analytics readers to dayKey too: CycleAnalytics.daysLogged (:117),
   bbtSeries, painSeries, InsightsView.bbtSeries (:34-36) — chart points should be
   CivilDay.localDate(for: entry.dayKey).
4. 4. NotificationService.scheduleNoteOneShot: `let id =
   "\(Category.noteReminder.rawValue).\(entry.dayKey)"`, passing dayKey instead of
   entryDay (NotificationService.swift:373, :383). No collision risk either way; this
   removes the last place where an identifier is derived through the current zone.
   Old-format pending ids are still removed by prefix in cancelAll.
5. 5. Broaden the 9776951 audit test from two literal strings to a pattern: flag any
   `startOfDay(for: <ident>.date)` or `\.date` comparison inside Services/ and
   Views/Insights/, with an explicit allowlist for the Export and HealthKit formatters
   that legitimately format the instant.

*Files:* `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/PredictionEngine.swift`

*Tests:* CivilDayTests.testNoEntryLookupInfersTheDayFromItsInstant gains the broadened pattern
and the allowlist; it must still pass for Export/HealthKit formatters. Add a detector-
level test: an entry written at UTC+13 midnight is assigned the same cycle day when
read under UTC-7.

#### PE-07 — PatternEngine (all 'best' selections) / PredictionEngine.mostFrequentSymptom / CycleAnalytics.mostCommonEarlyPeriodSymptom / CycleHistoryRow.topSymptom

With a tie in her data — two symptoms logged the same number of times, which is common
early on — Caelyn names one of them today and the other tomorrow, for no reason. An
insight she swiped away comes back under a different title, and the PDF she exports
can name a different symptom than the screen she is looking at.

**Root cause.** Selection among equal-scoring candidates is delegated to Dictionary iteration order,
which Swift randomises per process via the seeded Hasher. Every 'best' comparison is
strict — `phaseCounts.max(by: { $0.value < $1.value })` and the `top.value >
best!.count` incumbent check (PatternEngine.swift:142, :145, verified), the energy max
AND min (:228-235), :291-293, :329-340, PredictionEngine.swift:385-393,
CycleAnalytics.swift:149, CycleHistorySection.swift:57-63 — so ties resolve to
whichever element the hash table yielded first. The dismissal contract then amplifies
it: PatternInsight.stableKey is `category|title` (PatternEngine.swift:59), derived
from the rendered title, so a nondeterministic selection produces a nondeterministic
identity and the persisted dismissal at PatternInsightsSection.swift:11 stops
matching.

**Fix.**

1. 1. Add one `argmax` helper imposing a total order — sort candidates by (score
   descending, key.rawValue ascending) — and apply it at all eight selection sites
   listed in the root cause. For the energy MIN, apply the mirrored total order (score
   ascending, rawValue ascending), otherwise the 'lowest' phase still flips.
2. 2. At PatternEngine.swift:291-293, convert the Dictionary.filter result to an Array
   before selecting — Dictionary.filter returns a Dictionary and keeps the
   instability.
3. 3. At PatternEngine.swift:329-340, add rawValue as a THIRD sort key after
   cycleCount and sd: identically co-logged symptoms tie on both of the first two.
4. 4. Make the final `results.sorted { $0.confidence > $1.confidence }` total too —
   add category.rawValue then title as tiebreakers — so the order of equal-confidence
   cards (e.g. the 0.55 condition cards) is stable across launches.
5. 5. Consider decoupling stableKey from the rendered title (category|symptom
   rawValue) so copy edits do not resurrect dismissed cards either; keep a migration
   path for already-stored keys.

*Files:* `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Views/Insights/CycleHistorySection.swift`, `Caelyn/Views/Insights/PatternInsightsSection.swift`

*Tests:* New: an exact two-way tie yields the rawValue-first symptom; build the same history
twice with the entries shuffled and assert identical insight titles and order.

#### PE-09, PE-10 — InsightsView.cycle / patternInsights / YearViewSection / MiniMonthView.dotColor / CycleHistorySection

Two problems from one habit. The Insights tab gets visibly slow and drains battery for
the users with the most history — the exact people Pro is sold to. And the Year in
Review mini-calendars paint her fertile week, PMS block and predicted period from
textbook defaults, so they disagree with the Calendar tab and with the 'What Caelyn
learned about you' numbers printed directly above them.

**Root cause.** Derived state is re-derived per read and per sub-view instead of computed once and
passed down. (a) InsightsView.cycle (InsightsView.swift:13-15, verified) and
patternInsights (:20-22) are computed properties, and ~16-23 forwarding reads in
body/loadedContent/summaryFacts each re-run CycleModel.make
(CyclePrediction.swift:209-248, measured at 8.4 ms on 1740 entries in 9776951) and,
three times, the whole PatternEngine.insights — the a1ca071 stash was applied to
HomeView only. (b) Sub-views derive their own inputs: YearViewSection.swift:34 builds
a SECOND CycleModel; MiniMonthView.entryMap (:89-97) is rebuilt on every read; each
CycleHistoryRow filters all entries (:49-55) giving O(cycles × entries)
CivilDay.localDate calls. (c) The correctness half: MiniMonthView's initialiser
(YearViewSection.swift:68-75, verified) accepts profile + nextPeriodStart only, so
dotColor (:143-152, verified) has no choice but to re-derive each window from
PredictionEngine's defaults — `profile?.averagePeriodLength ?? 5`, pmsWindow's default
5 days, fertileWindow's default luteal 14 — while CalendarMath.dayState uses
cycle.predictedPeriodWindow / cycle.pmsWindow / cycle.fertileWindow built from the
LEARNED pmsDaysBefore and lutealLength (CyclePrediction.swift:197-205, :295-321),
which are lazy computed properties deliberately not materialised in make().

**Fix.**

1. 1. Mirror a1ca071 exactly in InsightsView: a private non-observable final class
   `Derived` held in @State carrying `model: CycleModel?` and `insights:
   [PatternInsight]?`, written once at the top of body (as HomeView.swift:142 does),
   with `cycle` and `patternInsights` reading the stash and falling back to a
   recompute. One derivation per render instead of one per read.
2. 2. Delete the second CycleModel.make at YearViewSection.swift:34 and pass
   InsightsView's stashed `cycle` into YearViewSection and through to MiniMonthView.
3. 3. Extract the marker precedence out of CalendarMath.dayState
   (CalendarMath.swift:131-143) into `CalendarMath.futureMarker(for: day, cycle:
   cycle) -> DayMarker`, have dayState delegate to it, and replace
   YearViewSection.swift:143-152 with a call to it mapped to dot colours. The mini-
   month then owns no prediction parameter at all — it can only render ranges the
   single derivation produced.
4. 4. Build the dayKey→entry map ONCE in the parent and pass it as a `let` to
   MiniMonthView (deleting the per-read entryMap at :89-97), and precompute each
   CycleHistoryRow's entries in the parent rather than filtering all entries per row.
5. 5. Check HomeView.guidePersonal, which also re-runs the pattern engine on each Home
   render, and have it read the Home stash.

*Files:* `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Views/Insights/YearViewSection.swift`, `Caelyn/Views/Insights/CycleHistorySection.swift`, `Caelyn/Views/Calendar/CalendarMath.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* New unit test on the extracted futureMarker: with learned luteal 12 and learned PMS 3,
a day inside cycle.pmsWindow but outside the default 5-day window must be PMS-marked,
and the Calendar and Year view must agree for the same day. Add the XCTClockMetric
probe below with a budget; no behavioural tests change.

#### PG-05 — Home hero card — teaching-line loader (.task(id:) + CycleSummaryService.dailyTeaching)

Right after she logs something that moves her into a new phase — or at midnight when
the day rolls over — the big card on Home can show the OLD phase's teaching sentence
under the NEW phase's badge for up to a second, and the "thinking" indicator for the
new line disappears early. The card briefly teaches her the wrong thing on the screen
she looks at most.

**Root cause.** Two mechanisms compose. (a) Cancellation is not honoured: on an id change SwiftUI
cancels task A and starts task B, but A's `try? await Task.sleep` swallows the
CancellationError (HomeHeroCard.swift:124) and neither await (:124, :125) is followed
by a `Task.isCancelled` guard, so A runs on and executes `personalLine = resolved;
isThinking = false` (:126-127) — clobbering B's state.
`CycleSummaryService.dailyTeaching` (CycleSummaryService.swift:78-91) is cancellation-
blind too: its own `try? await rephrase` (:84) swallows cancellation and falls through
to `return base` (:90), so even a cancelled call hands back a complete string instead
of nil. (b) What makes the stale write wrong rather than merely redundant is that A
captured the OLD phase's facts while `personalLine`/`isThinking` are shared view state
— so A's string and B's badge come from different moments. The comment at
HomeHeroCard.swift:110-112 asserts this cannot happen.

**Fix.**

1. Extract the loader into a testable function:
   `HeroLineLoader.load(facts:thinkingDelay:) async -> String?`. The view writes state
   only for a non-nil return.
2. Guard at EVERY resumption point, not only the sleep: `do { try await
   Task.sleep(...) } catch { return nil }`, then `let line = await line`, then `guard
   !Task.isCancelled else { return nil }` before returning. Without the guard after
   the awaited line, the model-rephrase path — the only path where the bug is visible
   — still leaks.
3. Make `CycleSummaryService.dailyTeaching` cancellation-aware
   (CycleSummaryService.swift:84, :90), or every future caller re-inherits the
   swallow: let CancellationError propagate (or return nil) rather than falling
   through to `return base`.
4. Have the loader return the facts it was built from alongside the line, and have the
   view discard a result whose facts no longer match the current ones. That is the
   structural fix for mechanism (b): a result can no longer be applied to a different
   phase than it was computed for.
5. Delete or correct the comment at HomeHeroCard.swift:110-112, which currently
   documents the opposite of the behaviour.

*Files:* `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Services/CycleSummaryService.swift`

*Tests:* No existing test touches the loader. Add a unit test on HeroLineLoader: a cancelled
load returns nil; a load whose facts changed mid-flight is discarded; dailyTeaching
propagates cancellation instead of returning base.

#### PG-07 — Pattern insights — PatternEngine.insights consumed without the dismissed filter (HomeView.guidePersonal, ExportService)

An insight she explicitly dismissed — "Your mood often dips before your period" —
keeps coming back. It disappears from the Insights list, but it is still woven into
the Home teaching line every PMS day, still appears in the guide's "Today for you",
and still prints in the PDF she hands her doctor. The dismiss button looks broken, on
exactly the sentence some women most want to stop seeing.

**Root cause.** The dismissal filter lives in view state rather than at the producer.
`PatternEngine.insights(from:cycle:profile:)` is the single production point and has
no dismissal awareness; the `DismissedInsights` filter exists only inside
PatternInsightsSection (PatternInsightsSection.swift:8-20). There are three call sites
and two of them leak: HomeView.swift:72-73 takes the first insight matching the
current phase straight from the unfiltered list, and ExportService.swift:255-264 draws
`insights.prefix(6)` into the PDF's "Patterns Caelyn Noticed" section — also
unfiltered. Only the Insights list filters.

**Fix.**

1. Add the filter at the producer, with the dismissed set injectable so it is testable
   without writing real user defaults: `static func
   activeInsights(from:cycle:profile:dismissed: Set<String> = DismissedInsights.all())
   -> [PatternInsight]`, returning `insights(...).filter {
   !dismissed.contains($0.stableKey) }`.
2. Convert all three call sites: HomeView.swift:72 and ExportService.swift:255 switch
   to `activeInsights`; PatternInsightsSection drops its own local filter
   (InsightsView.swift:21 / PatternInsightsSection.swift:10-12) so there is exactly
   one place dismissal is applied.
3. Keep raw `insights(...)` private or clearly marked "unfiltered — tests only", so a
   fourth call site cannot reintroduce the leak by using the obvious-looking name.
4. For the PDF specifically, confirm the product intent: a dismissed insight should
   not appear in a document she hands a clinician. If any are to be kept, that must be
   an explicit opt-in, not the default.
5. No change to the stored format — this reads the existing `caelyn.dismissedInsights`
   UserDefaults key.

*Files:* `Caelyn/Services/PatternEngine.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Insights/PatternInsightsSection.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* New unit test: dismiss a stableKey and assert activeInsights excludes it, with the set
injected rather than written to UserDefaults. Add: the Home teaching line and the PDF
both omit a dismissed insight.

#### PG-08, PG-10, PG-23 — PhaseGuideView banner daysRange / PhaseGuide static copy; HomeHeroCard -> CycleRingView; WidgetCycleMath.phaseRaw

Caelyn tells her it has learned her own numbers, then shows her the textbook ones. On
the same card the badge says 'Ovulation window' while the ring's green arc sits three
days earlier; the guide banner says 'Luteal phase — Days 17-26' to someone on day 29
of a 35-day cycle; and the Home badge and the widget can name two different phases on
the same day.

**Root cause.** There is no single source of phase boundaries — four surfaces derive them
independently. (1) The classifier
PredictionEngine.phase(forCycleDay:periodLength:cycleLength:lutealLength:)
(PredictionEngine.swift:350-366) computes ovulation from the learned luteal but still
hardcodes `pmsStart = max(1, cycleLength - 4)` at :359, ignoring the learned
pmsDaysBefore that CycleModel already holds (CyclePrediction.swift:197-205). (2) The
banner copy is a compile-time table keyed only on the enum (PhaseGuide.guide(for:),
PhaseGuideView.swift:385-479) and PhaseGuideView.guide (:329) discards `personal` even
when present, so for any user whose cycleLength != 28, periodLength != 5 or
lutealLength != 14 the words and the badge disagree by construction. (3) CycleRingView
re-derives `ovulationDay = cycleLength - 14` and `pmsStart = cycleLength - 4`
(CycleRingView.swift:21-22) because HomeHeroCard's initializer has no parameter for
them (HomeHeroCard.swift:25-31); its arc-to-day mapping is also inconsistent with the
dot's — the dot places day d at (d-1)/L (:109) while phaseArc treats startDay/endDay
as raw fractions (:94-102), so the sage arc covers ov..ov+1 against a 3-day badge
window of ov-1..ov+1. (4) WidgetSnapshot carries no lutealLength/pmsDaysBefore
(WidgetDataStore.swift:40-50) so WidgetCycleMath hardcodes 14/13/-14/-5
(:137,:153,:179,:192), and WidgetSnapshot.recomputed(for:) is a TOTAL re-derivation
that unconditionally overwrites phaseRaw on every render (:103-113) — so even a
correctly learned phase written by the builder is thrown away on the next widget
refresh.

**Fix.**

1. 1. Add `pmsDaysBefore: Int = 5` to PredictionEngine.phase and replace the literal
   at PredictionEngine.swift:359 with `pmsStart = max(1, cycleLength - max(1,
   pmsDaysBefore) + 1)` — choosing the off-by-one deliberately, since today's -4 means
   a 5-day window. The defaulted parameter keeps PatternEngine.swift:132 and :223
   compiling unchanged.
2. 2. Expose the boundaries the classifier used: `PredictionEngine.phaseBoundaries(per
   iodLength:cycleLength:lutealLength:pmsDaysBefore:) -> (periodEnd: Int, ovulation:
   Int, pmsStart: Int)`, and have phase() itself call it so the two can never drift.
3. 3. Make PhaseGuide.guide(for:personal:) compute daysRange from those boundaries
   instead of the hardcoded strings at PhaseGuideView.swift:390,405,420,435,450, and
   stop discarding `personal` at :329. The PMS line must read from pmsDaysBefore so
   the banner cannot say '~5 days' while 'What Caelyn has learned' says 'about 8 days'
   (:282).
4. 4. Give CycleRingView explicit `ovulationDay` and `pmsStartDay` parameters;
   HomeHeroCard forwards the values that produced the badge, taken from the CycleModel
   HomeView already derived (HomeView.swift:141) rather than recomputed. Fix the index
   mapping at the same time: ovulation arc (ovulationDay - 2)...(ovulationDay + 1),
   PMS arc (pmsStartDay - 1)...cycleLength, period arc unchanged.
5. 5. Add `lutealLength: Int?` and `pmsDaysBefore: Int?` to WidgetSnapshot
   (WidgetDataStore.swift:40-50) as optionals with defaults 14/5, exactly as
   periodLength/fertilityStatusRaw were added, so a payload written by 1.3 build 15
   still decodes and no widget goes blank before the first app launch rewrites it.
   Populate them in WidgetSnapshotBuilder.build from cycle.lutealLength /
   cycle.pmsDaysBefore (both deliberately lazy), and have WidgetCycleMath.phaseRaw and
   fertilityStatus take them instead of the literals at :137,:153,:179,:192 so
   recomputed(for:) reproduces the same answer the app computed.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Views/Education/PhaseGuideView.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Components/CycleRingView.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/WidgetDataStore.swift`

*Tests:* New: guide(for: .luteal, personal: 35-day/5/14/5).daysRange == 'Days 23-30'. New:
PredictionEngine.phase with pmsDaysBefore 8 classifies day cycleLength-7 as .pms.
Extend CaelynTests.testWidgetCycleMathMatchesPredictionEngine (:671-676) to a learned-
luteal case, not just the default. ScreenshotTests.testStore1_Home will shift the arc
for seeded data — re-capture.

#### PG-14 — CycleSummaryService.rephrase / generate (dailyTeaching, summary)

On phones with Apple Intelligence, the sentence Caelyn writes on the home screen and
in the Pro summary comes from an on-device model, and the app accepts whatever it
returns as long as it is not blank. Nothing checks the day number is still right or
that it has not named a condition — the 'never diagnose' promise is a polite request
in a prompt. If the model is slow to load the first time, the home card can sit on
'Caelyn is reading your cycle' forever.

**Root cause.** Two mechanisms. (1) Acceptance-by-emptiness: CycleSummaryService has no acceptance
function at all. The only predicate on model output is `!text.trimmingCharacters(in:
.whitespacesAndNewlines).isEmpty` (CycleSummaryService.swift:32 for summary, :85 for
teaching), and `return response.content` (:57, :138) hands the raw string back. The
constraints live only inside the `instructions:` strings at :44-48 and :132-136 —
model-behaviour requests, not code. A repo-wide grep for a validator type returns
nothing. (2) No deadline: the generation await has no timeout, and HomeHeroCard
renders the thinking state while the task is outstanding (HomeHeroCard.swift:48-49,
113-128), so a slow first model load has no bound.

**Fix.**

1. 1. Put both gates inside CycleSummaryService, not in the view: a pure `static func
   accept(candidate:base:) -> Bool` plus a deadline race inside dailyTeaching and
   summary. This also covers the Insights card (InsightsView.swift:285, which likewise
   returns raw model text) and any future caller, and leaves
   HomeHeroCard.swift:113-128 untouched. Gating in the view would leave summary(for:)
   ungated.
2. 2. Implement accept() as a digit SUBSET check, not multiset equality: the
   candidate's digit tokens must all appear in the base. Equality is wrong for
   summary(for:), whose base is fallback(facts:) (:144-156) emitting avgCycle,
   daysUntilPeriod, variation and avgPeriod while a legitimate 2-3 sentence rephrase
   may use only some of them.
3. 3. Add a banned-term check to accept(): condition names, diagnosis verbs, dosage
   words, and imperative medical instruction — sharing the same term list as the
   static copy audit (see PG-15/PG-26/PG-16) so there is one vocabulary.
4. 4. Add a length/shape guard (max sentences, no questions, no second person
   imperative) so a rambling or off-format rephrase falls back silently.
5. 5. Race the generation against a deadline (2s for the hero teaching line, 5s for
   the Pro summary) and return fallback(facts:) on timeout, so the thinking state is
   always bounded.
6. 6. On any rejection, return the deterministic fallback and log the reason (privacy:
   .public category only, never the generated text) so rejection rates are observable
   without logging health content.

*Files:* `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Views/Insights/InsightsView.swift`

*Tests:* New guardrail tests, no model needed: accept() rejects an altered day number, rejects
a banned term, accepts a faithful rephrase using a digit subset; timeout path returns
the fallback string. testCycleSummaryFallbackProducesUsableText unchanged.

#### PG-15, PG-26, PG-16 — PhaseGuide static copy (.ovulation tips); IrregularCycleReason.note; GuideQuestions 'see-doctor' answer

Three hand-written lines break the app's own promises about how it talks. The
ovulation tips tell her to 'use protection from 5 days before ovulation', which
implies she is safe outside that window — contraceptive instruction the app elsewhere
refuses to give. The irregular-cycle banner names PCOS to a woman whose cycles average
36 days. And the one answer listing red flags — soaking through protection hourly,
bleeding between periods, months with no period — closes with 'None of these mean
something is wrong.'

**Root cause.** The health-voice rules exist only as conventions with no enforcement point over static
strings. The no-medical-advice rule is implemented as a runtime constraint on
GENERATED text — a prompt instruction at CycleSummaryService.swift:44-48 and provider-
forward deterministic answers (PhaseGuideView.swift:333) — while hand-written copy
reaches the screen through an entirely separate ungated path: PhaseGuide.guide(for:)
(:417-431) -> guide.tips -> tipsSection's unfiltered ForEach (:138-147), with no
disclaimer anywhere in the 483-line view and no test (grep -rln PhaseGuide
CaelynTests/ is empty). The never-name-a-condition rule is a doc comment on one type
(TypicalRanges.swift:3-6) enforced by hand inside that type's own Status construction,
with no reach over IrregularCycleReason.note, which is a hard-coded String on a model
enum in Caelyn/Models/ (CyclePrediction.swift:82-103) — outside the copy layer
entirely; the existing banned-term audits cover only HealthKit/import permission
wording. And GuideQuestions.QA (TypicalRanges.swift:109-113) carries only (id,
question, answer) with no severity tier, so every answer closes with a reassurance
clause by template and the escalation answer inherited it (:144-146) — the structure
makes the wrong tone the path of least resistance and leaves a reviewer or test no
field to key off.

**Fix.**

1. 1. Rewrite PhaseGuideView.swift:424 and :428 in the framing already shipping at
   InsightsView.swift:309: the fertile window is an estimate, not a contraceptive
   method — 'if you're avoiding pregnancy, use protection every time, or talk to a
   clinician about a method that suits you'. Remove the 'from 5 days before ovulation'
   instruction entirely.
2. 2. Rewrite IrregularCycleReason.longCycles (CyclePrediction.swift:93-94) in the
   TypicalRanges voice with no condition named: 'Your cycles have been running longer
   than 35 days. That's outside the common range — worth mentioning to a doctor if it
   continues.' Also revise .shortCycles (:95-96): it names no condition, but 'if this
   is within normal range for you' trades on the normal/abnormal framing
   TypicalRanges.swift:4 forbids — say 'common range'. Leave .skippedPeriods (:98) for
   this fix.
3. 3. Replace the closing sentence at TypicalRanges.swift:145 so the negation no
   longer cancels the list, keeping one urgency gradient: 'These don't always mean
   something is wrong — but each one is worth a conversation, and soaking through
   protection every hour is worth a same-day call.'
4. 4. Add a `tier` (reassurance | escalation) to GuideQuestions.QA
   (TypicalRanges.swift:109-113) so an escalation answer is distinguishable by type,
   and assert in test that no escalation answer contains a blanket-negation phrase.
5. 5. Add one copy-audit test that covers every user-facing health string, not one
   phrase: iterate CyclePhase.allCases -> PhaseGuide.guide(for:) asserting over
   whatIsHappening + howYouFeel + every tip + hormoneNote, plus
   IrregularCycleReason.allCases.note and every GuideQuestions answer, that no string
   contains a condition name (PCOS, endometriosis, fibroid, thyroid), an imperative
   contraceptive claim ('use protection', 'avoiding pregnancy', 'safe day', 'safe to',
   "can't get pregnant", 'instead of birth control'), a dosage word, or
   'abnormal'/'normal range'. This is the enforcement point the rules never had.
6. 6. Add the audit to the same test file as the existing voice assertion
   (CaelynTests.swift:1044) so the convention has one home, and note the rule in the
   header comment of PhaseGuide and IrregularCycleReason pointing at it.

*Files:* `Caelyn/Views/Education/PhaseGuideView.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/TypicalRanges.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* New copy-audit test over all phases, all irregular reasons and all guide answers (step
5). Extend CaelynTests.testGuideQuestionsPhaseFirstAndProviderForward (:1056) with the
escalation-tier assertions. S2 screenshot unaffected — tips are below the fold and
guide rows ship collapsed.

#### PRIV-11 — 11 App Lock

App Lock can be switched on and yet protecting nothing — on a phone with no passcode
and no PIN, or after she removes her PIN — and Settings shows the toggle as ON but
greyed out, so she can neither see that nothing is protected nor turn it off.

**Root cause.** One predicate, `BiometricService.canAuthenticate || PINService.isSet`, is evaluated
independently in two places with opposite meanings: AppLockGate.swift:83 reads it as
"give up and open" (a deliberate fail-open so a user is never permanently locked out),
SettingsView.swift:355 reads it as "this control cannot be changed". Neither
distinguishes "cannot enable" (lockEnabled false) from "enabled but unenforceable"
(lockEnabled true), and the disabled branch collapses the two — which is what both
renders the toggle stuck and makes the subtitle talk about enabling. Two further
mechanisms make the state reachable and sticky: intent is captured with no capability
check at the point of capture (onboarding writes lockEnabled = true with no guard),
and PINManageView's "Remove PIN" (PINViews.swift:256-260) has no guard either; and
ProfileStore.swift:52 merges lockEnabled with `||`, so the flag can sync onto a device
that cannot enforce it and can be resurrected after any local clear.

**Fix.**

1. 1. Introduce one named `LockStatus` value — `.off`, `.enforced(kind)`,
   `.enabledButUnenforceable` — computed from lockEnabled plus the capability
   predicate, and make it the single source of truth for AppLockGate.swift:79-87,
   SettingsView.swift:325-336/:355, SettingsRows.swift:108-116 and
   PINViews.swift:216-218. This is the same named predicate the auto-erase item needs;
   build it once and have both consume it.
2. 2. Do NOT auto-clear lockEnabled when the status is unenforceable and do not let
   the gate heal itself. With sync on, the weak device would clear a flag the strong
   device depends on, and ProfileStore.swift:52's `||` would resurrect it on the next
   merge — a flapping toggle. Clearing must require an explicit action on the device
   she is holding.
3. 3. In the `.enabledButUnenforceable` case, render the toggle ENABLED (so she can
   switch it off) and replace the subtitle with the true state: "App Lock is on but
   this iPhone has no Face ID or PIN set up, so nothing is being asked for. Set a PIN,
   or turn this off." Offer a direct "Set a PIN" action.
4. 4. Guard the write, not the screens: put the capability check at the point
   lockEnabled is set — onboarding and the Settings toggle — so the unenforceable
   state is not created silently in the first place.
5. 5. Add a confirmation to PINViews.swift's "Remove PIN" (:256-260) when removing the
   PIN would leave the status unenforceable: "Face ID isn't available on this iPhone.
   Removing your PIN turns App Lock off." — and have accepting it set lockEnabled =
   false as the explicit, consent-backed clear.

*Files:* `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/SettingsRows.swift`, `Caelyn/Views/Main/PINViews.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`

*Tests:* Add LockStatusTests covering the three cases and the onboarding write guard.
ProfileStoreTests line 76 ('App Lock was switched off by an empty second profile')
stays unchanged — the `||` merge is deliberately not altered by this item.

#### PRIV-18, PRIV2-14 — 11 App Lock PIN+biometrics (lockout and PIN storage)

The PIN is far easier to break than the privacy page implies. Someone with the phone
can keep guessing — five tries, wait sixty seconds, repeat forever, and moving the
device clock forward skips the wait entirely — so all 10,000 four-digit PINs can be
worked through in about a day and a half. Anyone who can read the app's Keychain (a
forensic tool, a jailbroken phone) recovers both the unlock PIN and the duress PIN in
under a second, and the stored item names literally say "primary" and "duress",
telling an attacker a duress PIN exists.

**Root cause.** The stored PIN record carries no work factor: PINService.hash is a single SHA-256 pass
over salt+pin (/Users/smile/Desktop/caelyn/Caelyn/Services/PINService.swift:72-76,
verified) and verify calls it exactly once per candidate (:60), so the cost of testing
a guess is a property of the record, not of the app. The only cost-raising mechanism
lives entirely outside that record — registerFailure writes caelyn.pin.failCount and
caelyn.pin.lockoutUntil into UserDefaults.standard (:80-101, verified) — so an offline
attacker reproduces hash from the salt (stored in the same Keychain service) and never
executes it. Online, registerFailure zeroes failCount at the moment it arms the
lockout (:84-85), so the only state outliving a lockout is the single lockoutUntil
epoch: there is no persisted cumulative-failure counter for a policy to escalate
against, and the deadline's only reference frame is Date.now (:55, :99-100). Finally,
kSecAttrAccount is set from literal strings "primary"/"duress"/"salt" (:15, used at
:118), so the item names themselves disclose the duress feature's existence.

**Fix.**

1. 1. Put a work factor in the record. Replace hash with PBKDF2-HMAC-SHA256 at a
   calibrated iteration count (target ~100 ms on the oldest supported device), and
   version the stored blob: a one-byte prefix, v1 = legacy bare SHA-256, v2 = PBKDF2.
2. 2. Migrate lazily — a stored SHA-256 hash cannot be converted without the
   plaintext, and rewriting blindly would make every existing PIN wrong.
   AppLockGate.showLockScreen only fails open when there is NO unlock method at all
   (:81-83), so a PIN that exists but never matches is a hard lockout with no recovery
   short of deleting the app. On verify: if the record is v1, check with the old
   algorithm; on a SUCCESSFUL match the plaintext is in hand, so re-derive with PBKDF2
   and rewrite as v2 in the same call. Do the same for the duress record on a duress
   match.
3. 3. Make the Keychain account names opaque. Derive them as a stable hash of a per-
   install secret plus a role string so the three items are indistinguishable, and
   migrate each one at the same moment its record is rewritten in step 2 (read old
   account, write new, delete old). Never ship a build in which the plaintext names
   and the opaque names both exist for the same role.
4. 4. Offer a 6-digit PIN. PINViews.swift:10 and :135-141 hard-code length 4; make the
   length a stored preference, default 4 for existing users, offered at setup. A
   6-digit space plus PBKDF2 is what makes the offline attack uneconomic.
5. 5. Add persisted cumulative-failure state so the online policy can escalate: keep a
   `cumulativeFailures` counter that is NOT zeroed when the lockout arms (today's :85
   does zero it), and derive the delay from it — 60 s, 5 min, 15 min, 1 h, capped.
6. 6. Make the deadline clock-tamper resistant: store BOTH a wall-clock deadline AND
   lockoutStart + ProcessInfo.systemUptime, and stay locked while EITHER says locked
   (uptime alone resets to 0 on reboot, so neither is sufficient). If `now <
   lockoutStart`, the clock was moved backward — treat that as tampering that holds
   the lockout rather than as a long wait.
7. 7. Correct the privacy copy at PrivacyTrustView.swift:48-50 ("only a salted hash of
   it is kept in this device's Keychain"), which a reader takes to mean the PIN is not
   recoverable. After step 1 the statement is defensible; before it, it is not.
8. 8. Keep the PIN-invariant predicates item (PRIV2-02/PRIV-10) landed FIRST, and make
   matchesPrimary/matchesDuress go through the same versioned derivation so they
   cannot drift from verify.

*Files:* `Caelyn/Services/PINService.swift`, `Caelyn/Views/Main/PINViews.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`

*Tests:* CaelynTests.testPINHashIsDeterministicAndSaltSensitive (CaelynTests.swift:984) calls
PINService.hash(_:salt:) directly and asserts count == 32 — it must be updated for the
new derivation and output shape. Add PINLockoutPolicyTests with an injected `now`
covering escalation, reboot (uptime reset), clock-forward and clock-backward. Add a
v1→v2 lazy-migration test: write a v1 record, verify with the correct PIN, assert the
stored record is now v2 and still verifies.

#### PRIV2-09 — 10 Paranoid Mode page

"Paranoid Mode — Maximum privacy in one tap" stops Caelyn sending anything new, but
removes nothing that already left: every period and symptom sample Caelyn wrote is
still in Apple Health with Caelyn named as the source and readable by other apps she
has granted access, and her private iCloud copy is still in iCloud. The post-tap
notice makes it worse by saying "Nothing is lost either way; it is all here on this
iPhone."

**Root cause.** enableParanoidMode is a pure preference-flag mutator
(/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/SettingsView.swift:525-558,
verified in full): it assigns syncEnabledKey=false, healthKitConnected=false, the five
hk read/write flags false, hidePreview/privateNotifications true, five reminder flags
false, then forgetSyncState(), saveOrLog() and cancelAll(). It never calls
HealthKitService.deleteAllOwnSamples() — whose only caller in the whole app is
SecureWipeService.swift:92 — and never writes a cloud deletion marker, so
CloudDataDeletion.cloudCopyMayExistNow stays true. Second mechanism: the confirmation
and the notice are keyed to the wrong state. The relaunch notice is gated on
`syncWasActiveThisLaunch = Persistence.isSyncActive` (:534, :554-557), so a woman
whose sync preference is on but whose container did not open mirrored this launch is
told nothing at all, and the one person who most needs to hear about her iCloud copy —
sync off, copy still there — is told "it is all here on this iPhone".

**Fix.**

1. 1. Build the confirmation body from live state rather than a literal. Compose a
   pure `ParanoidModeSummary(healthConnected:cloudCopyMayExist:syncActive:)` returning
   the lines, testable the way deleteAllOffer is, and render it at
   SettingsView.swift:426-430.
2. 2. Derive the iCloud clause from `CloudDataDeletion.cloudCopyMayExistNow`, NOT from
   Persistence.isSyncActive, so the sync-off-but-copy-exists case is covered. When it
   is true, name the action that actually retracts the copy, reusing AccountView's
   existing wording verbatim: "Delete my iCloud copy" (AccountView.swift:315).
3. 3. Add a Health clause driven by whether Caelyn has ever written samples (a cheap
   count query, or at minimum profile.healthKitConnected), saying plainly that turning
   sharing off stops new samples but leaves the ones already in Health, and offering
   "Remove Caelyn's data from Apple Health" as a second, separately confirmed step
   that calls HealthKitService.deleteAllOwnSamples().
4. 4. Do NOT make either retraction automatic inside the one tap. Both are destructive
   and irreversible in other apps' data; Paranoid Mode's contract is "reversible —
   each switch can be turned back on individually" (the comment at :522-523). Offer
   them as explicit follow-on steps the summary names.
5. 5. Rewrite the "Nothing is lost either way; it is all here on this iPhone" sentence
   (:555-557) — it is the specific line that is false whenever a Health or iCloud copy
   survives.
6. 6. Fix the notice's gate: `Persistence.isSyncEnabled || Persistence.isSyncActive`
   so the preference-on-but-not-mirrored case is still told something (this is where
   the P3 copy item PRIV-20's second half lands).

*Files:* `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Services/HealthKitService.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* None existing. Add ParanoidModeSummary unit tests over the 2×2×2 of (healthConnected,
cloudCopyMayExist, syncActive), asserting the iCloud clause appears whenever
cloudCopyMayExist is true regardless of syncActive, and that no variant contains the
phrase "it is all here on this iPhone" while either copy may survive.

#### PRIV2-10 — 12 Hide app preview

"People nearby won't see Caelyn when you switch apps" — but the screen the privacy
shield shows in the app switcher has the word "Caelyn" as its largest element, in
36-point type, next to a padlock. For someone hiding the app's existence from a
partner or parent, that card is more legible at a glance than the Home-screen icon.

**Root cause.** Three masking surfaces each hardcode the app name — CaelynPrivacyShield
(/Users/smile/Desktop/caelyn/Caelyn/Views/Main/AppPreviewMask.swift:41-48,
`Text("Caelyn").font(.system(size: 36, weight: .semibold, design: .rounded))`),
LockScreen (AppLockGate.swift:178-180, "Caelyn is locked", which supersedes the shield
whenever App Lock is on because :86 makes the lock screen cover every non-active
phase), and the masked widget bodies (CaelynWidget/WidgetViews.swift:320, 332-340) —
while two hardcoded strings promise concealment (SettingsView.swift:370,
PrivacyTrustView.swift:68-71), with no type, code path or test connecting promise to
rendering: CaelynPrivacyShield has one call site and zero test references. The deeper
mechanism is that the promise is unsatisfiable in principle: iOS supplies the app's
name and icon beneath every task-switcher card, so no app can conceal its own
existence there, and a code fix to the shield can never make the current wording true.

**Fix.**

1. 1. Correct the copy to the guarantee the platform permits. SettingsView.swift:370 →
   "Blanks Caelyn's screen in the app switcher, so your cycle isn't visible at a
   glance." PrivacyTrustView.swift:68-71 → retitle from "Hidden in the task switcher"
   (which claims the app is hidden) to "Blank in the task switcher", and qualify the
   body to contents rather than identity.
2. 2. Add the honest companion sentence pointing at what actually conceals the app's
   existence on iOS — removing it from the Home screen and from Spotlight/Siri &
   Search — rather than a claim the shield cannot keep. This matters for the audience
   the feature names.
3. 3. Remove the app name from the shield itself (AppPreviewMask.swift:41-48): keep
   the padlock or a neutral mark, drop the 36pt Text("Caelyn"). It no longer adds
   information the OS does not already supply, and it is the most legible thing on the
   card.
4. 4. Decide the same question for the lock screen (AppLockGate.swift:179): "Caelyn is
   locked" → "Locked" removes the second, more frequently seen disclosure, since the
   lock screen supersedes the shield whenever App Lock is on.
5. 5. Apply the same to the masked widget bodies (CaelynWidget/WidgetViews.swift:320,
   332-340), which have the identical hardcoded-name shape.
6. 6. Permanent only if the promise and the rendering are pinned together: add the
   test in the tests field, so a future redesign that reintroduces the name fails.

*Files:* `Caelyn/Views/Main/AppPreviewMask.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`, `CaelynWidget/WidgetViews.swift`

*Tests:* No existing test reads the shield's content. Add an accessibility-label assertion in
CaelynUITests that the shield's view hierarchy contains no element whose label
contains "Caelyn", and a string test in the spirit of
testPrivateNotificationsNeverLeakHealthTerms asserting neither privacy string claims
the app itself is hidden.

#### PRIV2-13 — 10 Paranoid Mode page (privacy & trust page)

On the privacy page, the "What if I lose my phone?" answer is the only one that never
mentions iCloud — it says her data is locked behind her passcode and Caelyn's own
lock, full stop. If sync is on there is a second copy in her iCloud reachable from any
other device signed into her Apple Account, and this is the exact screen she came to
for that answer.

**Root cause.** Commit 6eb37a8 ("Stop promising more privacy than 1.3 can keep") audited this screen
against a DENYLIST of five specific absolute phrases known to be falsified by 1.3 —
visible verbatim in the regression test it shipped,
CaelynTests/DeletionModelTests.swift:858-862 ("no copy of it anywhere else", "exactly
one place", "makes no network calls of its own", "stays only on your device", plus
"never asks for your… name"). Every string containing one of those phrases was made
conditional on hasCloudCopy; every string that was merely INCOMPLETE without
mentioning iCloud, but contained none of them, was left alone. The lost-phone answer
(/Users/smile/Desktop/caelyn/Caelyn/Views/Settings/PrivacyTrustView.swift:112-115) is
such a string, so it stayed flat while the promise cards above it (:24-93) and the
court-order answer (:107-110) visibly change wording with sync — teaching the reader
that flat means "iCloud makes no difference here". hasCloudCopy is already in scope
for every answer (:9); nothing needed plumbing, only noticing.

**Fix.**

1. 1. Replace the phrase-denylist approach with state-derivation: walk the entire
   `threatModel` array (PrivacyTrustView.swift:95-130) and make every answer whose
   truth depends on sync a function of `hasCloudCopy` (:9), which is already available
   to all of them.
2. 2. Rewrite the lost-phone answer's hasCloudCopy == true branch to name the second
   copy and where to retract it, matching the precedent at SettingsView.swift:198:
   Account & iCloud → "Delete my iCloud copy".
3. 3. In the same branch, correct the auto-erase clause:
   AutoSweepService.checkAndSweep calls wipeEverything with the default .thisDevice
   scope on a possibly-mirrored store (AutoSweepService.swift:22-29 +
   SecureWipeService.swift:26-50), so an auto-erase on the lost phone propagates the
   deletions to her iCloud and her other devices. Say so, or the new copy will be
   honest about the copy and still wrong about the erase.
4. 4. Audit the remaining three answers against the same question ("is this sentence
   still true with a second copy in iCloud?") rather than against the five phrases,
   and branch any that fail.
5. 5. Permanent because the test in the tests field inverts the denylist: instead of
   forbidding five known phrases, it asserts that with hasCloudCopy true, no answer
   omits iCloud while making an absolute containment claim — which catches the next
   sentence written, not just the five already written.

*Files:* `Caelyn/Views/Settings/PrivacyTrustView.swift`, `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* Extend the existing regression test at CaelynTests/DeletionModelTests.swift:858-862:
with hasCloudCopy == true, assert every threatModel answer that uses an absolute
containment word ("only", "exactly one", "anywhere else", "stays on") also contains
"iCloud". Add a direct assertion that the lost-phone answer differs between
hasCloudCopy true and false.

#### PRO-05 — Paywall + restore + lapse (paywall copy)

A user who opens the paywall offline, reconnects and taps 'Try again' — or who opens
it in the first seconds after launch — is shown a paywall with no mention of the free
trial she is actually entitled to, and a renewal disclosure that omits it.

**Root cause.** Two mechanisms. (1) Trial eligibility is derived state cached in view-local @State
(PaywallView.swift:12-13) by a one-shot .task keyed to view appearance (:55-66) rather
than to purchase.products, the value it derives from. The rest of the view reads
purchase through @Observable (productsAreReady, :349), so the product-dependent layout
refreshes when products arrive while the product-dependent labels do not — the view is
half-reactive and the stale half carries the 3.1.2 disclosure (badge :212, sublabel
:224, CTA :410-411, disclosure :490-494). (2) PurchaseService.loadProducts()'s re-
entrancy guard drops a concurrent request rather than awaiting the in-flight one —
`guard !isLoadingProducts else { return }` (PurchaseService.swift:100-104, verified) —
so the paywall's own load can be a silent no-op while CaelynApp's launch-time call
(CaelynApp.swift:53) is still running, and the catch path leaves products empty
without retrying.

**Fix.**

1. 1. Preferred: compute `trialLabels: [ProductID: String]` inside
   PurchaseService.loadProducts() immediately after `products` is set, and have the
   paywall read that observable state. Eligibility then changes whenever the product
   set does, for every caller.
2. 2. Minimal alternative: change PaywallView's .task at :55 to `.task(id:
   purchase.products.map(\.id))` so labels recompute on every product-set change.
3. 3. Either way the 'Try again' handler (:382-384) needs no change: recomputation
   follows the product set, not the button.
4. 4. Optionally make loadProducts() await an in-flight load instead of dropping the
   request (PurchaseService.swift:100-104), so a second caller gets the result rather
   than nothing.
5. 5. Extract a pure `tierCopy(products:trials:)` helper so the
   badge/sublabel/CTA/disclosure derivation is unit-testable.
6. 6. Prioritise this alongside or before any change that adds an introductory offer
   to Yearly — that is what makes it user-visible on the default-selected tier.

*Files:* `Caelyn/Views/Premium/PaywallView.swift`, `Caelyn/Services/PurchaseService.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* None existing. Add a test that the label derivation re-runs when products change, via
the extracted pure tierCopy helper.

#### PRO-06 — Paywall + restore + lapse (restore)

A real subscriber setting up a new phone taps 'Restore Purchases' in Settings with a
flaky connection and is told 'No active Caelyn Pro subscription was found on this
Apple ID' — a false statement about a purchase she made.

**Root cause.** Outcome interpretation lives in the views, and the two copies diverged:
SettingsView.runRestore() (SettingsView.swift:305-310) sets showRestoreNotice = true
unconditionally and the alert at :132-138 keys its message solely on purchase.isPro,
while PaywallView.runRestore() (:498-507) correctly branches on purchase.lastError
first. Deeper: lastError is a single piece of shared, mutable, reset-on-entry service
state (PurchaseService.swift:30, cleared at :104) that both views poll after an await,
so it cannot reliably carry 'what did THIS restore do' for any caller — a concurrent
loadProducts() can clear or overwrite it across the suspension, and @MainActor
isolation does not prevent that.

**Fix.**

1. 1. Change the signature to `func restore() async -> RestoreOutcome` with cases
   restored, nothingToRestore, cancelled, failed(String). Compute inside
   PurchaseService: catch StoreKitError.userCancelled -> .cancelled; any other catch
   -> .failed(message); on success, await refreshPurchasedProducts() then
   purchasedProductIDs.isEmpty ? .nothingToRestore : .restored.
2. 2. Stop writing lastError from restore() (PurchaseService.swift:139-150). That
   removes the shared-state race with loadProducts() (:104, :111) rather than papering
   over it.
3. 3. Rewrite both call sites to switch on the returned value:
   SettingsView.swift:305-310 / :132-138 and PaywallView.swift:498-507. Neither view
   may read lastError for restore any more.
4. 4. Write the three user-facing strings once (restored / nothing to restore / could
   not reach the App Store) in a single place both views use, so a future third caller
   cannot diverge again.
5. 5. Keep .cancelled silent — no alert.

*Files:* `Caelyn/Services/PurchaseService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Premium/PaywallView.swift`

*Tests:* Add a unit test for the pure outcome mapping (error x purchasedProductIDs ->
RestoreOutcome), including the network-failure case that today reports 'no
subscription found'.

#### PRO-08 — 32 PDF export

If a subscription expires while the Export sheet is open, the PDF option re-draws as
locked but the button still says 'Generate PDF' and still produces one — and any
future screen that sets the export format would bypass the Pro check entirely.

**Root cause.** Two mechanisms compose. (1) `format` is unvalidated authoritative state:
ExportView.swift:11 declares `@State private var format: ExportFormat = .csv` and
ExportView.swift:136 (inside formatChip's action) is the file's only writer, so the
entitlement is validated once at tap time (:131, `let locked = (option == .pdf) &&
!purchase.isPro`) and the result of that validation is then persisted in `format` with
nothing reconciling it against the entitlement it was validated under. (2) The
enforcement point is an event handler, not a derived value: generate() (:255-283)
switches on `format` with no isPro check, and a previously generated PDF URL stays
shareable. CaelynApp.swift:72-75's foreground loadProducts() can flip isPro while the
sheet is up (PurchaseService.swift:107-109, 154-162).

**Fix.**

1. 1. Add `private var effectiveFormat: ExportFormat { purchase.isPro ? format : .csv
   }` and use it at ExportView.swift:166/168/173 (chip highlight), :205 (ShareLink
   title), :217 (button title) and :266 (the switch in generate()). This is the
   permanent half: the gate becomes a derived value every consumer reads, so a future
   writer of `format` cannot produce a Pro artefact.
2. 2. Keep the chip-tap paywall at :131-138 as the discovery affordance — it is good
   UX, just not the enforcement.
3. 3. Add `.onChange(of: purchase.isPro)` to reset `format` to .csv and call
   resetGeneration() when it becomes false, so an already-generated PDF URL stops
   being shareable mid-flow.
4. 4. Extract `effectiveFormat(selected:isPro:)` as a pure free function so the gate
   is unit-testable without the view.

*Files:* `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/PurchaseService.swift`

*Tests:* None existing. Add a unit test for the pure effectiveFormat(selected:isPro:) covering
(.pdf, false) -> .csv and (.pdf, true) -> .pdf.

#### REM-05 — AppDelegate.didReceive → NotificationRouter → MainTabView.onChange(of: pendingCategory)

Her phone has been closed all morning. She taps the 'Medication' reminder on the lock
screen expecting to land on the log. Caelyn opens on Home instead, with nothing
highlighted — and tapping the same reminder again does nothing either.

**Root cause.** Edge-triggered .onChange observation of a level-held value, with two parts. (1)
RootView's deliberate 120 ms Task.sleep before isLoaded = true (RootView.swift:44-60)
guarantees MainTabView is constructed AFTER the AppDelegate's main-actor hop has
already written router.pendingCategory (AppDelegate.swift:33-45) — the mount is
actively delayed past the write, so the .onChange at MainTabView.swift:82-84 and
:123-125 (no `initial: true`) never sees a change. (2) Because handlePendingCategory
is the only code that clears the value (MainTabView.swift:146) and it never ran,
pendingCategory stays set, so a second tap of the same category writes an identical
value and .onChange — which fires on change, not on assignment — ignores it too. The
failure is permanent for the session, not just for one tap. consumePending() exists on
the router and is never called.

**Fix.**

1. 1. Add `initial: true` to both observers: `.onChange(of: router.pendingCategory,
   initial: true) { _, c in handlePendingCategory(c) }` at MainTabView.swift:82-84 and
   :123-125. This fixes part 1 for both layouts.
2. 2. Replace the manual `router.pendingCategory = nil` inside handlePendingCategory
   (MainTabView.swift:146) with a call to the router's existing consumePending(), so
   the consume-on-read invariant lives in the router rather than in one view — that is
   what stops part 2 reappearing when another view starts observing the router.
3. 3. Verify handlePendingCategory is a no-op for nil (it is invoked immediately now
   that initial: true is set).

*Files:* `Caelyn/Views/MainTabView.swift`, `Caelyn/App/AppDelegate.swift`, `Caelyn/Views/RootView.swift`

*Tests:* No existing coverage (grep shows no NotificationRouter references in CaelynTests/).
Add a unit test on NotificationRouter semantics: consumePending returns the value once
and leaves nil; setting the same category twice is observable twice through consume.
Cold-launch routing itself needs the orchestrator's serial runtime probe.

#### REM-08 — NotificationService.content(for: .periodUpcoming) + the sync period branch

She set the period reminder to 'Day of'. On the morning Caelyn thinks her period
starts, the notification says 'Caelyn predicts your period in a couple of days.'

**Root cause.** content(for:isPrivate:) is keyed only by Category (NotificationService.swift:78-86),
so the .periodUpcoming body is a compile-time constant, while the scheduling loop at
:219-236 discards the information that would fix it — it breaks on the first
schedulable candidate without carrying that candidate's distance from nextPeriod (nor
the quiet-hours-shifted fire date it actually used) into content construction. Copy
and fire date are computed from independent inputs and can never be guaranteed to
agree; the day-of fallback at :218-236 makes the mismatch routine rather than rare.

**Fix.**

1. 1. Add `leadDays: Int? = nil` to content(for:isPrivate:) and thread it through
   makeContent and scheduleOneShot (NotificationService.swift:413-451). Default nil
   keeps the current string, so existing call sites and
   testNotificationContentDescriptiveWhenNotPrivate compile unchanged.
2. 2. Phrase from leadDays: 0 → 'Caelyn predicts your period today.', 1 →
   '…tomorrow.', 2 → '…in a couple of days.', n → '…in \(n) days.' Leave the private
   body untouched so testPrivateNotificationsNeverLeakHealthTerms still passes.
3. 3. Compute leadDays from the fire date actually selected, not from
   profile.periodReminderDaysBefore: inside the candidate loop, once
   `scheduledFireDate` returns a non-nil fire, `let lead = cal.dateComponents([.day],
   from: cal.startOfDay(for: fire), to: cal.startOfDay(for: nextPeriod)).day ?? 0` and
   pass max(0, lead). This keeps the copy correct even when quiet hours shift the fire
   across midnight.
4. 4. Do the same for .ovulation if its body makes a timing claim.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Settings/RemindersView.swift`

*Tests:* testNotificationContentDescriptiveWhenNotPrivate and
testPrivateNotificationsNeverLeakHealthTerms keep compiling via the default parameter;
add cases asserting the body text for leadDays 0, 1, 2 and 3.

#### REM-11, REM-20 — CycleStore.merge / dedupeSameDay and ProfileStore.merge — hand-maintained field lists

She uses Caelyn on an iPhone and an iPad. A note reminder she set on one device
disappears, or one she already marked done fires again. A reminder time she changed on
the newer device silently reverts, and 'Private notifications' can flip itself off.
Nothing warns her; the merge just keeps whichever copy happened to win.

**Root cause.** Both merges are hand-maintained per-field assignment lists with no completeness check
against the model. CycleStore.merge (CycleStore.swift:94-127, verified: flow/pain/mood
/energyLevel/note/medication/ovulationTestResult/pregnancyTest/cervicalMucus/basalTemp
erature/sexualActivity + the array unions) never mentions noteReminderRule,
noteReminderAt or noteReminderDone, which commit 2325af7 added to CycleEntry without
touching CycleStore. ProfileStore.merge (ProfileStore.swift:47-101, verified) ORs 28
bools and recency-picks six numbers but never touches dailyCheckInHour/Minute,
medicationHour/Minute, periodReminderHour/Minute, periodReminderDaysBefore,
ovulationReminderHour/Minute, birthControlReminderHour/Minute or privateNotifications.
An unmentioned field silently retains the keeper's value, and which row is the keeper
depends on createdAt ordering (CycleStore.swift:35) rather than on which device holds
the newer state — so the loss is asymmetric, invisible on one device, and invisible to
the whole test suite (zero noteReminder references in CaelynTests/).

**Fix.**

1. 1. Add the structural guard first — a test that enumerates CycleEntry's and
   UserProfile's stored properties (via Schema/Mirror on an instance) and fails if the
   merge function's source text does not mention each name. This is the permanent
   half: it fails the next time anyone adds a property, which is the actual mechanism.
2. 2. CycleEntry reminder fields: merge the rule and the resolved date as ONE unit,
   not field-by-field — `pick(rule)` and `pick(at)` independently can pair a .date
   rule from one row with a cycle-resolved date from the other, producing a wrong fire
   time instead of a missing one. Choose the whole triple from the same source row: if
   `srcNewer` and src.noteReminderRule != nil take (rule, at, done) from src, else
   keep dst's, with the empty side yielding to the non-empty one.
3. 3. noteReminderDone: do NOT use `dst.done || src.done`. If the keeper is an older
   row with done=true from a previous cycle and the newer row has a freshly set
   reminder, OR-ing resurrects the done flag and kills the new reminder. Take done
   from whichever row supplied the rule in step 2.
4. 4. ProfileStore: move the hour/minute/daysBefore fields into the existing `if
   srcNewer` recency block (ProfileStore.swift:91-99) next to averageCycleLength etc.
   — they always hold a value, so recency is the only sensible tiebreak.
5. 5. privateNotifications: `dst.privateNotifications = dst.privateNotifications ||
   src.privateNotifications` in the first block — more private wins, consistent with
   that block's stated rule and with its all-`||` polarity.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`

*Tests:* DeletionModelTests' merge tests gain reminder-field assertions; ProfileStoreTests
gains the reminder-time and privateNotifications cases; add the new property-
enumeration coverage test for both merges.

#### SC-1 — 41 Shareable card

She sees a card, taps Share, and Messages or Instagram receives a visibly different
one — tiny text stranded on a mostly empty gradient, with the decorative ring in the
wrong place. The only thing Caelyn asks her to share does not look like what she
approved.

**Root cause.** There are two layout passes at two different logical sizes. The preview lays
ShareableCardView out at 288x456 pt (ShareableCard.swift:150-151); renderCard() lays
the same view out at 900x1425 pt and also sets renderer.scale = 3 (:201-209) — so
layout size and pixel density are conflated and double-counted for a ~9.4x effective
multiplier over the preview, and the enlarged frame is the part that has no business
being there. Because every font (13/40/18/19/12 pt), the padding (34) and the ring
(280 pt circle at offset 90,-150) are absolute points (:74-77, :86-119), the same view
composes completely differently at the two sizes: at 288 pt the headline wraps to 3+
lines and the ring sits off the top-right edge; at 900 pt everything is one line in a
thin band. Rendering also happens synchronously on the main thread in onAppear (:197),
producing a ~46 MB RGBA bitmap.

**Fix.**

1. 1. Lead with preview-as-output: replace the live ShareableCardView at :150 with the
   rendered image (`rendered.resizable().scaledToFit().frame(width: 288)`). One layout
   pass in the whole file makes divergence structurally impossible. Keep the existing
   ProgressView at :182 as the placeholder and move the chrome
   (.clipShape/.overlay/.caelynShadow, :152-157) onto the image so the card still
   looks seated.
2. 2. Introduce a shared `designSize` constant (e.g. 288x456) used by both the
   renderer frame and any future live preview, and delete the 900x1425 frame at
   :201-209, leaving renderer.scale = 3 to carry pixel density alone.
3. 3. Do not rely on the ambient environment for colours in the renderer: pin the
   colour scheme explicitly on the rendered content so the shared PNG matches the
   preview in Dark theme (see probe).
4. 4. Move rendering off the synchronous onAppear path (:197) — render in a Task and
   show the placeholder until it lands — so presenting the sheet does not hitch on
   older devices.
5. 5. Consider scale = 2 if the output file size matters more than print-grade
   resolution; at designSize x 3 the PNG is already far beyond what any social app
   needs.

*Files:* `Caelyn/Views/Share/ShareableCard.swift`

*Tests:* None exist for the share card. Add a unit test rendering ShareableCardView at
designSize with scale 1 and 3 and asserting pixel size == designSize x scale, plus the
colour-scheme probe below.

#### SYNC2-07 — 38 Backup status

A woman who tried sync for a week a year ago and switched it off is told, for the rest
of the app's life, that the only way to erase this phone is to erase her iCloud copy
along with it — exactly the trade she may be unwilling to make, and exactly when a
local wipe matters most. She can also be told inside a two-step destructive dialog
that an iCloud copy exists when nothing was ever uploaded.

**Root cause.** Two independent facts are forced through one single-valued, mutually exclusive enum.
DeleteAllOffer has exactly two cases (SecureWipeService.swift:51-59) and
SettingsView.swift:185-193 renders exactly one button from it, so the dialog cannot
express 'a copy may be in iCloud AND this launch's container is unmirrored'. The two
axes — what might be sitting in iCloud (the sticky history flags) and whether this
process will export deletions (solely Persistence.isSyncActive) — must collapse into
one value and the stricter one necessarily wins. The disjunction in
cloudCopyMayExistNow (CloudDataDeletion.swift:70-78) is how they collapse, not why
they have to.

**Fix.**

1. 1. Add `CloudDataDeletion.localDeletesStayLocal: Bool { Persistence.isDemoStore ||
   !Persistence.isSyncActive }` — one meaning only: will the running container export
   deletions. Leave cloudCopyMayExistNow unchanged for 'could something of hers be in
   iCloud' (PrivacyTrustView.swift:9, the delete-cloud card).
2. 2. Do NOT simply swap localDeletesStayLocal into deleteAllOffer as originally
   proposed — DeleteAllOffer is exclusive and drives one button, so that swap removes
   the both-places wipe and the 'you have a copy in iCloud' warning
   (SettingsView.swift:197-199) from the woman who genuinely has a cloud copy.
3. 3. Make the offer two-axis: either add a third case .both (device-only wipe AND
   wipe-everywhere, both offered with distinct copy), or replace the enum with a small
   struct carrying `mayHaveCloudCopy` and `localDeletesStayLocal` and have
   SettingsView render one or two buttons from it.
4. 4. Make the dialog's assertion conditional on evidence rather than on the
   disjunction: say 'a copy may still be in iCloud' when cloudCopyMayExistNow is true
   but nothing has been observed uploading, and 'your iCloud copy' only when an export
   has actually succeeded (see the SyncReport item's lastExportAt).
5. 5. Land after the SyncReport item so step 4 has a signal to read.

*Files:* `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* DeleteAllOfferTests in DeletionModelTests.swift:610-645 drive the rule from
cloudCopyMayExistNow and must drive it from the new predicate; the assertion that a
mirrored launch withholds the local-only delete stays true, but the 'synced once, now
off' case must change to offer both.

#### T1-03 — 3 Cycle prediction / 1 Daily log

Browsing back through her log to a day earlier than the date she gave during setup,
every one of those days says 'Cycle day 1'.

**Root cause.** CycleModel.make applies the `<= day` cutoff only to logged flow
(PredictionEngine.swift:208-216) while the profile seed passes through unfiltered
(CyclePrediction.swift:227). Viewing a date before the seed therefore makes the anchor
a date in that day's future, and `max(0, days)` at PredictionEngine.swift:174-176
renders the negative distance as day 1. Reachable whenever the seed falls inside the
trailing 14-day window the Log tab offers (LogView.swift:117-123), which is the common
case for a new user.

**Fix.**

1. 1. In CycleModel.make, cut the seed off at the viewed day exactly as logged flow
   already is: `let seed = profile?.lastPeriodStart.map { calendar.startOfDay(for: $0)
   }.flatMap { $0 <= day ? $0 : nil }`.
2. 2. With no logged flow before that date either, the anchor is nil, hasPrediction is
   false, and LogView already omits the cycle-day clause (LogView.swift:198-200) — no
   view change needed.
3. 3. Permanent because the cutoff then applies to every input to the anchor rather
   than to one of the two.

*Files:* `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Views/Log/LogView.swift`

*Tests:* Add to the CaelynTests anchor section: make(entries: [], profile: seed May 4, today:
Apr 20) -> hasPrediction false. testTheOnboardingSeedAlonePredictsNormally
(CaelynTests.swift:1603) is unaffected because today is after the seed.

#### T1-08 — 5 Home / 3 Cycle prediction

She forgets to log one day in the middle of her period. Caelyn decides the period
ended before that gap and shows 'That cycle, in review — your period ran 2 days' while
she is still bleeding and still logging it, and the symptom and pain summaries in the
card only cover the first two days.

**Root cause.** HomeView.periodRecap re-implements the flow-streak walk with a strict `while
flowDays.contains(cursor)` loop (HomeView.swift:305-311) because the engine's single
definition, PredictionEngine.consecutiveFlowDays (PredictionEngine.swift:97-109), is
private and unreachable from the view. Since mostRecentPeriodStart (:209-224) honours
sameStreakGapTolerance and the view's walk does not, the start of a period is tolerant
and its end is strict, and that one disagreement produces all three symptoms — the
premature card, the truncated periodEntries window at HomeView.swift:325-328 that
corrupts the symptom and pain lines, and the wrong length.

**Fix.**

1. 1. Promote PredictionEngine.swift:97 to a non-private `static func
   periodLength(startingAt:in:calendar:)` so the tolerant streak has exactly one
   implementation in the codebase.
2. 2. Derive PeriodRecap in CycleModel/CycleAnalytics from it and have HomeView only
   render — the recap becomes unit-testable, which it is not today.
3. 3. Use the TOLERANT last-flow-day for the periodEntries filter at
   HomeView.swift:325-328 as well, not only for the length; otherwise the length reads
   5 while the symptom and pain lines still summarise days 1-2.
4. 4. After this, HomeView.swift:307 is the last strict streak walk outside the tests
   — remove it so no second definition can drift again.

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* Add a recap test to CaelynTests against the days 1,2,4,5 fixture — currently
impossible because the recap is private to the view. Assert length 5, lastFlowDay day
5, and that periodEntries covers all four logged days.

#### T1-11 — 1 Daily log / 5 Home / 6 Calendar

If the Log tab is open across midnight — or she comes back to the app the next morning
— it is still sitting on yesterday while calling it 'Today', so a flow she taps at ten
past midnight is written to the wrong day. Home can likewise still show yesterday's
cycle day until something makes it redraw.

**Root cause.** Two mechanisms, and only one of them is a lazy time read. (a) The damaging one:
LogView.selectedDate (LogView.swift:8) is a RESOLVED Date seeded once at view-identity
creation and changed only by taps (:67, :143), and the view identity is never
destroyed during a session — MainTabView.swift:90-120 keeps all five tabs mounted and
AppLockGate.swift:26-29 hides rather than removes the tree — so the selection outlives
any number of midnights. Adding an invalidation source would refresh the pill labels
but still write to the stale stored day. (b) The cosmetic one: HomeView and
CalendarView derive `today` inside body (HomeView.swift:23, 140-142;
CalendarView.swift:8) with no input that changes at midnight, and nothing observes
.NSCalendarDayChanged or scenePhase, so a foreground return may not re-run body
(suspected; depends on SwiftUI invalidation).

**Fix.**

1. 1. Fix (a) by changing the representation, not by patching the value: `@State
   private var selection: Date? = nil` where nil means 'the current day', with
   `private var selectedDate: Date { selection ?? clock.today }`. The Today button and
   a tap on the today pill set nil; any other pill sets a concrete day. There is then
   no stored day to go stale, and no number of elapsed midnights can desynchronise it.
2. 2. Add a small observable `DayClock` that publishes on .NSCalendarDayChanged and on
   scenePhase == .active, and inject it where `today` is read (HomeView, CalendarView,
   LogView) so (b) redraws.
3. 3. Do not use the `.onChange(of: clock.today) { if selectedDate == old {
   selectedDate = new } }` patch — it only handles exactly one midnight and fails for
   an app suspended over several.

*Files:* `Caelyn/Views/Log/LogView.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Calendar/CalendarView.swift`, `Caelyn/Views/Main/MainTabView.swift`

*Tests:* Make `today` injectable and unit-test the rule that an unset selection always resolves
to the clock's today across a simulated midnight. The Home re-render behaviour needs a
device observation and cannot be asserted in XCTest.

#### T2-04 — 1 Daily log / 8 Local-first storage

She writes a note on her iPad and attaches 'remind me before my next period'. When the
iPad's copy of that day reaches her iPhone, the note arrives but the reminder is
thrown away. It never fires on either device, and the Log tab shows the reminder as
'Off' for something she definitely set.

**Root cause.** CycleStore.merge enumerates fields by hand — eleven scalars (CycleStore.swift:98-108),
three array unions (:110-112), the severity map (:114-124), updatedAt (:126) — and the
three note-reminder properties added later for the note-to-self feature
(CycleEntry.swift:57-59: noteReminderRule, noteReminderAt, noteReminderDone) appear
nowhere in the file. Note that it is the KEEPER that survives: dedupeSameDay sorts
oldest-createdAt-first and keeps the first row for a dayKey, so the reminder lost is
whichever row is not the keeper, independent of which note wins the pick at :102 — the
note can transfer while the reminder that belongs to it does not.

**Fix.**

1. 1. Add the three fields to merge, but pick noteReminderRule and noteReminderAt AS A
   UNIT, never independently: independent picks can pair one row's rule with the other
   row's fire time whenever exactly one of the two is nil, producing a .date rule
   pointed at a time she never chose. Write it as one decision: `let reminderSrcWins =
   srcNewer ? (src.noteReminderRule != nil) : (dst.noteReminderRule == nil)` and copy
   rule, at and done together when it is true.
2. 2. Decide noteReminderDone with the pair, not separately — a 'done' flag belonging
   to a rule that lost is meaningless.
3. 3. Add a compile-time guard against the next field being forgotten: a test that
   enumerates CycleEntry's stored properties and fails when one is absent from merge,
   or a doc rule at the top of merge requiring every new property to be listed.
4. 4. Re-schedule after a merge: NotificationService.syncFromLiveStore must run once
   the coordinator's reconcile pass changes anything, or a reminder that merged in
   correctly still never fires this session.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Log/DailyLogForm.swift`

*Tests:* CloudMigrationConflictTests and LocalFirstContractTests both pin the merge's additive
contract and should gain a case for a reminder arriving on the incoming row. Add the
property-enumeration guard test.

#### T2-05 — 2 Symptom tracking

Caelyn allows five custom symptoms, so adding a sixth forces her to remove one — and
that is the moment it breaks. Every past day that recorded the removed symptom keeps
it: the day still shows a 'How severe?' row labelled 'Insomnia' with
Mild/Moderate/Severe buttons, but the chip that would let her take it off is gone, so
she can never un-log it. It stays in her CSV and PDF, keeps the day marked as logged,
and the same orphan arrives from imports.

**Root cause.** The chip grid is a function of the mutable vocabulary (profile.customSymptoms,
DailyLogForm.swift:367, 392-400) while the severity rows are a function of the entry
(entry.loggedCustomSymptoms, :369, 433-434, 456-458), and removeCustomSymptom clears
the name from TODAY's entry only, then removes it from the profile unconditionally
(:1045-1056) — so the two sources desynchronise by design. The vocabulary and the
entry values also merge under different rules: CycleStore.merge unions
loggedCustomSymptoms (CycleStore.swift:112) while ProfileStore.merge takes dst's list
whole when non-empty (ProfileStore.swift:89), and ImportReconciler appends entry names
without ever touching profile.customSymptoms — two more ways to create the same
orphan.

**Fix.**

1. 1. Render the chips from the UNION of the vocabulary and what the open day actually
   holds: `ForEach(Array(customNames) + customSelected.filter {
   !customNames.contains($0) })` (DailyLogForm.swift:393), so an orphan is always
   deselectable on the day that holds it.
2. 2. Keep the cap on the vocabulary only: the `customNames.count < 5` check (:410)
   and addSymptomDisabled/commitAddSymptom (:550-566) stay keyed to
   profile.customSymptoms, or an orphan chip on an old day would consume a slot and
   block adding a new symptom.
3. 3. Suppress 'Remove symptom' in the context menu (:401-407) for an orphan chip — it
   is not in the vocabulary, so removeCustomSymptom would be a no-op on a name she can
   see.
4. 4. Have ImportReconciler add any custom name it writes to an entry
   (ImportReconciler.swift:498) into profile.customSymptoms when there is room, so
   imports stop manufacturing orphans at the source.
5. 5. Leave stored data alone — no sweep that strips orphaned names from past entries.
   Deleting her history to tidy a vocabulary would be the wrong trade; making the name
   reachable again is the fix.

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Services/ImportReconciler.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* No existing test covers custom-symptom removal (DailyLogDraftTests models only the
typed drafts). Add: a removed custom symptom is still offered as a chip on a past day
that logged it; removing it from that day clears the severity row; the five-symptom
cap counts only vocabulary names.

#### T2-06 — 1 Daily log (note-to-self reminders)

She writes herself a note and picks "Remind me before my next period". Caelyn prints
back, in plain words, "Reminds you 2 days before your next period." If Caelyn has no
prediction yet — a brand-new user, or anyone who answered "I'm not sure right now" at
onboarding — there is nothing to count back from, so no reminder is ever scheduled and
none ever arrives. The same silence happens if she declined notification permission.
Nothing anywhere tells her; the screen still says it will remind her.

**Root cause.** The caption is a pure function of the persisted RULE, never of its resolved fire date.
DailyLogForm branches on currentReminderRule — itself just a decode of
entry.noteReminderRule (:795-797) — and prints rule.picked, a constant string on the
enum (NoteReminder.swift:26-32), verified at DailyLogForm.swift:823-833. The form
never builds a CycleModel and never reads entry.noteReminderAt, so it has no way to
render a third state between "Off" and "Reminds you on ...". Resolution happens in a
different layer that is additive-only and silent: NoteReminder.fireDate returns nil
for .beforePeriod and .atPeriod when nextPeriodStart is nil
(NoteReminder.swift:53-62); scheduleNoteReminders then stores noteReminderAt = nil and
schedules nothing, and it returns at its very first guard when authorization is not
.authorized (NotificationService.swift:352, read and confirmed). A nil noteReminderAt
also drops the note out of HomeView.dueNoteReminders (HomeView.swift:111-120), so the
Home card cannot act as a backstop either.

**Fix.**

1. 1. Build the cycle model in the form. DailyLogForm already has allEntries and
   profile in scope (:9-10, :47), so `CycleModel.make(entries:profile:today:)` — the
   same call NotificationService makes at NotificationService.swift:99 — gives it
   hasPrediction (CyclePrediction.swift:260) with no new plumbing and no schema
   change.
2. 2. In the reminder menu (DailyLogForm.swift:809-813), DISABLE rather than hide the
   two cycle-relative rules when !cycle.hasPrediction, with the reason inline: "Caelyn
   needs one logged period first". A hidden option reads as a missing feature; a
   disabled one with a reason teaches what to do next.
3. 3. Drive the caption off the RESOLVED date, not off a second hasPrediction check:
   render entry.noteReminderAt when it is non-nil, and an explicit unresolved state
   otherwise. This is the permanent part — the display becomes a function of the same
   value the scheduler writes, so no future rule can be announced without being
   schedulable.
4. 4. Handle declined notification authorization as its own visible state, with a tap-
   through to Settings. Today NotificationService.swift:352 returns at the first guard
   while the form reads "Reminds you...".
5. 5. Do not silently clear the rule when there is no prediction — keep it stored so
   it resolves on its own once she logs a period, and say so ("Will remind you once
   Caelyn knows your next period").

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/NoteReminder.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* NoteReminder.fireDate's existing pure tests are unaffected. Add: with no prediction,
the form's reminder-caption function returns the unresolved state for
.beforePeriod/.atPeriod and the resolved date for .date (extract the caption as a pure
function of (rule, noteReminderAt, hasPrediction, authorizationStatus) so it is
testable without the View).

#### T2-07 — 1 Daily log (note-to-self reminders / deletion)

She deletes a day — often precisely because what she wrote was private — and the next
morning her phone says "A note to yourself · You left yourself a note. Tap to see it."
Tapping it opens Caelyn to nothing. Clearing just the note text does the same thing.
For an app that promises "delete everything in seconds", a notification that outlives
the deletion is the wrong kind of surprise.

**Root cause.** Note reminders are scheduled eagerly at set-time (DailyLogForm.swift:848-869 ->
NotificationService.scheduleNoteOneShot, :378-386) but the pending one-shot is removed
only by the wholesale cancelAll() at the head of the next full sync
(NotificationService.swift:138-151, :166). Neither invalidating write path is among
the paths that trigger syncFromLiveStore: LogView's delete does modelContext.delete +
saveOrLog + a HealthKit cleanup and nothing else (LogView.swift:88-96, read and
confirmed), and DailyLogForm.commitNote writes `note = nil` through withEntry with no
resyncReminders call (:1078-1085, verified — only setReminder and the date picker call
it, at :843 and :863). So the UNCalendarNotificationTrigger outlives the thing it
points at until some unrelated scenePhase transition happens to run a sync.

**Fix.**

1. 1. Add `static func noteDidChange(day: Date)` to NotificationService that rebuilds
   the day-derived identifier "caelyn.note.reminder.<yyyyMMdd>" and calls
   removePendingNotificationRequests(withIdentifiers:). The identifier format already
   exists at NotificationService.swift:383 via dateSuffix(for:).
2. 2. NOTE while implementing: scheduleNoteOneShot keys the identifier on
   `entry.date`, an instant (NotificationService.swift:378-386). Derive the suffix
   from entry.dayKey instead, so the cancel and the schedule cannot disagree after a
   timezone change — otherwise this fix inherits the bug class fixed in
   37dddd7/9776951 (see T1-16/T1-17).
3. 3. Call noteDidChange from the LogView delete (LogView.swift:88-96), using the
   entry's day before the object is deleted.
4. 4. Call it from commitNote when the new value is nil
   (DailyLogForm.swift:1078-1085).
5. 5. On the same path, clear entry.noteReminderRule / noteReminderAt /
   noteReminderDone when the note goes empty. Otherwise the orphaned rule silently
   reactivates the next time she types anything on that day: scheduleNoteReminders
   only gates on the note being non-empty (NotificationService.swift:355-359), not on
   the rule having been reconfirmed. This is the half that makes the fix permanent
   rather than per-instance.
6. 6. Consider routing both invalidating paths through CycleStore so future delete
   sites inherit the cancellation (see the day-row-resolution item).

*Files:* `Caelyn/Views/Log/LogView.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/CycleStore.swift`

*Tests:* New NotificationService tests against a fake UNUserNotificationCenter: setting a
reminder then deleting the day leaves no pending request with that identifier;
clearing the note text does the same; the identifier derived from dayKey is stable
across two different calendars (pins step 2).

#### T2-09 — 9 Onboarding (OnboardingViewModel.adopt)

She sets up Caelyn on a second device. Partway through, her profile arrives from
iCloud. She has just answered the reminders question — period reminders on, daily
check-in on — and granted notification permission. All four of those answers are
thrown away. The lock answer she gave on the very next screen is kept. Nothing
explains the difference, and the reminders step never comes back, so she gets no
reminders at all and has to find them in Settings.

**Root cause.** adopt and ProfileStore.merge each hand-maintain their OWN list of which UserProfile
preferences are additive, and the two lists have drifted. Verified side by side:
ProfileStore.merge ORs remindPeriodStart, remindDailyCheckIn, remindMedication and
remindOvulation (ProfileStore.swift:60-63) along with lockEnabled (:52) and fourteen
other flags; OnboardingViewModel.adopt (:137-155) fills lastPeriodStart and
trackingGoals only when absent, ORs healthKitConnected, applies `if enableLock {
profile.lockEnabled = true }` — and names none of the four reminder flags. The
mechanism is the duplicated, unsynchronised classification, not the default-false
ambiguity (that is only why an OR is the right policy). It is also why
ProfileStoreTests.swift:168-209 could assert on lockEnabled and never notice the gap.

**Fix.**

1. 1. Extract merge's field-by-field classification into ONE internal entry point —
   e.g. `ProfileStore.absorbAdditive(answers:into:)` taking a small value type holding
   the onboarding answers — and have both dedupe's merge (ProfileStore.swift:49-70)
   and OnboardingViewModel.adopt (:137-155) call it, so `remindPeriodStart || ...` and
   `lockEnabled || ...` exist exactly once. This is the permanent fix: a new
   preference added to the policy is automatically honoured by both paths.
2. 2. Short-term patch if the extraction must wait: add the four ORs at
   OnboardingViewModel.swift:154, beside the existing enableLock line. Mark it with a
   TODO pointing at step 1, because a third list is how this happened.
3. 3. Fix the teardown half as well. adopt is reached far less often than RootView's
   re-route, so latch onboarding for the lifetime of the flow (a @State set once at
   flow start) rather than letting a mid-flow profile arrival re-evaluate the route
   and tear the flow down under her.
4. 4. Note the adjacent unsorted read while in this file: OnboardingViewModel.swift:98
   fetches UserProfile with an unsorted FetchDescriptor — it is a seventh instance of
   the T2-10 mechanism and should adopt ProfileStore.current(in:) in the same pass.

*Files:* `Caelyn/Views/Onboarding/OnboardingViewModel.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`, `CaelynTests/ProfileStoreTests.swift`

*Tests:* ProfileStoreTests already covers the dedupe merge; add a sibling test for adopt: an
existing profile with all reminder flags false plus onboarding answers with all four
true must end with all four true, asserted by iterating the policy rather than by
naming fields (so the test cannot drift the way the code did).
ProfileStoreTests.swift:168-209 should be re-pointed at the shared absorbAdditive so
both paths are covered by one assertion set.

#### T2-10 — 8 Local-first storage (service-level UserProfile reads)

If a second copy of her settings arrives from iCloud mid-session, the screens she is
looking at and the background services can read two different copies. The visible app
reads the right one; the code that writes to Apple Health and schedules her
notifications may read the other. So she turns a reminder on, the screen shows it on,
and the scheduler — reading the other copy — schedules nothing. It heals itself at the
next cold start, which is also why it is so hard to catch.

**Root cause.** Commit c2b96fa swept the view layer only: every @Query for UserProfile is sorted by
createdAt (all eighteen), but the service layer reads through bare FetchDescriptors
with no sortBy, and a FetchDescriptor with no sort returns rows in store order, which
SwiftData does not guarantee between launches. Verified by grep — eight unsorted
sites: CaelynApp.swift:97, OnboardingViewModel.swift:98, ProfileStore.swift:26,
HealthKitSync.swift:32 and :43, NotificationService.swift:329,
HealthSyncService.swift:317, CloudSyncCoordinator.swift:91. The triggering path is not
mainly "a stale read at foreground sync" — it is write-then-read-a-different-row
inside ONE interaction: RemindersView.swift:152-155/:303-304/:316,
BirthControlView.swift:144, SettingsView.swift:758 and HomeView.swift:460 all call
NotificationService.syncFromLiveStore() immediately after mutating the sorted keeper,
and that sync begins with cancelAll(). ProfileStore.dedupe runs only at launch and
CloudSyncCoordinator deliberately does not call it for profiles, so the two-row window
is real and can last a whole session.

**Fix.**

1. 1. Add `static func current(in context: ModelContext) -> UserProfile?` to
   ProfileStore, fetching with `sortBy: [SortDescriptor(\UserProfile.createdAt)]` and
   returning .first — the same ordering dedupe uses to pick its keeper
   (ProfileStore.swift:31-32).
2. 2. Replace all eight unsorted sites with it: CaelynApp.swift:97,
   OnboardingViewModel.swift:98, HealthKitSync.swift:32 and :43,
   NotificationService.swift:329, HealthSyncService.swift:317,
   CloudSyncCoordinator.swift:91 (ProfileStore.swift:26 is dedupe's own fetch and
   should sort too). This half changes NO stored data and is what makes the services
   and dedupe structurally incapable of picking differently.
3. 3. Add a CI grep or a test asserting no bare `FetchDescriptor<UserProfile>()`
   outside ProfileStore, so the next service cannot reintroduce one.
4. 4. SEPARATELY, and only with a plan: calling ProfileStore.dedupe from
   CloudSyncCoordinator.reconcileArrivedRecords (CloudSyncCoordinator.swift:73-83)
   DOES change stored data — it merges fields into the keeper and
   context.delete(duplicate) (ProfileStore.swift:33-36), and on a mirrored container
   that propagates a record delete to her other devices. Do not bundle it with step 1.
   Land step 1 first, confirm the window is harmless, then design the dedupe-on-
   arrival with an explicit answer for what a concurrent edit on the other device does
   to the deleted row.
5. 5. CORRECTION to the filed note: step 1 is migration-class none; only step 4
   touches stored data.

*Files:* `Caelyn/Services/ProfileStore.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/HealthKitSync.swift`, `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Views/Onboarding/OnboardingViewModel.swift`

*Tests:* ProfileStoreTests already asserts dedupe keeps the oldest row; add a test that
ProfileStore.current agrees with dedupe's keeper when two rows exist, and that it
agrees across repeated fetches. Add the grep test from step 3.

#### watch:W-06 — Watch companion (tier gating / WatchHomeView.emptyState)

A free user installs the watch app and is told "Open Caelyn on your iPhone to sync".
She does. Nothing happens — ever. The watch has no way to tell her the watch face
needs Pro, so it blames her phone. And in the other direction, when a subscription
lapses, nothing new is ever sent, so the watch keeps showing the full Pro dashboard
from the last time she paid.

**Root cause.** Tier is enforced as a transport decision on the phone instead of as data on the wire.
WidgetDataSync.sync() wraps the only watch channel in `if PurchaseService.shared.isPro
{ ... }` (Caelyn/Services/WidgetDataSync.swift:139-141, read and confirmed), so "free"
is expressed as the ABSENCE of a message — indistinguishable on the wrist from "not
yet synced". Meanwhile WidgetSnapshot.isPro, which is written at
WidgetDataSync.swift:78 and honoured by every iOS widget family
(WidgetViews.swift:104, 182, 305, 342), is never read anywhere in CaelynWatch/:
WatchHomeView.body branches only on `displaySnapshot == nil`
(WatchHomeView.swift:22-26, verified) and renders dashboard(snap) unconditionally
otherwise (:39-47).

**Fix.**

1. 1. ORDER IS LOAD-BEARING — ship both halves in ONE commit. Removing the gate at
   WidgetDataSync.swift:139-141 while WatchHomeView still renders dashboard(_:)
   unconditionally would hand every free user the complete Pro watch dashboard.
2. 2. Remove the isPro transport gate: always push the snapshot, with isPro set
   honestly (depends on widgets:W-04 landing so the flag is correct).
3. 3. Branch WatchHomeView.body on THREE states, not two: displaySnapshot == nil ->
   keep today's "Open Caelyn on your iPhone to sync" (now genuinely the only remaining
   cause); snapshot present with !snap.isPro -> a Pro-upsell state naming the feature
   ("The Caelyn watch face is part of Pro"), matching the language the iOS widgets
   already use at WidgetViews.swift:104; snapshot present with isPro -> today's
   dashboard.
4. 4. Leave Quick Log reachable in the non-Pro state if it is intended to be free;
   decide this explicitly rather than inheriting it from whichever branch renders.
5. 5. Once the push is unconditional, revisit the empty-state copy and icon
   (WatchHomeView.swift:53-71) — "iphone.and.arrow.forward" is the right image only
   for a never-synced watch.

*Files:* `Caelyn/Services/WidgetDataSync.swift`, `CaelynWatch/WatchHomeView.swift`, `Caelyn/Services/WidgetDataStore.swift`

*Tests:* Extract the three-way state choice into a pure function (e.g.
`WatchDisplayState.from(_ snapshot: WidgetSnapshot?) -> enum`) and test all three from
CaelynTests: nil -> .needsSync, isPro == false -> .needsPro, isPro == true ->
.dashboard. No test exists today for any of it.

#### watch:W-08 — Watch companion (WatchHomeView.displaySnapshot — day change while resident)

She checks her watch at 23:50 and it says Day 13. She checks it again at 07:00 the
next morning and it still says Day 13, because the watch app was only suspended, not
killed, and nothing told it the date had changed. The home-screen widget gets this
right; the watch does not.

**Root cause.** The current date is an implicit, untracked input. displaySnapshot reads `.now` inside
a computed property consumed by body (CaelynWatch/WatchHomeView.swift:13-17, verified:
`return base.recomputed(for: .now)`), so what is rendered is a snapshot of whenever
SwiftUI last invalidated the view, not of the actual clock. The view's declared
dependencies are only model.snapshot (:4) and showQuickLog (:5). The sole remaining
invalidator is a WCSession push, which is itself driven off the PHONE's lifecycle
(WidgetDataSync.swift:125-129) and Pro-gated (:139-141) — so on a free or lapsed
account nothing can ever invalidate the view. The widget avoids this entirely by pre-
building a per-midnight timeline (CaelynWidgetProvider.swift:41-50).

**Fix.**

1. 1. Wrap WatchHomeView's dashboard in `TimelineView(.explicit(midnights))`, where
   `midnights = [.now] + (1...7).compactMap { cal.date(byAdding: .day, value: $0, to:
   cal.startOfDay(for: .now)) }` — mirroring CaelynWidgetProvider.swift:44-48 so the
   watch and the widget share one schedule semantics.
2. 2. Do NOT use TimelineView(.everyMinute): it wakes the body 1,440 times a day on a
   battery-sensitive device to change one value at most once.
3. 3. Belt-and-braces, because a schedule computed at body time also goes stale while
   suspended: add `@State private var renderDate = Date()`, bump it on .onChange(of:
   scenePhase) when it becomes .active, and on .onReceive(NotificationCenter
   NSCalendarDayChanged / significantTimeChange).
4. 4. Pass renderDate (or the timeline context date) into recomputed(for:) instead of
   `.now`, making the date an explicit, tracked input rather than an ambient read.
   That is the permanent part: a future reader cannot reintroduce the bug by adding
   another `.now`.
5. 5. Audit WatchQuickLogView for the same ambient `.now` read when it stamps the
   entry date.

*Files:* `CaelynWatch/WatchHomeView.swift`, `CaelynWatch/WatchQuickLogView.swift`, `CaelynWidget/CaelynWidgetProvider.swift`

*Tests:* No unit test can observe SwiftUI invalidation. Test the pure part: recomputed(for: t)
for t = 23:59 and t = 00:01 the next day must differ by one cycle day (this probably
already holds and simply pins it). Everything else is the simulator probe below.

#### watch:W-11, widgets:W-07 — Build configuration (CaelynWatch/Info.plist + CaelynWidget/Info.plist versioning)

Nobody sees this in the app, but nothing in this audit can ship until it is fixed: the
main app is now at build 16 while the watch app and the widget are still stamped build
15. App Store Connect rejects or flags uploads where an embedded bundle's build number
does not match the app's, so the next archive fails validation and someone has to
hand-edit three files to get out of it — which has already happened three times in
this repo's history.

**Root cause.** An asymmetry in how the three targets get their version, plus a manual step upstream
of it. The Caelyn target sets GENERATE_INFOPLIST_FILE: YES (project.yml:108), so Xcode
synthesises CFBundleVersion from CURRENT_PROJECT_VERSION and overrides whatever the
checked-in plist says. The CaelynWidget and CaelynWatch targets have no
GENERATE_INFOPLIST_FILE at all — only INFOPLIST_FILE — so for them the plist file is
the single source of truth, and that file hardcodes the bare literal 15. Those
literals originate upstream in project.yml (verified: `CFBundleVersion: "15"` at :182
for the widget and :221 for the watch, against `CURRENT_PROJECT_VERSION: 16` at :24),
which means `xcodegen generate` re-asserts 15 rather than repairing it. Xcode only
expands $(...) tokens that are physically present in the file, so the project-level
CURRENT_PROJECT_VERSION these targets already inherit can never reach their bundles.
project.yml:21-23 documents the manual chore and the ITMS-90473 consequence — the
documentation of a trap, in place of its removal.

**Fix.**

1. 1. In project.yml, replace the widget literals (:182-183) and the watch literals
   (:221-222) with `CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"` and
   `CFBundleShortVersionString: "$(MARKETING_VERSION)"`. Quote both so YAML never
   reinterprets the leading $.
2. 2. Run `xcodegen generate` and commit the two regenerated plists — they should then
   contain the variables, not a number.
3. 3. Delete the "keep the widget/watch CFBundleVersion below identical" instruction
   at project.yml:21-23. Once the variables are in place, no human step remains, and
   leaving the instruction invites someone to "helpfully" hardcode a number again.
4. 4. Do NOT instead add GENERATE_INFOPLIST_FILE: YES to these two targets — it
   synthesises extra keys and risks disturbing the hand-specified NSExtension,
   WKApplication and WKCompanionAppBundleIdentifier entries these plists carry.
5. 5. Expansion is already proven in these exact files: CaelynWatch/Info.plist uses
   $(DEVELOPMENT_LANGUAGE), $(EXECUTABLE_NAME), $(PRODUCT_BUNDLE_IDENTIFIER) and
   $(PRODUCT_NAME), all of which resolve in the built products. Both embedded targets
   inherit CURRENT_PROJECT_VERSION and MARKETING_VERSION from the project level.
6. 6. While here, note the adjacent trap recorded at project.yml:188-196: the watch's
   `deploymentTarget:` key does not reach the generated pbxproj; only
   WATCHOS_DEPLOYMENT_TARGET in settings.base takes effect. Verify MinimumOSVersion in
   the built watch plist in the same pass.

*Files:* `project.yml`, `CaelynWidget/Info.plist`, `CaelynWatch/Info.plist`, `Caelyn.xcodeproj/project.pbxproj`

*Tests:* No unit test. Add a release-checklist line: after archiving, run `plutil -p` on the
embedded .appex and watch app Info.plist and confirm CFBundleVersion matches the
app's. A CI grep asserting no bare-integer CFBundleVersion in project.yml would hold
the line permanently.

#### widgets:W-04, watch:W-07 — Widgets + Watch companion (WidgetDataSyncModifier.sync / PurchaseService.isPro)

A paying subscriber opens the app and her widgets flip to "Upgrade for richer widgets"
— and stay that way until she next backgrounds the app. The same race skips the watch
push entirely, so her watch shows nothing new. It happens because on a cold launch the
app asks "is she Pro?" before the App Store has answered, hears "no", and writes that
"no" into the widget file. Buying Pro in the app has the same problem in reverse: the
widgets do not light up until she leaves the app.

**Root cause.** isPro has no "unresolved" state, and the snapshot's first write always lands inside
the unresolved window. PurchaseService.isPro is `proOverride ??
!purchasedProductIDs.isEmpty` (PurchaseService.swift:45); purchasedProductIDs starts
[] (:28) and is only filled by refreshPurchasedProducts() (:154-162), which suspends
on `for await result in Transaction.currentEntitlements` — a StoreKit IPC round trip
kicked off by an unawaited Task in init (:37). sync() samples that property at
.onAppear and at scenePhase .active (WidgetDataSync.swift:125-128, verified), both
typically within the first frames. Because WidgetDataStore.write replaces the whole
snapshot wholesale (:249-254) and the widget timeline policy is seven days out
(CaelynWidgetProvider.swift:50), the first post-launch sync does not merely miss the
flag — it overwrites last launch's correct isPro:true with false and pins it. Nothing
observes the property, so the later resolution triggers no re-sync.

**Fix.**

1. 1. Add `private(set) var entitlementsResolved = false` to PurchaseService and set
   it in refreshPurchasedProducts() itself, on the line immediately after
   `purchasedProductIDs = ids` (PurchaseService.swift:161). Never reset it, so a later
   slow refresh cannot re-open the unknown window.
2. 2. Set it in overridePro(_:) too (PurchaseService.swift:48) so --screenshot-mode
   stays hermetic and never consults a stale on-disk snapshot.
3. 3. Never downgrade on unknown: when entitlementsResolved == false, carry forward
   the PREVIOUS snapshot's isPro (read WidgetDataStore before writing) instead of
   writing false. Apply at BOTH sampling sites — WidgetDataSync.swift:135 and
   CloudSyncCoordinator.swift:98 — not just the first.
4. 4. Announce the change at the single mutation point rather than observing it per-
   view: have refreshPurchasedProducts() post a NotificationCenter notification (or
   call an injected onEntitlementsChanged closure) after assigning
   purchasedProductIDs, and have the DerivedState funnel (widgets:W-06 / watch:W-05)
   subscribe. This is strictly better than `.onChange(of:
   PurchaseService.shared.isPro)` on the modifier, because the modifier lives INSIDE
   AppLockGate (CaelynApp.swift:31-38) and may not be mounted while the app is locked,
   and because a view-level observer does nothing for CloudSyncCoordinator's
   independent write path.
5. 5. Call the same announcement after a successful purchase and after restore, so the
   widgets light up without leaving the app.

*Files:* `Caelyn/Services/PurchaseService.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* New unit test with an injectable entitlement state: building with resolved == false
preserves the previous snapshot's isPro; resolved == true overwrites it. New: the
entitlement announcement triggers exactly one DerivedState.refresh. No existing test
asserts isPro timing, so nothing needs changing.

---

### P3 (120)

#### ACC-08 — 24/25 — Apple's one-time name capture (AccountSession.apply)

Apple hands an app the user's name exactly once, ever. If Caelyn's database is reset
in any way after that — she deletes and reinstalls without sync, the store is
recovered after corruption, or the app is killed in the two seconds between Apple
answering and Caelyn saving — the name is gone for good. She is asked 'What should
Caelyn call you?' with an empty field, even though Apple already told Caelyn her name.

**Root cause.** Apple's one-time name payload is persisted only in the app's SwiftData container
(AccountSession.apply writes the user ID to the Keychain immediately at :30 but the
suggested name to the profile at :45, saved only when the caller later runs
saveOrLog), while the 'this name has already been delivered' latch that makes it one-
time lives server-side at Apple and is permanent. Any event that resets the container
without resetting Apple's latch — delete+reinstall (Persistence.swift:118-121 simply
opens an absent container), the preserve-aside recovery or the in-memory fallback
(:135-156) — destroys the only copy of a value that can never be re-obtained. The
Keychain's ThisDeviceOnly item outlives the container; the SwiftData row does not.

**Fix.**

1. 1. Add a second Keychain account 'appleSuggestedName' to AccountIdentityStore —
   same service, same kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly accessibility.
2. 2. Write it inside AccountSession.apply's .authorized branch at the same step as
   save(appleUserID:) (AccountSession.swift:30), guarded by the same
   PersonalName.fromApple filter so a private-relay address can never land there.
3. 3. Have namePrefill/nameFieldDraft (:119-140) fall back to the Keychain copy after
   profile.appleSuggestedName — keep the SwiftData field so a synced second device
   still sees the suggestion via ProfileStore.merge:83.
4. 4. ORDER: land this AFTER the wipe-registry item, or 'Delete all data' will start
   preserving her name across a wipe — the new item must be in the purge list from the
   day it exists.
5. 5. Also clear it in deleteAccount, alongside the existing identity clear, so
   'Delete Caelyn account' still removes everything Caelyn holds from Apple.
6. 6. Accept the limit honestly: users who already signed in and lost the suggestion
   cannot be recovered — Apple will not resend. No backfill is possible.

*Files:* `Caelyn/Services/Account/AccountIdentityStore.swift`, `Caelyn/Services/Account/AccountSession.swift`, `Caelyn/Services/Account/AppleSignInOutcome.swift`, `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* SignInWithAppleComplianceTests.testDeletingTheAccountRemovesEverythingCaelynHoldsFromA
pple: extend to assert the Keychain name is gone. AccountTests: add 'profile lost,
Keychain kept → prefill is still Maya'. Add a wipe test asserting the Keychain name
does not survive wipeEverything.

#### ACC-09, ACC-10 — 24 Account offer — AccountOfferPolicy.isDue and when the offer is recorded as answered  *(unconfirmed)*

Two contradictions in the offer. First, after a wipe, a reinstall or a reset of
onboarding, Settings says 'Signed in' while the app simultaneously offers her Sign in
with Apple. Second, if the app is killed while she is on the 'What should Caelyn call
you?' step, the question is never asked again — the headline 1.3 feature silently
never happens — and later, tapping 'Sign out' in Settings pops the 'Make Caelyn yours'
sheet on top of the screen she is standing on.

**Root cause.** The offer's state is derived from flags that do not reflect what actually happened.
(a) TWO SOURCES OF TRUTH for per-device sign-in with no reconciliation:
AccountOfferPolicy.isDue reads only the synced profile flags
(AccountOfferPolicy.swift:25-38), while 'signed in on this device' also lives in the
Keychain, which SettingsView.accountRowDetail (:446-450) and AccountView read directly
— so whenever the profile is recreated (a wipe, a reinstall,
SettingsView.resetOnboarding, or a crash after the Keychain write at
AccountSession.swift:30 but before the caller's saveOrLog) accountLinked is false
while the Keychain holds an ID. (b) THE 'ANSWERED' FLAG IS WRITTEN AT THE END OF A
MULTI-STEP FLOW rather than at the decision point: finish() sets hasSeenAccountOffer
only after Continue or Not now (AccountOfferSheet.swift:123-150), while a successful
apply() sets accountLinked=true immediately (AccountSession.swift:29-31) — and nothing
at launch re-asks a signed-in, unconfirmed user.

**Fix.**

1. 1. Add `isSignedInOnThisDevice:` to AccountOfferPolicy.isDue and pass
   AccountIdentityStore.isSignedIn; return false when the Keychain holds an ID.
2. 2. Heal the contradiction rather than only hiding it: in reconcileAppleCredential,
   set profile.accountLinked = true when Apple reports .authorized and the profile
   says false.
3. 3. Set hasSeenAccountOffer = true immediately after a successful apply() — signing
   in IS an answer — either in AccountOfferSheet.signIn or inside
   AccountSession.apply(.authorized). This removes the kill-mid-step hole and the
   absurd 'Sign out pops the offer over Settings' sequence in one move.
4. 4. Add the missing re-ask: at launch, if AccountIdentityStore.isSignedIn &&
   !profile.hasConfirmedPreferredName, present PreferredNameStep once using the same
   raise-only latch pattern (and the lock gate from the ACC-04 item).
5. 5. Depends on the wipe-registry item: once a wipe clears the Keychain identity,
   case (a) stops arising from wipes and only reinstall/crash paths remain — but the
   reconciliation is still needed for those.

*Files:* `Caelyn/Services/Account/AccountOfferPolicy.swift`, `Caelyn/Views/Settings/AccountOfferSheet.swift`, `Caelyn/Services/Account/AccountSession.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* AccountOfferTests: the Keychain-signed-in case (probe 1). AccountTests:
reconcile(.authorized) heals accountLinked. AccountOfferPresentationTests: the kill-
mid-flow case (probe 2); and signing out does not immediately re-raise the offer.

#### ACC-11, ACC-16 — 24 Optional Sign in with Apple — revocation observation and AccountView's cached signed-in state  *(unconfirmed)*

If she revokes Caelyn's access from Apple's own settings — on her Mac or iPad, or
while the Account screen is open — Caelyn keeps showing 'Signed in with Apple' with
the Sign out and Delete account rows underneath. It corrects itself on the next visit
or next foreground, but until then the screen is simply wrong.

**Root cause.** Identity state is mirrored into view state and refreshed only on a foreground poll,
and the one push signal is unobserved. (a) AppleSignInService exposes
ASAuthorizationAppleIDProvider.credentialRevokedNotification with a comment describing
when Apple posts it (AppleSignInService.swift:70-74), but grep finds no subscriber
anywhere — revocation is handled only on scenePhase == .active
(CaelynApp.swift:72-85). (b) AccountView's isSignedIn is a @State seeded at init (:20)
and in the one-shot .task (:55-59), then set manually by the view's own actions;
reconcileAppleCredential signs out through AccountSession without touching the view,
and the cards are keyed on isSignedIn (:146) rather than on profile.accountLinked or
the Keychain.

**Fix.**

1. 1. Observe the push signal in CaelynApp:
   `.onReceive(NotificationCenter.default.publisher(for:
   AppleSignInService.revocationNotification)) { _ in Task { await
   reconcileAppleCredential() } }` — or delete the property if it will not be used, so
   the comment stops describing behaviour that does not exist.
2. 2. Stop mirroring: read AccountIdentityStore.isSignedIn in AccountView's body (a
   cheap Keychain read, exactly as SettingsView.swift:446-450 already does) so the
   screen cannot hold a stale value.
3. 3. If body-reads are undesirable, refresh isSignedIn on scenePhase == .active and
   after reconcile — but prefer step 2, since it removes the class of bug rather than
   one trigger.

*Files:* `Caelyn/Services/Account/AppleSignInService.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* A source-assertion in SignInWithAppleComplianceTests pinning that
credentialRevokedNotification is observed (or absent entirely). No unit test can drive
the view's state; verify on device.

#### ACC-12 — 24 Optional Sign in with Apple — AccountIdentityStore.save / AccountSession.apply  *(unconfirmed)*

In the rare case where the Keychain write actually fails, the screen says 'Signed in'
anyway for the rest of the session — and then, at the next launch, flips back to
'Optional' with no explanation.

**Root cause.** A side-effecting Keychain call is treated as infallible. store() ignores the results
of SecItemDelete and SecItemAdd (AccountIdentityStore.swift:41-44, 55-66);
apply(.authorized) returns true unconditionally and sets accountLinked = true
(AccountSession.swift:29-31, 47-48); AccountView then sets isSignedIn from that return
value rather than from the Keychain (:193-195). An entitlement or keychain-access-
group misconfiguration, errSecInteractionNotAllowed or a full disk therefore produces
a phantom sign-in.

**Fix.**

1. 1. `save(appleUserID:) -> Bool` returning `status == errSecSuccess`, logging the
   OSStatus on failure.
2. 2. apply() returns false and leaves the profile untouched when the save fails — do
   not set accountLinked on an unsaved identity.
3. 3. AccountView derives isSignedIn from AccountIdentityStore.isSignedIn after apply,
   not from the return value (this also falls out of the ACC-11/ACC-16 item's body-
   read change).
4. 4. Surface the failure to her with one line rather than a silent no-op.

*Files:* `Caelyn/Services/Account/AccountIdentityStore.swift`, `Caelyn/Services/Account/AccountSession.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* Existing AccountTests pass (the Keychain works in-process). The negative path needs an
injectable Keychain shim if it is worth testing; otherwise assert only that save
returns true on success and that apply returns false when save returns false.

#### ACC-13 — 24 Optional Sign in with Apple — AppleSignInService.signIn / AccountView.signIn re-entrancy  *(unconfirmed)*

A fast double-tap on Sign in with Apple in Settings can start two authorizations: one
of them hangs forever and a second Apple sheet may appear or fail to appear.

**Root cause.** Single-slot continuation storage with no busy check, and the guard exists in only one
of the two callers. AppleSignInService.signIn() unconditionally overwrites
self.continuation and self.controller (AppleSignInService.swift:15-18, 36-48);
finish() resumes whichever continuation is current and nils it (:76-80), so the first
Task never resumes (leaked CheckedContinuation). AccountOfferSheet has an isWorking
flag plus .disabled; AccountView.signIn (:165-177, 188-205) has neither.

**Fix.**

1. 1. In the service: `guard continuation == nil else { return .cancelled }` at the
   top of signIn() — the guard belongs at the single-slot resource, not in each
   caller, so no future caller can reintroduce it.
2. 2. Add an isWorking @State to AccountView mirroring the offer sheet, for button
   feedback and to disable the control while in flight.

*Files:* `Caelyn/Services/Account/AppleSignInService.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Views/Settings/AccountOfferSheet.swift`

*Tests:* None existing; the service is device-only. A unit test is possible if the guard is
extracted to a testable `isBusy` property: assert a second signIn while busy returns
.cancelled without touching the stored continuation.

#### ACC-14 — 24/25 — AccountSession.apply, suggested-name capture across identities  *(unconfirmed)*

On a shared device: she signs in, signs out without finishing the name step, and
someone else signs in with a different Apple ID. The name step prefills with the FIRST
person's name and claims Apple suggested it.

**Root cause.** The 'first name wins' guard keys on field emptiness, not on identity: apply() stores
Apple's name only when appleSuggestedName == nil (AccountSession.swift:43-46) and
never compares the incoming userID with the stored one; signOut() — unlike
deleteAccount — does not clear appleSuggestedName.

**Fix.**

1. 1. In apply(), read AccountIdentityStore.appleUserID BEFORE saving the new one; if
   it differs from the incoming userID, replace appleSuggestedName with the new
   suggestion (or nil) instead of keeping the old one.
2. 2. Key the guard on identity, not emptiness — that is the mechanism fix and it also
   covers a re-sign-in by the same ID (where Apple sends nothing and the stored
   suggestion should correctly survive).
3. 3. If the Keychain suggested-name copy from the ACC-08 item has landed, clear that
   too on an identity change.

*Files:* `Caelyn/Services/Account/AccountSession.swift`, `Caelyn/Services/Account/AccountIdentityStore.swift`, `Caelyn/Views/Settings/AccountView.swift`

*Tests:* SignInWithAppleComplianceTests already has the deletion variant
(testSigningInAgainAfterDeletionStartsClean); add the sign-out variant (see probe),
plus a same-ID re-sign-in case asserting the existing suggestion is kept.

#### ACC-15 — 25 Preferred name — ProfileStore.merge of preferredName / hasConfirmedPreferredName  *(unconfirmed)*

She deliberately clears her name so Caelyn stops greeting her by it. If two profile
rows exist, the next launch brings the name back — with nothing to explain it. And
when both devices have a name on record, the older row's name always wins even if she
chose a different one more recently.

**Root cause.** The name merge has no intent or recency signal. merge() ORs hasConfirmedPreferredName
and nil-coalesces preferredName independently of each other (ProfileStore.swift:76-83
— verified: the OR block and the 'a value she chose beats one nobody did' nil-fill are
separate), so nil cannot express 'cleared on purpose' (AccountSession.swift:100-106
treats clearing as an answer) and the confirmed flag is merged apart from the name it
qualifies. The keeper is also chosen by createdAt age alone, so the older row's name
wins regardless of which decision was more recent.

**Fix.**

1. 1. Merge preferredName and hasConfirmedPreferredName as ONE unit: if exactly one
   row is confirmed, its name wins — INCLUDING when that name is nil.
2. 2. If both rows are confirmed, prefer the more recently active row (lastActiveAt).
3. 3. Only when neither is confirmed, nil-coalesce as today.
4. 4. Land this together with the BC-11 merge item — both edit ProfileStore.merge and
   both are instances of 'a hand-written fold decides by row age instead of by whether
   she chose'.

*Files:* `Caelyn/Services/ProfileStore.swift`, `Caelyn/Services/Account/AccountSession.swift`

*Tests:* ProfileStoreTests: add the confirmed-clear case (probe) and the both-confirmed case
where the more recently active row's name wins.

#### ACC-17 — 24 Optional Sign in with Apple — AccountView copy (sign-in card and delete-account message)  *(unconfirmed)*

The sign-in card promises 'an identity that survives reinstalling', but nothing is
actually restored by it — after a reinstall the surviving ID gives her nothing she can
see. And 'Delete Caelyn account' lists what is kept (history, the iCloud copy) without
mentioning that the name she chose is kept too, so Caelyn goes on greeting her by name
after she deleted the account.

**Root cause.** Copy written for an intended benefit the architecture never implemented, plus one
omission. The Apple user ID is consumed only by isSignedIn and the credential check
(AccountSession.swift:63-73, CaelynApp.swift:94) — it keys no CloudKit record, no
server, no restore — yet AccountView.swift:160 promises survival across reinstall.
deleteAccountMessage (:466-470) enumerates kept items but omits preferredName, which
the code keeps on purpose.

**Fix.**

1. 1. Either make the sentence true by landing the ACC-08 item (the Apple-suggested
   name then genuinely survives reinstalling), or reword to something the code
   delivers — 'a sign-in Caelyn remembers'.
2. 2. Add to deleteAccountMessage: 'The name you chose stays too — clear it above if
   you'd rather not be greeted by it.'
3. 3. Sequence after ACC-08 so the wording matches whichever outcome is chosen.

*Files:* `Caelyn/Views/Settings/AccountView.swift`

*Tests:* SignInWithAppleComplianceTests source assertions on AccountView copy keep passing; add
one pinning the kept-name sentence.

#### BC-13 — 36.h Birth-control notification tap routing and in-app follow-through  *(unconfirmed)*

She taps the pill reminder and lands on the Log screen, where there is nothing about
birth control at all — just a free-text medication box. There is no way to mark the
pill as taken, no 'Taken' button on the notification itself, and no record of whether
she took it. A missed-pill pattern, which is clinically meaningful, is invisible to
her and to her doctor.

**Root cause.** Birth control was implemented as reminder-only with no model surface — no entry field,
no notification action category — so routing had nowhere meaningful to go and
defaulted to the Log tab alongside medication. MainTabView.tab(for:) sends
.birthControl to .log (:130-136); the 2.5 s highlight broadcast (:141-155) lands on
nothing because no view under Caelyn/Views/Log reads highlightedNotificationCategory;
DailyLogForm has only the medication text field (:926-937); and grep finds no
setNotificationCategories or UNNotificationAction anywhere in the repo.

**Fix.**

1. 1. Register a `caelyn.birthcontrol` UNNotificationCategory with actions 'Taken' and
   'Remind me in 15 minutes'.
2. 2. On 'Taken', write a lightweight per-day flag — an additive, optional
   `CycleEntry.birthControlTaken: Bool?` or a small dedicated model — and suppress
   today's remaining reminder.
3. 3. Route taps to Home with a 'Pill today — Taken / Not yet' chip that also reads
   highlightedNotificationCategory, so the highlight pulse finally has a target.
4. 4. Unrealized potential, once the data exists: adherence streaks in Insights, and
   method + missed days in the PDF report.
5. 5. Depends on the plan-extraction item for the per-event identity (which
   notification is which).

*Files:* `Caelyn/Views/MainTabView.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* New model tests for the per-day flag (optional/defaulted so CloudKit mirroring accepts
it) and schedule-suppression tests; a UI test for the Home chip and for the tap
landing somewhere that represents birth control.

#### BC-14 — 36.e NotificationService.syncFromLiveStore in demo / screenshot / UI-test modes  *(unconfirmed)*

No end-user impact. In screenshot and UI-test runs, toggling Birth Control Mode
reaches into the real on-disk store instead of the hermetic test container, which can
make the UI suite order-dependent.

**Root cause.** The demo-mode guard was placed at one caller instead of inside the single entry point.
CaelynApp selects the preview/screenshot container and guards its own scenePhase sync
with those flags (CaelynApp.swift:66-75), but syncFromLiveStore reads
Persistence.live.mainContext unconditionally (NotificationService.swift:327-329).
BirthControlView.save() (:142-145) therefore opens the live store during a
--screenshot-mode UI test (CaelynUITests.swift:553-569, 776-786).

**Fix.**

1. 1. `guard !Persistence.isDemoStore else { return }` at the top of syncFromLiveStore
   — and of scheduleNoteReminders — so the guard lives at the entry point rather than
   at one caller.
2. 2. Better still: have syncFromLiveStore take a ModelContext from the environment so
   a demo container syncs against itself with a no-op notification centre; the hard-
   coded Persistence.live is the actual mechanism.
3. 3. Preserves d0b31aa's hermeticity contract.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/Persistence.swift`, `Caelyn/Views/Settings/BirthControlView.swift`

*Tests:* UI tests become hermetic; no unit test change. Optionally assert syncFromLiveStore is
a no-op when Persistence.isDemoStore is true.

#### BC-15 — 36.e/36.f NotificationService.sync — cancelAll-then-schedule atomicity  *(unconfirmed)*

If iOS suspends or kills the app in the moment between 'cancel everything' and 'add it
all back' — she taps a setting and immediately swipes the app away — she can be left
with no reminders at all until she next opens Caelyn, with nothing to indicate it.

**Root cause.** sync() awaits cancelAll() (NotificationService.swift:165-166) and then performs up to
~20 sequential `add` awaits, even though scheduleOneShot already uses deterministic
identifiers (:422) that make replace-by-id idempotent. The code removes everything
first instead of removing only the ids absent from the new plan, so the window between
the two states is a window with zero pending reminders.

**Fix.**

1. 1. Compute the full plan first (the pure function from the BC-05/06/07 item).
2. 2. Add or replace every request by its deterministic id.
3. 3. Then remove only the pending Caelyn ids that are NOT in the plan.
4. 4. Combined with the pill's repeating trigger, the worst case becomes a stale-but-
   present reminder rather than none — which is the point: the failure mode changes
   class, not just probability.
5. 5. Depends on the plan extraction landing first.

*Files:* `Caelyn/Services/NotificationService.swift`

*Tests:* Plan-function tests plus a reconciliation test: given a pending set and a new plan,
assert the computed add/remove sets never empty the queue for a category that still
has events. No existing test.

#### EXP-11, EXP-13 — Export — ExportView screen state (formatChip / generate / generatedURL lifecycle)  *(unconfirmed)*

Two small ways the Export screen can hand her the wrong thing. If her Pro access ends
while the sheet is open (a refund lands, or she restores on another device), the PDF
chip shows a lock but the button below still says "Generate PDF" and still works. And
if a log arrives from her watch or her other phone while the sheet is open, the "(N
entries in this range)" line updates but "Share" still hands out the file built before
it.

**Root cause.** ExportView's derived state is set at interaction time and never reconciled with the
inputs it was derived from. `format` is validated only inside the chip handler
(ExportView.swift:130-138) and `generate()` switches on it with no isPro check
(:255-283) — the gate lives where the state can be set, not where the file is
produced. Separately, `resetGeneration()` is wired to range/format/includeNotes only
(:47-49), while `entries` is a live @Query whose count label (:196) and `generatedURL`
(:201-214) therefore render two different generations of the same data.

**Fix.**

1. In `generate()` (ExportView.swift:255), before the switch: `if format == .pdf &&
   !purchase.isPro { format = .csv; showingPaywall = true; return }`. The gate now
   sits at the point of production, which is what makes it permanent against future
   refactors of the chip UI.
2. Add `.onChange(of: purchase.isPro) { _, pro in if !pro && format == .pdf { format =
   .csv } }` so the visible selection cannot survive an entitlement change.
3. Add `.onChange(of: filteredEntries.count) { _, _ in resetGeneration() }` plus a
   cheap data fingerprint (max `updatedAt` across filteredEntries) so a sync arrival
   or Watch log invalidates the generated file. Once the snapshot item (EXP-12) lands,
   compare the snapshot's hash instead and delete the two ad-hoc onChange handlers.
4. Add a UI test launched with `--screenshot-paywall` (Pro false,
   CaelynApp.swift:46-51) that taps the PDF chip, asserts the paywall appears and that
   no "Generate PDF" button ever exists — the locked path currently has zero coverage
   because the only export UI test runs under `--screenshot-mode`, which calls
   overridePro(true).

*Files:* `Caelyn/Views/Settings/ExportView.swift`, `CaelynUITests/CaelynUITests.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* New UI test for the free-tier PDF lock. No existing test changes.

#### EXP-12 — Export — ExportView.generate / ExportService (main-actor generation)  *(unconfirmed)*

On a long history, tapping Generate freezes the screen for a second or more and the
button never shows "Generating…" — the app looks hung during the one action a long-
time user performs on her richest data.

**Root cause.** `Task { await generate() }` sets `isGenerating = true` and then calls
generateCSV/generatePDF with no suspension point before the `defer { isGenerating =
false }` (ExportView.swift:255-283), so SwiftUI never gets a run-loop turn between the
two state writes and the whole render happens inside one main-actor block. The work
was deliberately kept on the main actor because SwiftData @Model objects are non-
Sendable (the comment at :260-263 names the intended fix), and the report itself is
expensive: PatternEngine.insights plus two separate `CycleModel.make` calls per report
(ExportService.swift:118-131, :207, :257).

**Fix.**

1. Define `struct ExportEntry: Sendable` (every exported field plus `dayKey`) and
   `struct ExportProfile: Sendable` (gentleModeEnabled, averageCycleLength,
   averagePeriodLength, customSymptoms, lastPeriodStart).
2. Snapshot filteredEntries and profile into those value types on the main actor, then
   `await Task.detached(priority: .userInitiated) {
   ExportService.generateCSV(snapshot…) }`. The @Model objects never leave the main
   actor, so the stz-002 data race the comment guards against stays closed.
3. Make ExportService pure over the value types. Side benefit: its tests no longer
   need a ModelContainer.
4. Compute `CycleModel` once per report and pass it to drawClinicalSummary and
   drawInsightsSection instead of calling `CycleModel.make` twice
   (ExportService.swift:207, :257).
5. Insert one `await Task.yield()` after setting `isGenerating = true` so the
   "Generating…" label actually paints even on fast devices.

*Files:* `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* Existing export unit tests move to the snapshot type (mechanical: build ExportEntry
values instead of CycleEntry). Add a test asserting generateCSV/generatePDF compile
and run off the main actor.

#### EXP-14 — Export — ExportRange.lookbackDays / ExportService.filterEntries  *(unconfirmed)*

"Last 3 months" is actually the last 90 days, so on 4 October it starts on 6 July
instead of 4 July. An entry from the 4th or 5th of July is missing from a report
labelled three months.

**Root cause.** The range is modelled as a day count rather than as calendar months: `lookbackDays`
returns 90/180/365 (ExportService.swift:30-37) and filterEntries subtracts that many
days from start-of-today (:49-50). The boundary handling itself is correct (inclusive,
start-of-day normalised); only the unit is wrong, and 365 also drops a day in leap
years.

**Fix.**

1. Replace `lookbackDays: Int?` with `months: Int?` on ExportRange (3 / 6 / 12 / nil).
2. In filterEntries compute `cutoff = calendar.date(byAdding: .month, value: -months,
   to: startOfDay(today))`, keeping the inclusive `>=` comparison and the start-of-day
   normalisation that plat-13 added.
3. Keep the comparison keyed to the stored day (CivilDay/dayKey) so the timezone work
   from 37dddd7 / 9776951 is not undone.
4. Update CaelynTests.testExportRangeLookbackDays, which asserts 90/180/365 today.

*Files:* `Caelyn/Services/ExportService.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* testExportRangeLookbackDays must change (it asserts the day counts).
testFilterEntriesByRangeCutoff and testFilterEntriesIncludesBoundaryDay still pass;
add a leap-year case and a 4-Oct → 4-Jul boundary case.

#### EXP-15 — Export — ExportView.optionsSection / ExportService.generateCSV (private notes scope)  *(unconfirmed)*

"Include private notes" removes her diary entries but still exports her medication
free text (drug names and doses) and the custom symptom names she wrote herself — and
the toggle defaults to ON, so a quick "Generate PDF" for a doctor includes her diary
unless she notices the switch.

**Root cause.** The toggle is wired to exactly one field. `includeNotes` gates only the `note` column
and the PDF notes section (ExportService.swift:84, :130), while `medication` (:90-93)
and custom symptom names are written unconditionally. The default was chosen for
completeness of the backup rather than for the clinical handout, and the subtitle
(ExportView.swift:182-187) describes a broader scope than the code implements.

**Fix.**

1. Product decision first — these are mutually exclusive: (a) widen the toggle to
   "Include notes and medication" and gate the medication column and PDF table cell on
   it, or (b) keep the scope and rewrite the subtitle to name exactly what is and is
   not excluded.
2. If (a): gate ExportService.swift:84 and the PDF entry-table medication column on
   `includeNotes`; custom symptom names cannot be gated without breaking the round
   trip, so say so in the subtitle.
3. Consider defaulting `includeNotes` to false when format == .pdf and true when
   format == .csv (ExportView.swift:12): the backup wants everything, the clinical
   handout should not leak a diary by default. This is a privacy-first default, not a
   feature change.
4. Whatever is chosen, make the subtitle generated from the gated column list rather
   than hand-written, so a future column cannot silently fall outside the promise.

*Files:* `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* testCSVHeaderRowMatchesIncludeNotes extends if medication is gated. Add: with
includeNotes false the PDF contains no medication string.

#### EXP-16 — Export — PredictionEngine.mostFrequentSymptom / CycleAnalytics.symptomFrequency as rendered in the PDF  *(unconfirmed)*

Generating the same report twice from identical data can name a different "Most common
symptom" and reorder the bar chart — which undermines trust in a document she hands to
a doctor.

**Root cause.** Both helpers resolve ties by dictionary iteration order, which Swift does not
guarantee between runs: `counts.max(by: { $0.value < $1.value })` over a `[Symptom:
Int]` (PredictionEngine.swift:385-392) and `sorted { $0.value > $1.value }` in
CycleAnalytics.symptomFrequency, neither with a secondary key. Both feed the PDF
(ExportService.swift:228, :336).

**Fix.**

1. In PredictionEngine.mostFrequentSymptom, replace `max(by:)` with `counts.sorted {
   ($0.value, $1.key.rawValue) > ($1.value, $0.key.rawValue) }.first` — or
   equivalently break the tie on `rawValue` ascending.
2. Apply the identical secondary key in CycleAnalytics.symptomFrequency's sort.
3. Add a brief comment on both stating that a clinical report must be byte-
   reproducible from the same data, so nobody removes the tie-break as redundant.

*Files:* `Caelyn/Services/PredictionEngine.swift`, `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* None break. Add a tie fixture (two symptoms at equal count) and assert the same
symptom and the same chart order across 100 repeated calls.

#### EXP-17 — Export — CSV fidelity and PDF polish (generateCSV / CaelynExportSource.cell / PDF drawing)  *(unconfirmed)*

Seven small ways the exported file and report fall short of "trustworthy": a
temperature imported from Health comes back rounded (36.4567 → 36.46), a note that
starts with a blank line is altered on import, days with nothing logged appear as
empty rows, a 45-page PDF has no page numbers, one table column runs 12 points past
the margin, and an all-time timeline labels days without years so "Mar 4" could be any
year.

**Root cause.** Independent small omissions, each at a single site rather than one shared mechanism:
(a) BBT written with `String(format: "%.2f")` (ExportService.swift:85); (b) `cell()`
trims whitespace and newlines from every column including the free-text ones
(CaelynExportSource.swift:56-60); (c) generateCSV iterates all entries with no
`hasContent` filter (CycleEntry.swift:95-110); (d) `escape()` quotes on , " \n but not
a bare \r, contrary to RFC 4180 §2.6 (ExportService.swift:100-104) — theoretical, iOS
keyboards never emit one; (e) table column widths sum to 512 pt against a 500 pt
content width (:380-381); (f) drawFooter writes no page number (:466-471); (g)
timeline labels use "MMM d" with no year (:297, :316).

**Fix.**

1. (a) Write basalTemperature with up to 4 decimals and no trailing zeros, so a
   HealthKit value round-trips exactly.
2. (b) In CaelynExportSource.cell, trim only the non-text columns; pass `note` and
   `medication` through with their leading/trailing whitespace intact (still treat an
   all-whitespace cell as empty).
3. (c) `entries.filter(\.hasContent)` before writing CSV rows, so a draft-seeded empty
   day never becomes a blank row in her backup.
4. (d) Add "\r" to escape()'s trigger set.
5. (e) Reduce the Symptoms column to 168 pt so the widths sum to 500.
6. (f) Stamp "Page N of M" in drawFooter — two-pass render, or post-process the
   PDFDocument with PDFKit after rendering.
7. (g) Use "MMM d, yyyy" for timeline labels whenever the rendered span crosses a
   calendar year.
8. Land (a)–(d) together with the round-trip item (EXP-06/EXP-07): they are the same
   file-fidelity contract and the same two files.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Services/Import/Sources/CaelynExportSource.swift`, `Caelyn/Models/CycleEntry.swift`

*Tests:* testCSVRowsMatchEntryCount builds entries with content, so (c) does not break it — but
confirm. Add: a 4-decimal BBT round-trips exactly; a note beginning with "\n" survives
import; a content-less entry produces no row; a 45-page PDF contains "Page 2 of".

#### EXP-19 — Export — ExportView.rangeRow / formatChip accessibility  *(unconfirmed)*

A VoiceOver user cannot tell which date range or file format is currently selected —
the selection is only drawn (a checkmark, a filled chip) — and the PDF lock is
announced only as the word "PRO" tacked onto the button name.

**Root cause.** Both controls are custom Buttons with no accessibility traits
(ExportView.swift:98-117, :130-177): neither adds `.isSelected`, and the lock badge is
a decorative Image with no label, so the only spoken hint is the visible "PRO" Text
read as part of the button name.

**Fix.**

1. Add `.accessibilityAddTraits(range == option ? .isSelected : [])` to rangeRow and
   the equivalent on formatChip.
2. Add `.accessibilityLabel(locked ? "PDF, Caelyn Pro required" : option.displayName)`
   on the format chip, and `.accessibilityHidden(true)` on the decorative lock image.
3. Keep the visible label text unchanged. Note that setting accessibilityLabel
   replaces the element's name, so CaelynUITests.testSettingsAndDataToolsJourney's
   `app.buttons["PDF"]` query must become a BEGINSWITH 'PDF' predicate.
4. Audit the same file for any other custom selection control before closing this out,
   so the trait is applied as a rule rather than at two sites.

*Files:* `Caelyn/Views/Settings/ExportView.swift`, `CaelynUITests/CaelynUITests.swift`

*Tests:* CaelynUITests.testSettingsAndDataToolsJourney taps buttons["PDF"]/["CSV"] — update the
queries. Add an accessibility assertion that the selected range reports isSelected.

#### F-29-07 — 29 TTC fertility score — empty states and card copy  *(unconfirmed)*

A brand-new TTC user who has not logged a period yet is shown a confident-looking
10-out-of-100 fertility gauge about nothing. A woman who logs her temperature, her
strip and her mucus every day is still told "Log your BBT, LH strip, and cervical
mucus for a more accurate score." On the last day of her fertile window the card says
"0 days remaining". And unlike every comparable card, this one carries no "estimate,
not medical advice" line.

**Root cause.** `FertilityResult` has no empty or insufficient-data state: with `nextPeriodStart ==
nil` the engine still returns a number (score 10, empty signals —
TTCFertilityEngine.swift:36-38), so the view has nothing to distinguish "low
fertility" from "nothing to say". The footer is a static literal
(TTCDashboardCard.swift:56-58) rather than derived from which signals are actually
missing, and the remaining-days arithmetic has no last-day branch (:48-53).

**Fix.**

1. Add an insufficient-data case to FertilityResult (e.g. `score: Int?` or an explicit
   `state` enum) and return it when `nextPeriodStart == nil`. The card then renders
   "Log a period so Caelyn can place your fertile window" and no gauge.
2. Derive the footer from the missing subset of {BBT, LH, mucus} on today's entry:
   name only what is absent ("Add an LH strip for a sharper score"), and show nothing
   when all three are present.
3. Add a last-day branch: when daysLeft == 0, say "Last day of your fertile window"
   rather than "0 days remaining".
4. Add one caption matching the house disclaimer style: "An estimate from what you log
   — not medical advice."
5. Build on the ledger item (F-29-02) so the empty state and the signal list come from
   one representation.

*Files:* `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Views/Home/TTCDashboardCard.swift`

*Tests:* No existing tests. Add: nil nextPeriodStart yields the insufficient state and no
score; a day with all three signals logged produces an empty footer; daysLeft == 0
renders the last-day wording.

#### F-29-08 — 29 TTC fertility score — testability and CycleModel.lutealLength cost  *(unconfirmed)*

No user-visible wrong answer, but two things that make the app slower the longer she
uses it and make this feature impossible to test: the fertility engine reads the clock
directly, and Home recalculates her learned luteal length about a dozen times on every
single render, scanning her entire history each time.

**Root cause.** Two separate mechanisms in one finding. (a) `TTCFertilityEngine.result` hard-codes
`Calendar.current.startOfDay(for: Date.now)` (TTCFertilityEngine.swift:26), so it
cannot be pinned to a date in a test and ignores the calendar the rest of the
derivation has honoured since 060c36d. (b) `CycleModel.lutealLength` and
`pmsDaysBefore` are computed properties that re-run a filter+map+sort over every entry
on each access (CyclePrediction.swift:184-205) — deliberately lazy, to avoid the Log
tab over-observing SwiftData, but never memoised within an instance. Home reads them
via `phase` (HomeView.swift:149, 158, 250, 281), guidePersonal (:70-76, :87),
fertileWindow (:249), daysUntilFertileWindowStart (:248) and ttcResult (:136) —
roughly a dozen full passes per render. The a1ca071 fix cached `make`, not these.

**Fix.**

1. Add `today: Date = .now, calendar: Calendar = .current` to
   `TTCFertilityEngine.result` and thread them from HomeView (`today`,
   `cycle.calendar`). Defaults keep every existing call site unchanged.
2. Memoise `lutealLength` and `pmsDaysBefore` inside CycleModel using a private final
   class box — the same non-observable pattern already used for HomeView.DerivedCycle
   — so first access computes and later accesses return the cached value. Laziness is
   preserved (the Log tab still never touches them) and the cost is paid once per
   model instance.
3. Confirm the box is not Observable, or the memoisation reintroduces exactly the
   over-observation the laziness was added to prevent (the keyboard-focus bug noted in
   CyclePrediction.swift:184-195).

*Files:* `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Models/CyclePrediction.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* Existing tests pass unchanged (defaults preserved). Enables the deterministic TTC
tests in F-29-09. Add a performance guard: 12 reads of lutealLength on five years of
history costs one computation.

#### F-29-09 — 29 TTC fertility score — test coverage

The whole TTC fertility feature ships with no automated tests at all. The green
590-passing run says nothing about it, which is why every other problem in this
feature reached real users.

**Root cause.** The planned test file `CaelynTests/TTCFertilityEngineTests.swift` (listed as a qa-3
deliverable at docs/BUILD_PLAN.md:57) was never written, so the engine shipped behind
a Pro + ttcEnabled gate (HomeView.swift:227-228) with 0 of 591 test functions touching
it. Testability was not the blocker: three of the four scoring sections, the clamp and
all four label boundaries (TTCFertilityEngine.swift:41-79) are pure in `todayEntry`,
and section 1 is testable with dates built relative to Date.now — the idiom the suite
already uses at CaelynTests.swift:899 and :926.

**Fix.**

1. Do NOT gate this on the injection item (F-29-08). Land
   CaelynTests/TTCFertilityEngineTests.swift now, table-driven.
2. Tier 1, zero refactor: every LH case (+30/+20/+10/−5), every mucus case
   (+20/+12/+5/−5/−10), both BBT bands and the implicit below-36.3 no-op, the nil-
   nextPeriodStart +10 path, the clamp at both ends (dry + negative + elevated BBT
   with no prediction → floor 0; ovulation day + positive LH + egg-white + pre-shift
   BBT → ceiling 100), and each label cut-point from both sides: 24/25, 49/50, 74/75.
3. Also assert today's defects so the fixes are pinned rather than assumed: that
   `signals` omits the penalty branches (the ledger item will flip these), and that
   the displayed list sums to the score once it does.
4. Tier 2, after F-29-08 lands: date-dependent cases with an injected `today` —
   ovulation day, fertile window edges, the day after the window closes, and the
   learned-luteal case from the fertile-window item.
5. Add the two wrist-engine gaps while the file is open: cycle boundaries, date gaps
   and baseline outliers currently have no coverage beyond the two happy-path tests at
   CaelynTests.swift:924-942.

*Files:* `CaelynTests/TTCFertilityEngineTests.swift`, `CaelynTests/CaelynTests.swift`, `Caelyn/Services/TTCFertilityEngine.swift`, `docs/BUILD_PLAN.md`

*Tests:* This item is the tests. New file CaelynTests/TTCFertilityEngineTests.swift; no
existing test changes.

#### F-40-05 — 40 Wrist-temperature ovulation detection — TemperatureShiftCard refresh and confidence  *(unconfirmed)*

If she logs a temperature on the Log tab while Insights is still open behind it, the
temperature-shift card keeps showing the old answer until she leaves the screen and
comes back. And a barely-there 0.21 °C rise is announced in exactly the same confident
words as a clean 0.5 °C one.

**Root cause.** The `.task` has no id (InsightsView.swift:318-322), so it is keyed to view identity
rather than to its inputs and runs once per appearance; `result` then sits in @State
(:294) until the view is torn down — which a tab switch or an iPad split view may
never do. Separately, `Result.confidence` (0.4–1.0, WristTempOvulationEngine.swift:50)
is computed and then ignored: the card reads only `r.detected` (:298).

**Fix.**

1. Change to `.task(id:)` keyed to the actual inputs — a small Hashable key of (cycle
   anchor, bbtSeries.count, latest BBT day, wrist window start) — so the detection re-
   runs whenever the series changes.
2. Clear `result` at the start of each run so a stale answer is not visible while the
   new fetch is in flight.
3. Use `confidence` in the copy: "a clear temperature shift" above roughly 0.7, "a
   possible temperature shift" below — the value already exists and distinguishing the
   two is the difference between honest and over-confident.
4. Fold this in with the consent-gate item (F-40-03): both edit the same five lines of
   that `.task`.

*Files:* `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Services/WristTempOvulationEngine.swift`

*Tests:* No existing tests. Add: the task key changes when a BBT entry is added; low-confidence
and high-confidence results produce different copy.

#### F-40-06 — 40 Wrist-temperature ovulation detection — HealthKit sample day keying  *(unconfirmed)*

Suspected, needs a device to confirm: the night's wrist temperature is probably filed
under the evening she went to bed rather than the morning she woke, so every shift
date Caelyn reports — and the ovulation date derived from it — may be one day earlier
than the same night shows in Apple's own Health app.

**Root cause.** `fetchWristTemperatures` maps each sample's `startDate`
(HealthKitService.swift:211-213) and the engine then truncates with
`calendar.startOfDay(for:)` (WristTempOvulationEngine.swift:36). An
appleSleepingWristTemperature sample for the night of the 14th→15th whose startDate is
23:30 on the 14th therefore lands on the 14th, while Health attributes it to the
morning it was measured for (the 15th). Sample-to-day keying uses the start of the
sleep session rather than its end.

**Fix.**

1. Confirm first on a real device with a temperature-capable Apple Watch — this is the
   one claim here that static reading cannot settle. Extend fetchWristTemperatures (or
   write a sibling) to return endDate as well, dump a week of samples, and compare
   both dates against what the Health app shows for the same nights.
2. If confirmed: key wrist samples by `endDate` (wake) when building the series. Leave
   manual BBT keyed to `entry.day` / dayKey — a hand-logged reading is already filed
   on the morning she took it, and the timezone work from 37dddd7 / 9776951 must not
   be disturbed.
3. Add a comment at the mapping site stating which date is used and why, so the two
   sources' keying rules are visible together.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/WristTempOvulationEngine.swift`

*Tests:* Device-only verification first. Then add a unit test with synthetic samples whose
start and end fall on different calendar days, asserting the series day equals the end
day for wrist samples and the stored day for manual BBT.

#### HK-13 — HealthKitSync.serialized (per-day chain) from DailyLogForm.withEntry  *(unconfirmed)*

Every tap on the log screen — each symptom chip, each pain type, the mood row, the
note — kicks off a full round of work against Apple Health: a dozen queries, deletes
and a save. Only the last one matters. It costs battery and makes the Log screen feel
heavier for connected users.

**Root cause.** The dispatcher models 'run after the previous one' but not 'already pending for this
day': HealthKitSync.serialized chains correctly (the inFlight equality check at :28 is
right) with no queued-for-this-day short-circuit (HealthKitSync.swift:15-29), while
each withEntry mutation schedules a complete syncEntryToHealth
(DailyLogForm.swift:1001-1017) that fans out a 12-type task group per call
(HealthKitService.swift:410-441). The worker snapshots nothing, so it could safely
drop redundant requests and does not.

**Fix.**

1. 1. Land HK-12 first so the queue is keyed on dayKey with no live @Model captured —
   the coalescing rule depends on the queued task reading live state at execution
   time.
2. 2. Keep a `pending: Set<Int>` of dayKeys in HealthKitSync; if a task for that day
   is queued-but-not-started, return immediately rather than enqueuing a second one.
3. 3. Optionally debounce 300ms on top, so a fast run of chip taps collapses into one
   write.
4. 4. Combined with HK-01's compare-and-skip, a redundant run that does slip through
   writes nothing at all.

*Files:* `Caelyn/Services/HealthKitSync.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/HealthKitService.swift`

*Tests:* New HealthKitSync test with an injected worker counting invocations: N rapid schedules
for one day produce one (or two) worker runs, and the last state is the one written.

#### HK-16 — HealthSyncService.syncOnForeground with a nil anchor  *(unconfirmed)*

Turning on 'Read fertility signals' quietly pulls years of temperature, mucus and
ovulation-test data from another app into Caelyn the next time she opens it — no
preview, no summary, and no way to undo it, even though the setting only promises to
'pick up anything that changed'.

**Root cause.** The sync mode is chosen by the caller, not by the anchor state, and the service never
learns whether an anchored query was actually incremental: with no stored anchor,
readChanges returns every sample for that type (HealthKitReader.swift:57-64) and
run(.incremental) commits every .fill with no preview and batchID nil
(HealthSyncService.swift:313-322). Read toggles just set flags
(HealthKitConnectView.swift:321-329).

**Fix.**

1. 1. Land HK-14/HK-11 first, which removes the most common nil-anchor case (missing
   anchors after a full import).
2. 2. In syncOnForeground, detect a nil anchor per type before the read and treat that
   type as not-incremental.
3. 3. Either skip it (leaving it to an explicit import) or commit it as a Batch
   (sourceID appleHealth, 'Picked up from Apple Health') so it appears in Import
   History and is undoable.
4. 4. Show a one-time banner with the count the first time a type is picked up this
   way, so the first bulk pull is visible rather than silent.

*Files:* `Caelyn/Services/Health/HealthSyncService.swift`, `Caelyn/Services/Health/HealthKitReader.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`

*Tests:* None existing. Add a service test: with no anchor for a type, the result is recorded
as an undoable Batch (or skipped), never as an unattended bulk fill.

#### HK-17 — HealthKitService dead/duplicate code: importFlowFromHealth, fetchAllMenstrualFlowSamples, ImportResult, canWriteMenstrualFlow, caelynFlow(fromSample:)/(fromHKRawValue:)  *(unconfirmed)*

No user-visible effect today. There are two separate pieces of code that translate
Apple Health's flow values, plus an unused import entry point that would ignore her
read settings if anything ever called it — so the next change to flow mapping is
likely to be made in only one of the two places.

**Root cause.** An earlier generation of the feature was left in place when Services/Health replaced
it: importFlowFromHealth (HealthKitService.swift:453-482) has no callers and reads all
flow regardless of hkReadFlow, reimplementing valueLookup; caelynFlow(fromSample:)
duplicates HealthDataCatalog.flowLevel(from:) with a second switch over
HKCategoryValueMenstrualFlow (:536-556); canWriteMenstrualFlow (:127-131) has no
callers. Only HealthSyncTests:704-706 references caelynFlow(fromHKRawValue:).

**Fix.**

1. 1. Delete importFlowFromHealth, fetchAllMenstrualFlowSamples, ImportResult and
   canWriteMenstrualFlow (HealthKitService.swift:22-29, 127-131, 453-501).
2. 2. Either make caelynFlow(fromHKRawValue:) delegate to
   HealthDataCatalog.flowLevel(fromRawValue:) or delete it and point the test at the
   catalog.
3. 3. Leave one comment in HealthKitService naming HealthDataCatalog as the single
   flow-mapping authority, so the duplicate is not reintroduced.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/Health/HealthDataCatalog.swift`, `CaelynTests/HealthSyncTests.swift`

*Tests:* Retarget HealthSyncTests:704-706 and
testEveryAppleHealthFlowValueMapsAsApplesDocumentationDescribesIt (:694) at
HealthDataCatalog.

#### HK-18 — HealthKitService.backfillFlowToHealth cycle-start computation  *(unconfirmed)*

After she has travelled across timezones, pressing Backfill can mark the wrong day as
the start of a period in Apple Health.

**Root cause.** Backfill predates the dayKey migration (37dddd7) and was not updated: it computes
`cal.dateComponents([.day], from: prev, to: entry.date).day > 1` on stored instants
(HealthKitService.swift:232-249), and after travel entries filed in different zones
can sit 15h or 33h apart, flipping the start flag. isCycleStart(for:) already uses
dayKey (:604-609), so the two computations disagree.

**Fix.**

1. 1. Sort backfill entries by dayKey rather than by date.
2. 2. Replace the instant arithmetic with `CivilDay.days(from: prev.dayKey, to:
   entry.dayKey) > 1`.
3. 3. Better: have backfill call the same isCycleStart definition (via the
   HealthWritePlan seam from HK-01) so there is one implementation rather than two
   that agree by inspection.

*Files:* `Caelyn/Services/HealthKitService.swift`

*Tests:* New HealthWritePlan backfill test with entries recorded in two different timezones,
asserting the cycle-start flags match the single-day isCycleStart result.

#### HK-19 — HealthKitConnectView.bindWrite  *(unconfirmed)*

The Apple Health write switches visibly flick off and back on when tapped, and tapping
twice quickly can fire two permission requests.

**Root cause.** Async work is started inside a synchronous Binding setter with no in-flight guard: the
setter spawns a Task and returns immediately while the getter still reads the old
value, so ToggleCard (a Button calling isOn.toggle(), ToggleCard.swift:7-12) renders
off, then on — and two quick taps spawn two Tasks that both call
requestWriteAuthorization (HealthKitConnectView.swift:256-287).

**Fix.**

1. 1. Add `@State private var requestingScope: WriteScope?` to HealthKitConnectView.
2. 2. Disable the ToggleCard while that scope is requesting.
3. 3. Set an optimistic local state immediately and correct it when the request
   returns, so the switch does not bounce.
4. 4. Ignore a second tap for a scope already in flight.

*Files:* `Caelyn/Views/Settings/HealthKitConnectView.swift`, `Caelyn/Views/Onboarding/Components/ToggleCard.swift`

*Tests:* None.

#### HK-20 — Write scope coverage (HealthKitService.allWritableTypes)  *(unconfirmed)*

Caelyn reads temperature, cervical mucus, ovulation tests, sexual activity and
pregnancy tests from Apple Health but never writes them back — so a woman trying to
conceive who logs her morning temperature in Caelyn cannot see it in Health or in any
app that reads Health, even though the permission text promises Caelyn 'saves what you
log back to Apple Health'.

**Root cause.** Write scopes were defined before the fertility fields were added to CycleEntry:
allWritableTypes is flow + symptoms + pain only (HealthKitService.swift:76-81,
140-160), while HealthDataCatalog.ovulationResultMetadataKey
(Health/HealthDataCatalog.swift:124) exists for a write that never happens and
CycleEntry carries the fields (CycleEntry.swift:48-52).

**Fix.**

1. 1. Land the HealthWritePlan seam (HK-01) first; this scope extends it rather than
   adding a third write path.
2. 2. Add `WriteScope.fertility` covering basalBodyTemperature (quantity),
   cervicalMucusQuality, ovulationTestResult (with the CaelynOvulationResult metadata
   key), sexualActivity and pregnancyTestResult.
3. 3. Add its own toggle on the Apple Health screen, requested on demand like the
   others, and a new UserProfile flag defaulting to false (lightweight, additive —
   safe for live 1.3 installs and for the additive iCloud merge).
4. 4. Extend HealthWritePlan.make to produce the quantity sample alongside the
   category samples, honouring the per-type authorization filter from HK-08.
5. 5. Prepare an App Review note (5.1.1) for the new share types before submitting.

*Files:* `Caelyn/Services/HealthKitService.swift`, `Caelyn/Services/Health/HealthDataCatalog.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Settings/HealthKitConnectView.swift`

*Tests:* Extend testEachWriteToggleAsksOnlyForTheTypesItNeeds (CaelynTests:917) to the third
scope. Add catalog round-trip tests for mucus and ovulation-test writes.

#### HK-21 — Caelyn -> Health propagation for non-interactive writes (ImportReconciler.commit, CycleStore.merge)  *(unconfirmed)*

She imports three years of Clue history, then opens the Health app and finds nothing
from Caelyn there. Only days she edits by hand are copied across; the Backfill button
that would fix it is three screens away and she has no reason to look for it.

**Root cause.** Health sync is wired at the view layer rather than at the store layer: only
interactive edit paths call HealthKitSync, while ImportReconciler.commit
(ImportReconciler.swift:307-390) and CycleStore.merge (CycleStore.swift:94-130) write
rows with no HealthKit call at all.

**Fix.**

1. 1. On the import done screen (BringHistoryModel.swift:196-241), when the write
   toggles are on, offer 'Also update Apple Health for these N days', bounded by
   summary.daysAffected.
2. 2. Run the per-day HealthWritePlan for exactly those days through the existing
   dispatcher rather than a bespoke path.
3. 3. Deliberately skip CloudKit-originated changes: the other device already wrote
   them and Health's own iCloud sync carries them. Say so in a comment so the omission
   is a decision, not a gap.
4. 4. Depends on HK-01's replace semantics — without it this would multiply duplicates
   across hundreds of days.

*Files:* `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Services/HealthKitSync.swift`

*Tests:* None existing. Add a BringHistoryFlowTests case asserting the offer appears only when
a write toggle is on and that it enqueues exactly the affected dayKeys.

#### HM-1 — 42 Streak card / Home freshness  *(unconfirmed)*

If the app is left open overnight or sits in the background for a long time, Home
keeps showing yesterday: the streak ring, the 14 dots and the mood card all describe
the wrong day until she taps something.

**Root cause.** Time is read as a side effect of rendering rather than modelled as state with an
explicit invalidation source. HomeView.today is `Calendar.current.startOfDay(for:
.now)` computed during body (HomeView.swift:23-27), and nothing invalidates Home at
midnight or on foreground — HomeView reads neither scenePhase nor NSCalendarDayChanged
(no hits in Caelyn/Views/Home). The streak card and mood card are fed from it
(:210-213, :239-242; HomeStreakCard.swift:118 calls isDateInToday on stale dates).
Writes are safe: logMood recomputes today at tap time.

**Fix.**

1. 1. Add `@State private var dayTick = 0` to HomeView.
2. 2. Add `.onReceive(NotificationCenter.default.publisher(for:
   .NSCalendarDayChanged)) { dayTick += 1 }` and `.onChange(of: scenePhase) { if $0 ==
   .active { dayTick += 1 } }`.
3. 3. Read dayTick in body (e.g. `let _ = dayTick`) so the derivation re-runs.
4. 4. Apply the same treatment to LogView's selectedDate default: if it was 'today'
   and the day has changed, move it to the new today rather than pinning yesterday.

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeStreakCard.swift`, `Caelyn/Views/Log/LogView.swift`

*Tests:* Not unit-testable (View). Device probe: open Home at 23:59, wait past midnight,
confirm the ring moves without touching the screen.

#### HP-1 — 46 Haptics  *(unconfirmed)*

The first buzz of a session feels weak or late, tapping 'Log Period' buzzes twice for
one tap, logging on the Apple Watch gives no confirmation at all, and someone who
dislikes haptics can only turn them off for the whole phone, not for Caelyn.

**Root cause.** A minimal helper written early: Haptics.swift:5-25 instantiates a fresh generator per
call with no prepare(), so the Taptic engine is cold on first use; there is no in-app
preference; and call sites layered a confirmation haptic on top of a button that
already taps — QuickActionButton fires Haptics.light() on every tap
(QuickActionButton.swift:11-13) and logPeriodToday then fires Haptics.success()
(HomeView.swift:770), contrary to the file's own 'selective, not noisy' guidance.
CaelynWatch has no WKInterfaceDevice.play / sensoryFeedback at all.

**Fix.**

1. 1. Keep static generators in Haptics and call prepare() on app foreground.
2. 2. Add `Haptics.isEnabled` backed by device-local UserDefaults key
   `caelyn.haptics.enabled` (default true) and a Settings -> App toggle
   (SettingsView.swift:562-600 currently has no haptics row).
3. 3. Give QuickActionButton a `haptic: Bool = true` parameter and pass false where
   the action confirms itself (Log Period), removing the double pulse.
4. 4. Add WKInterfaceDevice.current().play(.click) / .success in WatchQuickLogView's
   write path.
5. 5. Add the new UserDefaults key to SecureWipeService's cleared list.

*Files:* `Caelyn/Components/Haptics.swift`, `Caelyn/Components/QuickActionButton.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `CaelynWatch/WatchQuickLogView.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* None. If SecureWipeService tests enumerate cleared keys, add caelyn.haptics.enabled.

#### IMP-18 — 17 Import preview + undo + history (commit summary)  *(unconfirmed)*

If she logs something on one of the previewed days while the preview is still on
screen, Caelyn correctly keeps her value — but the success screen and the Imports list
then over-report how much was added, and an import where effectively nothing was
written can still be recorded as having changed things.

**Root cause.** ImportReconciler.commit recomputes the summary from the PLANNED decisions
(`summarize(decisions)`, :382) and then patches it after the fact with
`summary.keptUserValue += stale; summary.filled = max(0, summary.filled - stale)`
(:383-388). Stale .update decisions wrongly decrement `filled` (an update was never
counted there), and daysAffected and byField are never adjusted at all, so they still
count values that were skipped.

**Fix.**

1. 1. Build an `applied: [Decision]` array during the commit loop: the decisions
   actually written, plus the keep/duplicate/rejected passthroughs, with stale ones
   re-labelled .keepUserValue (or .alreadyMatches once IMP-08's split lands).
2. 2. Replace summarize(decisions) with summarize(applied) and delete the post-hoc
   patch at :383-388, so filled, keptUserValue, daysAffected and byField all derive
   from one source.
3. 3. Build the Batch record (valuesWritten / daysAffected) from the same applied
   summary, so Imports history and the success screen can never disagree.

*Files:* `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportPlanner.swift`

*Tests:* ImportSourceTests.testValueLoggedWhilePreviewIsOnScreenSurvivesTheCommit — extend to
assert daysAffected and byField, not just the surviving stored value.

#### IMP-19 — 17 Import preview + undo + history (preview copy)  *(unconfirmed)*

The 'what we found' breakdown never mentions moods, energy, medication notes or notes.
A Clue export full of feelings and energy shows a list that omits them, and a mood-
only file shows 'Found N days of history' with nothing listed underneath.

**Root cause.** ImportCopy.labels/order (ImportCopy.swift:13-27) covers only flow, symptom, pain,
temperature, mucus, ovulationTest, pregnancyTest and sexualActivity, while
Field.summaryKey (ImportReconciler.swift:397-414) also yields 'mood', 'energy',
'medication' and 'note'. The breakdown silently drops any key with no label, so the
two lists have drifted with nothing to catch it.

**Fix.**

1. 1. Add the four labels — 'mood', 'energy level', 'medication note', 'note' — to
   ImportCopy.labels and append them to `order` in the position the preview should
   read them.
2. 2. Add a unit test that every value Field.summaryKey can return has a label, so the
   two lists cannot drift again.

*Files:* `Caelyn/Services/Import/ImportCopy.swift`, `Caelyn/Services/Import/ImportReconciler.swift`

*Tests:* BringHistoryFlowTests.testCluePreviewNamesClueAndDescribesWhatItFound unchanged; add
the exhaustiveness test from step 2.

#### IMP-20 — 17 Import preview + undo + history (caveats)  *(unconfirmed)*

A healthy Clue export from someone who logs twice a day shows dozens of 'entries
couldn't be read and will be left out'. Nothing was unreadable — they were second
readings on the same day, and Flo's predicted future days. It reads like her file is
broken, which undermines trust for no reason.

**Root cause.** Summary carries a single `rejected` counter for heterogeneous Rejection cases:
.supersededInBatch (ImportReconciler.swift:161-166) and .futureDate (:252) land in the
same bucket as genuinely unparseable values, and ImportPreview.swift:196-198 renders
that one number with the 'couldn't be read' wording.

**Fix.**

1. 1. Add rejectedByReason: [Rejection: Int] to Summary and populate it where each
   rejection is created.
2. 2. Render per-reason lines in ImportPreview: 'N days are dated in the future and
   were left out', 'N entries were second readings on a day that already had one', 'N
   values were outside any human range' — keeping 'couldn't be read' for the parse-
   failure case only.
3. 3. Keep the aggregate `rejected` for callers that only need a total, so nothing
   else has to change.

*Files:* `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportPreview.swift`

*Tests:* ImportSourceTests.testFutureDatedRowsAreRejected (rejected > 0 still true), plus a new
assertion that the future-dated copy does not contain 'couldn't be read'.

#### IMP-21, IMP-23 — 16 Import from 9 sources (read-path performance)  *(unconfirmed)*

'Reading your history…' takes seconds on files that should take well under one,
because the same bytes are decoded and parsed up to three times and a fresh date
formatter is built for every value-and-format pair. The work is off the main thread so
nothing freezes, but she waits.

**Root cause.** Two instances of the same omission — no memoisation in the read path.
ImportValues.strictDate constructs a DateFormatter per call (:40-54) and
detectDateFormat calls it for up to 14 formats x every row (:90-96), with
GenericTableSource.dateColumn running a second full pass (:56-61); a three-year daily
CSV with non-ISO dates is roughly 15k formatter allocations. Separately
ImportPayload's `text`, `csvRows` and `csvHeaders` are lazy but do not reuse each
other (ImportPayload.swift:25,49-60): each calls decodedText(), and csvRows and
csvHeaders each run CSVReader.parse over the whole file — csvHeaders parses everything
to read one row.

**Fix.**

1. 1. Build one formatter per format per detectDateFormat call (or a static cache
   keyed by format + timeZone) and pass it into strictDate, instead of constructing
   inside the loop.
2. 2. Sample at most ~200 candidate values for detection — agreement across 200 rows
   is as decisive as across 15,000, and the agreement threshold is a fraction so it
   scales unchanged.
3. 3. Derive csvHeaders from csvRows?.first, and csvRows from the already-decoded
   `text`, so the file is decoded once and parsed once.

*Files:* `Caelyn/Services/Import/ImportValues.swift`, `Caelyn/Services/Import/ImportPayload.swift`, `Caelyn/Services/Import/Sources/GenericTableSource.swift`

*Tests:* No correctness test required;
BringHistoryFlowTests.testAVeryLargeImportStillPreviewsBeforeWriting should get
measurably faster and is the natural regression net. Land after IMP-05, which
restructures the same scoring loop.

#### IMP-22, IMP-28 — 17 Import preview + undo + history (commit and file-read performance)  *(unconfirmed)*

Confirming a multi-year import freezes the screen for seconds with no sign of progress
— the 'Adding…' label never even draws, so it looks like the tap did nothing. Opening
a large export shared in from another app hitches before anything appears.

**Root cause.** Heavy I/O runs synchronously on the main actor in the import flow. commit calls
CycleStore.entry(for:) per decision (ImportReconciler.swift:326,348 ->
CycleStore.swift:65-80), one predicate fetch each — a five-year Clue export is 10-20k
fetches — inside a synchronous @MainActor call, and BringHistoryModel.confirm sets
phase = .importing and commits in the same turn (BringHistoryModel.swift:196-218), so
the state change never renders. Separately IncomingImportFile.init?(openedAt:) runs
Data(contentsOf:) inside onOpenURL on the main thread (BringHistoryView.swift:480-485)
and BringHistoryModel.readFile reads on the main actor before the detached parse
(:85-95), because the security scope had to be held during the read and inline was
simplest.

**Fix.**

1. 1. In commit, fetch all entries once into [Int: CycleEntry] keyed by dayKey and
   resolve every decision from that map, creating missing rows through a local helper
   that inserts and registers them in the map.
2. 2. Make confirm() async and `await Task.yield()` after setting .importing, so the
   button state is drawn before the write begins.
3. 3. Read incoming files with Data(contentsOf:options: .mappedIfSafe) and move the
   copy into the detached task, holding the security scope there rather than on the
   main actor.
4. 4. Add a size guard above ~200 MB with a friendly message, instead of attempting
   the read and hoping.

*Files:* `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/Views/Import/BringHistoryView.swift`

*Tests:* BringHistoryFlowTests.testAVeryLargeImportStillPreviewsBeforeWriting and
testARealFileOnDiskIsReadThroughTheURLPath. confirm() becoming async means every test
calling it synchronously needs `await`. Land after IMP-18, which restructures the same
commit loop.

#### IMP-24, IMP2-09 — 17 Import preview + undo + history (flow states)  *(unconfirmed)*

Two opposite lies from one missing state. A confirm that correctly writes nothing —
because she logged every previewed day in the meantime — is shown as a red error with
'Try something else', when the outcome was protective and correct. And an undo that
removes nothing — because she had already changed everything that import wrote — shows
a green 'Removed what that import added. Everything you logged yourself is still
here', fires a success haptic, and deletes the row from Imports so she can neither
verify nor retry.

**Root cause.** CommitResult.succeeded means 'nothing went wrong', not 'something happened', and there
is no third state for 'ran cleanly, had nothing to do'. BringHistoryModel.confirm maps
the empty result to .failed(...) (:230-233), which BringHistoryView renders with the
alert-rose error card (:313-335). ImportPlanner.undo with no surviving claims builds
no decisions, so commit leaves touched == false, never saves, and returns succeeded:
true with an all-zero summary; undo then calls ledger.removeBatch(id:)
(ImportPlanner.swift:293-297), and both ImportHistoryView.undo (:121-130) and
BringHistoryModel.undoLastImport (:258-267) read succeeded as 'something was removed'.

**Fix.**

1. 1. Add Phase.nothingToAdd (or a .done carrying changeCount 0 and no Undo action)
   and render it in the neutral success style rather than the error card.
2. 2. Have both undo call sites branch on result.summary.cleared as well as succeeded:
   when cleared == 0, say 'There was nothing left to take back — you'd already changed
   or removed everything that import added', with no success haptic.
3. 3. Leave the batch in the Imports list when nothing was cleared, so the record of
   what happened survives. Remove it only when something was actually cleared, or when
   the ledger genuinely holds no claims for it any more and she is told the row is
   being retired.

*Files:* `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/Views/Import/BringHistoryView.swift`, `Caelyn/Views/Import/ImportHistoryView.swift`, `Caelyn/Services/Import/ImportPlanner.swift`

*Tests:* BringHistoryFlowTests phase expectations for the nothing-to-add case.
BringHistoryFlowTests.testUndoKeepsAnythingSheEditedAfterTheImport covers the data
half but not what the screen claims — add the probe for the all-edited batch.

#### IMP-25, IMP2-12 — 17 Import preview + undo + history (ledger storage design)  *(unconfirmed)*

The record of what came from where lives in one file on one phone. She cannot undo on
her iPad what she imported on her iPhone — that device's Imports list says 'Nothing
imported yet' for entries plainly visible in its calendar. If the app dies in the
instant between saving her data and saving that record, the import becomes permanent
and can never be taken back. And for someone who has had Apple Health connected for a
few years the file grows without limit and is rewritten whole, on the main thread,
after every foreground sync.

**Root cause.** The ledger is a single local whole-file JSON document with no transactional or sync
relationship to the store it describes. It is an Application Support file
(ImportLedger.swift:58-66, 260-265) deliberately kept out of the synced store
(privacy, no schema migration), so batches and claims never reach a second device.
commit saves the context first and records claims and the batch afterwards
(ImportReconciler.swift:366-380, ImportPlanner.swift:248-259), so the two writes are
not atomic across files. save() encodes the entire claim map plus batch list and
writes it synchronously on the main actor (:239-247), called at the end of every
commit including every throttled foreground Health catch-up
(HealthSyncService.swift:296-322), while claims are removed only by release or
removeAll and batchList only ever grows.

**Fix.**

1. 1. Say the true thing immediately, independent of the rest: ImportHistoryView's
   empty state should read 'Imports can be undone on the device they were made on.'
2. 2. Make the pair of writes recoverable: write the ledger BEFORE context.save() with
   a `pending` flag, confirm it after the save succeeds, and drop unconfirmed claims
   on rollback and at the next loadIfNeeded. The decoder is already tolerant of new
   optional fields.
3. 3. Add a retention rule: drop claims whose dayKey has no CycleEntry, and drop
   batchless claims older than the oldest surviving batch. A claim nothing can undo
   and nothing can conflict with is dead weight, and losing it fails safe — the value
   simply becomes hers, the direction the file header already relies on. Never prune a
   claim belonging to a batch still listed, or undo breaks.
4. 4. Coalesce the write: mark dirty and flush once per run-loop turn, or move encode-
   and-write off the main actor entirely, so a commit stops paying for the whole
   history every minute.
5. 5. Longer term, as a deliberate design decision rather than a patch: a CloudKit-
   synced ImportBatch record carrying only batchID, source, date and claim keys, so
   undo works on any device. This puts provenance in the synced store, which the
   current design avoids on purpose — decide it explicitly.

*Files:* `Caelyn/Services/Import/ImportLedger.swift`, `Caelyn/Services/Import/ImportReconciler.swift`, `Caelyn/Services/Import/ImportPlanner.swift`, `Caelyn/Views/Import/ImportHistoryView.swift`, `Caelyn/Services/Health/HealthSyncService.swift`

*Tests:* No existing test asserts ledger size or write frequency. New tests: pending claims are
dropped after a simulated rollback; the retention predicate never prunes a claim
belonging to a listed batch; a pruned claim leaves the value user-owned. Every
existing undo test must keep passing. Land after IMP-04, which rewrites the load/save
guards this builds on.

#### IMP-26 — 16 Import from 9 sources (calendar consistency)  *(unconfirmed)*

Caelyn decides whether it can read a file's dates using the phone's current calendar,
then actually reads them using the calendar the import was handed. The two can
disagree, so a column accepted at the detection step can be rejected when parsed —
rare in practice, but it makes tests that pin a calendar unreliable and will bite a
traveller.

**Root cause.** detect() has no calendar parameter in the ImportSource protocol
(ImportSource.swift:69), so GenericTableSource.dateColumn (:60) and
GenericJSONSource.dateKey (:42) call detectDateFormat / parseISODate with `.current`
while parse uses the caller's calendar.

**Fix.**

1. 1. Store the calendar on ImportPayload, set once by ImportPlanner.read, and use
   payload.calendar in every detector.
2. 2. Remove every `.current` literal from Services/Import/Sources/ so the divergence
   cannot reappear.
3. 3. Land this BEFORE the date-detection changes (IMP-05 and IMP-06/IMP-07): it is
   the plumbing both of those fixes assume, and their probes need a deterministically
   pinned calendar.

*Files:* `Caelyn/Services/Import/ImportPayload.swift`, `Caelyn/Services/Import/ImportPlanner.swift`, `Caelyn/Services/Import/ImportSource.swift`, `Caelyn/Services/Import/Sources/GenericTableSource.swift`, `Caelyn/Services/Import/Sources/GenericJSONSource.swift`

*Tests:* None existing. The IMP-05 and IMP-06/IMP-07 probes depend on this plumbing; add a case
that a payload read under a pinned non-current calendar detects and parses with that
same calendar.

#### IMP-27 — 17 Import preview + undo + history (code health)  *(unconfirmed)*

Nothing she can see today. But there are two copies of the import planning logic and
two unused copy helpers, so a fix can land in one path and silently not the other.

**Root cause.** ImportPlanner.plan(_ file:) and plan(payload:) duplicate the byDay / reconcile /
preview construction (ImportPlanner.swift:125-170, 175-224) because the sync path was
kept for ImportService compatibility and never re-expressed through the async path's
helper. ImportCopy.previewHeadline and previewReassurance are unused and hard-code
'Apple Health', and ImportCopy.importResult is Health-only but lives in the shared
copy type (ImportCopy.swift:39-73).

**Fix.**

1. 1. Have plan(payload:) build a ReadFile and call plan(_ file:), so one
   implementation remains.
2. 2. Delete ImportCopy.previewHeadline and previewReassurance.
3. 3. Move ImportCopy.importResult next to the Health route, or rename it so its scope
   is visible at the call site.
4. 4. Do this before IMP-08's copy split, or that fix has to be made twice and one
   copy will be missed.

*Files:* `Caelyn/Services/Import/ImportPlanner.swift`, `Caelyn/Services/Import/ImportCopy.swift`, `Caelyn/Services/ImportService.swift`

*Tests:* None new; the existing ImportSourceTests coverage of both paths is the regression net,
and it should keep passing unchanged.

#### IMP2-08 — 17 Import preview + undo + history (caveats ordering)  *(unconfirmed)*

The line telling her which columns Caelyn has no place for reshuffles while she is
looking at it, and when the file has more than four such columns it can name a
different four before and after she taps Add — so the column she cares about may be
listed on one render and absent on the next.

**Root cause.** ImportPreview.caveats sorts parsed.unmappedFields by count alone (`.sorted { $0.value
> $1.value }`, ImportPreview.swift:199-208) and takes prefix(4). Dictionary iteration
order is unspecified, and ties are the normal case because each unmapped column is
counted once per row, so equal counts emerge in a different order on each access.
caveats is a computed property and ImportPreviewCard.init snapshots it afresh on every
construction (ImportPreviewCard.swift:114-122), so a rebuild re-rolls the list on
screen. The total-order contract skipReasons establishes four lines later was simply
not applied here.

**Fix.**

1. 1. Use the same comparator shape as skipReasons: `.sorted { ($0.value, $1.key) >
   ($1.value, $0.key) }` — descending by count, ascending by name — which is a total
   order over distinct keys.
2. 2. Sweep for any other display list sorted on a non-unique dictionary value and
   give each the same tie-break.

*Files:* `Caelyn/Services/Import/ImportPreview.swift`, `Caelyn/Views/Import/ImportPreviewCard.swift`

*Tests:* None existing. Add the probe: repeated reads of caveats for a file with tied unmapped
columns must be equal.

#### IMP2-11 — 17 Import preview + undo + history (share-sheet re-entry)  *(unconfirmed)*

She shares the wrong export into Caelyn, sees the preview, realises her mistake, goes
back to Files and shares the right one. The sheet keeps showing the first file's
numbers, and tapping 'Add to Caelyn' imports the file she rejected. Rare, silent, and
recoverable only through undo.

**Root cause.** The read is tied to view appearance rather than to the file's identity.
BringHistoryView reads its file in a plain `.task { guard let incomingFile else {
return }; await model.read(...) }` (BringHistoryView.swift:89-94) rather than
`.task(id:)`, and `.sheet(item:)` (CaelynApp.swift:35-44) reuses the sheet's view
identity when the IncomingImportFile is replaced, so @State private var model persists
and the task never re-runs.

**Fix.**

1. 1. Change to `.task(id: incomingFile?.id) { … }` so a new file re-triggers the
   read.
2. 2. Add the `guard !isBusy` to BringHistoryModel.read(filename:data:) that
   readFile(at:) already has (BringHistoryModel.swift:82), so a replacement arriving
   mid-write cannot stomp an in-flight commit.
3. 3. Reset the model's phase when the id changes, so the new file starts at .reading
   instead of inheriting the previous preview's phase and its Add button.

*Files:* `Caelyn/Views/Import/BringHistoryView.swift`, `Caelyn/Views/Import/BringHistoryModel.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* The SwiftUI half needs a UI test (share a second file while the sheet is up, assert
the preview's filename and row count change). The isBusy half is unit-testable against
BringHistoryModel — probe below.

#### LC-10 — CycleStore.dedupeSameDay as run by the launch pass and the sync pass

While she is travelling, every launch quietly rewrites and re-uploads her entire
history because the time zone changed. With two devices in different zones — an iPad
left at home and a phone abroad — each one undoes the other's rewrite, forever,
burning battery and data with nothing to show for it.

**Root cause.** `CycleEntry.date` is a replicated stored field whose value is computed from a DEVICE-
LOCAL input — the current calendar's time zone — and `dedupeSameDay` rewrites it to
that device-local value on every pass with no idempotence guard
(CycleStore.swift:47-52). Because the normalisation target differs per device, the
pass is not a fixed point across a mirrored store: each device's run produces a value
the other device's run will immediately undo, and the write itself triggers the other
device's remote-change notification (CloudSyncCoordinator.swift:43-49, :73-75) that
re-runs the pass. dedupeSameDay only saves when `removed > 0 || backfilled > 0`
(CycleStore.swift:54), but the dirtied rows ride the next unrelated save on the same
mainContext — AppLockGate.recordActivity's saveOrLog is milliseconds later
(AppLockGate.swift:55, 92-95) — so the rewrite is persisted and, on a mirrored store,
exported.

**Fix.**

1. 1. Narrow the normalisation to the only case a date-based reader would actually get
   wrong, inside the existing else branch of dedupeSameDay (CycleStore.swift:~47-52):
   `if CivilDay.key(for: entry.date, calendar: calendar) != key { entry.date =
   CivilDay.localDate(for: key, calendar: calendar); backfilled += 1 }`.
2. 2. Add a comment stating why: normalising unconditionally to this device's midnight
   makes the pass non-idempotent across a mirrored store, so two devices in different
   zones each undo the other.
3. 3. Count any such repair into `backfilled` so the write happens inside dedupe's own
   save rather than riding an unrelated one.
4. 4. Identity is already `dayKey` after commits 37dddd7 / 9776951, so no reader
   changes and no numbers change.
5. 5. Why permanent: the pass becomes a fixed point — running it twice, or on two
   devices, produces no further writes — rather than a per-device rewrite that happens
   to be stable only when every device shares a zone.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/Models/CycleEntry.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`

*Tests:* UpgradeAndDeviceMatrixTests.testDatesAreStableAcrossTheMatrix and CivilDayTests assert
day stability via startOfDay(entry.date) — re-express them on `dayKey`. Add a test
that running dedupeSameDay twice under two different calendars performs zero writes on
the second run.

#### LC-11 — RootView.task 120 ms hydration sleep  *(unconfirmed)*

Every launch sits on a blank screen for an extra eighth of a second to guard against a
flash of the welcome screen that may not actually be possible — and on a slow device
with a lot of history, the guard could be too short anyway, briefly showing onboarding
and briefly leaving the lock off.

**Root cause.** Readiness is inferred from elapsed time instead of from a synchronous read of the
authoritative state. RootView.swift:54-59 sleeps 120 ms "to let SwiftData hydrate",
yet the same task has just executed two synchronous fetches over the same context
(CycleStore.swift:29, ProfileStore.swift:26), which already proves the store is
readable. If the race is real, a fixed delay can fail silently (flash onboarding, and
AppLockGate's hasOnboarded briefly false so the lock does not cover content); if it is
not, every launch pays the delay for nothing.

**Fix.**

1. 1. In the same task, after the dedupe pass, fetch the profile directly: `try?
   modelContext.fetch(FetchDescriptor<UserProfile>(sortBy:
   [SortDescriptor(\.createdAt)])).first` — or `ProfileStore.current(in:)` once the
   LC-06 item lands.
2. 2. Seed a `@State routedOnboarded: Bool` from that fetch and set `isLoaded`
   immediately; let @Query drive updates thereafter. Remove the sleep.
3. 3. Expose the same "store ready" signal to AppLockGate so the lock decision is made
   from the fetch rather than from @Query timing.
4. 4. Keep both dedupe passes but run them after the first frame when `storeMode ==
   .ok` and no dayKey backfill is pending (cheap to detect with a count predicate), so
   a ten-year history does not delay first paint.
5. 5. Why permanent: the routing decision reads the state it is about, so it cannot be
   wrong on a slow device and costs nothing on a fast one.

*Files:* `Caelyn/Views/RootView.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Services/CycleStore.swift`

*Tests:* None existing. Add a test that RootView's routing seed matches a direct fetch for a
store with an onboarded profile, and a launch-timing assertion in the UI suite that
onboarding is never visible for a seeded store.

#### LC-12 — MainTabView.body size-class switch (ipadLayout vs iPhoneLayout)  *(unconfirmed)*

On iPad, dragging another app alongside Caelyn (or resizing the window) throws away
everything she was doing: the tab content, any navigation she had pushed, open sheets
and scroll position are all rebuilt, a half-filled Log form is dismissed, and she can
land on a different tab than the one she was on.

**Root cause.** Layout and selection state are coupled through two parallel trees and two variables.
MainTabView.swift:56-62 picks `ipadLayout` when hSizeClass == .regular else
`iPhoneLayout`; the two trees are structurally different, so a size-class change tears
down all tab content and its state. Selection is held in two separate @State values,
`selection` (TabView) and `iPadSelection` (List) (MainTabView.swift:4-5), and only
`handlePendingCategory` writes both (:143-144) — so after a swap she lands on whatever
the other variable last held.

**Fix.**

1. 1. Collapse to one `@State selection: Tab` bound to both the TabView and the
   sidebar List (the List via a Binding adapter to Optional).
2. 2. Hoist the five destinations into a single `tabContent(for: Tab)` used by both
   layouts, so the same view instances (and their state) are reachable from either
   tree.
3. 3. Prefer keeping a single TabView and using `.tabViewStyle(.sidebarAdaptable)` on
   iOS 18+, with the NavigationSplitView branch only as the iOS 17 fallback — that
   removes the tree swap entirely on most devices.
4. 4. Why permanent: there is one selection and, on iOS 18+, one tree, so a size-class
   change becomes a layout change rather than an identity change.

*Files:* `Caelyn/Views/MainTabView.swift`

*Tests:* None existing. Add a UI test on iPad that enters Slide Over mid-navigation and asserts
the same tab and pushed destination are still showing.

#### LC-13 — SettingsView @Query entries  *(unconfirmed)*

Opening Settings loads her entire history into memory and reloads it on every change,
for data the screen never shows.

**Root cause.** A leftover declaration: `@Query private var entries: [CycleEntry]` at
SettingsView.swift:6 is unsorted, unfiltered, and has no second reference anywhere in
the file (grep). SwiftData still performs the fetch and keeps the array live, re-
fetching on every store change while Settings is on screen. The diagnostics card that
used it moved to DataStatusCard, which has its own query (DataStatusCard.swift:5-6).

**Fix.**

1. 1. Delete the property at SettingsView.swift:6.
2. 2. Add a lightweight CI lint: grep each file for `@Query` property names and fail
   when a name has no second occurrence in its own file.
3. 3. Why permanent: the lint catches the next orphaned query rather than relying on a
   reviewer noticing an unused declaration.

*Files:* `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Components/DataStatusCard.swift`

*Tests:* None.

#### LC-14 — ModelContainer.firstLaunchPreview as used by CaelynApp in --ui-test-onboarding  *(unconfirmed)*

No user impact — but the onboarding UI test can start handing the app a brand-new
empty database partway through a run, which will look like a product regression when
it eventually fires.

**Root cause.** A non-memoised factory used where a per-process singleton was intended. `static var
firstLaunchPreview: ModelContainer { ... try ModelContainer(...) }`
(RootView.swift:139) constructs a new instance on every access, while CaelynApp passes
it to `.modelContainer(...)` inside `body` (CaelynApp.swift:67-71) and reads
`@Environment(\.scenePhase)` (:9) — so body re-evaluates on every phase change (the
Health permission sheet and the notifications alert both cause inactive/active
transitions). Persistence.live / .preview / .screenshot are all `static let`; this one
is not.

**Fix.**

1. 1. Change it to `static let firstLaunchPreview: ModelContainer = { ... }()`, or
   move it to Persistence as `static let uiTestOnboarding` alongside the others.
2. 2. Hoist the container choice out of `body` into a `static let container` on
   CaelynApp, so `body` never constructs a container at all.
3. 3. Why permanent: the container becomes a per-process value like its three
   siblings, so body re-evaluation cannot change store identity.

*Files:* `Caelyn/Views/RootView.swift`, `Caelyn/App/CaelynApp.swift`, `CaelynUITests/CaelynUITests.swift`

*Tests:* None existing; the probe below demonstrates the instance churn and becomes a
regression test.

#### LC-15 — AppLockGate.sweepThenRecordActivity (every .active) · CaelynApp.task honourRemoteDeletionIfNeeded (every launch)  *(unconfirmed)*

Caelyn writes to her profile and uploads it every single time she opens the app, which
makes every one of her other devices re-scan her whole history; and every launch makes
an iCloud request even for someone who has never turned sync on.

**Root cause.** Two unguarded operations. (1) `AutoSweepService.recordActivity` stamps
`profile.lastActiveAt` and saves on every launch and every `.active` transition
(AppLockGate.swift:55, 71, 92-95; AutoSweepService.swift:31-36) regardless of whether
auto-wipe is even enabled — no coarsening and no relevance check. With sync on, that
is a CloudKit upload per foreground, and each arrival on another device triggers
CloudSyncCoordinator's full dedupe pass over all entries
(CloudSyncCoordinator.swift:61-83). (2)
`CloudDataDeletion.honourRemoteDeletionIfNeeded` is called unconditionally at
CaelynApp.swift:63 and performs `CloudDeletionTombstone.fetch`
(CloudDeletionTombstone.swift:105-112), a CKContainer request against her private
database, even when sync has never been enabled on this device and no cloud copy can
exist.

**Fix.**

1. 1. Coarsen recordActivity: write only when `CivilDay.key(for: lastActiveAt) !=
   CivilDay.key(for: now)`. Once per calendar day keeps the auto-wipe window exact to
   the day, which is its unit.
2. 2. Guard honourRemoteDeletionIfNeeded at the call site with
   `Persistence.isSyncEnabled || CloudDataDeletion.cloudCopyMayExistNow ||
   CloudDeletionTombstone.localConsent != nil` — a device that has never synced has
   nothing to stand down from.
3. 3. Leave resolveOutstandingDeletion unguarded; it already returns early on its own
   flags.
4. 4. Note the dependency: if the PRIV-04 item lands first, lastActiveAt moves to
   device-local UserDefaults and the upload half of (1) disappears on its own — but
   the coarsening is still worth keeping to avoid a write per foreground.
5. 5. Why permanent: both operations gain a precondition derived from whether they can
   possibly matter, rather than running because the app happened to launch.

*Files:* `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/Account/CloudDeletionTombstone.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`

*Tests:* CaelynTests ~:997-999 (shouldSweep) is unaffected. Add a test that recordActivity is a
no-op within the same civil day and writes across a day boundary, and a test that
honourRemoteDeletionIfNeeded short-circuits with no sync history (inject the flags via
UserDefaults the way DeletionModelTests does).

#### LC-16 — WidgetDataSyncModifier.sync / CloudSyncCoordinator.refreshDerivedSnapshot / WatchBridgeService.pushSnapshot  *(unconfirmed)*

A Pro subscriber's widget and watch show free-tier content right after launch, and
stay that way after she buys Pro until she backgrounds the app. The watch also lags
behind anything that arrives by sync.

**Root cause.** Snapshot refresh is edge-triggered on scenePhase only, while the inputs that change
independently have no trigger. `WidgetDataSyncModifier` reads
`PurchaseService.shared.isPro` inside `sync()` (WidgetDataSync.swift:131-141), called
from onAppear and scenePhase changes, so the Observable is never tracked: at cold
launch entitlements are still resolving (PurchaseService.swift:34-40), the snapshot is
written with isPro == false and the watch push is skipped, and it is corrected only at
the next scenePhase change. `CloudSyncCoordinator.refreshDerivedSnapshot` writes the
widget store but never calls `WatchBridgeService.pushSnapshot`
(CloudSyncCoordinator.swift:90-102), and WCSession activation completing is not a
trigger either.

**Fix.**

1. 1. Centralise in a `DerivedSnapshotPublisher` that rebuilds the snapshot, writes
   the App Group store, reloads widget timelines and pushes to the watch — the same
   object introduced by the PRIV-07 item.
2. 2. Call it from WidgetDataSyncModifier, from
   CloudSyncCoordinator.refreshDerivedSnapshot, and from an `onChange(of:
   PurchaseService.shared.isPro)` in the modifier so entitlement resolution and in-app
   purchase both trigger a refresh.
3. 3. Have WatchBridgeService cache the last snapshot and push it from
   `activationDidCompleteWith`.
4. 4. Why permanent: every input that can change the snapshot gets an explicit trigger
   into one publisher, instead of three consumers each hoping a scene-phase change
   happens after the input settles.

*Files:* `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/PurchaseService.swift`, `Caelyn/Services/WatchBridgeService.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`

*Tests:* None existing. Add a test that an isPro transition triggers a snapshot rebuild, and
that WatchBridgeService pushes its cached snapshot on activation completion (inject
the WCSession state).

#### LC-17 — AppDelegate.userNotificationCenter(_:willPresent:) / AppLockGate PIN flow  *(unconfirmed)*

Two small irritations. A reminder that was deliberately scheduled to be silent still
pops up with a banner and a sound while she is using the app. And if a banner, a call,
or a Control Centre pull interrupts her three digits into her PIN, the pad disappears
and she starts over.

**Root cause.** (a) `willPresent` returns `[.banner, .list, .sound]` for every notification
(AppDelegate.swift:22-28), ignoring the request's `interruptionLevel` — including the
dailyCheckIn scheduled as `.passive` precisely so it is quiet
(NotificationService.swift:174-191). (b) AppLockGate's scenePhase handler resets UI
sub-state along with security state: on `!= .active` it sets `showingPINPad = false`
and clears `pinError` as well as `isUnlocked` (AppLockGate.swift:61-76), so any
`.inactive` blip discards the in-progress PIN entry and bounces her back to the
biometric screen. Most visible for PIN-only users — exactly the people the fallback
exists for.

**Fix.**

1. 1. In willPresent, read the request's `content.interruptionLevel` and return
   `[.list]` for `.passive`, `[.banner, .list, .sound]` otherwise.
2. 2. Additionally suppress the banner for a category whose destination tab is
   currently on screen (the router already knows the mapping).
3. 3. In AppLockGate's `newPhase != .active` branch, reset only `isUnlocked` and
   `errorMessage`; leave `showingPINPad` and the entered digits intact so the pad is
   still up when she returns.
4. 4. Why permanent: (1) makes presentation a function of the request's own declared
   level rather than a constant, and (3) separates security state from UI sub-state so
   a future interruption cannot discard entry progress.

*Files:* `Caelyn/App/AppDelegate.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Main/PINViews.swift`

*Tests:* None existing. Add a unit test over a pure `presentationOptions(for
interruptionLevel:)` helper, and a UI test that backgrounding mid-PIN returns to the
pad rather than the biometric screen.

#### LC-18 — AppLockGate.showLockScreen fail-open  *(unconfirmed)*

If she removes her device passcode, or restores to a new iPhone, App Lock stops
working — but Settings still shows it switched on and nothing tells her the app is no
longer locked. She believes her history is protected when anyone can open it.

**Root cause.** The decision to fail open is made per-render and never surfaced as a state the UI can
explain. `showLockScreen` returns false when neither
`BiometricService.canAuthenticate` nor `PINService.isSet` (AppLockGate.swift:79-87) —
correct by design, since a user must never be permanently locked out — but
`profile.lockEnabled` is untouched, so the Settings toggle
(SettingsView.swift:348-364) still reads On. The same fail-open fires after a restore:
the PIN keychain item uses kSecAttrAccessibleWhenUnlockedThisDeviceOnly
(PINService.swift:114-125) and is not restored, while `lockEnabled` syncs over as true
on the mirrored profile.

**Fix.**

1. 1. Compute `lockEffective = lockEnabled && (BiometricService.canAuthenticate ||
   PINService.isSet)` once in AppLockGate and use it for the render decision.
2. 2. When `lockEnabled && !lockEffective`, show a one-time dismissable notice on Home
   and Settings: "App Lock is on but has no way to unlock on this iPhone — set an App
   PIN or a device passcode."
3. 3. Mark the Settings toggle row with the same state (detail text, not a silent On).
4. 4. Reuse the `DuressReadiness` predicate from the PRIV2-03 item rather than adding
   a second notion of lock readiness.
5. 5. Why permanent: the fail-open becomes a named state with a UI representation
   instead of a silent branch, so it can never be true without being visible.

*Files:* `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Services/PINService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Main/PINViews.swift`

*Tests:* None existing. Add unit tests over the lockEffective predicate for all four
combinations, and a UI assertion that the notice appears when lockEnabled is true with
no PIN and device auth disabled (--ui-test-disable-device-auth).

#### LC2-10 — Demo / screenshot mode gating  *(unconfirmed)*

No user impact — but App Store screenshots captured in paywall mode do not match the
ones captured in normal mode: the iPad paywall shot comes out with a sidebar instead
of tabs, first-visit tip cards show behind the paywall sheet, and the greeting is not
the fixed one.

**Root cause.** There is no single definition of "this run is a capture". Five places decide
independently and check different argument sets: `Persistence.isDemoStore` checks
--screenshot-mode, --screenshot-paywall and --ui-test-onboarding
(Persistence.swift:58-62); `CaelynApp.isScreenshotMode` checks the first two
(CaelynApp.swift:11-14); `MainTabView.isScreenshotMode` (MainTabView.swift:9, used at
:57-61), `FirstVisitIntroCard.isScreenshotMode` (:5) and HomeCopy check only
--screenshot-mode. The canonical predicate was added later for the cloud-state leak
and the earlier private copies were never migrated, so each new launch argument must
be remembered in five places.

**Fix.**

1. 1. Delete the three private copies in MainTabView, FirstVisitIntroCard and HomeCopy
   and read `Persistence.isDemoStore` — it is already @MainActor and all three call
   sites are main-actor views.
2. 2. Express the modes as one `enum LaunchMode` resolved once at launch, keeping
   `isPaywallMode` and `isOnboardingUITest` as cases for the two places that genuinely
   need to distinguish WHICH demo mode.
3. 3. Expect and accept the behaviour change: under --screenshot-paywall and --ui-
   test-onboarding, tips become hidden and the phone layout is forced; under
   --screenshot-mode nothing changes.
4. 4. Why permanent: a new launch argument is added in one place, so the five surfaces
   cannot diverge again.

*Files:* `Caelyn/Services/Persistence.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/MainTabView.swift`, `Caelyn/Components/FirstVisitIntroCard.swift`, `Caelyn/Views/Home/HomeCopy.swift`

*Tests:* ScreenshotTests and PreviewTourTests exercise these arguments — re-baseline the
--screenshot-paywall and --ui-test-onboarding expectations (tips hidden, phone layout
forced). Add a test that every demo launch argument resolves to the same LaunchMode
predicate in all call sites.

#### LC2-11 — Store failure — Persistence.preserveStoreAside  *(unconfirmed)*

When Caelyn recovers from a damaged database, there is a narrow window where being
killed mid-recovery leaves the leftovers of the old database sitting next to the
brand-new one — which can turn one failed open into two. And repeated failures pile up
full copies of her history on disk that she can never see.

**Root cause.** The preserve step is three independent filesystem operations with no transaction and
no post-condition check, ordered so the first one is the one that breaks the set's
consistency. `preserveStoreAside` iterates `["", "-shm", "-wal"]` in that order
(Persistence.swift:167-180), moving `default.store` FIRST and its sidecars after, with
a `try?`-and-log per file. A kill between the first and third move — or a sidecar move
that simply fails and is logged — leaves the directory with the previous database's
`-wal`/`-shm` and no main file, and step 2 (:134-144) then opens a brand-new
`default.store` into that directory, where SQLite will try to associate the foreign
journals with it. Separately, nothing ever removes old `.corrupt-<ts>` sets.

**Fix.**

1. 1. Reverse the order: move the sidecars first and the main store last, so the set
   is never left with the main file missing and journals present.
2. 2. Before step 2 re-opens, assert the post-condition: if `default.store` is absent
   but `default.store-wal` or `-shm` exist, delete them — they belong to a database
   that is no longer there.
3. 3. Log and surface a distinct failure if the main-store move itself fails, rather
   than proceeding to open a fresh store over an unreadable one.
4. 4. Bound the accumulation using the `purgePreservedStores()` / 90-day reaping
   introduced in the LC2-02/PRIV-12/PRIV-13 item.
5. 5. Make the function `internal` so it can be driven from a test against a staged
   directory.
6. 6. Why permanent: the operation gains an order in which every intermediate state is
   safe, plus an explicit post-condition check, rather than relying on not being
   interrupted.

*Files:* `Caelyn/Services/Persistence.swift`

*Tests:* None today. Add a test that stages a fake Application Support directory containing
default.store plus -shm/-wal, calls the (now internal) preserve function, and asserts
no orphan journals remain; and a second that stages only orphan journals and asserts
the pre-open check deletes them.

#### MC-3 — 43 Home mood check-in  *(unconfirmed)*

If she logged 'sad', 'irritable' or 'low energy' in the Log tab, the Home card says
'Logged: feeling sad' while no mood appears selected — and she cannot change or clear
it from Home.

**Root cause.** Two hand-written mood arrays instead of one ordered source: HomeMoodCheckIn.moods
lists 8 (HomeMoodCheckIn.swift:10) while DailyLogForm.moodSection offers all 11
(DailyLogForm.swift:571-575) from Mood's cases (Enums.swift:123-126). Home's subtitle
logic already handles all 11 (HomeMoodCheckIn.swift:14-33), so the display and the
chip row disagree. The list was trimmed for width although it already lives in a
horizontal ScrollView.

**Fix.**

1. 1. Add `static let checkInOrder: [Mood]` on Mood (Enums.swift) as the single
   ordered source.
2. 2. Use it in both HomeMoodCheckIn.swift:10 and DailyLogForm.swift:571-575.
3. 3. Show all 11 on Home (the row already scrolls horizontally). If the shorter row
   is kept for layout reasons, append the currently selected mood when it is not in
   the short list, so selection is always visible and clearable.
4. 4. Allow tapping the selected chip to clear the mood on Home, matching the form.

*Files:* `Caelyn/Models/Enums.swift`, `Caelyn/Views/Home/HomeMoodCheckIn.swift`, `Caelyn/Views/Log/DailyLogForm.swift`

*Tests:* Add a test asserting Mood.checkInOrder covers every Mood case, so a new mood cannot be
added to one surface only.

#### MODES-14, MODES-16 — 22 Irregular cycle mode (Home banner)  *(unconfirmed)*

Tapping Enable or Dismiss on the irregular-cycle banner may not stick if the app is
killed shortly afterwards, so the banner comes back or the mode silently isn't on. And
once dismissed it never returns, even if her cycles later change in a genuinely new
way — while enabling the mode from Settings instead of from the banner leaves a
different hidden state, so the same end result behaves differently later.

**Root cause.** Two defects in the same 40-line block. (a) HomeView.swift:821-822 and :834 mutate
irregularModeEnabled / irregularModeDismissed with no `modelContext.saveOrLog()`,
relying on the main context's autosave — unlike every other profile write in the area
(CycleSettingsView.swift:70, 233-235, 273-275, 329-331, 350-352, 401, 414, 418, 431,
475, 484; HomeView.swift:713-714). No autosaveEnabled is set anywhere and the
container is attached at CaelynApp.swift:67-71, so a background sync that fetches the
live store (NotificationService.swift:328-329) may read the pre-save value. (b)
irregularModeDismissed is a single Bool that records THAT she dismissed but not WHAT
she dismissed, and it is never cleared — so a later change of detected reason
(highVariation → skippedPeriods) resurfaces nothing, and the Settings-enable path
(which leaves dismissed false) and the banner-enable path (which sets it true) produce
different future behaviour from the same visible state.

**Fix.**

1. 1. Add `modelContext.saveOrLog()` after each mutation at HomeView.swift:821-822 and
   :834, plus Haptics.selection() for parity with the rest of the area.
2. 2. Add `irregularModeDismissedReason: String?` to UserProfile (additive optional).
   Keep the existing Bool for backward compatibility and treat an existing `true` as
   "all reasons dismissed".
3. 3. Show the banner only when the currently detected reason differs from
   irregularModeDismissedReason, so a materially new pattern surfaces again.
4. 4. Clear irregularModeDismissedReason when the mode is toggled OFF from Settings
   (CycleSettingsView.swift:220-235), and set it when the mode is enabled from
   Settings, so both enable paths leave the same state.
5. 5. Give ProfileStore.merge a rule for the new optional String (newest-wins, not
   union), and add it to the merge tests.

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Services/ProfileStore.swift`

*Tests:* None existing. Add a ProfileStoreTests case for the new optional String merge rule,
and the UI probe below.

#### MODES-15, MODES-17 — 28 Specialist modes — Pregnancy card and date input  *(unconfirmed)*

The due-date picker accepts any date at all, so one mis-tap produces an absurd card —
a past date shows "Past your due date" immediately, a date two years out shows "Week 0
· Trimester 1 · Implantation week · 700 days left". The week descriptions are also
slightly wrong: "Halfway there!" appears at weeks 16-19 when halfway is week 20, and
"Implantation week" covers weeks that precede conception.

**Root cause.** Two unrelated omissions in the pregnancy surface. (a) The due-date DatePicker has no
`in:` range (CycleSettingsView.swift:427-434) while the birth-date picker right beside
it is bounded (:486), so PregnancyModeCard's weeksPregnant clamps to 0 and the derived
strings go nonsensical (PregnancyModeCard.swift:14-21, 44-58). (b) The week bands are
hand-rolled with a naming error: `conceptionDate = due - 280`
(PregnancyModeCard.swift:10-12) is actually LMP, i.e. gestational week 0, not
conception — so every band built on it is offset by about two weeks; and both cards
read Calendar.current and .now directly (:6-8, :115-116), so unlike
CycleModel.make(today:) they cannot be tested with an injected date.

**Fix.**

1. 1. Bound the due-date picker: `in: today...today.addingTimeInterval(300 * 86400)`
   at CycleSettingsView.swift:427-434, matching the birth-date picker's shape at :486.
   Existing out-of-range stored dates stay valid — the card's isPastDue path already
   handles a past date.
2. 2. Land the life-stage setter item (MODES-04/MODES-05) first, which shows the
   picker on enable so the seeded default is visible before she can mis-set it.
3. 3. Rename `conceptionDate` to `lmpDate` in PregnancyModeCard.swift:10-12 and
   correct every band computed from it.
4. 4. Move the milestone bands into a testable `PregnancyWeeks` enum taking explicit
   `today` and `calendar` parameters, shared with the widget's pregnancy line
   (MODES-02), and fix the bands: halfway at week 20, implantation confined to the
   weeks after conception.
5. 5. Pass today/calendar into both cards (PregnancyModeCard.swift:6-8 and :112-142)
   instead of reading the wall clock, matching CycleModel.make's convention.

*Files:* `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Views/Home/PregnancyModeCard.swift`, `Caelyn/Services/WidgetDataSync.swift`

*Tests:* Add unit tests for the new PregnancyWeeks enum with an injected today, covering week
0, the trimester boundaries, week 20 (halfway) and past-due. UI test
CaelynUITests.swift:588-638 can assert the picker's bounds via its accessibility
value. docs/DIAGNOSIS.md:113 already flags the unbounded picker — update that line
when it closes.

#### MODES-18, PE-15 — ExportService.drawClinicalSummary / drawInsightsSection + PatternEngine.conditionInsights  *(unconfirmed)*

She exports the PDF to take to her doctor. It says 'Irregular' and 'Normal: 21–35
days' with no mention that she has PCOS, is in perimenopause, or was pregnant for part
of the period covered — context the app already holds. Inside the clinical report the
doctor also reads app marketing addressed to the patient ('Export the PDF report
before appointments'), and patterns she had already swiped away as wrong are presented
as 'Patterns Caelyn Noticed'.

**Root cause.** The export is built from a partial view of the app's state: it consumes CycleModel
statistics and PatternInsight rows without the qualifiers every other surface applies.
drawClinicalSummary prints fixed adult norms and the irregularity label regardless of
the profile's mode and life-stage fields (ExportService.swift:204-247, 221-226), which
it never reads. drawInsightsSection takes `insights.prefix(6)` with no category filter
and no dismissal filter (ExportService.swift:254-262), and condition banners are
PatternInsight values sharing the type with derived patterns
(PatternEngine.swift:390-432) — so UI copy written for the patient ends up in a
clinical document.

**Fix.**

1. 1. In drawInsightsSection, filter `category != .condition` and
   `!DismissedInsights.all().contains($0.stableKey)` before prefix(6).
2. 2. Longer term, move condition banners out of PatternInsight into their own
   ConditionNote type so they cannot be mistaken for derived patterns anywhere in the
   app.
3. 3. Add a 'Tracking modes' row to the clinical summary listing enabled modes (PCOS,
   Perimenopause, Endometriosis, Gentle, …) from the profile.
4. 4. Add a 'Pregnancy / Postpartum' row giving the interval when those modes hold
   dates.
5. 5. Take the printed norms from CycleNorms rather than the hard-coded '21–35 days',
   so the reference range matches the mode the rest of the app is using.
6. 6. Once PE-06/PE-08/PE-13 land, print each insight's sampleSize in the PDF — the
   export never sees `confidence`, so sample size in supportingValue is the only way a
   clinician can weigh a claim.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Services/PatternEngine.swift`, `Caelyn/Models/UserProfile.swift`

*Tests:* New export test extracting PDF text via PDFKit: with endoEnabled the output does not
contain 'Export the PDF report'; a dismissed insight's title is absent; with
pcosEnabled the 'Tracking modes' row names PCOS. No PDF text tests exist for these
sections today.

#### PE-16 — DismissedInsights / PatternInsightsSection.dismiss  *(unconfirmed)*

She dismisses an insight on her iPhone; it is still there on her iPad. She dismisses
one by accident — the x is a tiny target right next to body text — and there is no way
to get it back short of deleting all her data.

**Root cause.** The preference is stored outside the synced model and no undo was designed. Dismissed
keys live in UserDefaults.standard under 'caelyn.dismissedInsights'
(PatternEngine.swift:16-25) while CloudKit mirrors SwiftData only; there is no 'show
dismissed insights' control anywhere (zero references outside PatternEngine,
PatternInsightsSection and SecureWipe); and the dismiss button is an 11pt glyph with
6pt padding (~23pt, PatternInsightsSection.swift:129-140) against the 44pt HIG
minimum. SecureWipe does clear the key correctly (SecureWipeService.swift:108-109).

**Fix.**

1. 1. Add `var dismissedInsightKeys: [String] = []` to UserProfile (additive,
   defaulted → SwiftData lightweight migration, CloudKit-compatible).
2. 2. On first launch after the update, copy UserDefaults 'caelyn.dismissedInsights'
   into the profile field and leave the UserDefaults key in place so SecureWipe's
   existing removal list still covers it.
3. 3. Merge the field additively in ProfileStore.merge (union of the two arrays),
   consistent with the entry merge's array unions.
4. 4. Add 'Show dismissed insights' to Settings → Cycle, restoring all keys.
5. 5. Enlarge the dismiss hit area to 44pt via contentShape, and show a 5-second undo
   toast after a dismissal.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/ProfileStore.swift`, `Caelyn/Views/Insights/PatternInsightsSection.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* SecureWipe tests gain an assertion that the profile field goes with the profile. New
migration test seeding the old UserDefaults key and asserting it lands in the profile
exactly once. ProfileStoreTests covers the union merge.

#### PE-17 — PatternEngine copy / CycleSummaryService.fallback / PatternsSection / YearViewSection header / cycleLengthTrend formatting  *(unconfirmed)*

The section meant to prove Caelyn understands her reads as unfinished: 'Cramps is your
most logged symptom', 'Nausea peaks in your Ovulation window phase', 'in your cycle
phase', 'usually within 0 days of average', and a 'Last 12 months' header over six
months of free-tier data. One line also overstates a real 3-day shift as '28 → 32
days'.

**Root cause.** Display names are reused inside sentence templates with no grammatical form (several
already contain the word 'window', and .unknown's displayName is 'Cycle' —
CyclePrediction.swift:20-29); the Year header subtitle is a literal rather than
derived from the months actually shown; and cycleLengthTrend formats each mean
independently with String(format: "%.0f") (PatternEngine.swift:249-268), so half-even
rounding on both ends inflates a 3.0 delta to 4.

**Fix.**

1. 1. Add `CyclePhase.inSentence` ('your menstrual phase', 'your PMS window', 'around
   ovulation') and use it in every template — PatternEngine.swift:156, :241,
   CycleSummaryService.swift:146.
2. 2. Never emit a sentence for .unknown (covered structurally by the
   PE-06/PE-08/PE-13 item; this is the copy half).
3. 3. Fix the singular/plural verb: either a `Symptom.isPluralNoun` flag, or neutral
   phrasing — 'Your most-logged symptom: cramps' (PatternEngine.swift:383).
4. 4. PatternsSection: special-case variation 0 ('your cycles arrive almost exactly on
   time') instead of 'within 0 days of average'.
5. 5. YearViewSection subtitle: 'Last \(months.count) months'.
6. 6. cycleLengthTrend: round the DELTA once and show one decimal when |Δ| < 5, rather
   than formatting both means independently.

*Files:* `Caelyn/Services/PatternEngine.swift`, `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Views/Insights/PatternsSection.swift`, `Caelyn/Views/Insights/YearViewSection.swift`, `Caelyn/Models/CyclePrediction.swift`

*Tests:* Copy assertions on the generated strings for each case; check ScreenshotTests
expectations.

#### PE-18 — PatternEngine.pmsPredictorSymptom + PatternEngine.symptomLeadTime  *(unconfirmed)*

She sees two cards saying almost the same thing — 'Bloating often signals your period
is coming' and 'Bloating tends to appear ~2 days before your period' — and dismissing
one leaves the other. On the free tier that wastes one of her five slots.

**Root cause.** Two detectors share the .pmsPredictorSymptom category and are both appended with no
dedupe by (category, symptom) before sorting (PatternEngine.swift:100-105, :297-304,
:344-351), and a symptom reliably logged N days before each period satisfies both.

**Fix.**

1. 1. After both detectors run, drop the pmsPredictorSymptom result for symptom S when
   symptomLeadTime also fired for S — the lag version strictly dominates (it contains
   the presence claim plus the timing).
2. 2. Or merge them into one card carrying both facts, and give it a single stableKey
   so one dismissal covers it.

*Files:* `Caelyn/Services/PatternEngine.swift`

*Tests:* New: a history where both detectors fire for bloating yields exactly one card naming
bloating.

#### PE-19 — PainTrendChart / BBTChart / CycleLengthChart / PeriodLengthChart  *(unconfirmed)*

The Pro charts mislead exactly where Pro is supposed to pay off. The pain chart draws
a smooth high-pain band across a whole month because she logged a 7 on Jan 3 and a 6
on Feb 1 and nothing between. The temperature chart draws a fixed 36.4 °C line as 'the
threshold', so a woman whose baseline is 36.6 appears to be above it always. Over five
years the x-axis reads 'Jan Jan Jan', and 65 period bars become hairlines.

**Root cause.** Series are all-time with no windowing or per-cycle segmenting, and the constants were
chosen for a 6-cycle demo dataset: AreaMark+LineMark with monotone interpolation
through sparse points (InsightsCharts.swift:218-239), a hardcoded RuleMark at 36.4
(:276-283), `.dateTime.month(.abbreviated)` only (:43-46), and BarMark .ratio(0.55)
over a continuous date axis (:79-84).

**Fix.**

1. 1. Segment the pain and BBT series per cycle — `.foregroundStyle(by:)` on a cycle
   id, or insert nil gaps between cycles — so no mark is drawn across a gap.
2. 2. Default the window to the last 6 cycles with a segmented control for all-time.
3. 3. Compute the BBT coverline from her own pre-ovulation mean
   (WristTempOvulationEngine already does this) instead of 36.4.
4. 4. Use `.dateTime.month().year(.twoDigits)` when the span exceeds 12 months.
5. 5. Switch PeriodLengthChart to a categorical x-axis (cycle index) above 12 cycles.

*Files:* `Caelyn/Views/Insights/InsightsCharts.swift`, `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Services/WristTempOvulationEngine.swift`

*Tests:* Unit-test the series builders (segmentation produces one series per cycle; the
coverline equals the pre-ovulation mean). Charts themselves are visual — cover with a
screenshot test on a 5-year fixture.

#### PE-20 — InsightsStatsGrid / PatternsSection / TypicalRanges.variation / PredictionEngine.irregularCycleStatus  *(unconfirmed)*

Her cycles vary by 5 days. One screen paints that red and says 'Cycles vary a bit';
the screen next to it says 'In a common range (up to about 7)' with a tick. She cannot
tell whether something is wrong.

**Root cause.** The threshold constant is duplicated per view rather than owned once:
InsightsStatsGrid uses > 4 with alertRose (InsightsStatsGrid.swift:20-26),
PatternsSection uses > 4 with alertRose (:28-35), TypicalRanges.variation marks up to
7 as in range (TypicalRanges.swift:77-87), and irregularCycleStatus uses > 7
(PredictionEngine.swift:413-416).

**Fix.**

1. 1. Add `TypicalRanges.variationWatchThreshold(gentle:)` as the single owner of the
   number and have all four call sites read it.
2. 2. Change the stats grid to the calm plum 'watch' colour rather than alertRose, per
   TypicalRanges' own rule that alert colours are reserved for out-of-range.
3. 3. Land this alongside the PatternEngine.Thresholds centralisation so there is one
   place for evidence floors and one for display bands, not six.

*Files:* `Caelyn/Views/Insights/InsightsStatsGrid.swift`, `Caelyn/Views/Insights/PatternsSection.swift`, `Caelyn/Services/TypicalRanges.swift`, `Caelyn/Services/PredictionEngine.swift`

*Tests:* New: variation 5 produces the same verdict string and colour family from all four
consumers.

#### PE-21 — CycleAnalytics.daysLogged  *(unconfirmed)*

The 'Logged in 30 days' stat actually counts 31 days, and it counts by the moment an
entry was stored rather than the day it belongs to — so a late-evening entry can land
in the wrong bucket near a timezone change.

**Root cause.** Inclusive lower bound with an offset equal to the window length: `start =
startOfDay(today) − 30 days` then `date >= start` admits today plus the 30 prior days.
The filter also uses `$0.date` (the stored instant) rather than the stored day key,
which is the pattern the dayKey work (37dddd7, 9776951) moved every other reader off.

**Fix.**

1. 1. In CycleAnalytics.daysLogged (CycleAnalytics.swift:171-176) change the offset to
   −(lookbackDays − 1) so the window is exactly lookbackDays long including today.
2. 2. Change the comparison to use CivilDay.localDate(for: dayKey) instead of $0.date,
   matching every other reader post-37dddd7.
3. 3. Confirm the InsightsStatsGrid label (InsightsStatsGrid.swift:27) and the window
   now agree.

*Files:* `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Views/Insights/InsightsStatsGrid.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* testDaysLoggedRespectsLookback (CaelynTests.swift:274) gains a boundary case: an entry
at exactly 30 days ago must be excluded, one at 29 days included.

#### PE-22 — CycleSummaryCard (Insights AI summary)  *(unconfirmed)*

On a device with on-device AI, if she leaves the Insights tab open across midnight or
logs something new, the written summary still describes yesterday while the numbers
above it have already moved.

**Root cause.** The generating task is not keyed to its inputs: `.task { text = await summary(for:
facts) }` (InsightsView.swift:266-286) has no id, so once `text` is set a new entry, a
new day or a new top insight never re-runs it.

**Fix.**

1. 1. Make Facts Hashable and change the task to `.task(id: facts)` so it re-runs
   whenever the facts change.
2. 2. Render the deterministic fallback text immediately while a regeneration is in
   flight, so the card is never blank and never older than the grid.
3. 3. Include the current day in Facts so a midnight rollover alone invalidates it
   (pairs with the day-change observation item).

*Files:* `Caelyn/Views/Insights/InsightsView.swift`

*Tests:* Add a test that the Facts value changes when the day or entry set changes (pure value
test; the task itself is not unit-testable).

#### PE-23 — InsightsView.body / InsightsEmptyState  *(unconfirmed)*

Until she has completed two full cycles, the whole Insights tab says 'Your story is
just beginning' — even though the year view, her logged-day count and her first
cycle's history are already there and computable. The tab meant to show progress shows
nothing during the exact weeks she is deciding whether to keep using Caelyn.

**Root cause.** A single gate on completed cycles covers sections with entirely different data needs:
`if cycles.count < 2 { InsightsEmptyState } else { loadedContent }`
(InsightsView.swift:54-58, empty state copy at InsightsEmptyState.swift:47-49). A user
who imported months of symptom and mood history without flow data trips it too.

**Fix.**

1. 1. Gate per section rather than per tab: keep the empty-state card at the top while
   cycles.count < 2, as an explanation of what is still missing.
2. 2. Below it, still render YearViewSection (logged-day dots), the 'Logged in 30
   days' stat, streak context and CycleHistorySection whenever they have data.
3. 3. Each section declares its own data requirement, so adding a section later cannot
   be hidden by an unrelated gate.

*Files:* `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Views/Insights/InsightsEmptyState.swift`

*Tests:* None exist. Add a test over the per-section predicates (pure functions) covering 0, 1
and 2 completed cycles and a symptoms-only history.

#### PG-06, PG-21 — HomeView.guidePersonal + HomeHeroCard .task(id:) identity  *(unconfirmed)*

Two faces of the same gap on the home screen. Turning on Gentle guidance, or logging a
mood, does not change the sentence on the home card until the next day — the guide
sheet shows the new one while the home card keeps the old. And the home screen
recomputes all the pattern analysis on every single redraw, so scrolling gets choppier
the longer her history gets.

**Root cause.** There is no single memoised derived-teaching value with an identity.
HomeView.guidePersonal re-runs PatternEngine.insights, learnedLutealLength,
adaptivePmsDaysBefore and averagePeriodPain on every render (HomeView.swift:72,
86-88), and the last two a second time because cycle.lutealLength /
cycle.pmsDaysBefore recompute at :57 and :123 — PatternEngine's detectors are
O(entries x cycles) (PatternEngine.swift:312-327, 122-162). The a1ca071 fix stashed
CycleModel but not this layer, so the regression it addressed still applies here. At
the other end, HomeHeroCard keys its async work on `.task(id: "\(cycleDay)-\(phase)")`
(HomeHeroCard.swift:113), which omits TeachingFacts.gentle, topPatternLine and
cycleCount (HomeView.swift:69-90) — the task identity does not include the inputs that
shape its output. (Whether tab switching re-runs the task on reappear, masking the
Settings path, is not settled statically.)

**Fix.**

1. 1. Make CycleSummaryService.TeachingFacts Hashable — it is all value types.
2. 2. Compute guidePersonal (and the active insights) ONCE per render into the
   existing DerivedCycle stash next to the CycleModel, so the pattern detectors run
   once rather than per access.
3. 3. Have CycleModel.lutealLength / pmsDaysBefore memoise through a small reference
   box so the :57/:123 and :86-88 call sites share one computation instead of two.
4. 4. Replace the string key at HomeHeroCard.swift:113 with `.task(id:
   personal?.teaching)` — the Hashable facts value — so the hero line invalidates
   exactly when its inputs change and never otherwise.
5. 5. Verify the Gentle-guidance path end to end: toggling it in Settings must change
   the facts value, which must change the task id, which must regenerate the hero line
   without a day or phase change.

*Files:* `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Services/PatternEngine.swift`

*Tests:* None existing. Add a unit test that TeachingFacts differs when gentle flips. UI probe:
toggle Gentle guidance, return to Home without backgrounding, assert the hero text
contains the gentle menstrual phrasing within 2s.

#### PG-11 — PhaseGuideView.whatCaelynLearned vs InsightsView.LearnedAboutYouSection  *(unconfirmed)*

When her learned luteal length happens to be exactly 14, the guide says 'Your luteal
phase is 14 days — your ovulation estimate now uses it, not the textbook 14', which
contradicts itself. The Insights screen words the same fact correctly.

**Root cause.** The copy is duplicated across two views instead of living in one helper:
PhaseGuideView.swift:272-277 has no == 14 branch while InsightsView.swift:188-197 does
('Matches the 14-day default…'), so the two surfaces word the same fact differently
and one is self-contradictory.

**Fix.**

1. 1. Add a `LearnedCopy` enum with `luteal(_ days: Int) -> String` and `pms(_ days:
   Int) -> String`, including the == 14 (and == default pmsDaysBefore) branch.
2. 2. Replace the inline string at PhaseGuideView.swift:275 with
   LearnedCopy.luteal(...).
3. 3. Replace the branch at InsightsView.swift:193-197 with the same call so there is
   one definition.
4. 4. Do the same for the PMS row (PhaseGuideView.swift:282) so the default-value case
   is handled consistently there too.

*Files:* `Caelyn/Views/Education/PhaseGuideView.swift`, `Caelyn/Views/Insights/InsightsView.swift`

*Tests:* New string test on LearnedCopy.luteal(14) and LearnedCopy.luteal(11).

#### PG-18 — PhaseGuideView generic guide; TypicalRanges.periodLength & variation gentle copy  *(unconfirmed)*

Gentle mode promises 'softer, wider, reassuring ranges' for someone new to periods,
but the guide she sees on day one — before Caelyn has a single cycle — still quotes
the adult 21-35 day range. That is the exact user the setting was built for.

**Root cause.** Gentle was threaded through the personal path only. PhaseGuideView learns `gentle`
solely via `personal` (PhaseGuideView.swift:14, 20), which is nil below one cycle
(HomeView.swift:70), so the .unknown tips hardcode adult ranges (:471-473).
TypicalRanges.periodLength declares `gentle: Bool = false` and never reads it
(TypicalRanges.swift:59-73), and variation's watch string ignores gentle entirely
(:85).

**Fix.**

1. 1. Give PhaseGuideView a `gentle: Bool` parameter independent of `personal`;
   HomeView passes profile.gentleModeEnabled.
2. 2. Branch the .unknown tips (PhaseGuideView.swift:462-476) and the ovulation/PMS
   jargon on it.
3. 3. Give variation a gentle watch string ('Common while your cycles are still
   settling') at TypicalRanges.swift:85.
4. 4. Either use periodLength's `gentle` parameter for its watch copy or delete the
   parameter (TypicalRanges.swift:59-73) — an unread parameter is a standing
   invitation to assume it works.

*Files:* `Caelyn/Views/Education/PhaseGuideView.swift`, `Caelyn/Services/TypicalRanges.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`

*Tests:* Extend testGentleModeWidensReassurance to cover variation and the zero-cycle generic
guide.

#### PG-19 — HomeHeroCard.phaseLegend vs CycleRingView arcs  *(unconfirmed)*

The little coloured dots that explain the ring are not the colours of the ring. The
legend's green and purple are much darker than the pale sage and lavender arcs they
describe, and VoiceOver reads 'green for ovulation, purple for PMS'.

**Root cause.** Two files pick colours independently: HomeHeroCard.swift:155-163 uses successSage and
primaryPlum@55% while CycleRingView.swift:30-32 uses sage and lavender (token values
at Color+Caelyn.swift:52-55, 79-90, 104-108). There is no shared phase-to-colour
definition.

**Fix.**

1. 1. Add `CyclePhase.arcColor` (and, if the legend needs more contrast,
   `CyclePhase.legendColor` derived from arcColor by a fixed darkening, not an
   independent token).
2. 2. Use it in CycleRingView.swift:30-32 and HomeHeroCard.swift:155-173 so the two
   cannot diverge again.
3. 3. Check the legend's contrast against the card background after the change and
   adjust the derivation, not the individual call sites.
4. 4. Land after the ring boundary work (PG-08/PG-10/PG-23) to avoid conflicting edits
   to the same arcs.

*Files:* `Caelyn/Views/Home/HomeHeroCard.swift`, `Caelyn/Components/CycleRingView.swift`, `Caelyn/Theme/Color+Caelyn.swift`

*Tests:* None (visual); screenshot S1 shifts slightly and needs re-capture.

#### PG-20 — HomeCopy.phaseHeadline / phaseLead (.menstrual); HomeHeroCard confidence caption  *(unconfirmed)*

On a period day the home card reads 'Day 3 of your period' and then, directly
underneath, 'Day 3 — estrogen…'. And a brand-new user with no cycles at all is told
'Log a few more cycles' right under 'Welcome to Caelyn', as though she had already
logged some.

**Root cause.** Two small gating errors. The personal lead was written with a 'Day N' prefix for all
phases without checking the menstrual headline, so HomeCopy.swift:57 and
CycleSummaryService.swift:104-108 stack the same day number. Separately, the low-
confidence caption is gated on `confidence == .low` alone (HomeHeroCard.swift:72-76),
and CycleModel.confidence is derived from cycle count only
(CyclePrediction.swift:262), so it also fires for phase == .unknown with no anchor — a
user who has no prediction at all.

**Fix.**

1. 1. Drop the 'Day N —' prefix from the menstrual lead in
   CycleSummaryService.swift:104-108 (keep it for phases whose headline does not
   already carry the day).
2. 2. Gate the caption at HomeHeroCard.swift:72-76 on `phase != .unknown && confidence
   == .low`.
3. 3. Extend CivilDayTests.testNoPhaseHintEchoesItsOwnHeadline (:287-311) from the
   static hint to the teachingFallback leads, so the duplication class is covered
   rather than the one instance.

*Files:* `Caelyn/Views/Home/HomeCopy.swift`, `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`, `CaelynTests/CivilDayTests.swift`

*Tests:* CivilDayTests.testNoPhaseHintEchoesItsOwnHeadline (extend to leads). Add a zero-cycle
case asserting the caption is absent.

#### PG-24 — PhaseGuideView.QuestionRow accessibility  *(unconfirmed)*

In the guide's 'Common questions' list, each question is a tappable card. Because the
card is merged into a single accessibility element, a VoiceOver user may be read the
hint 'Tap to read the answer' and have no way to actually open it — suspected, not
proven statically.

**Root cause.** `.accessibilityElement(children: .combine)` is applied to the card containing the
toggle Button (PhaseGuideView.swift:334-373) with no explicit .accessibilityAction and
no .isButton trait added to the combined element, so activation depends entirely on
SwiftUI's action-merging behaviour rather than on anything the code states.

**Fix.**

1. 1. Add `.accessibilityAddTraits(.isButton)` and an explicit `.accessibilityAction {
   expanded.toggle() }` on the combined element — or combine only the label and leave
   the Button as the accessibility element.
2. 2. Keep the hint text consistent with whichever shape is chosen.
3. 3. Confirm with the UI probe below before and after, since the current behaviour
   cannot be settled by reading code.

*Files:* `Caelyn/Views/Education/PhaseGuideView.swift`

*Tests:* UI probe: open the guide, activate app.otherElements["Is it normal that my cycle
length changes?…"], assert the answer text exists.

#### PG-25 — CycleSummaryService.fallback; PatternEngine bodies woven into the teaching line  *(unconfirmed)*

The app sometimes writes 'in your pms window phase' or 'ovulation window phase', and
for a user with no prediction yet, 'in your cycle phase'. It reads like a template
that forgot to be edited.

**Root cause.** CyclePhase.displayName is a badge label ('PMS window', 'Ovulation window', 'Your
cycle'; InsightsView.swift:37-46) reused as prose: CycleSummaryService.swift:146
lowercases it into a sentence, and PatternEngine bodies do the same
(PatternEngine.swift:154-161, 239-246) before those bodies are appended to the hero
line (HomeView.swift:73, CycleSummaryService.swift:98-101).

**Fix.**

1. 1. Add `CyclePhase.proseName` returning 'PMS', 'ovulation', 'luteal', 'follicular',
   'your period', 'your cycle'.
2. 2. Use it at CycleSummaryService.swift:146 and PatternEngine.swift:157 and :242
   instead of displayName.lowercased().
3. 3. Special-case .unknown in the fallback: "You're on day N of your cycle." rather
   than 'in your cycle phase'.
4. 4. Leave displayName alone — it is correct as a badge.

*Files:* `Caelyn/Services/CycleSummaryService.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Services/PatternEngine.swift`

*Tests:* testCycleSummaryFallbackProducesUsableText (asserts 'luteal' — still passes). Add
assertions that no generated line contains 'window phase' or 'cycle phase'.

#### PRIV-19 — 14 Auto-erase if inactive  *(unconfirmed)*

Every time she opens Caelyn the app writes a timestamp twice, which with sync on is
two iCloud uploads and an app-wide view refresh per launch; if the erase window has
just elapsed both writes can start the wipe at once, and after a wipe the app tries to
stamp a profile it just deleted.

**Root cause.** No idempotency latch and no threshold on the stamp. AppLockGate runs
sweepThenRecordActivity from `.task` (AppLockGate.swift:55) and again on the `.active`
transition at launch (:70-71); each call does `profile.lastActiveAt = now;
modelContext.saveOrLog()` (AutoSweepService.swift:31-36, verified), and
AutoSweepService.checkAndSweep has no re-entry guard, so two overlapping calls can
both enter wipeEverything. After a sweep, recordActivity sets lastActiveAt on the
profile object the batch delete at SecureWipeService.swift:84-86 just removed, then
saves.

**Fix.**

1. 1. Land the auto-erase-clock item (PRIV-17/PRIV2-04) first — it moves the stamp to
   the authenticated paths only, which removes the duplicate launch stamp by
   construction and is most of this fix.
2. 2. Add an `isSweeping` latch (a static Bool or an actor-isolated flag) to
   AutoSweepService so checkAndSweep is a no-op while a sweep is in flight.
3. 3. Have checkAndSweep return whether it swept, and skip the subsequent stamp when
   it did — so the post-wipe write to a deleted profile cannot happen.
4. 4. Threshold the stamp: write only when autoWipeEnabled is true, or the stored
   stamp is older than an hour. With sync on this turns one CloudKit export per
   foreground into at most one per hour.

*Files:* `Caelyn/Services/AutoSweepService.swift`, `Caelyn/Views/Main/AppLockGate.swift`

*Tests:* None existing. Add an AutoSweepStateTests case asserting two concurrent checkAndSweep
calls perform one wipe, and one asserting no save is attempted after a sweep.

#### PRIV-20 — 10 Paranoid Mode  *(unconfirmed)*

The Paranoid Mode dialog says it "cancels all reminders" when note-to-self reminders
come back, and the after-the-fact notice about iCloud sync only appears in some cases,
so some women are told nothing about the sync switch at all.

**Root cause.** The copy was written against the profile's reminder flags, which do not enumerate note
reminders (their policy lives per-entry in CycleEntry.noteReminderRule); and the
relaunch notice is keyed on store state, `syncWasActiveThisLaunch =
Persistence.isSyncActive` (SettingsView.swift:534, verified), rather than on
preference-or-store, so the preference-on-but-container-not-mirrored case is switched
off silently.

**Fix.**

1. 1. Land the note-reminder class flag (PRIV2-07) first; this item is the copy half
   of it.
2. 2. Change SettingsView.swift:513-517 / :427 to enumerate what is actually turned
   off: "cancels your cycle, check-in, medication and birth-control reminders" — and,
   once PRIV2-07 lands and note reminders are genuinely in the set, say "and your note
   reminders" rather than the current blanket "all reminders".
3. 3. Change the notice condition at SettingsView.swift:534 to
   `Persistence.isSyncEnabled || Persistence.isSyncActive` so the preference-only case
   is still told the switch happened.
4. 4. Fold the wider Paranoid Mode copy rewrite into the under-reach item (PRIV2-09)
   so the dialog is composed once from live state rather than edited twice.

*Files:* `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* None existing. Covered by the ParanoidModeSummary unit tests added for PRIV2-09.

#### PRIV-21 — 15 Delete all data  *(unconfirmed)*

The second delete dialog states flatly "You have a copy in iCloud" when Caelyn only
suspects one, and the message afterwards can read "Everything on this iPhone was
deleted. Nothing was deleted — …", which contradicts itself.

**Root cause.** A single may-exist predicate rendered with definite wording:
CloudDataDeletion.cloudCopyMayExistNow is also true when only deletionIsPending is
set, or when the sync preference is on but the mirrored store never opened
(CloudDataDeletion.swift:214-215), yet SettingsView.swift:189-191 says "You have a
copy". Separately, SettingsView.swift:816-818 concatenates its own local-success
sentence with cloudOutcome.message, which begins "Nothing was deleted" when the cloud
half failed.

**Fix.**

1. 1. Change the dialog at SettingsView.swift:189-191 to "You may have a copy in
   iCloud…", matching the predicate's actual strength.
2. 2. Change the report construction at SettingsView.swift:816-818 so the two halves
   cannot contradict: "Everything on this iPhone was deleted. Your iCloud copy was
   not: <reason>."
3. 3. Keep the substrings "Nothing was deleted" and "may still be there" somewhere in
   the Outcome messages, because
   DeletionModelTests.testWhenTheCloudHalfFailsTheLocalHalfStillCompletesAndSaysSo
   asserts on them — move the phrasing into the Outcome's own message rather than the
   view's concatenation.
4. 4. Land this with the delete-all feedback item (PRIV2-12), whose durable-outcome
   rewrite touches the same strings.

*Files:* `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`

*Tests:* DeletionModelTests.testWhenTheCloudHalfFailsTheLocalHalfStillCompletesAndSaysSo must
keep passing — preserve its asserted substrings. Add an assertion that no rendered
report contains both "was deleted." and "Nothing was deleted".

#### PRIV-22, PRIV-23 — 11 App Lock (lock screen presentation)  *(unconfirmed)*

Small lock-screen rough edges: the "try again in 60 seconds" message is a frozen
number that never counts down, VoiceOver gives no feedback as she types PIN digits,
the app asks the system about Face ID several times per redraw, and a VoiceOver user
may still be able to read the Home screen content sitting invisibly behind the lock.

**Root cause.** Three separate omissions in one view. (a) No timer state: AppLockGate.swift:113-114
renders a static string computed once at the moment of the failed attempt. (b) No
accessibility modifiers: the PIN dots at PINViews.swift:34-40 carry no
accessibilityValue, and the locked content at AppLockGate.swift:27-29 is hidden with
`.opacity(0)` and `.allowsHitTesting(false)` only — visual hiding, which does not
remove it from the accessibility tree. (c) No memoisation:
BiometricService.canAuthenticate/availableKind are convenience accessors that each
create an LAContext, and they are evaluated 3-4 times per AppLockGate body (:22,
:44-46, :83) and four times per PrivacyTrustView.promises evaluation (:62-63).

**Fix.**

1. 1. Drive the lockout message from a TimelineView or a Timer so it counts down, and
   re-enable the pad automatically when it reaches zero. Land this with the lockout-
   policy item (PRIV-18/PRIV2-14), which changes the deadline's representation.
2. 2. Add `.accessibilityValue("\(entered.count) of \(length) digits")` to the PIN
   dots at PINViews.swift:34-40.
3. 3. Add `.accessibilityHidden(showLockScreen)` to the content at
   AppLockGate.swift:27-29. The structural version of this is to present the lock in
   its own overlay window rather than as a sibling in the same ZStack, which removes
   the class of problem — prefer that if the duress-flash item (PRIV2-06) is already
   restructuring this view.
4. 4. Compute `canAuthenticate` and `availableKind()` once into locals per body pass
   in AppLockGate and in PrivacyTrustView.promises, instead of calling the accessors
   inline.

*Files:* `Caelyn/Views/Main/AppLockGate.swift`, `Caelyn/Views/Main/PINViews.swift`, `Caelyn/Views/Settings/PrivacyTrustView.swift`, `Caelyn/Services/BiometricService.swift`

*Tests:* None existing. Add a UI probe: with the lock shown, assert Home's static texts (e.g. a
"Good morning"-style greeting label) do not exist in the accessibility hierarchy.

#### PRIV-24 — 15 Delete all data · 11 duress · 14 Auto-erase  *(unconfirmed)*

If the app crashes or is killed part-way through a delete, the leftovers stay: her
PIN, the widget snapshot, her Apple Health samples or preference flags can survive,
and the next launch just shows onboarding with no record that a wipe was interrupted.

**Root cause.** wipeEverything is a linear, unjournalled sequence (SecureWipeService.swift:83-134:
SwiftData → notifications → Health → widget → PIN → ledger → defaults). The cloud half
already has a journal — CloudDataDeletion's pendingKey (CloudDataDeletion.swift:26-31)
— and that is precisely why the cloud step is ordered first; the local half has no
equivalent, so a crash after step 1 leaves residue with nothing scheduled to finish
it, and because step 1 removed the profile rows the next launch cannot tell a wipe
from a fresh install.

**Fix.**

1. 1. Land the reach/reason parameter item (PRIV2-05/PRIV-16) first; the resume path
   needs a `reason: .resume` value to exist on the signature.
2. 2. Write `caelyn.wipeInProgress` (carrying the reach and reason) to UserDefaults
   before step 1 of SecureWipeService.wipeEverything, and remove it after the last
   step.
3. 3. Add the key to the explicit NOT-cleared list beside
   CloudDataDeletion.deletedAtKey (SecureWipeService.swift:125, :131-133), so step 6's
   own defaults sweep cannot erase the journal it is running under.
4. 4. In CaelynApp's launch task, if the key is set, re-run wipeEverything with the
   recorded reach and `reason: .resume` before any UI appears. Every step is already
   idempotent (batch deletes, cancelAll, deleteAllOwnSamples, WidgetDataStore.clear,
   PINService.clearAll, key removal), so a re-run is safe.
5. 5. Suppress the auto-erase banner for a `.resume` run so an interrupted duress wipe
   still finishes silently.

*Files:* `Caelyn/Services/SecureWipeService.swift`, `Caelyn/Services/Account/CloudDataDeletion.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* Add a DeletionModelTests case that a pre-set caelyn.wipeInProgress marker triggers a
re-run at launch and leaves no residue, and one that the marker survives step 6's
defaults sweep.

#### PRO-09, PRO-17 — Paywall + restore + lapse (entitlement propagation / first render)  *(unconfirmed)*

On every cold launch a paying subscriber briefly sees upsell cards, and for a short
window her home-screen and lock-screen widgets can say 'Upgrade to Pro'. Right after
she buys or lapses, the widgets keep showing the old state until she next backgrounds
the app.

**Root cause.** There is no persisted last-known entitlement and the refresh is asynchronous and un-
awaited: PurchaseService.init kicks off `Task { await refreshPurchasedProducts() }`
(PurchaseService.swift:34-40, verified) and isPro is `proOverride ??
!purchasedProductIDs.isEmpty` (:45), so it is false for the first frames of every
launch. Compounding it, WidgetDataSyncModifier.sync() reads
PurchaseService.shared.isPro imperatively (WidgetDataSync.swift:131-141, verified)
outside SwiftUI observation, driven only by onAppear and scenePhase (:124-129) — so
onAppear can sample the race and write isPro:false for a Pro user, and no entitlement
change triggers a re-sync until the next .active/.background transition
(CaelynApp.swift:72-75).

**Fix.**

1. 1. Persist last-known isPro to UserDefaults after each refreshPurchasedProducts(),
   and seed a `lastKnownPro` value on init for first-frame rendering only. StoreKit's
   refresh overwrites it within milliseconds and remains the sole authority — never
   gate a purchase or a restore on the cached value.
2. 2. Make the widget sync observe the entitlement: hold `@State private var purchase
   = PurchaseService.shared` in WidgetDataSyncModifier and add `.onChange(of:
   purchase.isPro) { _, _ in sync() }`, so a purchase or lapse re-syncs immediately
   instead of waiting for a scene transition.
3. 3. Land after the Watch item (PRO-07), which edits the same sync() body — otherwise
   the two changes conflict.
4. 4. Keep the screenshot override (overridePro, PurchaseService.swift:48) ahead of
   the cached value so --screenshot-mode stays hermetic.

*Files:* `Caelyn/Services/PurchaseService.swift`, `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/App/CaelynApp.swift`

*Tests:* None exist. Add a test that the cached value seeds isPro before the first refresh and
is overwritten by it, and that overridePro still wins.

#### PRO-10 — Paywall + restore + lapse (entitlement refresh)  *(unconfirmed)*

If a subscription expires or is refunded while the app is backgrounded and she next
opens it with no network, Caelyn keeps treating her as Pro — the check that would have
noticed is skipped whenever the network call fails.

**Root cause.** The refresh call sits inside the do block rather than after it: in loadProducts()
(PurchaseService.swift:100-113, verified) `await refreshPurchasedProducts()` runs only
after a successful `Product.products(for:)`, so every post-launch scene-phase refresh
is coupled to network success. currentEntitlements is cache-served and needs no
network, so the coupling is gratuitous. The init-time refresh covers cold launch only.

**Fix.**

1. 1. Move `await refreshPurchasedProducts()` out of the do block in loadProducts()
   (PurchaseService.swift:107-113) so it runs on both the success and catch paths.
2. 2. Keep setting lastError on the catch path for the product fetch, but do not let
   it suppress the entitlement re-evaluation.
3. 3. Matches the original recommendation at docs/DIAGNOSIS.md:186-187 ('in init() and
   on every catch path').

*Files:* `Caelyn/Services/PurchaseService.swift`, `docs/DIAGNOSIS.md`

*Tests:* None exist. Add a test with an injected failing product fetch asserting entitlements
were still re-evaluated.

#### PRO-11 — Paywall + restore + lapse (savings badge)  *(unconfirmed)*

The yearly plan's savings badge rounds down by up to a point — 59.9% is shown as 'SAVE
59%'.

**Root cause.** Misuse of NSDecimalNumber default rounding: `NSDecimalNumber(decimal:
percent).rounding(accordingToBehavior: nil)` (PurchaseService.swift:90-96, verified)
uses NSDecimalNumber.defaultBehavior whose scale is NSDecimalNoScale, making the call
a no-op; `Int(...)` then truncates toward zero. The existing test values (58.249 ->
58, CaelynTests.swift:445-465) pass under both behaviours and cannot detect it.
Negative savings fall through to 'BEST VALUE' (PaywallView.swift:442-446).

**Fix.**

1. 1. Replace the rounding with an explicit NSDecimalNumberHandler(roundingMode:
   .plain, scale: 0, raiseOnExactness: false, raiseOnOverflow: false,
   raiseOnUnderflow: false, raiseOnDivideByZero: false), or simply
   `.doubleValue.rounded()`.
2. 2. Return 0 explicitly when savings are negative so the BEST VALUE fallback is
   intentional rather than incidental.
3. 3. Fix the stale comment claiming the value is rounded.

*Files:* `Caelyn/Services/PurchaseService.swift`, `Caelyn/Views/Premium/PaywallView.swift`, `CaelynTests/CaelynTests.swift`

*Tests:* Add testYearlySavingsPercentRoundsUp with a .6 fraction (the probe); the existing test
at CaelynTests.swift:445-465 stays but no longer carries the burden of proof.

#### PRO-12 — profile.isPro vs PurchaseService.isPro  *(unconfirmed)*

No user-visible effect today. There is a second, dead 'Pro' field stored on her
profile and synced to her iCloud; it is always false, and the tests claim dropping it
would lose her purchase — which is not true. A future change that trusts it would
silently gate on a dead flag.

**Root cause.** A pre-StoreKit-2 flag that was never retired. No gate reads profile.isPro — every gate
reads PurchaseService.shared.isPro (confirmed by grep across Caelyn, CaelynWidget,
CaelynWatch) — yet the field persists (UserProfile.swift:82, 151, 168), onboarding
writes `isPro: false` (OnboardingViewModel.swift:122), ProfileStore unions it
(`dst.isPro = dst.isPro || src.isPro`, ProfileStore.swift:79), and ProfileStoreTests
assert 'her purchase was lost' if it is dropped (ProfileStoreTests.swift:64, 80, 120,
128). CloudKit forbids removing attributes, so it was left in place without being
marked dead. Already noted Low at docs/DIAGNOSIS.md:122.

**Fix.**

1. 1. Do NOT remove the attribute — removal would be the project's first non-additive
   CloudKit migration and Production would refuse it.
2. 2. Mark it `@available(*, deprecated, message: "Never read. StoreKit
   (PurchaseService.isPro) is the only entitlement truth.")`.
3. 3. Drop the `isPro:` init parameter from the onboarding construction
   (OnboardingViewModel.swift:122).
4. 4. Delete the merge line at ProfileStore.swift:79 and the two misleading
   ProfileStoreTests assertions.
5. 5. Add a source-scan test (same shape as SignInWithAppleComplianceTests) that fails
   if any View or Service reads `.isPro` on a UserProfile.

*Files:* `Caelyn/Models/UserProfile.swift`, `Caelyn/Views/Onboarding/OnboardingViewModel.swift`, `Caelyn/Services/ProfileStore.swift`, `CaelynTests/ProfileStoreTests.swift`

*Tests:* Remove the isPro assertions at ProfileStoreTests.swift:64/80 and 120/128; add the
reader-scan test.

#### PRO-13 — Paywall + restore + lapse (Settings Pro card)  *(unconfirmed)*

Someone who bought Caelyn Pro outright is told to 'Manage your subscription in iOS
Settings' for a subscription she does not have, and an actual subscriber gets no one-
tap way to manage or cancel from the very card that says 'Active'.

**Root cause.** Entitlement-type awareness and the manage action live in AccountView rather than in
PurchaseService, so SettingsView cannot use them. AccountView already distinguishes
renewing from lifetime (hasAutoRenewingSubscription, AccountView.swift:460-464) and
implements openSubscriptionManagement() (:477-489), but the only button calling it
sits inside the 'Delete your Caelyn account?' confirmation (:433-438), shown only when
signed in with Apple. SettingsView.proSection (:223-242) has one Active state for all
three products. Separately, the lifetime product description in Caelyn.storekit:11
('nothing in the cloud') and PaywallView.swift:190 ('Your data stays on this device
either way') predate optional iCloud sync.

**Fix.**

1. 1. Move hasRenewingSubscription, hasLifetime and showManageSubscriptions() out of
   AccountView into PurchaseService.
2. 2. Branch the Active card in SettingsView.swift:223-242: lifetime -> 'Lifetime ·
   yours forever'; renewing -> a 'Manage subscription' button calling the moved
   helper.
3. 3. Update the two copy strings (Caelyn.storekit:11 and PaywallView.swift:190) to
   acknowledge that iCloud sync is optional and off by default, rather than asserting
   nothing is ever in the cloud.
4. 4. Keep the lifetime exclusion inside the moved helper so the compliance scan still
   finds it.

*Files:* `Caelyn/Services/PurchaseService.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Views/Premium/PaywallView.swift`, `Caelyn.storekit`

*Tests:* SignInWithAppleComplianceTests.swift:255-260 scans AccountView for
'ProductID.lifetime.rawValue' — update the scanned file path to wherever the helper
moves.

#### PRO-14 — 27 Advanced charts / 30 Unlimited pattern insights / 31 Full year view  *(unconfirmed)*

The Insights tab stutters for users with a long history — the heaviest, most Pro-
facing screen recomputes her whole cycle model dozens of times every time it draws.

**Root cause.** Computed-property fan-out with no per-render stash: every derived property in
InsightsView (cycles, avgCycleLength, cycleVariation, confidence, currentCycleDay,
nextStart, currentPhase, daysUntilPeriod, patternInsights — InsightsView.swift:14-47)
calls `cycle`, which calls CycleModel.make; loadedContent and summaryFacts read them
many times (:81-137), and patternInsights (the full PatternEngine) is read 2-3 times.
YearViewSection.body makes another CycleModel (:34) and MiniMonthView.entryMap
rebuilds a dictionary of all entries per month (:89-97), 12 times. The same defect was
fixed on Home in a1ca071 (HomeView.swift:35-52, 142) and never carried over.

**Fix.**

1. 1. Derive `cycle` and `patternInsights` once at the top of InsightsView.body using
   the same DerivedCycle stash pattern as HomeView.swift:35-52.
2. 2. Pass the derived values down to the sections rather than letting each recompute.
3. 3. Fold with the prediction-windows item (PRO-01/PRO-04): YearViewSection takes the
   three windows as values, which also deletes the second CycleModel.make at
   YearViewSection.swift:34.
4. 4. Build MiniMonthView's entry lookup once for the whole year and slice per month,
   instead of rebuilding a full dictionary 12 times (:89-97).

*Files:* `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Views/Insights/YearViewSection.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* None. Optionally add a counting test (inject a model factory that increments a
counter) asserting CycleModel.make is called once per render.

#### PRO-15 — 32 PDF export  *(unconfirmed)*

Every export leaves a file of her reproductive-health data sitting in the app's
temporary folder, and the doctor-facing PDF includes her private notes by default
unless she notices the toggle.

**Root cause.** No lifecycle ownership of the generated file, and one default serving two very
different audiences. writeToTempFile writes Caelyn-<range>-<date>.<ext> into tmp
(ExportService.swift:525-536) and resetGeneration() only nils the URL, so files
accumulate until the system purges tmp. includeNotes initialises to true for both
formats (ExportView.swift:12, 250-253), and the PDF is the clinical artefact.

**Fix.**

1. 1. Delete the previously generated file in resetGeneration() and in ExportView's
   onDisappear, so at most one export file exists at a time.
2. 2. Default includeNotes to false when format == .pdf — or flip it to false and
   prompt when the user switches to PDF — while leaving CSV's default as it is.
3. 3. State in the PDF options copy what 'private notes' means in a document she may
   hand to a clinician.

*Files:* `Caelyn/Services/ExportService.swift`, `Caelyn/Views/Settings/ExportView.swift`

*Tests:* None. Add a test that resetGeneration removes the file it previously wrote (inject the
directory).

#### PRO-16 — 29 TTC fertility score  *(unconfirmed)*

The fertility score judges her temperature against fixed textbook numbers rather than
her own baseline, so a woman who simply runs warm is told she is past ovulation every
single day. A positive LH test logged yesterday — which predicts ovulation today —
counts for nothing today.

**Root cause.** Unrealized potential: the TTC engine was written before WristTempOvulationEngine and
the learned-luteal work and was never re-based on them. TTCFertilityEngine.swift:41-48
scores basalTemperature against absolute thresholds (>= 36.7 -> −15 'post-ovulation',
36.3–36.7 -> +8) with no personal baseline, reads only today's entry (:61-70), and
hard-codes Calendar.current.startOfDay(for: Date.now) inside the engine (:26), which
prevents deterministic tests — and none exist (no TTCFertilityEngine references in
CaelynTests). Meanwhile WristTempOvulationEngine already implements a personal
coverline (prior-6-day mean + 0.2 °C, :26-28, 43-47).

**Fix.**

1. 1. Add `today:` and `recentEntries:` parameters to TTCFertilityEngine.result so it
   is pure and testable (removing the Date.now read at :26).
2. 2. Score BBT relative to the prior-6-day mean, reusing WristTempOvulationEngine's
   coverline constant rather than absolute °C thresholds.
3. 3. Carry an LH positive/surge forward 24–36 h so yesterday's positive still
   contributes today.
4. 4. Fold in WristTempOvulationEngine.detectShift as a confirmation signal when wrist
   temperature is available.
5. 5. Add unit tests for each signal branch; do this together with removing the
   `lutealLength = 14` default (PRO-01/PRO-04 item), which touches the same function
   signature.
6. 6. Keep the °C-only input and 35–42 validation in DailyLogForm (:657-672) unchanged
   — this is a scoring change, not an input change.

*Files:* `Caelyn/Services/TTCFertilityEngine.swift`, `Caelyn/Services/WristTempOvulationEngine.swift`, `Caelyn/Views/Home/TTCDashboardCard.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* New tests only: one per signal branch (BBT below/above personal coverline, LH positive
today, LH positive yesterday, wrist-temp shift confirmed), all with injected `today`.

#### PRO-18 — Paywall + restore + lapse (entitlement evaluation)  *(unconfirmed)*

No user impact today. If Caelyn ever sells anything that is not Pro — a tip jar, a
one-off extra — buying it would silently unlock all of Pro.

**Root cause.** Set membership is used as a boolean with no product allow-list: `isPro` is
`!purchasedProductIDs.isEmpty` (PurchaseService.swift:45, verified) and
refreshPurchasedProducts (:154-162) inserts every verified transaction's productID
without filtering to ProductID.allCases.

**Fix.**

1. 1. In refreshPurchasedProducts (PurchaseService.swift:154-162) insert only IDs
   where `ProductID(rawValue: transaction.productID) != nil`.
2. 2. Alternatively keep all purchased IDs but derive isPro from an explicit Pro-
   granting set, which is clearer if a non-Pro product is ever added.

*Files:* `Caelyn/Services/PurchaseService.swift`

*Tests:* None exist. Add a test that an unknown product ID in the entitlement set does not
grant isPro.

#### REM-12 — NotificationService.scheduleNoteReminders / scheduleOneShot (iOS 64-pending limit)  *(unconfirmed)*

A heavy note-taker's furthest-out note reminders quietly never arrive, because iOS
only holds 64 pending notifications and Caelyn queues notes last. And if several notes
are set to the same cycle moment, she gets five identical 'You left yourself a note'
banners at once.

**Root cause.** No accounting of the pending budget: the fixed categories can queue ~23 requests (7
check-in + 7 medication + 1 period + 1 ovulation + 7 pill), note reminders are
unbounded and scheduled after everything else, and every add is `try? await …
add(request)` (NotificationService.swift:385, :424) so iOS's rejection is swallowed
with no diagnostics.

**Fix.**

1. 1. Extract a pure planner: given the fixed requests and the candidate note
   requests, return the list actually to be scheduled. Compute remaining = 64 − fixed
   count and take note reminders soonest-first up to that budget.
2. 2. Coalesce note reminders that resolve to the same minute into one request with
   body 'You left yourself N notes' (keeping the no-text privacy rule).
3. 3. Replace `try?` with do/catch + Logger(subsystem:category:'notifications') at
   both add sites so a rejection is visible in Console.
4. 4. Order the schedule so the fixed categories and the soonest notes are added
   first.

*Files:* `Caelyn/Services/NotificationService.swift`

*Tests:* Unit test the pure planner: 80 candidate requests in → 64 out, soonest-first; two
candidates at the same minute collapse to one.

#### REM-13 — DailyLogForm.commitNote + the scheduleNoteReminders entry filter  *(unconfirmed)*

She deletes the note she had set a reminder on. Weeks later she writes a new note on
that same day — and a reminder she never asked for fires.

**Root cause.** The rule's lifecycle is not tied to the note's. commitNote writes note = nil
(DailyLogForm.swift:1079-1086) but leaves
noteReminderRule/noteReminderAt/noteReminderDone in place; scheduleNoteReminders then
skips the entry only because `entry.note?.isEmpty == false` fails
(NotificationService.swift:355-359) and the control is hidden
(DailyLogForm.swift:788-790), so the orphaned rule is invisible until a new note re-
satisfies the filter.

**Fix.**

1. 1. In commitNote, when value == nil also set noteReminderRule = nil, noteReminderAt
   = nil, noteReminderDone = false.
2. 2. Call NotificationService.scheduleResync() (from the REM-03 item) afterwards so
   the already-queued request is cancelled immediately rather than at the next
   foreground.
3. 3. Optional one-time cleanup of existing orphans: in the launch dedupe walk, clear
   reminder fields on any entry whose note is nil/empty.

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/CycleStore.swift`

*Tests:* DailyLogDraftTests: clearing a note clears its rule, date and done flag.

#### REM-14 — RemindersView.refreshAuthStatus / deniedBanner / handleToggle; SettingsView.remindersDetail  *(unconfirmed)*

She taps 'Open iOS Settings' from the Reminders screen, allows notifications, comes
back — and Caelyn still shows the 'notifications are off' banner. Elsewhere, Settings
cheerfully says '3 on' when nothing can actually fire.

**Root cause.** Permission is sampled, not observed: authStatus is read once in .task
(RemindersView.swift:113) and after an explicit request, with no refresh when the view
returns to the foreground, and the Settings summary row (SettingsView.swift:603-611)
counts enabled flags without consulting authorization at all.

**Fix.**

1. 1. Refresh authStatus on `.onChange(of: scenePhase)` == .active in RemindersView
   (alongside the existing .task at :113).
2. 2. In SettingsView.remindersDetail (:603-611), when authorization is .denied show a
   bell.slash glyph and 'Off in iOS Settings' instead of the count.
3. 3. Leave the toggles operable but add an inline hint under a toggled-on row while
   denied, rather than hiding or disabling it — the stored preference should survive
   her granting permission later.

*Files:* `Caelyn/Views/Settings/RemindersView.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* None required; optionally a UI test asserting the Settings row copy under a denied-
permission launch argument.

#### REM-15 — AppDelegate.willPresent  *(unconfirmed)*

The daily check-in is described in Settings as arriving quietly — 'no banner, no
sound'. While the app is open, it pops a banner anyway.

**Root cause.** willPresent returns [.banner, .list, .sound] unconditionally
(AppDelegate.swift:22-28); presentation options are not derived from the request's
interruptionLevel, which the scheduler already sets to .passive for the check-in
(NotificationService.swift:185-190, :442-449).

**Fix.**

1. 1. In willPresent: `let level = notification.request.content.interruptionLevel;
   completionHandler(level == .passive ? [.list] : [.banner, .list, .sound])`.

*Files:* `Caelyn/App/AppDelegate.swift`, `Caelyn/Services/NotificationService.swift`

*Tests:* None.

#### REM-16 — NotificationService.syncFromLiveStore (profile fetch + demo-store guard)  *(unconfirmed)*

In a rare sync race Caelyn can read the wrong copy of her profile and cancel every
reminder. Separately, running the app in screenshot or UI-test mode can still read and
write the real on-disk store.

**Root cause.** Two conventions not applied here. (a) `FetchDescriptor<UserProfile>()` with `.first`
is unsorted (NotificationService.swift:328, verified) — commit c2b96fa moved view
queries to sort by createdAt precisely because a transient second profile makes
`.first` a coin flip before ProfileStore.dedupe runs at next launch, and here the
loser is a defaults-only profile that cancels everything. (b) Persistence.isDemoStore
(Persistence.swift:58-62), added by d0b31aa for exactly this, is consulted only by
CaelynApp; syncFromLiveStore reaches Persistence.live directly, and via
scheduleNoteReminders it writes.

**Fix.**

1. 1. `FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])` at
   NotificationService.swift:328.
2. 2. `guard !Persistence.isDemoStore else { return }` at the top of
   syncFromLiveStore.
3. 3. Apply the same two fixes to the other direct Persistence.live readers named in
   the finding: CloudSyncCoordinator.refreshDerivedSnapshot (:91),
   HealthKitSync:32/43, HealthSyncService:317, CaelynApp:97 — cross-area, coordinate
   with those owners.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Services/Persistence.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`

*Tests:* None existing; a source-grep audit test asserting every Persistence.live reader checks
isDemoStore would make it permanent.

#### REM-17 — MainTabView.tab(for:) + DailyLogForm advanced section + highlightedNotificationCategory consumers  *(unconfirmed)*

She taps the medication reminder, lands on the Log tab — and the medication field is
not there, because it is folded away under 'More to track'. Nothing on screen is
highlighted to show her where to go.

**Root cause.** Routing stops at the tab: tab(for:) sends .medication/.birthControl to Log
(MainTabView.swift:129-136) but DailyLogForm's medicationField lives inside the
collapsed `showAdvanced` section (DailyLogForm.swift:875-940, default false). The
highlightedNotificationCategory environment value is consumed by exactly one view,
HomeMoodCheckIn for .dailyCheckIn (HomeMoodCheckIn.swift:7-12), so period, ovulation,
medication and note taps pulse nothing.

**Fix.**

1. 1. Have DailyLogForm read the highlightedNotificationCategory environment value;
   when it is .medication or .birthControl, set showAdvanced = true and focus the
   medication field.
2. 2. Have HomeHeroCard pulse for .periodUpcoming and .ovulation, and the note-
   reminder card pulse for .noteReminder.
3. 3. Carry the entry's dayKey in the notification's userInfo for .noteReminder so the
   tap can open that specific day's sheet rather than the tab.

*Files:* `Caelyn/Views/MainTabView.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Home/HomeMoodCheckIn.swift`, `Caelyn/Views/Home/HomeHeroCard.swift`

*Tests:* None existing; a UI test can assert the medication field is visible after launching
with a simulated medication tap once the routing probe exists.

#### REM-18 — NotificationService.sync birth-control patch/ring branches + content(for: .birthControl)  *(unconfirmed)*

A ring user who does not open Caelyn for three weeks misses the reminder to put the
next ring in. And the reminder never says what to do — remove, change or insert — only
'Don't forget your birth control today.'

**Root cause.** The patch/ring loops break after the first future event
(NotificationService.swift:274-321), so only one request is ever pending — horizon
logic copied from the daily model but truncated. patchDays/ringDays can also go
negative when birthControlStartDate is later than today (clock skew, or a profile
synced from a device in a later timezone) and Swift's % preserves the sign, so the
derived offsets are wrong. The body is a Category-keyed constant (:105-110) even
though the scheduler knows which kind of day it is.

**Fix.**

1. 1. Schedule every patch/ring event within max(scheduleHorizonDays, 28) instead of
   breaking after the first.
2. 2. Clamp: `let days = max(0, ...)` before the modulo at the patch/ring day
   computation.
3. 3. Add an `action` enum (change / remove / insert) parameter to the birth-control
   content so the non-private body names the actual task; leave the private body
   unchanged.
4. 4. Extract the offset computation into a pure function so it can be tested.

*Files:* `Caelyn/Services/NotificationService.swift`, `Caelyn/Views/Settings/BirthControlView.swift`

*Tests:* Test the extracted offset planner at cycle days 0, 7, 21, 27 and with a negative
(future start date) input.

#### RP-1, RP-2 — 47 Rating prompt  *(unconfirmed)*

Caelyn can use up one of its only three lifetime chances to ask for a review without
ever showing the alert — and start a 30-day silence on the back of it. The same path
can also pop a real App Store review alert in the middle of a screenshot or UI-test
run.

**Root cause.** The request path records and attempts its effects without validating its
preconditions. In requestReview() (RatingService.swift:82-91, verified) the two
`defaults.set` calls for lastPromptDate and timesPrompted execute BEFORE the `if let
scene = … .foregroundActive` lookup, so when no foreground-active window scene exists
(a scene transition, or a unit-test host) the counters advance and the cool-down
starts with no prompt shown. And considerRequestingReview (:46-52) — called from every
DailyLogForm mutation (DailyLogForm.swift:1010-1012, i.e. every chip tap) — has no
check for Persistence.isDemoStore or UI-test launch arguments, so the gate introduced
in d0b31aa for cloud state was never applied to the one system alert the app can
raise. CaelynUITests has no addUIInterruptionMonitor; it passes today only because
fresh simulators have firstLaunchDate == now.

**Fix.**

1. 1. Move both `defaults.set` calls inside the `if let scene { … }` block in
   requestReview() (RatingService.swift:84-90) so quota is spent only when an alert is
   actually requested.
2. 2. Replace SKStoreReviewController.requestReview(in:) with StoreKit's
   AppStore.requestReview(in:) — available since iOS 16, inside the 17.0 target
   (project.yml:7-8), and the SK call is deprecated from iOS 18.
3. 3. Keep the UserDefaults keys unchanged so upgrading users keep their prompt
   history.
4. 4. Add a single `RatingService.isEnabled` gate at the top of
   considerRequestingReview (:48): `guard !Persistence.isDemoStore,
   !CommandLine.arguments.contains("--ui-test-onboarding") else { return }`, or set
   the flag once from CaelynApp's existing mode detection so every future entry point
   inherits it.
5. 5. Add an addUIInterruptionMonitor in CaelynUITests as a belt-and-braces guard for
   any system alert.

*Files:* `Caelyn/Services/RatingService.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/Persistence.swift`, `CaelynUITests/CaelynUITests.swift`

*Tests:* None exist for RatingService. Add the probe as a unit test (fails today, passes after
the fix) and a test asserting the demo store never prompts.

#### SC-2 — 41 Shareable card  *(unconfirmed)*

Caelyn's only way for a user to share something is reachable roughly twice in a
lifetime, and once she dismisses the one-week celebration card it is gone forever. Two
of the four card designs are never shown at all.

**Root cause.** Templates were designed ahead of entry points and the share is attached to a one-time
celebration rather than a durable surface. ShareableMoment has four cases
(ShareableCard.swift:8-13) but only .oneWeek (HomeView.swift:479) and .learnedRhythm
(InsightsView.swift:227, gated on cycles.count >= 3 at :99) are ever constructed;
.phase and .privacy are never built. The .oneWeek entry lives on a celebration gated
by !firstWeekCelebrated (HomeView.swift:16, 174-176, 471-482) — dismissing it sets the
device-local flag permanently. Separately the sheet caption 'never your cycle data'
(:163) is true today but the dormant .phase template prints her phase name, so wiring
it later would make the caption false.

**Fix.**

1. 1. Decide per template: either delete .phase and .privacy, or give them a home.
2. 2. If keeping them, add a durable 'Share a moment' row (Settings -> About, and/or
   Insights) offering .privacy always and .learnedRhythm once >= 3 cycles exist.
3. 3. Keep the celebration share as a shortcut rather than the only door.
4. 4. If .phase is ever wired, change the caption at ShareableCard.swift:163 to 'never
   your dates or numbers' in the same change — not afterwards.

*Files:* `Caelyn/Views/Share/ShareableCard.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Insights/InsightsView.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* Add a test asserting every ShareableMoment case is constructed by at least one entry
point (source scan), so a dormant template cannot reappear.

#### ST-1 — 42 Streak card  *(unconfirmed)*

A user with months of history who steps away for a fortnight comes back to 'Your first
log starts here' and is told to start her streak, as though she were brand new — the
opposite of the welcome the 'grace, not guilt' design intends.

**Root cause.** The card infers 'has she ever logged' from whatever data it happens to receive:
hasPastLogs is computed from recentDays only (HomeStreakCard.swift:10), and recentDays
is a 14-day window (CycleAnalytics.swift:211-222). The `case 1` copy additionally
assumes a streak of 1 means a first log (HomeStreakCard.swift:15-16), and the
accessibility label (:34-37) ignores the paused state. Home already computes
loggedDayCount (HomeView.swift:93-95) and simply does not pass it.

**Fix.**

1. 1. Pass `totalLoggedDays: loggedDayCount` from HomeView.swift:93-95 into
   HomeStreakCard.
2. 2. case 0: totalLoggedDays > 0 -> paused/welcome-back copy; else first-log copy.
3. 3. case 1: totalLoggedDays > 1 -> 'Back at it — day 1'; else 'First log — great
   start!'.
4. 4. Mirror the same branch in the accessibility label at :34-37.
5. 5. Extract `streakLabel(streak:totalLogged:)` as a static pure function so the copy
   branches are unit-testable.

*Files:* `Caelyn/Views/Home/HomeStreakCard.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Services/CycleAnalytics.swift`

*Tests:* None exist (the label is private). After extracting streakLabel(streak:totalLogged:),
test (0,0), (0,40), (1,1) and (1,40).

#### SYNC-15 — 38 Backup status  *(unconfirmed)*

The diagnostics card (and the equivalent lines in export) shows the date of her most
recent log one day off when she has two devices in different time zones.

**Root cause.** Readers that were not migrated to the stored day key still format CycleEntry.date,
which is the writing device's local midnight expressed as an instant, instead of
CycleEntry.day.

**Fix.**

1. 1. DataStatusCard.swift:27-30 — format `latest.day`, not `latest.date`.
2. 2. Sort the query that finds `latest` by dayKey rather than date.
3. 3. Sweep the same pattern in the user-facing export readers (ExportService.swift:77
   and :403) — owned by the export area but the same one-line change.
4. 4. This is a prerequisite for deleting the `date` rewrite in
   CycleStore.dedupeSameDay: any reader left on `.date` after that change shows the
   writer's zone rather than hers.

*Files:* `Caelyn/Components/DataStatusCard.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/ExportService.swift`

*Tests:* None required; the card is DEBUG-only. Cover the export readers with an existing
export test fixture written in a non-device zone.

#### SYNC-16 — 26 Private iCloud sync  *(unconfirmed)*

On a day when she logs a lot, the widgets can stop refreshing by late afternoon
because the app has spent its daily refresh allowance.

**Root cause.** refreshDerivedSnapshot calls WidgetCenter.shared.reloadAllTimelines() after every
notification burst regardless of whether anything actually merged
(CloudSyncCoordinator.swift:82, 100-101), while WidgetDataSyncModifier already reloads
on appear and scene changes (WidgetDataSync.swift:125-138). If
NSPersistentStoreRemoteChange is also posted for the process's own saves — framework
behaviour not settled by reading — each log edit costs two reloads against WidgetKit's
budget.

**Fix.**

1. 1. Reload only when the pass actually changed something: gate the
   reloadAllTimelines() call on merged > 0.
2. 2. Better: compare the newly built snapshot against the stored one and skip the
   write and the reload when they are identical — that is correct whatever the
   framework does with local saves.
3. 3. If a distinction by author is wanted, inspect the persistent-history
   transactions since the last token (NSPersistentHistoryChangeRequest) and reload
   only when an author other than this app appears.

*Files:* `Caelyn/Services/Account/CloudSyncCoordinator.swift`, `Caelyn/Services/WidgetDataSync.swift`

*Tests:* New: building the same snapshot twice writes once and requests no second reload.

#### SYNC2-10 — 26 Private iCloud sync  *(unconfirmed)*

After she travels, the launch pass quietly rewrites every entry in the store but
reports that it did nothing, and the device log says 'merged 0' on exactly the passes
that changed the most — which is what would make the time-zone problem hard to
diagnose from a log.

**Root cause.** dedupeSameDay's dirty-tracking counters (`removed`, `backfilled`) were written for the
two operations that change the row SET and never extended to the one that changes a
row's VALUE (the `date` normalisation at CycleStore.swift:47-52, added later in the
same loop). Both the save condition at :54 and the return value at :55 are derived
from those two counters, so a pure normalisation pass mutates every row, saves nothing
explicitly, and returns 0.

**Fix.**

1. 1. Count normalisations in a third variable, include it in the `if removed > 0 ||
   backfilled > 0` save condition at CycleStore.swift:54, and log it separately so the
   reconcile path (CloudSyncCoordinator.swift:73-83) can report what the pass actually
   did.
2. 2. Keep the extra count OUT of the return value: CivilDayTests.swift:170-200 and
   UpgradeAndDeviceMatrixTests.swift:193-229 assert the return equals the number of
   REMOVED rows.
3. 3. If the date rewrite is deleted as part of the dayKey item, this counter
   disappears with it — implement whichever lands first and drop the other.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/Services/Account/CloudSyncCoordinator.swift`

*Tests:* No existing test fails. If the counter is added, do not change the return value, or
CivilDayTests.swift:170-200 and UpgradeAndDeviceMatrixTests.swift:193-229 break.

#### SYNC2-11 — 38 Backup status  *(unconfirmed)*

Caelyn tells her to go to iPhone Settings and sign in to iCloud. She does, comes back
— and the sync switch is still dead with the same sentence underneath. The screen only
ever asked iCloud once, when she first opened it.

**Root cause.** AccountView.availability is initialised to .unreachable (AccountView.swift:21) and set
once in .task (:56). The toggle's disabled: is `!availability.canEnableSync &&
!syncOn` (:221) and statusLine renders availability.message (:249-255), but there is
no scenePhase observer — CaelynApp already re-checks the Apple credential on every
.active transition for exactly this reason (CaelynApp.swift:80-84) and iCloud account
status was never given the same treatment. Separately, the initial value is a FAILURE
case rather than an 'unknown' case, so the pre-answer render is indistinguishable from
a real failure.

**Fix.**

1. 1. Add an `unknown` case to CloudAvailability whose message is quiet ('Checking
   with iCloud…') and whose canEnableSync is false, and start AccountView in it
   instead of .unreachable.
2. 2. Re-run `CloudAccount.availability()` on scenePhase == .active inside
   AccountView, the same way the Apple credential is reconciled, so returning from
   iPhone Settings enables the switch without her having to leave the screen and come
   back.
3. 3. Land with the SyncReport item — availability is one of its inputs, and the
   status line must distinguish unknown from failed.

*Files:* `Caelyn/Views/Settings/AccountView.swift`, `Caelyn/Services/Account/CloudAccount.swift`

*Tests:* CloudAvailability is Equatable with an exhaustive message switch; adding a case
requires updating it. No existing test enumerates the cases — add one.

#### T1-12 — 9 Onboarding (Apple Health connect step)  *(unconfirmed)*

At onboarding she taps Connect Apple Health, Apple's permission sheet appears, and she
declines every single type. Caelyn still tells her "Apple Health connected" and shows
all the read toggles switched on. Nothing is ever imported, and she has no idea why.

**Root cause.** HealthKit by design never reports read authorization, and the onboarding step treats
"requestReadAuthorization did not throw" as "granted" (OnboardingSteps.swift:947-953),
so complete() sets healthKitConnected plus every hkRead* flag to true
(OnboardingViewModel.swift:124-130). syncOnForeground then runs on every foreground
and reads nothing, with no state anywhere that distinguishes "asked and refused" from
"asked and granted".

**Fix.**

1. 1. Keep the toggles as they are — they are the only honest model of a permission
   the platform will not disclose.
2. 2. Change the card's phrasing from a claim to a record of what happened: "Apple
   Health asked" rather than "Apple Health connected".
3. 3. Use the one signal that does exist: when the first sync returns
   summary.daysAffected == 0, show "Nothing imported yet — check Health -> Sharing"
   with a tap-through, on both the onboarding card and the matching Settings row so
   the two surfaces never disagree.
4. 4. Do not retry the authorization request automatically; iOS will not re-present
   the sheet, and a silent retry would read as a hang.

*Files:* `Caelyn/Views/Onboarding/OnboardingSteps.swift`, `Caelyn/Views/Onboarding/OnboardingViewModel.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* None exist. Add a pure test for the status-copy function: (healthKitConnected: true,
daysAffected: 0) -> the 'nothing imported' copy; (true, >0) -> the connected copy.

#### T1-13 — 1 Daily log (LogView date pills / empty rows)  *(unconfirmed)*

She clears every field on a day. The day still shows the little "logged" dot on the
date strip and still offers a trash icon, as though something were there. Her streak
and summary are unaffected, so it is only the indicators that lie.

**Root cause.** withEntry never removes a row it has emptied (DailyLogForm.swift:998-1008), and
LogView's two indicators check existence rather than content — hasEntryOnSelectedDate
(LogView.swift:28-34) and the date pill (:131). The import path already gets this
right: ImportReconciler deletes a day it empties (ImportReconciler.swift:347-354), so
the codebase already contains the correct rule, applied in only one of two places.

**Fix.**

1. 1. Minimum, zero-risk half: make LogView's two checks use hasContent rather than
   existence (LogView.swift:28-34 and :131). This fixes what she sees without deleting
   anything.
2. 2. Fuller half, for consistency with ImportReconciler: in withEntry, after the
   mutation, if `!target.hasContent && target.noteReminderRule == nil` then delete the
   row and call HealthKitSync.deleteFlowIfConnected for that day.
3. 3. Guard the note-reminder case explicitly — a day whose only content is a
   scheduled note reminder must not be deleted out from under the reminder (see
   T2-07).
4. 4. Treat step 2 as the one that changes stored data: a delete propagates over
   CloudKit, and the additive merge policy means it must not race an incoming copy
   that still has content. Prefer step 1 first, step 2 behind a deliberate decision.

*Files:* `Caelyn/Views/Log/LogView.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Services/Import/ImportReconciler.swift`

*Tests:* DailyLogDraftTests: add 'clearing the last field removes the row' and 'a row whose
only content is a note reminder survives'. The stz-011 phantom-entry tests
(DailyLogDraftTests.swift:287) must keep passing unchanged.

#### T1-14, T1-15 — 2 Symptom tracking (DailyLogForm symptom grid)  *(unconfirmed)*

Two ways the symptom grid shows her something other than what is stored. First: if she
logged "Pelvic pressure" while endometriosis mode was on and later turns that mode
off, the symptom still appears in the severity rows but its chip is gone — she can see
it and cannot remove it, and Insights keeps counting it. Second: the severity row
always shows "Mod" highlighted even when no severity was ever saved, so tapping the
highlighted pill deletes the stored value with no visible change on screen.

**Root cause.** One mechanism on two controls: the display model is derived from configuration and
defaults rather than from what the entry actually holds, so stored data becomes
invisible or unreachable. visibleSymptoms is built purely from profile condition flags
and never consults entry?.symptoms (DailyLogForm.swift:339-357, consumed at :380-388
and :453-455). currentLevel is `severity ?? 2` (:463), so the rendered state for
'absent' is identical to the rendered state for 'moderate' (:478-501, :1020-1030) and
the toggle at the active level writes nil while the UI keeps drawing 2.

**Fix.**

1. 1. Append anything in entry?.symptoms that is not already in visibleSymptoms, so
   the grid is the union of what is configured and what the day actually holds
   (DailyLogForm.swift:339-357). That is the permanent shape: any future way of hiding
   a symptom category automatically still leaves logged data removable.
2. 2. Give the appended-but-unconfigured chips a quiet visual treatment and keep them
   tappable-off, so she can clear them without turning the mode back on.
3. 3. Stop the severity display from inventing a value: either render no active pill
   when severity is nil, or make tapping the currently active level a no-op. Prefer
   the first — the nil state is real and should be visible.
4. 4. Confirm toggleSymptom's behaviour: it already stores 2 on selection, so nil
   should not arise through the normal path; the ?? 2 default exists only to paper
   over rows where it did. Removing the default will surface any remaining producer of
   nil.

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`

*Tests:* None exist for either. Extract visibleSymptoms and the severity-pill state as pure
functions of (profile flags, entry) and test: a symptom present on the entry but
absent from the flags still appears; severity nil renders no active pill; toggling an
active pill does not produce an invisible state change.

#### T1-16, T1-17 — 6 Calendar / 1 Daily log / 8 Local-first storage (residual instant-based `date`)  *(unconfirmed)*

Two leftovers from this week's timezone fix. While she is travelling, and before the
next app launch, the month summary can file the 1st of a month under the previous
month, the 'days logged' count can be off, and deleting a day from the Log tab can
remove the wrong day's data from Apple Health. And separately: every launch in a new
timezone silently rewrites the stored timestamp on every row she has ever logged — so
for someone who travels, or a household split across timezones with sync on, two
devices rewrite each other's rows at every launch, burning network and battery in
proportion to how much history she has. No data is lost either way.

**Root cause.** The dayKey pass converted the engine and the calendar grid but left `date` load-
bearing in three readers and one writer. The readers still key on the instant:
MonthSummaryCard (:11-21), CycleAnalytics.daysLogged (:172-176), and LogView's delete,
which passes entry.date to HealthKitSync (LogView.swift:88-93, verified: `let
dateToClean = entry.date`), where it is day-ranged with the current calendar
(HealthKitSync.swift:19-21, :35). The writer is dedupeSameDay, which sets entry.date =
localDate(key) whenever it differs (CycleStore.swift:48-50) in order to keep those
very readers working — and does so unconditionally on zone, with no explicit save
(saveOrLog runs only when removed/backfilled > 0), relying on autosave. So the two
halves sustain each other: the rewrite exists because the readers need `date`, and the
readers persist because the rewrite hides their flaw.

**Fix.**

1. 1. Convert the three readers to the stored day: use entry.day (or the day(in:)
   helper) in MonthSummaryCard.swift:11-21 and CycleAnalytics.swift:172-176, and pass
   the civil day to HealthKitSync from LogView.swift:88-93 so HealthKitSync.serialized
   keys on the civil day rather than an instant.
2. 2. Only once step 1 lands, stop normalising in dedupeSameDay
   (CycleStore.swift:48-50) altogether: dayKey becomes the identity and `date` becomes
   write-once. That is what ends the cross-device rewrite churn permanently, rather
   than merely making it cheaper.
3. 3. Interim, if step 2 must wait: normalise only on a genuine day mismatch
   (`CivilDay.key(for: entry.date, calendar:) != key`) rather than on any instant
   difference, and call saveOrLog explicitly when any date was normalised instead of
   relying on autosave.
4. 4. Note the ordering dependency: shipping step 2 without step 1 would expose the
   three readers to un-normalised dates and turn a rare mid-trip drift into a
   persistent one.
5. 5. Audit for the same residue while here: NotificationService.scheduleNoteOneShot
   keys its identifier off entry.date (NotificationService.swift:383) — see T2-07 step
   2.

*Files:* `Caelyn/Views/Calendar/MonthSummaryCard.swift`, `Caelyn/Services/CycleAnalytics.swift`, `Caelyn/Views/Log/LogView.swift`, `Caelyn/Services/HealthKitSync.swift`, `Caelyn/Services/CycleStore.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* CivilDayTests: extend the 'readers keyed to stored day' coverage to MonthSummaryCard's
inputs (extract its filters into CycleAnalytics so they are testable) and to the
HealthKit delete range. UpgradeAndDeviceMatrixTests.testRepeatedLaunchesChangeNothing
(:151) and testDatesAreStableAcrossTheMatrix (:361) should each be extended with a
second calendar/timezone and assert that no row's date was rewritten.

#### T1-18, T2-11 — 5 Home / 1 Daily log / 8 Local-first storage (day -> row resolution)  *(unconfirmed)*

Two symptoms of one thing: Caelyn does not have a single agreed way of answering
"which saved row is this day?". So in the brief window after iCloud delivers a
duplicate row and before Caelyn tidies it up, the log screen can show one row and
write to another — she taps a symptom chip, nothing visibly changes, she taps again,
and after the two rows are merged the symptom ends up logged when she meant to remove
it. Separately, three buttons on Home create rows by hand instead of going through the
shared path, and "Change date" for a period never writes the new day to Apple Health.

**Root cause.** 'The entry for this day' is not a single well-defined object. DailyLogForm resolves it
from the @Query snapshot — `allEntries.first { $0.dayKey == key }` over an array
sorted by date descending (DailyLogForm.swift:9, :49-54) — while withEntry writes
through CycleStore.entry(for:in:), which issues a fresh FetchDescriptor with a dayKey
predicate, NO sort, and takes .first (CycleStore.swift:65-80). After normalisation
duplicates share a date, so the @Query sort cannot disambiguate and the fetch has no
sort at all: the two .first calls are ordered independently. dedupeSameDay resolves
the same question by createdAt (CycleStore.swift:34-35); neither lookup does. The Home
half is the same absent convention upstream: logPeriodToday (HomeView.swift:706-712),
logMood (:760-763) and movePeriodStart (:783-786) build rows with CycleEntry(date:) +
modelContext.insert and resolve 'does one exist?' from the @Query snapshot — exactly
the pattern DailyLogForm's comment at :998-1004 was written to forbid — and
movePeriodStart additionally omits the HealthKitSync call its sibling logPeriodToday
makes at :772-774.

**Fix.**

1. 1. Give CycleStore.entry(for:in:) a deterministic tiebreak: `sortBy:
   [SortDescriptor(\CycleEntry.createdAt)]` on the descriptor
   (CycleStore.swift:65-80), so it returns the same row dedupeSameDay keeps.
2. 2. Make every reader use the same ordering: DailyLogForm.entry (:49-54),
   LogView.entryOnSelectedDate, HomeView.todayEntry — either `allEntries.filter {
   $0.dayKey == key }.min(by: { $0.createdAt < $1.createdAt })` or a @Query sorted by
   createdAt. One rule, stated once.
3. 3. Route Home's three direct inserts through CycleStore.entry(for:)
   (HomeView.swift:706-712, :760-763, :783-786). dayKey is already set by the
   initialiser, so the dayKey fix holds today; the risk being removed is the stale-
   snapshot duplicate, not a missing key.
4. 4. Call HealthKitSync.syncIfConnected after movePeriodStart, matching
   logPeriodToday (HomeView.swift:772-774). If CycleStore.movePeriodStart is
   introduced by another item, this is subsumed by it.
5. 5. Hold the line with a grep-style test asserting no `CycleEntry(date` appears
   outside CycleStore and the test mocks — that is what makes it permanent rather than
   a sweep that decays.

*Files:* `Caelyn/Services/CycleStore.swift`, `Caelyn/Views/Log/DailyLogForm.swift`, `Caelyn/Views/Log/LogView.swift`, `Caelyn/Views/Home/HomeView.swift`

*Tests:* CivilDayTests' duplicate-merge cases should assert that CycleStore.entry(for:) returns
the dedupe keeper BEFORE the merge runs, and that the form's reader returns the same
object as the writer for a day with two rows. Add the grep test from step 5.

#### T1-19 — 5 Home (irregular-mode banner)  *(unconfirmed)*

She taps "Enable irregular mode" (or dismisses the banner) on Home. The change takes
effect on this phone but is not written out immediately, so with sync on her other
device can keep showing the banner she just dismissed until the system happens to
save.

**Root cause.** Both button actions mutate profile flags and rely on SwiftData autosave
(HomeView.swift:819-840), while every other profile write in the app calls
modelContext.saveOrLog() explicitly. The convention exists; these two sites predate or
missed it.

**Fix.**

1. 1. Add modelContext.saveOrLog() to both button actions at HomeView.swift:820-835.
2. 2. While here, grep for other profile mutations that do not save — the fix is only
   permanent if the convention is complete. A lint-style test asserting that profile-
   mutating view actions are followed by a save is not practical, so a one-time sweep
   plus a comment at the mutation site is the realistic ceiling.

*Files:* `Caelyn/Views/Home/HomeView.swift`

*Tests:* None exist and none are strictly needed; if the sweep in step 2 finds other sites, a
ProfileStore-level test that a mutation is durable after a context reload would cover
the class.

#### T1-20 — 1 Daily log (test architecture — DailyLogDraftTests)  *(unconfirmed)*

Invisible to users, but it undermines the protection around this week's most important
fix. The tests that are supposed to guard the daily log's save behaviour do not
actually run the app's code — they run a hand-written copy of it that has already
drifted. So the delete-doesn't-delete fix is protected by tests that would pass even
if the real code broke.

**Root cause.** The draft, seed, adopt and commit rules live as private members of the DailyLogForm
View, so they cannot be called from a test. DailyLogDraftTests therefore models them
instead — acknowledged in its own header at :21-23 — and the model has diverged: the
harness's withEntry uses `CycleEntry(date: day)` + insert and finds rows with
`cal.isDate($0.date, inSameDayAs:)` (:41-45, :88-95), whereas the shipping form goes
through CycleStore.entry(for:) and matches on dayKey (DailyLogForm.swift:998-1008).
Any fix to the form must be re-typed into the mirror, and the suite structurally
cannot detect a divergence.

**Fix.**

1. 1. Extract the drafts, the seeds, adopt() and the three commits into a
   `LogDraftModel` — a plain struct or @Observable with an injected store closure for
   row lookup and mutation — owned by DailyLogForm.
2. 2. Point DailyLogDraftTests at the extracted model. The fourteen existing cases
   carry over unchanged in intent; only the harness goes away.
3. 3. Delete the mirror's own withEntry and row-lookup helpers (:41-45, :88-95) rather
   than updating them — leaving a second implementation is what caused the drift.
4. 4. Sequence this AFTER the daily-log behaviour fixes (T1-13, and the day-row-
   resolution item) land, so those are written once against the extracted model rather
   than twice.

*Files:* `Caelyn/Views/Log/DailyLogForm.swift`, `CaelynTests/DailyLogDraftTests.swift`

*Tests:* DailyLogDraftTests rewritten against LogDraftModel; the fourteen existing cases carry
over unchanged in intent. The signal that the extraction worked: deliberately breaking
the form's commit guard must now fail a test.

#### TH-1 — 44 Theme  *(unconfirmed)*

A user who chose Dark gets a white flash on every cold launch and every return from
the app lock before the app snaps to dark — exactly the moment, logging at night, when
it is most jarring.

**Root cause.** The theme's only source of truth is a SwiftData row that is not synchronously readable
at first render. ThemedContentView derives preferredColorScheme from @Query
profiles.first?.theme (CaelynApp.swift:104-121, verified) which is empty until
SwiftData hydrates, while RootView paints Color(uiColor: .systemBackground) for >= 120
ms (RootView.swift:38-41, 55-59). themeBinding (SettingsView.swift:770-775, verified)
writes only the profile.

**Fix.**

1. 1. Mirror profile.theme.rawValue to a device-local UserDefaults key
   `caelyn.theme.cached`, written in themeBinding.set (SettingsView.swift:770-775).
2. 2. Also write it from `ThemedContentView.onChange(of: profiles.first?.theme)` so a
   CloudKit-delivered theme change updates the cache too.
3. 3. Initialise @State scheme from that key before the query hydrates; keep the query
   as the authority once loaded.
4. 4. Make RootView's placeholder honour the cached scheme rather than
   .systemBackground.
5. 5. Add caelyn.theme.cached to SecureWipeService's cleared key list.
6. 6. Note this pairs naturally with the week-start calendar injection in the same
   ThemedContentView.

*Files:* `Caelyn/App/CaelynApp.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Services/SecureWipeService.swift`

*Tests:* SecureWipeService tests enumerating cleared keys gain the new key.

#### TH-2 — 44 Theme  *(unconfirmed)*

In Dark mode several tappable controls — the selected day on the Log tab's date strip,
'Enable irregular mode', the storage warning banner — print white text on a light-plum
or light-rose fill, which is hard to read.

**Root cause.** CaelynColor.onPrimary exists precisely because primaryPlum becomes light 0xBB82C3 in
dark mode and white text drops to ~3:1 (Color+Caelyn.swift:58-65), but the token was
introduced after these call sites and nothing prevents raw `.white`. Confirmed in
context: HomeView.swift:826-829, LogView.swift:150/153/162-167,
RootView.swift:93/97/115 (white on alertRose, light 0xE9808F in dark). Nine further
`.white` foregrounds exist (CycleSettingsView:514, ExportView:147/161/211,
ProUpsellCard:32/98, PaywallView:309, OnboardingSteps:819, GoalCard:46) — suspected,
not read in context.

**Fix.**

1. 1. Replace `.white` with CaelynColor.onPrimary at every plum-filled site
   (HomeView.swift:826-829, LogView.swift:150/153/162-167).
2. 2. Add CaelynColor.onAlert and use it for alertRose fills
   (RootView.swift:93/97/115).
3. 3. Review the nine suspected sites in context and convert the ones on adaptive
   fills; leave any that sit on a fixed dark fill.
4. 4. Add a lint-style unit test that greps for `foregroundStyle(.white)` outside
   Caelyn/Theme/ and fails on new offenders, so the token cannot be bypassed again.

*Files:* `Caelyn/Theme/Color+Caelyn.swift`, `Caelyn/Views/Home/HomeView.swift`, `Caelyn/Views/Log/LogView.swift`, `Caelyn/Views/RootView.swift`, `Caelyn/Views/Settings/CycleSettingsView.swift`, `Caelyn/Views/Settings/ExportView.swift`, `Caelyn/Views/Premium/ProUpsellCard.swift`, `Caelyn/Views/Premium/PaywallView.swift`, `Caelyn/Views/Onboarding/OnboardingSteps.swift`

*Tests:* New lint-style unit test scanning for foregroundStyle(.white) outside Theme/.

#### TH-3 — 44 Theme  *(unconfirmed)*

On a dark home screen the Caelyn widget is a bright pastel tile, and a user who forced
Dark inside the app still gets a light widget. The theme stops at the app's edge.

**Root cause.** Widget colour helpers were written as fixed light constants 'matching CaelynColor'
before the adaptive palette existed, and the snapshot schema has no colour-scheme
dimension: widgetDeepText 0x2F1B32, Color.white.opacity(0.65) badge, phaseTintHex
container (CaelynWidgetBundle.swift:17-21, 49-55; WidgetViews.swift:48).
WidgetSnapshot carries no dark variants and no theme (WidgetDataStore.swift:24-52),
and nothing in CaelynWidget reads colorScheme (no hits). Lock-screen accessory
families are fine via system vibrant rendering.

**Fix.**

1. 1. Add optional `phaseTintDarkHex`, `phaseAccentDarkHex` and `themeRaw` to
   WidgetSnapshot (WidgetDataStore.swift:24-52), filled by WidgetDataSync.build.
2. 2. In widget views read @Environment(\.colorScheme) and pick the dark hexes,
   mirroring CaelynColor's dark set (bg 0x16091A, card 0x241329, text 0xEDE0F3, plum
   0xBB82C3).
3. 3. Replace Color.white.opacity(0.65) at WidgetViews.swift:48 with a scheme-aware
   value.
4. 4. When themeRaw is light or dark, apply `.environment(\.colorScheme, …)` to the
   entry view so a forced in-app theme reaches the widget.
5. 5. Keep all three fields optional so older snapshots decode unchanged (same pattern
   as anchorPeriodStart / hidePreview).

*Files:* `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `CaelynWidget/CaelynWidgetBundle.swift`, `CaelynWidget/WidgetViews.swift`

*Tests:* Any WidgetSnapshot Codable round-trip test gains the new fields; add a decode test for
a snapshot written before the fields existed.

#### W-10 — CaelynApp.syncWidgetData() / WidgetDataSyncModifier.sync() during --screenshot-mode and --ui-test-onboarding launches  *(unconfirmed)*

On a phone or simulator used for App Store screenshots or UI tests, the home-screen
widget quietly gets replaced with fake demo data (or goes blank and says "Set up
Caelyn") and stays wrong until the app is opened normally again. Only affects devices
used for testing — a shopper's installed copy can never be launched with these flags —
but it means a tester can look at a widget that is showing invented numbers and
believe it is real.

**Root cause.** The `.syncWidgetData()` view modifier is attached unconditionally in the scene body
(Caelyn/App/CaelynApp.swift:34), so it runs even when the scene is backed by the
seeded in-memory screenshot container or the empty first-launch-preview container
(CaelynApp.swift:66-71). Its `sync()` (Caelyn/Services/WidgetDataSync.swift:131-142)
builds a snapshot from whatever models the environment hands it, writes it to the
shared App Group suite via WidgetDataStore.write, and calls
WidgetCenter.reloadAllTimelines — the shared suite is real device state, not in-
memory, so the demo snapshot outlives the process. Commit d0b31aa introduced
Persistence.isDemoStore (Caelyn/Services/Persistence.swift:58-62) precisely so that
"everything that reports on storage" can tell demo from live, but the widget write
path was never added to that set: WidgetDataSync.swift never references isDemoStore.
Under --screenshot-mode the snapshot is additionally stamped isPro: true because
PurchaseService.overridePro(true) runs at :48-51, so the written snapshot also lies
about entitlement.

**Fix.**

1. In Caelyn/Services/WidgetDataSync.swift, at the top of `private func sync()` (line
   131), add `guard !Persistence.isDemoStore || CommandLine.arguments.contains("--
   screenshot-widget") else { return }` so no demo/in-memory container can ever reach
   the shared suite, while leaving a deliberate opt-in flag for the day someone wants
   to capture a widget screenshot.
2. Put the guard inside `sync()` (not on the `.syncWidgetData()` call site in
   CaelynApp.swift:34) so every future caller inherits it — that is what makes the fix
   permanent rather than a one-site patch. If the SnapshotRefresher refactor from
   finding W-06 lands first, the guard belongs at the single entry point of that
   refresher instead, in the same shape.
3. Apply the same guard to the Watch push on the next line
   (`WatchBridgeService.shared.pushSnapshot(snapshot)`, WidgetDataSync.swift:139-141)
   — a paired Watch would otherwise be handed demo numbers by the same call.
4. Add a short comment above the guard pointing at Persistence.isDemoStore's docstring
   (Caelyn/Services/Persistence.swift:52-62) so the next person adding a storage-
   reporting path sees the list it belongs to.
5. Optionally extend Persistence.isDemoStore's docstring with "…and the widget/watch
   snapshot write" so the invariant is documented where it is defined.

*Files:* `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/App/CaelynApp.swift`, `Caelyn/Services/Persistence.swift`

*Tests:* Add a unit test in CaelynTests/CaelynTests.swift that calls the extracted sync body
(make it an internal static func taking an `isDemoStore: Bool` parameter so it is
testable without a scene) and asserts that with isDemoStore == true nothing is written
to the App Group suite, and with false the snapshot round-trips through
WidgetDataStore.read(). No existing test changes — no current test touches
WidgetDataSync's write path.

#### W-11 — WidgetDataStore.write / read / clear — App Group container availability  *(unconfirmed)*

If a future build is signed with a provisioning profile that is missing the shared-
data group (which has already needed hand-fixing once, commit dafb345), every user's
widget would silently show "Set up Caelyn" forever. The app would look fine, nothing
would be logged, nobody would get an error, and the support reply would be "try re-
adding the widget" — which never helps, because the widget physically cannot read the
app's data.

**Root cause.** `UserDefaults(suiteName:)` returns a non-nil object even when the calling process
lacks the application-groups entitlement; it silently falls back to a private,
unshared suite and only emits a cfprefsd warning to the system log.
WidgetDataStore.write (Caelyn/Services/WidgetDataStore.swift:249-254) and read
(:256-262) rely on that non-nil result as proof of access and never call
FileManager.containerURL(forSecurityApplicationGroupIdentifier:), which is the only
API that actually fails when the entitlement is absent. On the read side, a failed
read is indistinguishable from "no data yet": CaelynWidgetProvider.getTimeline
(CaelynWidget/CaelynWidgetProvider.swift:30-36) treats `WidgetDataStore.read() == nil`
and `anchorPeriodStart == nil` identically and emits the same empty entry. The group
identifier is also duplicated as a literal in four places (WidgetDataStore.swift:14,
Caelyn/Caelyn.entitlements:25-28, CaelynWidget/CaelynWidget.entitlements:5-8,
CaelynWatch/CaelynWatch.entitlements) with nothing asserting they match.

**Fix.**

1. Add `static var isContainerReachable: Bool {
   FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:
   caelynAppGroupID) != nil }` to WidgetDataStore
   (Caelyn/Services/WidgetDataStore.swift, next to the existing write/read at :248).
2. In `write` (:249), when `!isContainerReachable`, emit
   `Logger(subsystem:category:).fault("App Group \(caelynAppGroupID) unreachable —
   widgets and watch cannot be updated")` and (DEBUG only) `assertionFailure`. Do not
   change the early-return behaviour; this is observability, not a behaviour change.
3. In Caelyn/Views/Settings/SettingsView.swift, show a single quiet row — "Widgets
   unavailable in this build" — only when `!WidgetDataStore.isContainerReachable`. It
   is invisible to every correctly-signed install, and it is the one place a tester or
   a support reply can see the real cause.
4. In CaelynWidget/CaelynWidgetProvider.swift:30-36, split the two cases: when
   `!WidgetDataStore.isContainerReachable`, build the empty entry with a distinct
   reason (e.g. add `enum EmptyReason { case noData, noAccess }` to CaelynWidgetEntry
   alongside `hasData`) and have the views render "Widget can't reach Caelyn's data"
   instead of "Set up Caelyn".
5. Add a build-time-ish guard against the literal drifting: a unit test that reads the
   three .entitlements plists from the repo and asserts each contains exactly the
   string in `caelynAppGroupID`. This is the part that makes the fix permanent — the
   logging catches a bad profile at runtime, the test catches a mismatched identifier
   before it ships.

*Files:* `Caelyn/Services/WidgetDataStore.swift`, `CaelynWidget/CaelynWidgetProvider.swift`, `CaelynWidget/WidgetViews.swift`, `Caelyn/Views/Settings/SettingsView.swift`, `Caelyn/Caelyn.entitlements`, `CaelynWidget/CaelynWidget.entitlements`, `CaelynWatch/CaelynWatch.entitlements`

*Tests:* New test file CaelynTests/AppGroupConsistencyTests.swift: (1) parse the three
entitlement plists via PropertyListSerialization and assert
`com.apple.security.application-groups` contains `caelynAppGroupID` in each; (2)
assert `WidgetDataStore.isContainerReachable` is true when the test host runs with the
app's entitlements. No existing test changes.

#### W-12 — CaelynWidget/WidgetViews.swift text rendering + date formatting in WidgetDataStore.upcomingStrings / WidgetSnapshotBuilder; StandBy and test-file comments  *(unconfirmed)*

Someone who has turned text size up for readability gets a widget whose text does not
grow at all — every size is hardcoded. Someone using VoiceOver hears the countdown
read as "Period in 3 d" rather than "Period in 3 days". And outside the US, dates in
the widget appear in American order ("Mar 4") instead of the order that locale uses.
Separately, a code comment and the device-test script claim the large widget shows in
StandBy, which it does not, and a comment points at a test file that does not exist —
both send maintainers down dead ends.

**Root cause.** Four small decisions, one theme — fixed values chosen for layout/reading control
instead of system-adaptive APIs. (a) Every widget label uses absolute
`.font(.system(size:…))` (CaelynWidget/WidgetViews.swift:66, :71, :91, :129, :201,
:259) rather than a text style, so Dynamic Type has no input; `.minimumScaleFactor`
only shrinks, never grows. (b) The small widget wraps its whole stack in
`.accessibilityElement(children: .combine)` (:78) with no `.accessibilityLabel`, so
VoiceOver concatenates the literal abbreviated string "Period in \(n)d" from
countdownLine (:84). (c) The month-day formatter hardcodes `dateFormat = "MMM d"` in
two places — Caelyn/Services/WidgetDataStore.swift:169 (the widget/watch midnight
recompute) and Caelyn/Services/WidgetDataSync.swift:14-17 (the app-side builder) —
instead of `setLocalizedDateFormatFromTemplate("MMMd")`, which fixes US month-before-
day order for every locale. (d) Documentation drift: the comment at
WidgetViews.swift:176 says systemLarge "also renders in Standby" (StandBy presents
systemSmall) and docs/DEVICE_TEST_SCRIPT.md step G4 tests for that; the comments at
WidgetDataStore.swift:9 and :130 cite a `WidgetCycleMathTests` file that does not
exist — `ls CaelynTests/` confirms there is no such file; the parity tests live in
CaelynTests/CaelynTests.swift.

**Fix.**

1. Replace absolute sizes with text styles in CaelynWidget/WidgetViews.swift: the big
   cycle-day numbers at :66 (size 54) and in LargeWidgetView (size 80) become
   `.font(.system(.largeTitle, design: .rounded).weight(.bold))`; the caption-weight
   labels at :71, :91, :201 become `.font(.system(.caption2, design:
   .rounded).weight(.medium))` (or `.caption`/`.footnote` where the current size is
   13-14, e.g. :259). Keep the existing `.minimumScaleFactor` and `.lineLimit(1)` on
   each so large accessibility sizes shrink to fit rather than clip.
2. Add `.accessibilityLabel("Period in \(snapshot.daysUntilPeriod) days")` to the
   `Label` inside countdownLine (WidgetViews.swift:84), leaving the visible
   abbreviated text as-is; do the same for any other "d"-abbreviated string in the
   medium/large views.
3. Replace the two hardcoded formatters with locale templates:
   Caelyn/Services/WidgetDataStore.swift:169 `fmt.dateFormat = "MMM d"` →
   `fmt.setLocalizedDateFormatFromTemplate("MMMd")`, and
   Caelyn/Services/WidgetDataSync.swift:14-17 the same. Both must change together or
   the app-side snapshot and the widget's midnight recompute will disagree on date
   order.
4. Correct the StandBy claims: fix the comment at WidgetViews.swift:176 to say
   systemLarge is Home Screen / Lock Screen only, and amend step G4 in
   docs/DEVICE_TEST_SCRIPT.md to test the small widget in StandBy.
5. Fix the test-file references: either rename the comments at
   Caelyn/Services/WidgetDataStore.swift:9 and :130 to point at
   CaelynTests/CaelynTests.swift, or (preferred, since it makes the comment
   permanently true) move the widget-math parity tests out of CaelynTests.swift into a
   real CaelynTests/WidgetCycleMathTests.swift.

*Files:* `CaelynWidget/WidgetViews.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Services/WidgetDataSync.swift`, `docs/DEVICE_TEST_SCRIPT.md`, `CaelynTests/CaelynTests.swift`

*Tests:* Add a unit test asserting the window/upcoming strings produced by
WidgetCycleMath.upcomingStrings under a non-US locale (e.g. en_GB, de_DE) put the day
before the month — it fails today and passes after step 3. If the widget-math tests
are moved to WidgetCycleMathTests.swift, the existing parity assertions in
CaelynTests/CaelynTests.swift move with them unchanged. Optional: a snapshot test of
the small widget at .accessibilityExtraExtraExtraLarge.

#### watch:W-12 — Watch companion (hidePreview)  *(unconfirmed)*

She chose the most private setting Caelyn offers — nothing about her cycle on the lock
screen, nothing in the app switcher. Her watch ignores it: a wrist-raise still shows
"Day 14 · Ovulation window" to anyone standing beside her.

**Root cause.** hidePreview is carried in the snapshot (WidgetDataStore.swift:49-51) and honoured by
the iOS accessory widgets (WidgetViews.swift:300, :320, :332), but it is never read
anywhere in the watch target: WatchHomeView renders the dashboard purely on snapshot
presence (WatchHomeView.swift:22-26, :39-47). It is the same unread-flag mechanism as
widgets:W-03, on a third surface.

**Fix.**

1. 1. When snap.hidePreview == true, render a masked ring — the Caelyn mark plus the
   drop icon, no cycle day, no phase name, no fertile status — reusing the visual
   language settled for the home-screen families in widgets:W-03.
2. 2. Offer tap-to-reveal that lasts only until the app is backgrounded, so a
   deliberate glance still works without persisting the reveal.
3. 3. Leave Quick Log unaffected: logging does not disclose anything to an onlooker.
4. 4. Fold this into the same three-state branch introduced for watch:W-06 so
   WatchHomeView.body has exactly one place that decides what to render.

*Files:* `CaelynWatch/WatchHomeView.swift`, `Caelyn/Services/WidgetDataStore.swift`, `Caelyn/Views/Settings/SettingsView.swift`

*Tests:* None exist. Extend the extracted WatchDisplayState function from watch:W-06 with a
fourth case: snapshot present, isPro true, hidePreview true -> .masked.

#### watch:W-13 — Watch companion (WidgetSnapshot Codable contract)  *(unconfirmed)*

Nothing is wrong today, but there is a trap waiting. The watch app can be hours or
days behind the phone app, because automatic watch app installation can lag or be
switched off. If a future release renames or removes a field in the data the phone
sends, every lagging watch silently decodes nothing and tells the user to open her
iPhone — a message that would be false and unfixable from her side.

**Root cause.** The watch decodes with `try?` and falls to the empty state on failure, with no log and
no distinguishing state (WatchDataModel.swift:60-72). WidgetSnapshot's first fourteen
fields are non-optional (WidgetDataStore.swift:24-38, verified), and the type's header
comment documents additive optionals for OLDER snapshots reaching a NEWER reader but
says nothing about the reverse direction — a newer phone talking to an older watch,
which is the direction that actually breaks.

**Fix.**

1. 1. Write the contract into the WidgetDataStore header comment, beside the existing
   recompute-anchors note at :39-41: fields are append-only and optional from now on;
   existing fields are never renamed and never removed; readers tolerate unknown keys.
2. 2. Add a fixture test: check in a 1.3 snapshot JSON blob and decode it with the
   current type (catches removals and renames).
3. 3. Add the reverse test: encode the current type and decode it with a frozen copy
   of the 1.3 struct kept in the test target (catches a new non-optional field).
4. 4. Give the watch a distinguishable failure state instead of the generic empty
   state when a context arrives but does not decode — even just a different line of
   copy — so the next occurrence is diagnosable from a screenshot.
5. 5. Note the interaction with watch:W-03: once an undecodable context means 'clear',
   step 4's state must be distinct from the cleared state, or a decode failure would
   look like a wipe.

*Files:* `Caelyn/Services/WidgetDataStore.swift`, `CaelynWatch/WatchDataModel.swift`

*Tests:* New fixture tests as described in steps 2 and 3. These are cheap and are the only
mechanism that can catch the failure before it ships, since both directions are
invisible at compile time.

#### watch:W-14 — Watch companion (WatchQuickLogView.saveButton / sendQuickLog)  *(unconfirmed)*

She logs from her wrist and sees "Logged! Syncing to iPhone..." — and she sees exactly
that whether her phone is in her pocket, in another building, or whether the save
failed outright. She cannot tell "saved on my iPhone" from "queued until my iPhone is
nearby".

**Root cause.** Fire-and-forget with no state machine for the transfer outcome. pendingLogSent is set
and never read (WatchDataModel.swift:7, :39-52); the confirmation is shown
unconditionally (WatchQuickLogView.swift:129-149, :153-167); and the phone's reply
handler fires BEFORE the Task that actually saves — `handleIncoming(message);
replyHandler(["status": "ok"])` (WatchBridgeService.swift:44-47, read and confirmed),
with the save happening inside a detached `Task { @MainActor ... }` at :55-66 — so
even the acknowledgement carries no information about whether anything was written.

**Fix.**

1. 1. On the phone, move the reply inside the save Task and send it AFTER
   context.saveOrLog(): `["status": "saved", "dayKey": entry.dayKey]`
   (WatchBridgeService.swift:44-47 and :55-66). An ack sent before the work is not an
   ack.
2. 2. On the watch, replace pendingLogSent with a small enum — .idle / .sending /
   .savedOnPhone / .queued / .failed — and drive the confirmation from it.
3. 3. Show "Saved on iPhone" on a reply, "Will sync when your iPhone is nearby" when
   falling back to transferUserInfo, and a real failure state when neither path is
   available.
4. 4. Keep transferUserInfo as the fallback — it is a reliable queue, and the honest
   copy is about latency, not loss.

*Files:* `CaelynWatch/WatchDataModel.swift`, `CaelynWatch/WatchQuickLogView.swift`, `Caelyn/Services/WatchBridgeService.swift`

*Tests:* None exist. Once the extraction in watch:W-17 lands, assert that the reply payload is
produced only after the save and carries the saved entry's dayKey.

#### watch:W-15 — Store listing vs shipped capability  *(unconfirmed)*

The App Store listing copy promises "watchOS widgets (Pro)". There is no watch widget
or complication in the app — only the watch app itself. If that line is live on the
store, it is a promise the app cannot keep.

**Root cause.** Listing copy was written ahead of a feature that was never built. The only widget
bundle is iOS — systemSmall/Medium/Large plus accessoryCircular/Rectangular
(CaelynWidgetBundle.swift:25-31) — and CaelynWatch is the only watchOS target in the
project (project.pbxproj:1023-1040). The claim appears at
docs/APP_STORE_LISTING.md:156 and :205.

**Fix.**

1. 1. Check the LIVE App Store Connect listing first — the risk depends entirely on
   whether this text shipped or only lives in docs.
2. 2. If live: remove the line at the next metadata update. It is a review and
   consumer-trust risk, not merely a doc inaccuracy.
3. 3. If not live: fix docs/APP_STORE_LISTING.md:156 and :205 so the docs stop
   drifting from the product.
4. 4. If the complication is wanted, note the dependency: watch:W-01's snapshot
   persistence is the enabler — a complication must render from a stored snapshot
   without a live push.

*Files:* `docs/APP_STORE_LISTING.md`, `CaelynWidget/CaelynWidgetBundle.swift`

*Tests:* None.

#### watch:W-16, widgets:W-08, widgets:W-09 — Widgets + Watch companion (display derivation: copy and colour)  *(unconfirmed)*

Nothing visibly broken for most people, but the same sentences and the same colours
are worked out in four different places, and they have already stopped agreeing. The
watch uses its own hand-written colours instead of Caelyn's plum palette, so it does
not match the phone and will not follow a future palette change. During her period the
small widget and the lock-screen widget say "MENSTRUAL · 2 · Period in 26d" — the
countdown Home deliberately hides while she is bleeding. And the app builds a set of
display strings that both the widget and the watch throw away, one of which is already
wrong (it writes "Fertile window: <dates in the past>" during the luteal phase).

**Root cause.** Display derivation has no single owner, so each surface grew its own. (1)
WidgetSnapshotBuilder computes lines and window text (WidgetDataSync.swift:38-63) and
duplicates the hex tables that also live in WidgetCycleMath.accentHex/tintHex (:92-113
vs WidgetDataStore.swift:225-245) — all of it dead, because both consumers always call
recomputed(for:) which overwrites phase*, fertilityStatusRaw, periodWindowText and all
three lines (WidgetDataStore.swift:105-123). Being dead is why its missing `fertileEnd
>= startOfToday` guard (present in the recompute at :183) went unnoticed. (2)
WatchHomeView maps phaseRaw to its own RGB constants
(CaelynWatch/WatchHomeView.swift:104-113) while the snapshot already carries
phaseAccentHex. (3) SmallWidgetView.countdownLine
(CaelynWidget/WidgetViews.swift:81-95) and AccessoryRectangularView.periodLine
(:366-379) branch on raw daysUntilPeriod without the phase gating that Home
(HomeCopy.swift:54-63, :102-103) and the multi-line widget strings
(WidgetDataStore.swift:197) both apply.

**Fix.**

1. 1. Reduce WidgetSnapshotBuilder to anchors and static fields only — cycleLength,
   periodLength, anchorPeriodStart/anchorDayKey, lutealLength, pmsDaysBefore, isPro,
   hidePreview, updatedAt — and have build() return `.recomputed(for: now)`. One
   producer of display fields, not two.
2. 2. Delete the CyclePhase.widgetAccentHex/widgetTintHex extension and the builder's
   lines/window-text code (WidgetDataSync.swift:38-63, :92-113). Deleting is the fix;
   keeping two tables in sync by hand is the bug.
3. 3. Add `WidgetCycleMath.countdownLine(phaseRaw:cycleDay:periodLength:daysUntilPerio
   d:daysLate:)` returning the one-line copy — "Day 2 of your period" when menstrual,
   "Period in N days", "Period may start today", and the late copy from the SNAP-LATE
   item — and call it from SmallWidgetView (WidgetViews.swift:81-95) and
   AccessoryRectangularView (:366-379). Drop the dead `< 0` branch at :88, which is
   unreachable because recompute clamps daysUntilPeriod >= 0 and the provider guards
   on the anchor.
4. 4. In WatchHomeView, use `Color(hex: snap.phaseAccentHex)` (copy the short hex
   initialiser) and delete the local colour switch at :104-113.
5. 5. Keep a parity test that WidgetCycleMath.displayName/icon(raw) equals
   CyclePhase(rawValue: raw).displayName/icon for every case, so the one remaining
   table cannot drift from the enum.
6. 6. Sequence AFTER the luteal and lateness items — this cleanup bakes the shared
   helper's signature, and doing it first would freeze the wrong model into it.

*Files:* `Caelyn/Services/WidgetDataSync.swift`, `Caelyn/Services/WidgetDataStore.swift`, `CaelynWidget/WidgetViews.swift`, `CaelynWatch/WatchHomeView.swift`, `Caelyn/Views/Home/HomeCopy.swift`

*Tests:* CaelynTests.swift:1301-1306 compares builder.cycleDay/daysUntilPeriod to CycleModel
and stays valid, since recomputed(for: today) yields the same numbers. Add the probe
below as a regression test for the builder/recompute drift, plus a unit test for the
new countdownLine helper covering menstrual, upcoming, today and late.

#### watch:W-17 — Watch companion (test coverage of the bridge)  *(unconfirmed)*

Invisible to users, but it is why every watch fix in this audit would ship unverified:
there is not one automated test anywhere covering the watch connection — not the
mapping of a wrist log into a saved day, not the Pro gate, not the replay, not whether
the data format survives a round trip.

**Root cause.** handleIncoming is `private nonisolated` and reaches straight for the WCSession
singleton and Persistence.live.mainContext (WatchBridgeService.swift:49-71, read and
confirmed), so there is no seam to inject. A grep across CaelynTests and CaelynUITests
for WatchBridge, handleIncoming or WatchDataModel returns no matches, and
project.yml:135-168 defines no watch test target.

**Fix.**

1. 1. Extract `static func apply(payload: [String: Any], in context: ModelContext) ->
   CycleEntry?` (internal, not private) from handleIncoming
   (WatchBridgeService.swift:49-71), leaving the delegate method as a thin wrapper
   that supplies the live context. Test apply directly: date -> dayKey mapping, flow
   and mood raw-value decoding, pain, and idempotence when the same payload arrives
   twice.
2. 2. Put WCSession behind a `WatchSessionProviding` protocol so the activation-replay
   logic (watch:W-04) and the tier-on-the-wire behaviour (watch:W-06) become testable.
3. 3. Add a WidgetSnapshot encode/decode round-trip test — it costs nothing and
   underpins the forward-compatibility fixtures in watch:W-13.
4. 4. Land this alongside watch:W-04 rather than after it, so that item's unit test
   has a seam to use.

*Files:* `Caelyn/Services/WatchBridgeService.swift`, `CaelynTests/`, `project.yml`

*Tests:* All new. Start with the probe below (payload mapping and dayKey correctness across a
late-delivery boundary), then the replay and tier tests once the protocol seam exists.

---

