# Phase 6 — Enabling iCloud Sync (device / account steps)

Opt-in iCloud Sync is **implemented in code** and **off by default**. The code
compiles, all tests pass, and the default (sync-off) app is fully local-only. The
steps below are the parts that require *your* Apple Developer account and a real
device — they cannot be done or verified from the build machine.

## 1. Add the CloudKit capability (Xcode, one time)

Xcode → target **Caelyn** → **Signing & Capabilities** → **+ Capability** → **iCloud**:
- Check **CloudKit**.
- Add/confirm the container: **`iCloud.smallpanta-icould.com.caelynperiodtracker`**
  (this exact ID is what `Persistence.cloudKitContainerID` expects).
- Xcode will provision the container in your account and add the entitlement keys.
- Also add the **Background Modes** → **Remote notifications** capability (CloudKit
  uses silent pushes to sync).

> The entitlement is intentionally NOT committed to the repo, because an
> unprovisioned CloudKit container breaks `xcodebuild` on the CI/simulator. Adding
> it in Xcode with your team is the correct, provisioned path.

## 2. Test the destructive migration BEFORE shipping

Phase 6 removed `@Attribute(.unique)` from `CycleEntry.date` (CloudKit forbids
unique constraints). For a **fresh install** this is a non-event. For an **existing
user upgrading**, SwiftData attempts a lightweight migration.

- Install a **pre-Phase-6** build, add several entries, then upgrade to this build.
- Confirm entries survive and no duplicate-by-day rows appear.
- If the migration fails, `Persistence.preserveStoreAside` renames the old store to
  `default.store.corrupt-<ts>` (no permanent loss) and the storage-problem banner
  shows — but the goal is for the lightweight migration to just work.

## 3. Verify sync on two devices

- Turn on **Settings → iCloud Sync**, reopen the app (the container is built once at
  launch, so the toggle takes effect on relaunch).
- Confirm entries appear on a second device signed into the same Apple Account.
- Confirm that with sync **off**, nothing leaves the device.

## 4. Deploy the schema to Production — REQUIRED before every release that adds a field

**This blocks build 16.** CloudKit keeps two completely separate schemas,
Development and Production. `NSPersistentCloudKitContainer` creates record types
and fields automatically in **Development only** — a development build talking to
the Development schema will look perfect. Production never changes on its own.

A field missing from Production fails every export of its record type, and it
fails *silently from the user's side*: her iCloud account is fine, the mirrored
store opens fine, and reads and writes work normally because the store is local
either way. Nothing visible is wrong. Her history simply stops leaving the phone.

`CycleEntry.dayKey` is exactly such a field. It is new in build 16, has never
shipped, and is not in Production.

**Steps** (icloud.developer.apple.com/dashboard):

1. Pick container **`iCloud.smallpanta-icould.com.caelynperiodtracker`**.
2. **Schema → Record Types → CD_CycleEntry** in the **Development** environment.
   Confirm `CD_dayKey` is listed. If it is not, run a development build on a
   device with sync on and log one entry — that is what creates it.
3. **Schema → Deploy Schema Changes…** → review the diff → **Deploy**.
4. Switch the environment selector to **Production** and confirm `CD_dayKey` is
   now on `CD_CycleEntry`.

Deployment is **additive and irreversible**: a field cannot be removed from
Production, so deploy only what the release actually ships. Do this *before* the
build goes to TestFlight or the App Store, not after — a user who opens the app
first exports nothing and gets no retry notification.

### Verify it actually worked

The app now tells the truth about this rather than assuming. `CloudSyncHealth`
listens for `NSPersistentCloudKitContainer.eventChangedNotification` and only
lets the sync card say "backed up" once an **export** has finished successfully.
So:

- Settings → Account & iCloud, with sync on, should read **"Your history is
  backed up to your private iCloud. Last updated …"**.
- If it reads **"Caelyn hasn't managed to finish backing up yet"**, the export is
  failing — the Production schema is the first thing to check. The real reason is
  in Console.app, filtered to subsystem
  `smallpanta-icould.com.caelynperiodtracker`, category `cloudsync`.

### Checking from the command line (optional)

`xcrun cktool` can diff the two environments without the web dashboard, but it
needs a **management token** that only the account owner can mint: CloudKit
Console → **Settings → Tokens → Management Tokens → Create Token**. Then:

```sh
xcrun cktool save-token <token> --type management
xcrun cktool export-schema \
  --team-id <TEAM_ID> \
  --container-id iCloud.smallpanta-icould.com.caelynperiodtracker \
  --environment production | grep -A20 CD_CycleEntry
```

## 5. Exporting and validating a build (two traps that cost an hour each)

**Automatic signing picks the wrong profile.** `-exportArchive` with
`signingStyle: automatic` reaches for an auto-generated *iOS Team Store
Provisioning Profile*, which carries neither Push Notifications nor Sign In with
Apple, and fails with three capability errors that look like the App ID is
misconfigured. It is not — the correct profiles already exist. Export manually
and name them:

```xml
<key>signingStyle</key><string>manual</string>
<key>signingCertificate</key><string>Apple Distribution</string>
<key>provisioningProfiles</key>
<dict>
  <key>smallpanta-icould.com.caelynperiodtracker</key><string>Caelyn 1.3 AppStore App</string>
  <key>smallpanta-icould.com.caelynperiodtracker.widget</key><string>Caelyn 1.3 AppStore Widget</string>
  <key>smallpanta-icould.com.caelynperiodtracker.watchapp</key><string>Caelyn 1.3 AppStore Watch</string>
</dict>
```

(The ASC API key does not rescue the automatic path: its role has no access to
cloud-managed distribution certificates, which is a separate error again.)

**An approved version train is closed.** A version that has shipped accepts no
further builds, at any build number. The archive and the export both succeed —
only validation refuses, with `90186` *"the train version 'X' is closed for new
build submissions"* and `90062` *"must contain a higher version than the
previously approved version"*. Bump `MARKETING_VERSION`, not just
`CURRENT_PROJECT_VERSION`.

So **always validate before uploading**:

```sh
xcrun altool --validate-app -f /tmp/caelyn-export/Caelyn.ipa --type ios \
  --apiKey UJ7WBMA5H5 --apiIssuer <issuer-id>
```

Expect `VERIFY SUCCEEDED with no errors`.

## 6. Not yet built: Partner Share

Partner sharing (CKShare-based) is **not** shipped. It builds on this sync
foundation but is a large, device-only feature; the old fake/disabled Share UI was
removed in Phase 0. It remains a genuine follow-on — do not advertise it until built
and verified on-device.
