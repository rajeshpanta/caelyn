import SwiftUI

struct InsightCard: View {
    let title: String
    let message: String
    var icon: String = "sparkle"
    var accent: Color = MavieColor.primaryPlum

    var body: some View {
        MavieCard {
            HStack(alignment: .top, spacing: MavieSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(MavieFont.caption.weight(.semibold))
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                        .tracking(0.5)
                    Text(message)
                        .font(MavieFont.body)
                        .foregroundStyle(MavieColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: MavieSpacing.sm) {
        InsightCard(
            title: "Pattern",
            message: "You often log cramps 1 day before your period."
        )
        InsightCard(
            title: "Cycle",
            message: "Your last 3 cycles averaged 29 days.",
            icon: "calendar",
            accent: MavieColor.successSage
        )
        InsightCard(
            title: "Heads up",
            message: "Heavy flow usually appears on day 2.",
            icon: "drop.fill",
            accent: MavieColor.alertRose
        )
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
