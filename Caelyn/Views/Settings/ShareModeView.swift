import SwiftUI
import CloudKit

struct ShareModeView: View {
    @State private var isSharing = false
    @State private var shareURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    @State private var activeShare: CKShare? = nil
    @State private var showingRevokeConfirm = false

    var body: some View {
        List {
            introSection
            if let share = activeShare {
                activeShareSection(share: share)
            } else {
                createShareSection
            }
            privacySection
        }
        .navigationTitle("Partner Access")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .task { await loadExistingShare() }
        .sheet(isPresented: $isSharing) {
            // CloudKit sharing sheet
            if let share = activeShare {
                CloudSharingView(share: share)
            }
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share with a partner")
                        .font(CaelynFont.body.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Give a trusted person view-only access to your cycle data through iCloud.")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                }
            } icon: {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(CaelynColor.primaryPlum)
            }
        }
    }

    private var createShareSection: some View {
        Section {
            Button {
                Task { await createShare() }
            } label: {
                if isLoading {
                    HStack {
                        ProgressView().tint(CaelynColor.primaryPlum)
                        Text("Setting up…")
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    }
                } else {
                    Label("Invite a Partner", systemImage: "link.badge.plus")
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .fontWeight(.medium)
                }
            }
            .disabled(isLoading)
        } footer: {
            Text("Your data stays encrypted in your private iCloud. Your partner gets read-only access via their Apple ID.")
        }
    }

    private func activeShareSection(share: CKShare) -> some View {
        Section("Active share") {
            Button {
                isSharing = true
            } label: {
                Label("Manage Partner Access", systemImage: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(CaelynColor.primaryPlum)
            }
            Button(role: .destructive) {
                showingRevokeConfirm = true
            } label: {
                Label("Revoke Access", systemImage: "person.crop.circle.badge.minus")
            }
            .confirmationDialog(
                "Revoke partner access?",
                isPresented: $showingRevokeConfirm,
                titleVisibility: .visible
            ) {
                Button("Revoke Access", role: .destructive) { Task { await revokeShare() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your partner will lose access to your cycle data immediately. You can share again anytime.")
            }
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Label("Your partner can view your cycle phase, upcoming events, and logged symptoms.", systemImage: "eye")
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
            Label("They cannot edit or delete any of your data.", systemImage: "lock.fill")
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
            Label("All data is end-to-end encrypted via Apple's CloudKit private database.", systemImage: "shield.checkered")
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
    }

    // MARK: - CloudKit operations

    private func loadExistingShare() async {
        let container = CKContainer(identifier: "iCloud.smallpanta-icould.com.caelynperiodtracker")
        let db = container.privateCloudDatabase
        do {
            let zones = try await db.allRecordZones()
            for zone in zones {
                if let share = try? await db.record(for: CKRecord.ID(zoneID: zone.zoneID)) as? CKShare {
                    await MainActor.run { activeShare = share }
                    return
                }
            }
        } catch {
            // No existing share — that's normal
        }
    }

    private func createShare() async {
        await MainActor.run { isLoading = true }
        let container = CKContainer(identifier: "iCloud.smallpanta-icould.com.caelynperiodtracker")
        let db = container.privateCloudDatabase
        do {
            // Create a shared zone
            let zone = CKRecordZone(zoneName: "CaelynShared")
            try await db.save(zone)
            // Create a CKShare for the zone
            let share = CKShare(recordZoneID: zone.zoneID)
            share.publicPermission = .readOnly
            share[CKShare.SystemFieldKey.title] = "Caelyn Cycle Data" as CKRecordValue
            try await db.save(share)
            await MainActor.run {
                activeShare = share
                isLoading = false
                isSharing = true
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Could not create share: \(error.localizedDescription)"
            }
        }
    }

    private func revokeShare() async {
        guard let share = activeShare else { return }
        let container = CKContainer(identifier: "iCloud.smallpanta-icould.com.caelynperiodtracker")
        let db = container.privateCloudDatabase
        do {
            try await db.deleteRecord(withID: share.recordID)
            await MainActor.run { activeShare = nil }
        } catch {
            await MainActor.run { errorMessage = "Could not revoke: \(error.localizedDescription)" }
        }
    }
}

// MARK: - UICloudSharingController wrapper

struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: CKContainer(identifier: "iCloud.smallpanta-icould.com.caelynperiodtracker"))
        controller.availablePermissions = [.allowReadOnly]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
