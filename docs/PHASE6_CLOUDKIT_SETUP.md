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

## 4. Not yet built: Partner Share

Partner sharing (CKShare-based) is **not** shipped. It builds on this sync
foundation but is a large, device-only feature; the old fake/disabled Share UI was
removed in Phase 0. It remains a genuine follow-on — do not advertise it until built
and verified on-device.
