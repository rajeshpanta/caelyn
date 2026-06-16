import SwiftUI

struct InsightsEmptyState: View {
    let cyclesLogged: Int
    let confidence: Confidence

    var body: some View {
        VStack(spacing: CaelynSpacing.lg) {
            illustrationCard
            tipCard
        }
    }

    private var illustrationCard: some View {
        CaelynCard(padding: CaelynSpacing.lg) {
            VStack(spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [CaelynColor.lavender, CaelynColor.blush.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: CaelynColor.primaryPlum.opacity(0.15), radius: 12, x: 0, y: 4)

                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CaelynColor.primaryPlum, CaelynColor.softRose],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)
                }

                VStack(spacing: 8) {
                    Text("Your story is just beginning 🌸")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .multilineTextAlignment(.center)

                    Text(cyclesLogged == 0
                         ? "Log a couple of cycles and Caelyn will start surfacing your patterns — averages, common symptoms, and trends, all in one place."
                         : "You've logged \(cyclesLogged) cycle\(cyclesLogged == 1 ? "" : "s") — you're almost there! A couple more and your insights will unlock.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                }

                progressBar
            }
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Getting to know you")
                    .font(CaelynFont.caption.weight(.medium))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                Spacer()
                Text("\(min(cyclesLogged, 3))/3 cycles")
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.primaryPlum.opacity(0.8))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CaelynColor.deepPlumText.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [CaelynColor.primaryPlum, CaelynColor.softRose],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * min(CGFloat(cyclesLogged) / 3.0, 1.0),
                            height: 8
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: cyclesLogged)
                }
            }
            .frame(height: 8)
        }
    }

    private var tipCard: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(CaelynColor.sage.opacity(0.8))
                        .frame(width: 40, height: 40)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(CaelynColor.successSage)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Quick tip")
                        .font(CaelynFont.caption.weight(.semibold))
                        .foregroundStyle(CaelynColor.successSage)
                    Text("Log your flow, mood, and any symptoms each day — even just a tap takes a second and helps Caelyn learn your unique patterns faster.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
