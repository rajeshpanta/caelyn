import SwiftUI

struct iCloudSyncView: View {

    private var isSignedIntoiCloud: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

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
        .navigationTitle("iCloud Backup")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your data, your iCloud.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.deepPlumText)
            Text("Caelyn backs up to your private iCloud — not our servers. Only your devices can read it.")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Status card

    private var statusCard: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isSignedIntoiCloud
                              ? CaelynColor.successSage.opacity(0.18)
                              : CaelynColor.lavender)
                        .frame(width: CaelynIconSize.xl, height: CaelynIconSize.xl)
                    Image(systemName: isSignedIntoiCloud ? "checkmark.icloud.fill" : "icloud.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSignedIntoiCloud ? CaelynColor.successSage : CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(isSignedIntoiCloud ? "iCloud backup active" : "iCloud not signed in")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(isSignedIntoiCloud
                         ? "Your cycle data syncs automatically across your devices."
                         : "Sign in to iCloud in iOS Settings to enable automatic backup.")
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
            icon: "icloud.fill",
            title: "Private CloudKit",
            body: "Caelyn uses Apple's private CloudKit container — a space only your signed-in devices can access. Apple cannot read the contents."
        ),
        (
            icon: "arrow.triangle.2.circlepath",
            title: "Automatic sync",
            body: "Log on your iPhone, see it on your iPad. Sync happens in the background — no manual export needed."
        ),
        (
            icon: "server.rack",
            title: "No Caelyn servers",
            body: "The sync path is Device → iCloud → Device. Caelyn has no server in this loop and never sees your data."
        ),
        (
            icon: "square.and.arrow.down",
            title: "Works offline too",
            body: "Data is always stored on your device first. iCloud sync is a bonus — Caelyn works fully offline with no degradation."
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
                        q: "Can I turn off iCloud backup?",
                        a: "Go to iOS Settings → [your name] → iCloud → iCloud Drive, and toggle Caelyn off. Your data stays on your device."
                    )
                    Rectangle()
                        .fill(CaelynColor.deepPlumText.opacity(0.06))
                        .frame(height: 1)
                    faqRow(
                        q: "What happens if I delete the app?",
                        a: "Your data remains in iCloud. Reinstall Caelyn, sign in to the same iCloud account, and your history returns automatically."
                    )
                    Rectangle()
                        .fill(CaelynColor.deepPlumText.opacity(0.06))
                        .frame(height: 1)
                    faqRow(
                        q: "Can Caelyn be legally compelled to hand over my data?",
                        a: "No — we have no servers and no access to your data. iCloud sync goes through Apple, not us. Your data is private CloudKit, which Apple cannot read."
                    )
                }
            }
        }
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
            Text("iCloud sync requires a free iCloud account. The sync container is Caelyn's private CloudKit space — separate from iCloud Drive. Manage or delete your iCloud data at any time in iOS Settings → [your name] → iCloud.")
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
        iCloudSyncView()
    }
}
