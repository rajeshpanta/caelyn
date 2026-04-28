import SwiftUI

struct InsightsEmptyState: View {
    let cyclesLogged: Int
    let confidence: Confidence

    var body: some View {
        CaelynCard(padding: CaelynSpacing.lg) {
            VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                HStack(spacing: CaelynSpacing.sm) {
                    ZStack {
                        Circle().fill(CaelynColor.lavender).frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CaelynColor.primaryPlum)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Patterns coming soon")
                            .font(CaelynFont.headline)
                            .foregroundStyle(CaelynColor.deepPlumText)
                        Text(confidence.displayText)
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    }
                }

                progressDots

                Text(cyclesLogged == 0
                     ? "Once you've logged a few cycles, Caelyn will surface your averages, common symptoms, and gentle patterns here."
                     : "You've logged \(cyclesLogged) cycle\(cyclesLogged == 1 ? "" : "s"). A couple more and Caelyn can start showing patterns.")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .fill(idx < cyclesLogged ? CaelynColor.primaryPlum : CaelynColor.primaryPlum.opacity(0.18))
                    .frame(width: 10, height: 10)
            }
            Text("\(min(cyclesLogged, 3))/3 cycles")
                .font(CaelynFont.caption.weight(.medium))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .padding(.leading, 4)
        }
    }
}
