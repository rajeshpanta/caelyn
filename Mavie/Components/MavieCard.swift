import SwiftUI

struct MavieCard<Content: View>: View {
    var padding: CGFloat = MavieSpacing.lg
    var radius: CGFloat = MavieRadius.card
    var background: Color = MavieColor.cardWhite
    var shadow: MavieShadow = .card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .mavieShadow(shadow)
    }
}

#Preview {
    VStack(spacing: MavieSpacing.md) {
        MavieCard {
            Text("Default card")
                .font(MavieFont.headline)
                .foregroundStyle(MavieColor.deepPlumText)
        }
        MavieCard(radius: MavieRadius.cardLarge, background: MavieColor.lavender, shadow: .subtle) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Larger radius, lavender, subtle shadow")
                    .font(MavieFont.headline)
                    .foregroundStyle(MavieColor.deepPlumText)
                Text("Variant for emphasis cards")
                    .font(MavieFont.subheadline)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
            }
        }
        MavieCard(padding: MavieSpacing.md, background: MavieColor.blush) {
            Text("Tighter padding, blush")
                .font(MavieFont.body)
                .foregroundStyle(MavieColor.deepPlumText)
        }
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
