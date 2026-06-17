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
                title: "Your pattern",
                message: "You often experience \(symptom.displayName.lowercased()) at this point in your cycle. That's your body's rhythm — not random.",
                icon: "sparkles",
                accent: CaelynColor.primaryPlum
            )
        }
    }
}
