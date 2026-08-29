import SwiftUI

/// Backup — the honest state of where Caelyn's data lives.
///
/// **Why there is no sync toggle here.** Caelyn 1.0 ships with NO iCloud/CloudKit
/// entitlement (see `Caelyn/Caelyn.entitlements` — no
/// `com.apple.developer.icloud-container-identifiers` / `icloud-services`), so the
/// opt-in mirroring path in `Persistence.live` can never open its container and
/// always falls back to the local store. A toggle that silently does nothing while
/// the UI reports "syncing" would tell users their data is backed up when it is
/// not — the one lie a privacy-first app can never ship. So the switch is gone and
/// this screen states exactly what is true: local-only, and Export is the backup.
///
/// To turn sync back on later: add the iCloud → CloudKit capability for
/// `Persistence.cloudKitContainerID`, add Background Modes → Remote notifications,
/// push the CloudKit schema to Production, then restore a toggle bound to
/// `Persistence.syncEnabledKey` **driven by a real "did the sync store open"
/// flag** — never by the preference alone. See docs/PHASE6_CLOUDKIT_SETUP.md.
struct BackupInfoView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                headline
                statusCard
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
        .navigationTitle("Backup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Persistence.isSyncActive ? "Your data lives here,\nand in your iCloud." : "Your data lives here.\nNowhere else.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.deepPlumText)
            Text(Persistence.isSyncActive
                 ? "Caelyn keeps every entry on this device, and mirrors it to your own private iCloud so it follows you to a new iPhone. There's still no Caelyn server and no copy we can read. Export is still yours to keep."
                 : "Caelyn keeps every entry on this device. There's no Caelyn server and no cloud copy — which also means there is no automatic backup. You can turn on private iCloud sync in Account & iCloud, or use Export to keep a copy.")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(CaelynColor.lavender)
                        .frame(width: CaelynIconSize.xl, height: CaelynIconSize.xl)
                    Image(systemName: "iphone")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(Persistence.isSyncActive ? "This device + your private iCloud" : "Stored on this device")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(Persistence.isSyncActive
                         ? "Synced to your own iCloud account. Never to a Caelyn server."
                         : "Nothing is uploaded anywhere — not to us, not to iCloud.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Promise cards

    private let promises: [(icon: String, title: String, body: String)] = [
        (
            icon: "square.and.arrow.up",
            title: "Export is your backup",
            body: "Settings → Export data saves a CSV or PDF of everything you've logged. Keep it wherever you like — Files, email, a drive of your own. A Caelyn CSV imports back in full, so an export is a genuine restore point."
        ),
        (
            icon: "exclamationmark.triangle",
            title: "Deleting the app deletes your data",
            body: "With sync off there is no cloud copy, so removing Caelyn (or erasing this iPhone) removes your history with it. Export before you delete the app, switch phones, or reset your device — or turn on iCloud sync so a new iPhone picks it up for you."
        ),
        (
            icon: "person.slash",
            title: "No account, no server",
            body: "There's no sign-up and no Caelyn backend — that's the reason there's nothing of yours to breach, sell, or subpoena. The trade-off is that backing up is your call, not something we do quietly in the background."
        ),
        (
            icon: "icloud",
            title: "iCloud sync is yours to switch on",
            body: "Caelyn can mirror your history to your own private iCloud so it reaches a new iPhone without an export. It is off until you turn it on in Account & iCloud, it goes to your iCloud rather than to us, and turning it off leaves everything here on this device."
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
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    faqRow(
                        q: "How do I move to a new iPhone?",
                        a: "Export a CSV on the old phone, install Caelyn on the new one, then use Settings → Import data. Your history comes across without re-logging anything."
                    )
                    divider
                    faqRow(
                        q: "Does an iPhone backup include Caelyn?",
                        a: "An encrypted iPhone backup (iCloud Backup or a computer backup) does restore apps and their data when you restore the whole device. That's Apple's backup, not ours — we can't see it, and we can't promise how you've set it up. A Caelyn export is the copy you fully control."
                    )
                    divider
                    faqRow(
                        q: "Can Caelyn read my data?",
                        a: "No. It never leaves this device, so there's nothing for us to read. We run no servers."
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
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                Text("Note")
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    .tracking(0.4)
            }
            Text("A good habit: export once a month, and always before changing phones. It takes a few seconds and it's the only copy of your history that exists outside this device.")
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
