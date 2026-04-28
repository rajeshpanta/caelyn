import SwiftUI

struct StatCard: View {
    let value: String
    let label: String
    var unit: String? = nil
    var accent: Color = CaelynColor.primaryPlum

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(CaelynFont.numberMedium)
                        .foregroundStyle(accent)
                    if let unit {
                        Text(unit)
                            .font(CaelynFont.subheadline.weight(.medium))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    }
                }
                Text(label)
                    .font(CaelynFont.footnote)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
            }
        }
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CaelynSpacing.sm) {
        StatCard(value: "29", label: "Avg cycle", unit: "days")
        StatCard(value: "5", label: "Avg period", unit: "days")
        StatCard(value: "±3", label: "Variation", unit: "days", accent: CaelynColor.alertRose)
        StatCard(value: "Cramps", label: "Most common symptom")
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
