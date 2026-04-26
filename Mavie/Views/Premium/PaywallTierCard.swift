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
                Spacer(minLength: MavieSpacing.xs)
                titleRow
                priceRow
                originalPriceRow
                Spacer(minLength: 4)
                perMonthRow
            }
            .padding(MavieSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: isSelected
                        ? [MavieColor.cardWhite, MavieColor.lavender.opacity(0.4)]
                        : [MavieColor.cardWhite.opacity(0.7), MavieColor.cardWhite.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: MavieRadius.cardLarge, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.cardLarge, style: .continuous)
                    .stroke(
                        isSelected ? MavieColor.primaryPlum : MavieColor.deepPlumText.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .mavieShadow(isSelected ? .card : .subtle)
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
                    .font(MavieFont.caption.weight(.bold))
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
                .font(MavieFont.caption.weight(.bold))
                .tracking(0.4)
        }
        .foregroundStyle(MavieColor.primaryPlum)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(MavieColor.lavender, in: Capsule())
    }

    private var titleRow: some View {
        Text(kind.title.uppercased())
            .font(MavieFont.caption.weight(.semibold))
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
            .tracking(0.6)
    }

    private var priceRow: some View {
        Text(displayPrice)
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .foregroundStyle(MavieColor.deepPlumText)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    @ViewBuilder
    private var originalPriceRow: some View {
        if let strikethroughPrice {
            Text(strikethroughPrice)
                .strikethrough()
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.4))
        }
    }

    @ViewBuilder
    private var perMonthRow: some View {
        if let perMonthLabel {
            Text(perMonthLabel)
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
    }
}
