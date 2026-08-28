# Caelyn 1.3 — Account, Sign in with Apple, and private iCloud sync

This document is the persistence audit that the 1.3 work is built on. It is written
from the code as it stood at `050a6c4` (released 1.2), not from assumption.

## 1. What the persistence architecture actually is

**SwiftData, one container, two models.** `Persistence.schema` is exactly
`[CycleEntry.self, UserProfile.self]`. There is no Core Data stack, no server, and
no second store. The container is built once, lazily, in `Persistence.live`.

`Persistence.live` already has a three-tier failure ladder that predates this work
and must not be weakened:

1. open the on-disk store (lightweight migration happens here),
2. on failure, **preserve the unreadable store aside** as `default.store.corrupt-<ts>`
   and open a fresh one — never silently discard,
3. last resort, in-memory, with `storeMode` recorded honestly for the UI.

### Everything that stores user state

| Store | Mechanism | Contains |
|---|---|---|
| SwiftData `CycleEntry` | on-disk store | every logged day — flow, pain, symptoms, mood, energy, notes, medication, ovulation/pregnancy tests, cervical mucus, BBT, sexual activity, note reminders |
| SwiftData `UserProfile` | on-disk store | cycle/period averages, goals, lock + privacy flags, HealthKit toggles, reminder times, condition modes, custom symptoms, `isPro` |
| `ImportLedger` | JSON file, Application Support | import provenance — claims keyed `dayKey\|fieldKey`, and undoable batches |
| `HealthSyncAnchorStore` | `UserDefaults.standard` | one `HKQueryAnchor` per HealthKit type |
| `WidgetDataStore` | App Group `UserDefaults` | a single derived `WidgetSnapshot` for widget + watch |
| `PINService` | Keychain | PIN and duress PIN |
| assorted flags | `UserDefaults.standard` | 27 `caelyn.*` keys — intro seen, celebration flags, rating cadence, PIN lockout, `caelyn.syncEnabled`, `caelyn.storeFailed` |

## 2. Is the current schema CloudKit-compatible?

**Yes — and this was designed in, not lucky.** Verified against the code:

- **No `@Attribute` of any kind** anywhere in `Caelyn/Models/`. In particular no
  `.unique`, which CloudKit forbids.
- **No `@Relationship` anywhere in the app.** The two models are independent, so
  the "relationships must be optional and have inverses" rule cannot be violated.
- **Every non-optional property has a default value** — required, because CloudKit
  mirroring makes all attributes optional on the server.
- Every stored enum (`FlowLevel`, `Symptom`, `Mood`, `PainType`, `CervicalMucus`,
  `TrackingGoal`, `EnergyLevel`, `BirthControlMethod`, `OvulationTestResult`,
  `AppTheme`) is `String, Codable`, and the one dictionary
  (`symptomSeverity: [String: Int]`) is Codable.

### No production store has ever had a unique constraint

`@Attribute(.unique)` was removed from `CycleEntry.date` in `0f6cfab` on
**2026-07-15**. Builds 3 and 4, which predate it, were uploaded in April, expired,
and were never released. App Store Connect shows the released **1.0 shipped as
build 11** (2026-08-20), 1.1 as build 12, 1.2 as build 13 — all after the removal.

So every store in the wild already has the CloudKit-compatible shape. **Enabling
mirroring requires no schema change and no destructive migration.** That is the
single most important finding in this audit, and it is why an existing user does
not have to start over.

The uniqueness the constraint used to provide is enforced in code instead:
`CycleStore.entry(for:)` is a fetch-or-create funnel, and `CycleStore.dedupeSameDay`
merges any same-day rows that slip through.

## 3. Data classification

### A — user-synced private cloud data
`CycleEntry` in full, and the *preference* half of `UserProfile`: cycle/period
averages, goals, first day of week, theme, condition modes, custom symptoms,
reminder times and toggles, and the new preferred name. This is what makes a new
device feel like hers.

### B — local / device-specific, must NOT sync
- **HealthKit anchors** (`caelyn.hkAnchor.*`). An anchor is a position in *this
  device's* HealthKit history. Syncing one would make Device B skip records it has
  never read. They are already in `UserDefaults.standard`, which does not sync.
