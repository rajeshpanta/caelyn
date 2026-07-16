import SwiftUI

/// iCloud Sync — **opt-in and off by default.** By default Caelyn keeps everything
/// on-device with no account and no Caelyn server. If the user turns sync on, the
/// store mirrors to *their own* private CloudKit database (Apple end-to-end
/// encrypted) — never through us. The toggle takes effect on next launch because
/// the SwiftData container is built once at startup (see Persistence).
struct BackupInfoView: View {

    @AppStorage(Persistence.syncEnabledKey) private var syncEnabled = false
    @State private var changed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                headline
                toggleCard
                if changed { restartNote }
                ForEach(promises.indices, id: \.self) { idx in
                    promiseCard(promises[idx])
                }
                faqSection
                disclaimer
            }
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.top, CaelynSpacing.md)
            .padding(.bottom, CaelynSpacing.xl)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Local by default.\nSync only if you want it.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.deepPlumText)
            Text("Caelyn keeps everything on this device with no account and no server of ours. You can optionally sync across your own devices through your private iCloud — turned off unless you switch it on.")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Toggle

    private var toggleCard: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                Toggle(isOn: $syncEnabled) {
                    HStack(spacing: CaelynSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(CaelynColor.lavender)
                                .frame(width: CaelynIconSize.xl, height: CaelynIconSize.xl)
                            Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(CaelynColor.primaryPlum)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync with iCloud")
                                .font(CaelynFont.headline)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text(syncEnabled ? "On — syncs to your private iCloud" : "Off — stored on this device only")
                                .font(CaelynFont.subheadline)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        }
                    }
                }
                .tint(CaelynColor.primaryPlum)
            }
        }
        .onChange(of: syncEnabled) { _, _ in changed = true }
    }

    private var restartNote: some View {
        HStack(alignment: .top, spacing: CaelynSpacing.sm) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .foregroundStyle(CaelynColor.primaryPlum)
            Text("Reopen Caelyn to \(syncEnabled ? "start" : "stop") syncing. Your data stays safe on this device either way.")
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CaelynSpacing.md)
        .background(CaelynColor.lavender.opacity(0.4), in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
    }

    // MARK: - Promise cards

    private let promises: [(icon: String, title: String, body: String)] = [
        (
            icon: "hand.raised.fill",
            title: "Off unless you turn it on",
            body: "Sync is opt-in. Leave it off and Caelyn behaves exactly as before — everything stays on this device, and nothing is uploaded anywhere."
        ),
        (
            icon: "icloud.fill",
            title: "Your own private iCloud",
            body: "When on, Caelyn mirrors your data to YOUR private CloudKit database — Apple end-to-end encrypted, in your Apple account. We never see it, and we still run no server."
        ),
        (
            icon: "person.slash",
            title: "No Caelyn account, ever",
            body: "There's still no sign-up and no Caelyn backend. Sync uses the iCloud you're already signed into on this iPhone — nothing new to create."
        ),
        (
            icon: "square.and.arrow.up",
            title: "Export is still your backup",
            body: "Whether sync is on or off, Settings → Export saves a CSV or PDF you fully control. That file remains a backup you can keep anywhere."
        ),
    ]

    private func promiseCard(_ p: (icon: String, title: String, body: String)) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(CaelynColor.lavender)
                        .frame(width: 44, height: 44)
                    Image(systemName: p.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.title)
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(p.body)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("FAQ")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    faqRow(
                        q: "Where does my data go when sync is on?",
                        a: "Only to your own private iCloud (CloudKit), end-to-end encrypted. It never passes through a Caelyn server — we don't have one."
                    )
                    divider
                    faqRow(
                        q: "Can Caelyn read my synced data?",
                        a: "No. It lives in your private iCloud database tied to your Apple Account. We have no access to it."
                    )
                    divider
                    faqRow(
                        q: "What if I delete the app with sync off?",
                        a: "With sync off, data lives only on this device, so deleting the app deletes it. Export first, or turn on sync, if you want to keep it."
                    )
                }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(CaelynColor.deepPlumText.opacity(0.06))
            .frame(height: 1)
    }

    private func faqRow(q: String, a: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(q)
                .font(CaelynFont.body.weight(.medium))
                .foregroundStyle(CaelynColor.deepPlumText)
            Text(a)
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                Text("Note")
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                    .tracking(0.4)
            }
            Text("Syncing requires being signed into iCloud on this device. If iCloud isn't available, Caelyn keeps working locally and your data stays safe on this device.")
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(CaelynSpacing.md)
        .background(CaelynColor.lavender.opacity(0.3), in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        BackupInfoView()
    }
}
