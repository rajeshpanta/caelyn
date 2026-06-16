import SwiftUI

struct PrivacyTrustView: View {

    private let promises: [(icon: String, title: String, body: String, color: Color)] = [
        (
            icon: "iphone",
            title: "No server — ever",
            body: "Every entry, every log, every note lives exclusively on your device. We have no database, no server, no cloud of our own.",
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
            icon: "faceid",
            title: "Face ID / Touch ID lock",
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
            body: "Because we hold no data on our servers, there is nothing for us to hand over — even if legally compelled. This isn't a policy. It's the architecture.",
            color: CaelynColor.alertRose
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                headline
                ForEach(promises.indices, id: \.self) { idx in
                    promiseCard(promises[idx])
                }
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

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                Text("Health disclaimer")
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
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
