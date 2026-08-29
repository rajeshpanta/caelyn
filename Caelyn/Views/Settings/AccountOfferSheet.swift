import AuthenticationServices
import SwiftData
import SwiftUI

/// Offered once, just after onboarding: would she like Caelyn to know her name and
/// keep her history safe?
///
/// **Why it exists.** The account and iCloud sync landed in Settings → Data →
/// Account & iCloud, three taps down, which is where features go to be never found.
/// Someone finishing onboarding has just told Caelyn about her cycle; that is the
/// moment she cares whether it survives a lost phone, and the moment to ask.
///
/// **Why it is not onboarding.** It appears after onboarding has finished, over the
/// app she can already use. "Not now" is a full-width button with the same weight as
/// the other one, it dismisses permanently, and nothing behind it is locked. Asked
/// once, tracked on the profile, never again — a second nag would make it a wall,
/// and the whole design of this feature is that it is never a wall.
struct AccountOfferSheet: View {

    @Environment(\.modelContext) private var modelContext
    let profile: UserProfile?
    /// Called when she has answered, either way.
    let onFinished: () -> Void

    @State private var signInService = AppleSignInService()
    @State private var namePrompt: NamePrompt?
    @State private var isWorking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                Spacer(minLength: CaelynSpacing.lg)

                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    Text("Make Caelyn yours \u{1F338}")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Two optional extras. You can do both, one, or neither \u{2014} Caelyn works exactly the same either way.")
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }

                benefit(
                    icon: "hand.wave.fill",
                    title: "Caelyn can use your name",
                    body: "So it greets you properly instead of saying nothing at all. You choose the name \u{2014} it doesn't have to be your real one."
                )

                benefit(
                    icon: "icloud.fill",
                    title: "Your history follows you",
                    body: "A private copy in your own iCloud means a new iPhone picks up where you left off, with nothing to export and nothing to re-type."
                )

                Spacer(minLength: CaelynSpacing.md)

                VStack(spacing: CaelynSpacing.sm) {
                    SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
                        .allowsHitTesting(false)
                        .overlay {
                            Button(action: signIn) { Color.clear.contentShape(Rectangle()) }
                                .accessibilityLabel("Sign in with Apple")
                                .accessibilityIdentifier("UIA.AccountOffer.SignIn")
                        }
                        .disabled(isWorking)

                    CaelynButton(title: "Not now", variant: .tertiary) { finish() }
                        .accessibilityIdentifier("UIA.AccountOffer.NotNow")
                }

                Text("You can set either of these up later in Settings \u{2192} Account & iCloud.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.bottom, CaelynSpacing.xl)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .interactiveDismissDisabled(isWorking)
        .sheet(item: $namePrompt) { prompt in
            PreferredNameStep(prefill: prompt.prefill) { confirmed in
                AccountSession.setPreferredName(confirmed, on: profile)
                modelContext.saveOrLog()
                namePrompt = nil
                finish()
            }
            .interactiveDismissDisabled()
        }
    }

    private func benefit(icon: String, title: String, body: String) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(CaelynColor.lavender)
                        .frame(width: CaelynIconSize.xl, height: CaelynIconSize.xl)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(body)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func signIn() {
        isWorking = true
        Task {
            let outcome = await signInService.signIn()
            isWorking = false
            guard AccountSession.apply(outcome, to: profile) else {
                // Cancelled or failed. She stays on the offer, which still has
                // "Not now" — backing out of Apple's sheet must not dismiss the
                // decision or look like an error.
                return
            }
            modelContext.saveOrLog()
            Haptics.success()
            if AccountSession.needsNameConfirmation(profile) {
                namePrompt = NamePrompt(prefill: AccountSession.namePrefill(for: profile))
            } else {
                finish()
            }
        }
    }

    /// Marks the question answered so it is never asked again, whichever way she
    /// went. Declining is an answer.
    private func finish() {
        profile?.hasSeenAccountOffer = true
        modelContext.saveOrLog()
        onFinished()
    }
}

#Preview {
    AccountOfferSheet(profile: nil) {}
}
