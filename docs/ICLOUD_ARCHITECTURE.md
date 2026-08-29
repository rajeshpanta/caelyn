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

## 6. The deletion model (1.3)

Four actions, deliberately distinct, each stating its own scope. None of them is
allowed to do a second one's job quietly.

| Action | Apple identity | Local history | iCloud copy |
|---|---|---|---|
| **Sign out** | removed | kept | kept |
| **Delete Caelyn account** | removed | kept | kept |
| **Delete my iCloud copy** | kept | **kept** | **removed**, sync switched off |
| **Delete all data** | — | removed | removed *only if she picks that scope* |

**Deleting the iCloud copy is a direct CloudKit zone deletion,** not "delete the
rows and let sync carry it". Mirrored deletions are asynchronous: if Caelyn cleared
the local rows, turned sync off and the app were killed a second later, the
deletions would never finish uploading and the cloud copy would survive intact.
Removing `com.apple.coredata.cloudkit.zone` is one server-side operation whose
success can actually be checked.

**Ordering.** Sync is switched off *before* the zone is removed, so the live mirror
is not simultaneously pushing the local store back into it. In a both-halves wipe
the cloud goes first: if the app dies mid-wipe, the safe half to have completed is
the one that removes data from a server.

**Resurrection guard.** `caelyn.cloudCopyDeletedAt` records that she chose to
destroy the copy. While it stands and sync is off, every launch re-asserts the
deletion — covering both an interrupted attempt and a mirroring delegate that
recreated the zone before detaching. Signing back in never clears it, because
signing in is an identity action. Deliberately re-enabling sync *does* clear it,
because that is her changing her mind and she is entitled to a fresh copy.

**Honesty.** `caelyn.cloudDeletionPending` survives a kill, so an unfinished
deletion is reported as unfinished rather than shown as done. An unreachable iCloud
returns `.unavailable` and is never recorded as a deletion. No `CKError`,
`CKAccountStatus` or `NSCocoaErrorDomain` string can reach the screen.

## 7. Sign in with Apple — account-deletion compliance

### What Caelyn receives and keeps

`AppleSignInService` reads exactly three things off `ASAuthorizationAppleIDCredential`:
`user`, `fullName?.givenName`, `fullName?.familyName`. It never touches
`identityToken`, `authorizationCode`, `email`, `realUserStatus` or `state`.

| Item | Received | Stored | Where | Lifetime | Deleted on account deletion |
|---|---|---|---|---|---|
| Stable user identifier | yes | yes | Keychain, `com.caelyn.account`, ThisDeviceOnly | until sign-out/delete | **yes** |
| Given / family name | first authorization only | yes, if usable | `UserProfile.appleSuggestedName` | until deleted | **yes** |
| Identity token (JWT) | **never read** | no | — | — | n/a |
| Authorization code | **never read** | no | — | — | n/a |
| Access token | never issued | no | — | — | n/a |
| Refresh token | never issued | no | — | — | n/a |
| Email / private relay | **not requested** | no | — | — | n/a |

`preferredName` is deliberately kept — it is a preference she typed, like the first
day of the week, and is separately clearable.

### Why there is no programmatic token revocation

Apple's account-deletion guidance says apps supporting Sign in with Apple *"should
use the Sign in with Apple REST API to revoke user tokens."* That endpoint
(`/auth/revoke`) requires two things Caelyn structurally does not have:

- **`token`** — *"The user refresh token or access token intended to be revoked."*
  Caelyn never reads the authorization code, so no token is ever issued to it.
- **`client_secret`** — *"A secret JSON Web Token (JWT) that uses the Sign in with
  Apple private key associated with your developer account."* Shipping that key in
  the app would expose it to every user; obtaining one safely needs a server.

Caelyn operates no server, by design. Building one to revoke a token that was never
issued would mean a privacy-first period tracker starts making network calls to a
Caelyn backend — a real privacy regression in exchange for a call with no argument
to pass. **There is no user session with Apple to revoke.**

What Caelyn does instead: deletes every trace of the identity locally, and tells her
where to remove Caelyn from her Apple Account, because that is the only revocation
that exists and only she can perform it.

### Why keeping cycle history is compliant

Apple: *"Deleting an account removes the account from the **developer's records**,
along with any data associated with the account that the developer isn't legally
required to maintain."*

Caelyn has **no developer records**. There is no server and no Caelyn-held copy of
anything. Her history lives on her device and, if she enabled sync, in her own
private CloudKit database that Caelyn cannot read. It is also not *associated with
the account*: it exists identically for someone who never signed in, it is created
before and independently of any account, and it is unaffected by one.

Deleting reproductive-health history because someone unlinked an Apple ID would be
an active harm, not compliance. Permanent deletion remains obvious and in-app
through **Delete my iCloud copy** and **Delete all data**, and the account-deletion
screen names both.

### What was added for compliance

- **Auto-renewable subscription notice.** Apple: *"If the user has auto-renewable
  subscriptions, notify them that their billing will continue through Apple and
  request that they cancel their subscription before continuing."* Caelyn sells
  monthly and yearly Pro subscriptions and said nothing. The delete-account
  confirmation now warns when one is active and offers Apple's own
  `https://apps.apple.com/account/subscriptions` link.
- **Manual authorization guidance**, since Caelyn cannot revoke on her behalf.

## 8. Privacy and App Store metadata changes required

These need doing in App Store Connect and on the website — they are not code, and
none of them has been done:

1. **App Privacy → Data Types.** Adding Sign in with Apple means declaring
   `Identifiers → User ID` (linked to the user, App Functionality only — **not**
   tracking, and not advertising).
   **Email Address is NOT declared.** No shipped version of Caelyn has ever
   requested an email address: 1.2 and earlier had no Sign in with Apple at all,
   and 1.3 requests `[.fullName]` only. (An early draft of the 1.3 branch briefly
   requested `.email` and never read it; it was removed before release.) Hide My
   Email is unaffected — it is Apple's choice at the sheet, not something the scope
   enables.
   `Contact Info → Name` must be declared if the user sets a preferred name
   (App Functionality, linked to the user, not used for tracking).
2. **Health data.** Cycle data now leaves the device *to the user's own iCloud*.
   Apple does not treat the user's private CloudKit database as a third-party
   disclosure, so "Data Not Collected" for health can stand — but the privacy
   policy must stop saying data never leaves the phone.
3. **Privacy policy** (`docs/privacy.html`) needs new sections for: Sign in with
   Apple and what identifier is kept, private iCloud sync and that it is the
   user's own iCloud rather than a Caelyn server, the preferred name, and account
   deletion versus data deletion being separate actions.
4. **Account deletion.** Apple requires an in-app route once an app offers account
   creation. It is at Settings → Account & iCloud → Delete Caelyn account.
   The App Store review note should state plainly that Caelyn separates *account*
   deletion from *health-data* deletion on purpose, and that both are reachable
   in-app: Delete Caelyn account, Delete my iCloud copy, and Delete all data (which
   asks whether she means this iPhone, or this iPhone and iCloud).
5. **In-app copy already updated:** `BackupInfoView` no longer promises "not in
   iCloud either"; it now reads the real store state.

5. **Data deletion description.** The App Privacy questionnaire's account-deletion
   answer should describe all three routes, not just the identity one, and should
   say that deleting the account does not delete health data — that being a
   deliberate safety property rather than an omission.
6. **iCloud/CloudKit disclosure.** The policy must say the copy lives in the user's
   own private CloudKit database, that Caelyn operates no server and cannot read
   it, that sync is opt-in and off by default, and that deleting the copy is a
   one-way operation the user controls.
