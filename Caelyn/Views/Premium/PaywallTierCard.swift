import SwiftUI

struct PaywallTierCard: View {
    let kind: Kind
    let displayPrice: String
    let strikethroughPrice: String?
    let perMonthLabel: String?
    let badgeText: String?
    let badgeBackground: Color
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void

    enum Kind {
        case monthly
        case yearly

        var title: String {
            switch self {
            case .monthly: return "Monthly"
            case .yearly:  return "Yearly"
            }
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                topBadge
                Spacer(minLength: CaelynSpacing.xs)
                titleRow
                priceRow
                originalPriceRow
                Spacer(minLength: 4)
                perMonthRow
            }
            .padding(CaelynSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [CaelynColor.cardWhite, CaelynColor.lavender.opacity(0.4)]
                        : [CaelynColor.cardWhite.opacity(0.7), CaelynColor.cardWhite.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
                    .stroke(
                        isSelected ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .caelynShadow(isSelected ? .card : .subtle)
            .scaleEffect(isSelected ? 1.0 : 0.985)
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var topBadge: some View {
        HStack {
            if isBestValue {
                bestValuePill
            }
            Spacer(minLength: 0)
            if let badgeText {
                Text(badgeText)
                    .font(CaelynFont.caption.weight(.bold))
                    .tracking(0.3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(badgeBackground, in: Capsule())
            }
        }
        .frame(minHeight: 22)
    }

    private var bestValuePill: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .bold))
            Text("BEST VALUE")
                .font(CaelynFont.caption.weight(.bold))
                .tracking(0.4)
        }
        .foregroundStyle(CaelynColor.primaryPlum)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(CaelynColor.lavender, in: Capsule())
    }

    private var titleRow: some View {
        Text(kind.title.uppercased())
            .font(CaelynFont.caption.weight(.semibold))
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
            .tracking(0.6)
    }

    private var priceRow: some View {
        Text(displayPrice)
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(CaelynColor.deepPlumText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var originalPriceRow: some View {
        if let strikethroughPrice {
            Text(strikethroughPrice)
                .strikethrough()
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
        }
    }

    @ViewBuilder
    private var perMonthRow: some View {
        if let perMonthLabel {
            Text(perMonthLabel)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
    }
}
