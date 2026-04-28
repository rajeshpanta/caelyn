#if DEBUG
import SwiftUI

/// Design-token reference view used only by Xcode previews. Compiled out of
/// Release builds.
struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                header
                colorsSection
                typographySection
                spacingSection
                radiiSection
                shadowsSection
            }
            .padding(CaelynSpacing.lg)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.xxs) {
            Text("Caelyn")
                .font(CaelynFont.largeTitle)
                .foregroundStyle(CaelynColor.deepPlumText)
            Text("Design system · Phase 1")
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
        .padding(.top, CaelynSpacing.lg)
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            sectionTitle("Colors")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: CaelynSpacing.sm
            ) {
                ForEach(swatches, id: \.name) { swatch in
                    ColorSwatchView(swatch: swatch)
                }
            }
        }
    }

    private let swatches: [ColorSwatch] = [
        .init(name: "Background Cream", hex: "#FFF8F3", color: CaelynColor.backgroundCream),
        .init(name: "Card White",       hex: "#FFFFFF", color: CaelynColor.cardWhite),
        .init(name: "Primary Plum",     hex: "#6F3D74", color: CaelynColor.primaryPlum),
        .init(name: "Deep Plum Text",   hex: "#2F1B32", color: CaelynColor.deepPlumText),
        .init(name: "Soft Rose",        hex: "#EFA7B2", color: CaelynColor.softRose),
        .init(name: "Blush",            hex: "#FBE4E7", color: CaelynColor.blush),
        .init(name: "Lavender",         hex: "#EEE7FF", color: CaelynColor.lavender),
        .init(name: "Sage",             hex: "#DCEBDD", color: CaelynColor.sage),
        .init(name: "Warm Sand",        hex: "#F4E2D1", color: CaelynColor.warmSand),
        .init(name: "Alert Rose",       hex: "#D96A7A", color: CaelynColor.alertRose),
        .init(name: "Success Sage",     hex: "#6E9B7B", color: CaelynColor.successSage)
    ]

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            sectionTitle("Typography")
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                typographyRow(label: "Number Large",  font: CaelynFont.numberLarge,  sample: "29")
                typographyRow(label: "Number Medium", font: CaelynFont.numberMedium, sample: "Day 18")
                typographyRow(label: "Large Title",   font: CaelynFont.largeTitle,   sample: "Good morning")
                typographyRow(label: "Title",         font: CaelynFont.title,        sample: "Your cycle")
                typographyRow(label: "Title 2",       font: CaelynFont.title2,       sample: "Insights")
                typographyRow(label: "Title 3",       font: CaelynFont.title3,       sample: "Patterns")
                typographyRow(label: "Headline",      font: CaelynFont.headline,     sample: "Period expected in 9 days")
                typographyRow(label: "Body",          font: CaelynFont.body,         sample: "Predicted window: May 3–7")
                typographyRow(label: "Callout",       font: CaelynFont.callout,      sample: "Calm · Tired · Energetic")
                typographyRow(label: "Subheadline",   font: CaelynFont.subheadline,  sample: "Cycle day 18")
                typographyRow(label: "Footnote",      font: CaelynFont.footnote,     sample: "Stored privately on your device")
                typographyRow(label: "Caption",       font: CaelynFont.caption,      sample: "Last logged 2 hours ago")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CaelynSpacing.md)
            .background(CaelynColor.cardWhite, in: RoundedRectangle(cornerRadius: CaelynRadius.card))
            .caelynShadow(.card)
        }
    }

    private func typographyRow(label: String, font: Font, sample: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(CaelynFont.caption.weight(.medium))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
                .tracking(0.5)
            Text(sample)
                .font(font)
                .foregroundStyle(CaelynColor.deepPlumText)
        }
    }

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            sectionTitle("Spacing")
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                spacingBar(label: "xxs", value: CaelynSpacing.xxs)
                spacingBar(label: "xs",  value: CaelynSpacing.xs)
                spacingBar(label: "sm",  value: CaelynSpacing.sm)
                spacingBar(label: "md",  value: CaelynSpacing.md)
                spacingBar(label: "lg",  value: CaelynSpacing.lg)
                spacingBar(label: "xl",  value: CaelynSpacing.xl)
                spacingBar(label: "xxl", value: CaelynSpacing.xxl)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CaelynSpacing.md)
            .background(CaelynColor.cardWhite, in: RoundedRectangle(cornerRadius: CaelynRadius.card))
            .caelynShadow(.card)
        }
    }

    private func spacingBar(label: String, value: CGFloat) -> some View {
        HStack(spacing: CaelynSpacing.sm) {
            Text(label)
                .font(CaelynFont.caption.weight(.medium))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .frame(width: 36, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(CaelynColor.primaryPlum.opacity(0.7))
                .frame(width: value, height: 12)
            Text("\(Int(value))pt")
                .font(CaelynFont.caption.monospacedDigit())
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
            Spacer(minLength: 0)
        }
    }

    private var radiiSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            sectionTitle("Corner radii")
            HStack(spacing: CaelynSpacing.sm) {
                radiusSample(label: "chip",      radius: CaelynRadius.chip)
                radiusSample(label: "button",    radius: CaelynRadius.button)
                radiusSample(label: "card",      radius: CaelynRadius.card)
                radiusSample(label: "cardLarge", radius: CaelynRadius.cardLarge)
            }
        }
    }

    private func radiusSample(label: String, radius: CGFloat) -> some View {
        VStack(spacing: CaelynSpacing.xs) {
            RoundedRectangle(cornerRadius: radius)
                .fill(CaelynColor.lavender)
                .frame(height: 64)
                .overlay(
                    Text("\(Int(radius))")
                        .font(CaelynFont.callout.weight(.semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                )
            Text(label)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var shadowsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            sectionTitle("Shadows")
            HStack(spacing: CaelynSpacing.md) {
                shadowSample(label: "subtle", shadow: .subtle)
                shadowSample(label: "card",   shadow: .card)
            }
        }
        .padding(.bottom, CaelynSpacing.xl)
    }

    private func shadowSample(label: String, shadow: CaelynShadow) -> some View {
        VStack(spacing: CaelynSpacing.xs) {
            RoundedRectangle(cornerRadius: CaelynRadius.card)
                .fill(CaelynColor.cardWhite)
                .frame(height: 80)
                .caelynShadow(shadow)
            Text(label)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(CaelynFont.title3)
            .foregroundStyle(CaelynColor.deepPlumText)
    }
}

private struct ColorSwatch {
    let name: String
    let hex: String
    let color: Color
}

private struct ColorSwatchView: View {
    let swatch: ColorSwatch

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(swatch.color)
                .frame(height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(swatch.name)
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text(swatch.hex)
                    .font(CaelynFont.caption.monospacedDigit())
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CaelynSpacing.sm)
        }
        .background(CaelynColor.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: CaelynRadius.button)
                .stroke(CaelynColor.deepPlumText.opacity(0.06), lineWidth: 1)
        )
        .caelynShadow(.subtle)
    }
}

#Preview {
    DesignSystemPreview()
}
#endif
