import SwiftUI

struct HomePatternInsight: View {
    let confidence: Confidence
    let mostFrequentSymptom: (Symptom, Int)?

    var body: some View {
        if confidence == .low || mostFrequentSymptom == nil {
            InsightCard(
                title: "Patterns",
                message: HomeCopy.emptyStatePatternMessage(confidence),
                icon: "sparkles",
                accent: CaelynColor.primaryPlum
            )
        } else if let (symptom, _) = mostFrequentSymptom {
            InsightCard(
                title: "Pattern",
                message: "You often log \(symptom.displayName.lowercased()) around this time of your cycle.",
                icon: "sparkles",
                accent: CaelynColor.primaryPlum
            )
        }
    }
}
