import SwiftUI
import SwiftData

struct DataStatusCard: View {
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Query private var profiles: [UserProfile]

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.sage.opacity(0.6), shadow: .subtle) {
            HStack(alignment: .top, spacing: CaelynSpacing.md) {
                statBlock(value: "\(entries.count)", label: "entries")
                divider
                statBlock(value: profiles.first != nil ? "✓" : "—", label: "profile")
                divider
                statBlock(value: latestDateString, label: "last log")
                Spacer(minLength: 0)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(CaelynColor.deepPlumText.opacity(0.1))
            .frame(width: 1, height: 28)
    }

    private var latestDateString: String {
        guard let latest = entries.first else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: latest.date)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(CaelynFont.title3.weight(.semibold))
                .foregroundStyle(CaelynColor.successSage)
            Text(label)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
    }
}

#Preview {
    DataStatusCard()
        .padding()
        .background(CaelynColor.backgroundCream)
        .modelContainer(Persistence.preview)
}
