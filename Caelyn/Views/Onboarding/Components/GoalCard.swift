import SwiftUI

struct GoalCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? CaelynColor.primaryPlum : CaelynColor.lavender)
                        .frame(width: 36, height: 36)
                    Image(systemName: isSelected ? "checkmark" : icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : CaelynColor.primaryPlum)
                }
                Text(title)
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.deepPlumText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CaelynSpacing.md)
            .background(
                isSelected ? CaelynColor.lavender.opacity(0.6) : CaelynColor.cardWhite,
                in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? CaelynColor.primaryPlum.opacity(0.45) : CaelynColor.deepPlumText.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .caelynShadow(.subtle)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
