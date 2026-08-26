import SwiftUI

/// The "here's what we found" panel, shared by the confirmation screen and the
/// summary after an import.
///
/// Its whole job is to make an import feel like something she is deciding rather
/// than something happening to her: the counts in her own words, then — in
/// writing, before she taps anything — the promise that what she has typed is not
/// at risk.
struct ImportPreviewCard: View {

    let headline: String
    let sourceLine: String
    let breakdown: [String]
    let safetyLine: String
    let caveats: [String]
    var spanDescription: String?

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            CaelynCard {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    Text(headline)
                        .font(CaelynFont.title3)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let spanDescription {
                        Text(spanDescription)
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.primaryPlum)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(sourceLine)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    if !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                            ForEach(breakdown, id: \.self) { line in
                                HStack(alignment: .firstTextBaseline, spacing: CaelynSpacing.xs) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(CaelynColor.successSage)
                                    Text(line)
                                        .font(CaelynFont.body)
                                        .foregroundStyle(CaelynColor.deepPlumText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, CaelynSpacing.xs)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Found " + breakdown.joined(separator: ", "))
                    }
                }
            }

            CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.successSage.opacity(0.12)) {
                HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CaelynColor.successSage)
                    Text(safetyLine)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }

            if !caveats.isEmpty {
                CaelynCard {
                    VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                        Text("Worth knowing")
                            .font(CaelynFont.caption.weight(.semibold))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                            .tracking(0.6)
                        ForEach(caveats, id: \.self) { line in
                            HStack(alignment: .firstTextBaseline, spacing: CaelynSpacing.xs) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
                                Text(line)
                                    .font(CaelynFont.subheadline)
                                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    init(preview: ImportPreview, calendar: Calendar = .current) {
        headline = preview.headline
        sourceLine = preview.sourceLine
        breakdown = preview.breakdown
        safetyLine = preview.safetyLine
        caveats = preview.caveats
        spanDescription = preview.spanDescription(calendar: calendar)
    }
}