- **PIN and duress PIN** (Keychain, no `kSecAttrSynchronizable`) — a device lock.
- `healthKitConnected` and the `hkRead*`/`hkWrite*` toggles: HealthKit permission
  is per-device, so a synced "connected" flag would lie on Device B.
- `lockEnabled`, `hidePreview`, PIN lockout counters, `caelyn.storeFailed`.
- `caelyn.syncEnabled` itself.

### C — derived / rebuildable
`WidgetSnapshot` in the App Group, all `caelyn.seenIntro.*` and celebration flags,
predictions. Never a cloud authority; always recomputable from A.

### D — credentials / security storage
The Sign in with Apple stable user identifier, in the Keychain. Not in SwiftData,
because it is a credential rather than history, and it must survive independently
of whether cycle data is ever deleted.

## 4. Risks this audit found, which the implementation must handle

1. **`dedupeSameDay` runs only at launch** (`RootView.swift:34`). CloudKit delivers
   records *during* a session, so a duplicate day created on another device would
   sit visible until the next cold start. Needs a remote-change trigger.
2. **`ImportLedger` is a plain file and does not sync.** Without provenance on
   Device B, an imported value has no claim, so `ImportReconciler` treats it as
   hand-entered. That fails *safe* — her data is protected — but import undo and
   re-import correctness would differ per device. Addressed deliberately in the
   import section.
3. **`isPro` is in `UserProfile`.** Entitlement comes from StoreKit, not from a
   synced boolean; a synced `isPro` must never be the authority.
4. **The widget/watch snapshot must not become a second source of truth** once two
   devices write.

## 5. CloudKit schema status

| | |
|---|---|
| Container | `iCloud.smallpanta-icould.com.caelynperiodtracker` |
| Database | **Private only.** No record of any kind is written to a public database. |
| Environment used so far | **Development only.** |
| Promoted to Production | **No.** |
| Record types | Mirrors of `CycleEntry` and `UserProfile`, generated by SwiftData. |
| Relationships | None. |

**Production schema has deliberately not been promoted.** A CloudKit production
schema is close to permanent — fields cannot be removed or retyped once promoted —
and promotion cannot be done or verified from a build machine. It should happen
only after the two-device hardware test below passes, so the schema that gets
frozen is one that has been seen to work.

### What deliberately does not sync
HealthKit anchors, the PIN and duress PIN, HealthKit connection/permission flags,
app-lock and preview-hiding flags, PIN lockout counters, `caelyn.storeFailed`,
`caelyn.syncEnabled` itself, the widget/watch snapshot, and every "seen this
intro" flag. None of these are history; all of them are properties of one device.

## 6. Privacy and App Store metadata changes required

These need doing in App Store Connect and on the website — they are not code, and
none of them has been done:

1. **App Privacy → Data Types.** Adding Sign in with Apple means declaring
   `Identifiers → User ID` (linked to the user, used for App Functionality only —
   **not** tracking, and not advertising). If the `.email` scope stays requested,
   `Contact Info → Email Address` must be declared even though Caelyn never reads
   or stores the value; the honest alternative is to drop the scope.
2. **Health data.** Cycle data now leaves the device *to the user's own iCloud*.
   Apple does not treat the user's private CloudKit database as a third-party
   disclosure, so "Data Not Collected" for health can stand — but the privacy
   policy must stop saying data never leaves the phone.
3. **Privacy policy** (`docs/privacy.html`) needs new sections for: Sign in with
   Apple and what identifier is kept, private iCloud sync and that it is the
   user's own iCloud rather than a Caelyn server, the preferred name, and account
   deletion versus data deletion being separate actions.
4. **Account deletion.** Apple requires an in-app route once an app offers account
   creation. It exists at Settings → Account & iCloud → Delete Caelyn account, and
   is deliberately distinct from Delete all data.
5. **In-app copy already updated:** `BackupInfoView` no longer promises "not in
   iCloud either"; it now reads the real store state.
