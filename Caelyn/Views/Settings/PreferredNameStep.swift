import SwiftUI

/// One friendly question, asked once, right after she signs in.
///
/// **Why this exists rather than adopting Apple's name silently.** Apple hands back
/// whatever is on her Apple ID, which is frequently her full legal name and often
/// not what anyone actually calls her. Greeting someone as "Margaret" when everyone
/// says "Maggie" is a small thing that reads as the app not really knowing her — so
/// Apple's name is a prefill, and the value she confirms is the one Caelyn uses.
///
/// Deliberately not an onboarding flow: one question, one field, one button, and a
/// line telling her it is changeable. Someone who wants no name at all can clear
/// the field and continue, and that counts as an answer — she is not asked again.
struct PreferredNameStep: View {

    /// Prefilled with Apple's suggestion when there is a usable one, empty otherwise.
    @State private var name: String
    @FocusState private var fieldFocused: Bool

    /// Called with the confirmed value. Nil means she chose to have no name.
    let onContinue: (String?) -> Void

    init(prefill: String, onContinue: @escaping (String?) -> Void) {
        _name = State(initialValue: prefill)
        self.onContinue = onContinue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                Text("What should Caelyn call you? \u{1F338}")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }

            CaelynCard(padding: CaelynSpacing.md) {
                TextField("Your name", text: $name)
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .onSubmit(confirm)
                    .accessibilityIdentifier("UIA.NameStep.Field")
            }

            Text(preview)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: preview)

            Spacer(minLength: 0)

            VStack(spacing: CaelynSpacing.xs) {
                CaelynButton(title: "Continue", action: confirm)
                    .accessibilityIdentifier("UIA.NameStep.Continue")

                Text("You can change this anytime in Settings.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            }
        }
        .padding(.horizontal, CaelynSpacing.lg)
        .padding(.vertical, CaelynSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .onAppear { fieldFocused = true }
    }

    /// Acknowledges the prefill when there is one, so it doesn't look like Caelyn
    /// guessed her name out of nowhere.
    private var subtitle: String {
        PersonalName.usable(name) == nil
            ? "However you'd like to be greeted. Leave it blank if you'd rather not."
            : "Apple suggested this \u{2014} change it to whatever you'd actually like to be called."
    }

    /// Shows the real greeting, including the honest nameless version, so Continue
    /// never produces a surprise.
    private var preview: String {
        if let usable = PersonalName.usable(name) {
            return "Caelyn will say: \u{201C}\(HomeCopy.greeting(name: usable))\u{201D}"
        }
        return "Caelyn will say: \u{201C}\(HomeCopy.greeting())\u{201D}"
    }

    private func confirm() {
        fieldFocused = false
        onContinue(PersonalName.usable(name))
        Haptics.success()
    }
}

#Preview("Apple suggested a name") {
    PreferredNameStep(prefill: "Rajesh") { _ in }
}

#Preview("No name from Apple") {
    PreferredNameStep(prefill: "") { _ in }
}

/// Identifiable wrapper so the step can be presented with `.sheet(item:)`, which
/// guarantees the prefill is captured at presentation time rather than read from
/// changing state while the sheet is up.
struct NamePrompt: Identifiable {
    let prefill: String
    var id: String { prefill }
}
