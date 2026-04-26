import SwiftUI

struct SymptomChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(MavieFont.caption.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(.horizontal, MavieSpacing.xs)
            .foregroundStyle(isSelected ? MavieColor.primaryPlum : MavieColor.deepPlumText.opacity(0.7))
            .background(
                isSelected ? MavieColor.lavender : MavieColor.cardWhite
            )
            .clipShape(RoundedRectangle(cornerRadius: MavieRadius.chip, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.chip, style: .continuous)
                    .stroke(
                        isSelected ? MavieColor.primaryPlum.opacity(0.4) : MavieColor.deepPlumText.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
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
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: MavieSpacing.xs), count: 3), spacing: MavieSpacing.xs) {
        ForEach(Array(symptoms.enumerated()), id: \.offset) { idx, item in
            SymptomChip(label: item.0, icon: item.1, isSelected: idx == 0 || idx == 4) {}
        }
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
