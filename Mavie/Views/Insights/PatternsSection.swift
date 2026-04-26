import SwiftUI

struct PatternsSection: View {
    let cycles: [Cycle]
    let mostCommonEarlyPeriodSymptom: Symptom?
    let averagePeriodPain: Double?
    let cycleVariation: Int

    var body: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Patterns", subtitle: "From your last \(cycles.count) cycles")
            VStack(spacing: MavieSpacing.sm) {
                if let symptom = mostCommonEarlyPeriodSymptom {
                    InsightCard(
                        title: "Pattern",
                        message: "You often log \(symptom.displayName.lowercased()) in the first days of your period.",
                        icon: "sparkles"
                    )
                }
                if let avgPain = averagePeriodPain {
                    InsightCard(
                        title: "Period pain",
                        message: "Your period pain averages \(String(format: "%.1f", avgPain)) out of 10.",
                        icon: "bolt.heart",
                        accent: MavieColor.alertRose
                    )
                }
                InsightCard(
                    title: "Cycle variation",
                    message: cycleVariation <= 2
                        ? "Your cycle is fairly steady — usually within \(cycleVariation) day\(cycleVariation == 1 ? "" : "s") of average."
                        : "Your cycle has varied by about ±\(cycleVariation) days recently. Mavie still tracks every shift.",
                    icon: "waveform.path.ecg",
                    accent: cycleVariation > 4 ? MavieColor.alertRose : MavieColor.successSage
                )
            }
        }
    }
}
