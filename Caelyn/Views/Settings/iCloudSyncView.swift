import SwiftUI

/// Honest, local-only backup explainer. Caelyn stores everything on-device with
/// no CloudKit sync and no account (the previous "iCloud backup active" screen
/// described sync that never ran — see docs/DIAGNOSIS.md). Real opt-in
/// private-CloudKit backup is a later phase; until then this screen tells the
/// truth and points users to Export as their backup path.
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
            Text("Your data lives on this device.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.deepPlumText)
            Text("Caelyn keeps everything on-device — there's no cloud copy and no account. That's the strongest privacy guarantee, and it means your backup is in your hands.")
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
                        .fill(CaelynColor.successSage.opacity(0.18))
                        .frame(width: CaelynIconSize.xl, height: CaelynIconSize.xl)
                    Image(systemName: "lock.iphone")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CaelynColor.successSage)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Stored on this device only")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Nothing is uploaded anywhere. To keep a copy, export your data from Settings → Export.")
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
            icon: "iphone",
            title: "On-device only",
            body: "Your cycle history is saved in Caelyn's private storage on this iPhone. It is not sent to iCloud or any server."
        ),
        (
            icon: "server.rack",
            title: "No Caelyn servers",
            body: "Caelyn has no backend and no account system. There is no copy of your data anywhere for us — or anyone — to access."
        ),
        (
            icon: "square.and.arrow.up",
            title: "Back up with Export",
            body: "Use Settings → Export to save a CSV or PDF of your data to Files, AirDrop, or anywhere you choose. That file is your backup."
        ),
        (
            icon: "arrow.clockwise",
            title: "Restoring",
            body: "Because data lives only on this device, deleting the app removes it. Export first if you plan to reinstall or switch phones."
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
                        q: "How do I back up my data?",
                        a: "Go to Settings → Export and save a CSV or PDF. Store it wherever you like — that exported file is your backup."
                    )
                    Rectangle()
                        .fill(CaelynColor.deepPlumText.opacity(0.06))
                        .frame(height: 1)
                    faqRow(
                        q: "What happens if I delete the app?",
                        a: "Your data is stored only inside Caelyn on this device, so deleting the app deletes the data. Export it first if you want to keep it."
                    )
                    Rectangle()
                        .fill(CaelynColor.deepPlumText.opacity(0.06))
                        .frame(height: 1)
                    faqRow(
                        q: "Can Caelyn be legally compelled to hand over my data?",
                        a: "No — we have no servers and no copy of your data. There is nothing for us to hand over."
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
            Text("Cloud sync across your devices is something we're building carefully and privately. Until it ships, Caelyn stays fully local — and Export is always available as your backup.")
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
