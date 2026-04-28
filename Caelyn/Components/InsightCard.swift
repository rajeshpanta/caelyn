import SwiftUI

struct InsightCard: View {
    let title: String
    let message: String
    var icon: String = "sparkle"
    var accent: Color = CaelynColor.primaryPlum

    var body: some View {
        CaelynCard {
            HStack(alignment: .top, spacing: CaelynSpacing.sm) {
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
                        .font(CaelynFont.caption.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                        .tracking(0.5)
                    Text(message)
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.sm) {
        InsightCard(
            title: "Pattern",
            message: "You often log cramps 1 day before your period."
        )
        InsightCard(
            title: "Cycle",
            message: "Your last 3 cycles averaged 29 days.",
            icon: "calendar",
            accent: CaelynColor.successSage
        )
        InsightCard(
            title: "Heads up",
            message: "Heavy flow usually appears on day 2.",
            icon: "drop.fill",
            accent: CaelynColor.alertRose
        )
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
