import SwiftUI

struct GoalCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(
                                isSelected
                                    ? LinearGradient(
                                        colors: [CaelynColor.primaryPlum, CaelynColor.softRose.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [CaelynColor.lavender, CaelynColor.blush.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: isSelected ? CaelynColor.primaryPlum.opacity(0.35) : .clear,
                                radius: 8, x: 0, y: 3
                            )
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(isSelected ? .white : CaelynColor.primaryPlum)
                    }

                    // Check badge
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(CaelynColor.successSage)
                                .frame(width: 18, height: 18)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 4, y: 4)
                    }
                }

                Text(title)
                    .font(CaelynFont.subheadline.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CaelynSpacing.md)
            .background(
                isSelected
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [CaelynColor.lavender.opacity(0.8), CaelynColor.blush.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(CaelynColor.cardWhite)
            )
            .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .stroke(
                        isSelected
                            ? CaelynColor.primaryPlum.opacity(0.4)
                            : CaelynColor.deepPlumText.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected
                    ? CaelynColor.primaryPlum.opacity(0.12)
                    : Color.black.opacity(0.04),
                radius: isSelected ? 10 : 4,
                x: 0, y: isSelected ? 4 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Double-tap to deselect" : "Double-tap to select")
    }
}
