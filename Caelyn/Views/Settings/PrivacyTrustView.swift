import SwiftUI

struct PrivacyTrustView: View {

    private let promises: [(icon: String, title: String, body: String, color: Color)] = [
        (
            icon: "iphone",
            title: "No server — ever",
            body: "Caelyn has no database, no server, and no cloud of its own. By default every entry stays only on your device; turn on iCloud Sync and it goes to your OWN private iCloud — still never to us.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "person.slash",
            title: "No account required",
            body: "Caelyn never asks for your email, name, age, or location. We don't know who you are, and we prefer it that way.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "hand.raised.slash.fill",
            title: "No ads or data selling",
            body: "Caelyn contains zero third-party trackers, zero analytics SDKs, zero advertising networks. Your health data is not a product.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "list.bullet.rectangle.portrait",
            title: "Exactly what's stored, and where",
            body: "Your cycle logs live in an on-device database. If you set a PIN, only a salted hash of it is kept in the device Keychain — never the PIN itself. Preferences sit in local app storage. None of it is in any cloud of ours.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "wifi.slash",
            title: "The only data that leaves your phone",
            body: "Caelyn makes no network calls of its own and runs no servers. The only things that ever leave are what you export, what you sync to Apple Health, an encrypted copy to your OWN private iCloud if you turn on Sync, and purchase checks handled by Apple.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: BiometricService.availableKind() == .none ? "lock.fill" : BiometricService.availableKind().icon,
            title: "\(BiometricService.availableKind() == .none ? "App" : BiometricService.availableKind().displayName) lock",
            body: "Optional but built in. Enable it in Settings and the app locks itself whenever it moves to the background.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "eye.slash.fill",
            title: "Hidden in the task switcher",
            body: "Enable \"Hide app preview\" in Privacy settings and Caelyn masks itself in the iOS task switcher — nothing visible at a glance.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "bell.badge.slash",
            title: "Private notifications",
            body: "When enabled, reminders show only \"Caelyn reminder\" on your lock screen — no details that reveal what the app is for.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "square.and.arrow.up",
            title: "Export or delete anytime",
            body: "Your data belongs to you. Export as CSV or PDF anytime, or wipe everything with one tap in Settings → Delete all data.",
            color: CaelynColor.primaryPlum
        ),
        (
            icon: "lock.shield.fill",
            title: "Subpoena-resistant by design",
            body: "Because we hold no data and run no server, there is nothing for us to hand over — even if legally compelled. This isn't a policy; it's the architecture. (If you enable iCloud Sync, your copy lives in your Apple account, under Apple's policies — never ours.)",
            color: CaelynColor.alertRose
        )
    ]

    /// The threat model, in plain language: concrete "what if" scenarios and what
    /// actually happens in each. Privacy must be PROVABLE, not promised (S7).
    private let threatModel: [(q: String, a: String)] = [
        (
            q: "Someone picks up my phone",
            a: "With App Lock on, Caelyn locks itself the moment it leaves the foreground — Face ID, Touch ID, or your PIN to get back in. \"Hide app preview\" blanks it in the app switcher, and private notifications never show cycle details on your lock screen."
        ),
        (
            q: "Someone forces me to open Caelyn",
            a: "If you've set a duress PIN, entering it instead of your real PIN silently and permanently erases everything — the app opens looking brand new, with no sign anything was deleted."
        ),
        (
            q: "A court orders Caelyn to hand over my data",
            a: "There is nothing to hand over. We run no servers and keep no copies. With sync off, your data exists in exactly one place: your device. With sync on, it's in your own Apple iCloud account — under Apple's policies, never ours."
        ),
        (
            q: "I lose my phone",
            a: "Your data is locked behind your device passcode and Caelyn's own lock. If you enabled \"Auto-erase if inactive,\" the next time anyone opens Caelyn after your chosen idle period, it erases everything before showing a thing. (If the app is never opened again, the data simply stays locked behind your passcode.)"
        ),
        (
            q: "Caelyn (the company) disappears",
            a: "The app keeps working — it never depended on a server. Your data stays on your device, and Export (CSV/PDF) is always there to take it anywhere else."
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                headline
                ForEach(promises.indices, id: \.self) { idx in
                    promiseCard(promises[idx])
                }
                threatModelSection
                legalNote
            }
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.top, CaelynSpacing.md)
            .padding(.bottom, CaelynSpacing.xl)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .navigationTitle("Your Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Private by architecture,\nnot policy.")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.deepPlumText)

            Text("Period tracking data is among the most sensitive information on your phone. Caelyn was built from the ground up so that data never has to leave it.")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func promiseCard(_ promise: (icon: String, title: String, body: String, color: Color)) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(promise.color == CaelynColor.alertRose
                              ? CaelynColor.blush
                              : CaelynColor.lavender)
                        .frame(width: 44, height: 44)
                    Image(systemName: promise.icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(promise.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(promise.title)
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(promise.body)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var threatModelSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("WHAT IF…")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    ForEach(threatModel.indices, id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(threatModel[idx].q)
                                .font(CaelynFont.body.weight(.medium))
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text(threatModel[idx].a)
                                .font(CaelynFont.subheadline)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if idx < threatModel.count - 1 {
                            Rectangle()
                                .fill(CaelynColor.deepPlumText.opacity(0.06))
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                Text("Health disclaimer")
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    .tracking(0.4)
            }
            Text("Caelyn is a personal cycle tracker, not a medical device. Predictions are estimates based on your logs. For medical concerns, please consult a healthcare provider.")
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
        PrivacyTrustView()
    }
}
