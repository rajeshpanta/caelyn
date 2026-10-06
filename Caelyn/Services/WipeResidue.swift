#if DEBUG
import Foundation

/// Device forensics for the wipe. DEBUG builds only.
///
/// The unit tests prove `SecureWipeService` removes each kind of residue from a
/// scratch directory. What they cannot prove is that the real wipe, reached the
/// way she reaches it — a duress PIN typed into the lock screen after whoever has
/// her phone has burned through the attempts — clears the real places on a real
/// device: the app's own temp and Application Support directories, the shared
/// App Group, and the Keychain.
///
/// So a UI test launches with `--ui-test-plant-residue`, which puts one of each
/// there, then triggers the wipe and reads `survivors()` from the readout below —
/// inside the same process that wiped, and again seconds later, so anything that
/// re-arms itself after the wipe is caught too.
///
/// Not from a separate hosted test run afterwards: that launches the real app
/// first, and its own startup (reconciling the Apple credential, rewriting the
/// widget snapshot, adopting settings) changes exactly what is being inspected.
enum WipeResidue {

    static let launchArgument = "--ui-test-plant-residue"
    static let clearArgument = "--ui-test-clear-residue"

    private static let exportName = "Caelyn-all-residue-probe.csv"
    private static let corruptName = "default.store.corrupt-residue-probe"
    private static let ledgerName = "CaelynImportLedger.json"
    private static let appleUserID = "residue-probe-apple-user"

    private static var applicationSupport: URL? {
        try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                     appropriateFor: nil, create: true)
    }

    /// Put one of every kind of residue a wipe has to remove where the app keeps it.
    @MainActor
    static func plant() {
        let probe = Data("residue probe".utf8)
        let tmp = FileManager.default.temporaryDirectory
        try? probe.write(to: tmp.appending(path: exportName))
        if let support = applicationSupport {
            try? probe.write(to: support.appending(path: corruptName))
            try? probe.write(to: support.appending(path: corruptName + "-wal"))
            try? Data("{}".utf8).write(to: support.appending(path: ledgerName))
        }
        AccountIdentityStore.save(appleUserID: appleUserID)
        WidgetDataStore.write(WidgetSnapshot.placeholder())
        // Armed with a fresh activity stamp, so it cannot fire during the test.
        AutoSweepSettings.lastActiveAt = .now
        AutoSweepSettings.afterDays = 30
        AutoSweepSettings.isEnabled = true
    }

    /// Remove exactly what `plant` put down, so a control run leaves the device
    /// as it found it — no fake Apple identity, no armed auto-erase.
    @MainActor
    static func clear() {
        let fm = FileManager.default
        try? fm.removeItem(at: fm.temporaryDirectory.appending(path: exportName))
        if let support = applicationSupport {
            try? fm.removeItem(at: support.appending(path: corruptName))
            try? fm.removeItem(at: support.appending(path: corruptName + "-wal"))
            try? fm.removeItem(at: support.appending(path: ledgerName))
        }
        if AccountIdentityStore.appleUserID == appleUserID { AccountIdentityStore.signOut() }
        WidgetDataStore.clear()
        AutoSweepSettings.forget()
    }

    /// Everything that is still there. Empty means the wipe left nothing behind.
    @MainActor
    static func survivors() -> [String] {
        var found: [String] = []
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory
        for name in (try? fm.contentsOfDirectory(atPath: tmp.path)) ?? []
            where name.hasPrefix("Caelyn-") {
            found.append("temp export \(name)")
        }
        if let support = applicationSupport {
            for name in (try? fm.contentsOfDirectory(atPath: support.path)) ?? []
                where name.contains(".corrupt-") || name == ledgerName {
                found.append("Application Support \(name)")
            }
        }
        if PINService.isSet { found.append("Keychain: primary PIN") }
        if PINService.hasDuress { found.append("Keychain: duress PIN") }
        if AccountIdentityStore.appleUserID != nil { found.append("Keychain: Apple user ID") }
        // The app rewrites an empty snapshot the moment it is next on screen, which
        // is correct — so what counts is whether one still carries her cycle.
        if let snapshot = WidgetDataStore.read(),
           snapshot.anchorPeriodStart != nil || snapshot.daysUntilPeriod >= 0
            || !snapshot.periodWindowText.isEmpty {
            found.append("App Group: widget snapshot with her cycle")
        }
        if AutoSweepSettings.isEnabled { found.append("auto-erase still armed") }
        if UserDefaults.standard.bool(forKey: AppLockSettings.key) { found.append("App Lock still on") }
        return found
    }
}

import SwiftUI

/// Shows `WipeResidue.survivors()` live, for UI tests. Only exists when the app
/// was launched with `--ui-test-plant-residue`, and only in DEBUG builds.
struct WipeResidueReadout: View {
    private let active = CommandLine.arguments.contains(WipeResidue.launchArgument)

    var body: some View {
        if active {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let survivors = WipeResidue.survivors()
                Text(survivors.isEmpty ? "none" : survivors.joined(separator: " | "))
                    .font(.system(size: 7))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    // It must never take a tap meant for the app underneath.
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("UIA.WipeResidue.Survivors")
            }
        }
    }
}
#endif
