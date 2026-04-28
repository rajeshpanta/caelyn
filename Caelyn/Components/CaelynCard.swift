import SwiftUI

struct CaelynCard<Content: View>: View {
    var padding: CGFloat = CaelynSpacing.lg
    var radius: CGFloat = CaelynRadius.card
    var background: Color = CaelynColor.cardWhite
    var shadow: CaelynShadow = .card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .caelynShadow(shadow)
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.md) {
        CaelynCard {
            Text("Default card")
                .font(CaelynFont.headline)
                .foregroundStyle(CaelynColor.deepPlumText)
        }
        CaelynCard(radius: CaelynRadius.cardLarge, background: CaelynColor.lavender, shadow: .subtle) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Larger radius, lavender, subtle shadow")
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text("Variant for emphasis cards")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
            }
        }
        CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.blush) {
            Text("Tighter padding, blush")
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText)
        }
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
