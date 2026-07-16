import SwiftUI

struct TTCDashboardCard: View {
    let result: TTCFertilityEngine.FertilityResult
    let nextPeriodStart: Date?

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(scoreColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("TTC Fertility")
                            .font(CaelynFont.caption.weight(.semibold))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                            .tracking(0.3)
                        Text("\(result.label) fertility today")
                            .font(CaelynFont.headline)
                            .foregroundStyle(CaelynColor.deepPlumText)
                    }
                    Spacer()
                    scoreGauge
                }

                if !result.signals.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(result.signals, id: \.self) { signal in
                            Label(signal, systemImage: "checkmark.circle.fill")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.successSage)
                        }
                    }
                }

                if let next = nextPeriodStart {
                    let fertile = PredictionEngine.fertileWindow(nextPeriodStart: next)
                    let start = fertile.lowerBound, end = fertile.upperBound
                    let cal = Calendar.current
                    let today = cal.startOfDay(for: .now)
                    if start > today {
                        let daysUntil = cal.dateComponents([.day], from: today, to: start).day ?? 0
                        Text("Fertile window in \(daysUntil) day\(daysUntil == 1 ? "" : "s")")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    } else if fertile.contains(today) {
                        let daysLeft = cal.dateComponents([.day], from: today, to: end).day ?? 0
                        Text("In your fertile window — \(daysLeft) day\(daysLeft == 1 ? "" : "s") remaining")
                            .font(CaelynFont.caption.weight(.medium))
                            .foregroundStyle(CaelynColor.successSage)
                    }
                }

                Text("Log your BBT, LH strip, and cervical mucus for a more accurate score.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
            }
        }
    }

    // MARK: - Score gauge

    private var scoreGauge: some View {
        ZStack {
            Circle()
                .stroke(CaelynColor.deepPlumText.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(result.score) / 100.0)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: result.score)
            Text("\(result.score)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(scoreColor)
        }
        .frame(width: 48, height: 48)
        .accessibilityLabel("Fertility score \(result.score) out of 100, \(result.label)")
        .accessibilityElement(children: .ignore)
    }

    private var scoreColor: Color {
        switch result.score {
        case 75...: return CaelynColor.primaryPlum
        case 50..<75: return CaelynColor.successSage
        case 25..<50: return CaelynColor.warmSand
        default: return CaelynColor.deepPlumText.opacity(0.4)
        }
    }
}
