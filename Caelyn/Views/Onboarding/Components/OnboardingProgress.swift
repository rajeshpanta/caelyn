import SwiftUI

struct OnboardingProgress: View {
    let position: Int
    let total: Int
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: CaelynSpacing.md) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.75))
                    .frame(width: 36, height: 36)
                    .background(CaelynColor.cardWhite, in: Circle())
                    .caelynShadow(.subtle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { idx in
                    Capsule()
                        .fill(idx < position ? CaelynColor.primaryPlum : CaelynColor.primaryPlum.opacity(0.15))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: position)
                }
            }

            Text("\(position)/\(total)")
                .font(CaelynFont.footnote.weight(.medium))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                .monospacedDigit()
                .frame(minWidth: 32)
                .accessibilityLabel("Step \(position) of \(total)")
        }
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.md) {
        OnboardingProgress(position: 1, total: 7, onBack: {})
        OnboardingProgress(position: 4, total: 7, onBack: {})
        OnboardingProgress(position: 7, total: 7, onBack: {})
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
