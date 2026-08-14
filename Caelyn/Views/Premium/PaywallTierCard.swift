import SwiftUI

/// One selectable plan, as a compact row.
///
/// This used to be a 180pt-tall card, two of them side by side plus a full-width
/// lifetime card below — which pushed the buy button off the first screen and
/// made choosing feel like reading a pricing table. Rows are ~72pt, so all three
/// plans and the button fit on an iPhone SE without scrolling, and the eye can
/// compare prices down a single column instead of across three shapes.
struct PaywallTierCard: View {
    let kind: Kind
    /// The price as StoreKit formats it for her storefront — never hardcoded.
    let displayPrice: String
    /// e.g. "per year" — sits under the price.
    let unitLabel: String?
    /// e.g. "Just $1.67 a month" or "One payment, nothing recurring".
    let subLabel: String?
    let badgeText: String?
    let badgeBackground: Color
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    enum Kind {
        case monthly, yearly, lifetime

        var title: String {
            switch self {
            case .monthly:  return "Monthly"
            case .yearly:   return "Yearly"
            case .lifetime: return "Lifetime"
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CaelynSpacing.sm) {
                selectionDot
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(kind.title)
                            .font(CaelynFont.headline)
                            .foregroundStyle(CaelynColor.deepPlumText)
                        if let badgeText { badge(badgeText) }
                    }
                    if let subLabel {
                        Text(subLabel)
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: CaelynSpacing.xs)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(displayPrice)
                        .font(CaelynFont.headline.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText)
                    if let unitLabel {
                        Text(unitLabel)
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    }
                }
                .layoutPriority(1)
            }
            .padding(.horizontal, CaelynSpacing.md)
            .padding(.vertical, CaelynSpacing.sm + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                    .stroke(
                        isSelected ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.10),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
            .fill(isSelected ? CaelynColor.lavender.opacity(0.55) : CaelynColor.cardWhite)
    }

    /// A filled plum circle with a tick when chosen; a quiet ring when not.
    private var selectionDot: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.22),
                    lineWidth: isSelected ? 0 : 1.5
                )
                .background(Circle().fill(isSelected ? CaelynColor.primaryPlum : .clear))
                .frame(width: 22, height: 22)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(CaelynColor.onPrimary)
            }
        }
        .accessibilityHidden(true)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.4)
            .foregroundStyle(CaelynColor.onPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(badgeBackground, in: Capsule())
            // At accessibility sizes the badge would wrap and shove the price
            // off the row; the plan title and price matter more than the label.
            .opacity(dynamicTypeSize.isAccessibilitySize ? 0 : 1)
            .frame(width: dynamicTypeSize.isAccessibilitySize ? 0 : nil)
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.sm) {
        PaywallTierCard(kind: .yearly, displayPrice: "$19.99", unitLabel: "per year",
                        subLabel: "Just $1.67 a month · 7-day free trial",
                        badgeText: "BEST VALUE", badgeBackground: CaelynColor.successSage,
                        isSelected: true) {}
        PaywallTierCard(kind: .monthly, displayPrice: "$3.99", unitLabel: "per month",
                        subLabel: "7-day free trial", badgeText: nil,
                        badgeBackground: .clear, isSelected: false) {}
        PaywallTierCard(kind: .lifetime, displayPrice: "$99.99", unitLabel: "once",
                        subLabel: "One payment, nothing recurring",
                        badgeText: "FOREVER", badgeBackground: CaelynColor.primaryPlum,
                        isSelected: false) {}
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
