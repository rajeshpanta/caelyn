import SwiftUI

struct DesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                header
                colorsSection
                typographySection
                spacingSection
                radiiSection
                shadowsSection
            }
            .padding(MavieSpacing.lg)
        }
        .background(MavieColor.backgroundCream.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.xxs) {
            Text("Mavie")
                .font(MavieFont.largeTitle)
                .foregroundStyle(MavieColor.deepPlumText)
            Text("Design system · Phase 1")
                .font(MavieFont.subheadline)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
        .padding(.top, MavieSpacing.lg)
    }

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            sectionTitle("Colors")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: MavieSpacing.sm
            ) {
                ForEach(swatches, id: \.name) { swatch in
                    ColorSwatchView(swatch: swatch)
                }
            }
        }
    }

    private let swatches: [ColorSwatch] = [
        .init(name: "Background Cream", hex: "#FFF8F3", color: MavieColor.backgroundCream),
        .init(name: "Card White",       hex: "#FFFFFF", color: MavieColor.cardWhite),
        .init(name: "Primary Plum",     hex: "#6F3D74", color: MavieColor.primaryPlum),
        .init(name: "Deep Plum Text",   hex: "#2F1B32", color: MavieColor.deepPlumText),
        .init(name: "Soft Rose",        hex: "#EFA7B2", color: MavieColor.softRose),
        .init(name: "Blush",            hex: "#FBE4E7", color: MavieColor.blush),
        .init(name: "Lavender",         hex: "#EEE7FF", color: MavieColor.lavender),
        .init(name: "Sage",             hex: "#DCEBDD", color: MavieColor.sage),
        .init(name: "Warm Sand",        hex: "#F4E2D1", color: MavieColor.warmSand),
        .init(name: "Alert Rose",       hex: "#D96A7A", color: MavieColor.alertRose),
        .init(name: "Success Sage",     hex: "#6E9B7B", color: MavieColor.successSage)
    ]

    private var typographySection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            sectionTitle("Typography")
            VStack(alignment: .leading, spacing: MavieSpacing.sm) {
                typographyRow(label: "Number Large",  font: MavieFont.numberLarge,  sample: "29")
                typographyRow(label: "Number Medium", font: MavieFont.numberMedium, sample: "Day 18")
                typographyRow(label: "Large Title",   font: MavieFont.largeTitle,   sample: "Good morning")
                typographyRow(label: "Title",         font: MavieFont.title,        sample: "Your cycle")
                typographyRow(label: "Title 2",       font: MavieFont.title2,       sample: "Insights")
                typographyRow(label: "Title 3",       font: MavieFont.title3,       sample: "Patterns")
                typographyRow(label: "Headline",      font: MavieFont.headline,     sample: "Period expected in 9 days")
                typographyRow(label: "Body",          font: MavieFont.body,         sample: "Predicted window: May 3–7")
                typographyRow(label: "Callout",       font: MavieFont.callout,      sample: "Calm · Tired · Energetic")
                typographyRow(label: "Subheadline",   font: MavieFont.subheadline,  sample: "Cycle day 18")
                typographyRow(label: "Footnote",      font: MavieFont.footnote,     sample: "Stored privately on your device")
                typographyRow(label: "Caption",       font: MavieFont.caption,      sample: "Last logged 2 hours ago")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MavieSpacing.md)
            .background(MavieColor.cardWhite, in: RoundedRectangle(cornerRadius: MavieRadius.card))
            .mavieShadow(.card)
        }
    }

    private func typographyRow(label: String, font: Font, sample: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(MavieFont.caption.weight(.medium))
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.4))
                .tracking(0.5)
            Text(sample)
                .font(font)
                .foregroundStyle(MavieColor.deepPlumText)
        }
    }

    private var spacingSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            sectionTitle("Spacing")
            VStack(alignment: .leading, spacing: MavieSpacing.sm) {
                spacingBar(label: "xxs", value: MavieSpacing.xxs)
                spacingBar(label: "xs",  value: MavieSpacing.xs)
                spacingBar(label: "sm",  value: MavieSpacing.sm)
                spacingBar(label: "md",  value: MavieSpacing.md)
                spacingBar(label: "lg",  value: MavieSpacing.lg)
                spacingBar(label: "xl",  value: MavieSpacing.xl)
                spacingBar(label: "xxl", value: MavieSpacing.xxl)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MavieSpacing.md)
            .background(MavieColor.cardWhite, in: RoundedRectangle(cornerRadius: MavieRadius.card))
            .mavieShadow(.card)
        }
    }

    private func spacingBar(label: String, value: CGFloat) -> some View {
        HStack(spacing: MavieSpacing.sm) {
            Text(label)
                .font(MavieFont.caption.weight(.medium))
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                .frame(width: 36, alignment: .leading)
            RoundedRectangle(cornerRadius: 2)
                .fill(MavieColor.primaryPlum.opacity(0.7))
                .frame(width: value, height: 12)
            Text("\(Int(value))pt")
                .font(MavieFont.caption.monospacedDigit())
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.4))
            Spacer(minLength: 0)
        }
    }

    private var radiiSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            sectionTitle("Corner radii")
            HStack(spacing: MavieSpacing.sm) {
                radiusSample(label: "chip",      radius: MavieRadius.chip)
                radiusSample(label: "button",    radius: MavieRadius.button)
                radiusSample(label: "card",      radius: MavieRadius.card)
                radiusSample(label: "cardLarge", radius: MavieRadius.cardLarge)
            }
        }
    }

    private func radiusSample(label: String, radius: CGFloat) -> some View {
        VStack(spacing: MavieSpacing.xs) {
            RoundedRectangle(cornerRadius: radius)
                .fill(MavieColor.lavender)
                .frame(height: 64)
                .overlay(
                    Text("\(Int(radius))")
                        .font(MavieFont.callout.weight(.semibold))
                        .foregroundStyle(MavieColor.primaryPlum)
                )
            Text(label)
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var shadowsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            sectionTitle("Shadows")
            HStack(spacing: MavieSpacing.md) {
                shadowSample(label: "subtle", shadow: .subtle)
                shadowSample(label: "card",   shadow: .card)
            }
        }
        .padding(.bottom, MavieSpacing.xl)
    }

    private func shadowSample(label: String, shadow: MavieShadow) -> some View {
        VStack(spacing: MavieSpacing.xs) {
            RoundedRectangle(cornerRadius: MavieRadius.card)
                .fill(MavieColor.cardWhite)
                .frame(height: 80)
                .mavieShadow(shadow)
            Text(label)
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(MavieFont.title3)
            .foregroundStyle(MavieColor.deepPlumText)
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
                    .font(MavieFont.caption.weight(.semibold))
                    .foregroundStyle(MavieColor.deepPlumText)
                Text(swatch.hex)
                    .font(MavieFont.caption.monospacedDigit())
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(MavieSpacing.sm)
        }
        .background(MavieColor.cardWhite)
        .clipShape(RoundedRectangle(cornerRadius: MavieRadius.button))
        .overlay(
            RoundedRectangle(cornerRadius: MavieRadius.button)
                .stroke(MavieColor.deepPlumText.opacity(0.06), lineWidth: 1)
        )
        .mavieShadow(.subtle)
    }
}

#Preview {
    DesignSystemPreview()
}
