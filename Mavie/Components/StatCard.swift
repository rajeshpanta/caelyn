import SwiftUI

struct StatCard: View {
    let value: String
    let label: String
    var unit: String? = nil
    var accent: Color = MavieColor.primaryPlum

    var body: some View {
        MavieCard(padding: MavieSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(MavieFont.numberMedium)
                        .foregroundStyle(accent)
                    if let unit {
                        Text(unit)
                            .font(MavieFont.subheadline.weight(.medium))
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                    }
                }
                Text(label)
                    .font(MavieFont.footnote)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
            }
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MavieSpacing.sm) {
        StatCard(value: "29", label: "Avg cycle", unit: "days")
        StatCard(value: "5", label: "Avg period", unit: "days")
        StatCard(value: "±3", label: "Variation", unit: "days", accent: MavieColor.alertRose)
        StatCard(value: "Cramps", label: "Most common symptom")
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
