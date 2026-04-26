import SwiftUI

struct GoalCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: MavieSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(isSelected ? MavieColor.primaryPlum : MavieColor.lavender)
                        .frame(width: 36, height: 36)
                    Image(systemName: isSelected ? "checkmark" : icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : MavieColor.primaryPlum)
                }
                Text(title)
                    .font(MavieFont.headline)
                    .foregroundStyle(MavieColor.deepPlumText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MavieSpacing.md)
            .background(
                isSelected ? MavieColor.lavender.opacity(0.6) : MavieColor.cardWhite,
                in: RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? MavieColor.primaryPlum.opacity(0.45) : MavieColor.deepPlumText.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .mavieShadow(.subtle)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
