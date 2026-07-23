import SwiftUI

struct SymptomChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.selection()
            if !reduceMotion {
                pressed = true
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = false }
            }
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(CaelynFont.caption.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(.horizontal, CaelynSpacing.xs)
            .foregroundStyle(isSelected ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.7))
            .background(
                isSelected ? CaelynColor.lavender : CaelynColor.cardWhite
            )
            .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
                    .stroke(
                        isSelected ? CaelynColor.primaryPlum.opacity(0.4) : CaelynColor.deepPlumText.opacity(0.06),
                        lineWidth: 1
                    )
            )
            // Same "Caelyn heard you" beat as the mood chip: spring settle on tap,
            // fill blooming into lavender over ~220ms.
            .scaleEffect(pressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityHint(isSelected ? "Logged" : "Tap to log this symptom")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let symptoms: [(String, String)] = [
        ("Cramps", "bolt.heart"),
        ("Bloating", "circle.dotted"),
        ("Acne", "drop"),
        ("Cravings", "fork.knife"),
        ("Fatigue", "moon.zzz"),
        ("Headache", "brain.head.profile")
    ]
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CaelynSpacing.xs), count: 3), spacing: CaelynSpacing.xs) {
        ForEach(Array(symptoms.enumerated()), id: \.offset) { idx, item in
            SymptomChip(label: item.0, icon: item.1, isSelected: idx == 0 || idx == 4) {}
        }
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
