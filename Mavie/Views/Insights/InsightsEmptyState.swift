import SwiftUI

struct InsightsEmptyState: View {
    let cyclesLogged: Int
    let confidence: Confidence

    var body: some View {
        MavieCard(padding: MavieSpacing.lg) {
            VStack(alignment: .leading, spacing: MavieSpacing.md) {
                HStack(spacing: MavieSpacing.sm) {
                    ZStack {
                        Circle().fill(MavieColor.lavender).frame(width: 40, height: 40)
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MavieColor.primaryPlum)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Patterns coming soon")
                            .font(MavieFont.headline)
                            .foregroundStyle(MavieColor.deepPlumText)
                        Text(confidence.displayText)
                            .font(MavieFont.subheadline)
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                    }
                }

                progressDots

                Text(cyclesLogged == 0
                     ? "Once you've logged a few cycles, Mavie will surface your averages, common symptoms, and gentle patterns here."
                     : "You've logged \(cyclesLogged) cycle\(cyclesLogged == 1 ? "" : "s"). A couple more and Mavie can start showing patterns.")
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { idx in
                Circle()
                    .fill(idx < cyclesLogged ? MavieColor.primaryPlum : MavieColor.primaryPlum.opacity(0.18))
                    .frame(width: 10, height: 10)
            }
            Text("\(min(cyclesLogged, 3))/3 cycles")
                .font(MavieFont.caption.weight(.medium))
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                .padding(.leading, 4)
        }
    }
}
