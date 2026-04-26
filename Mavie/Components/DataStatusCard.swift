import SwiftUI
import SwiftData

struct DataStatusCard: View {
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Query private var profiles: [UserProfile]

    var body: some View {
        MavieCard(padding: MavieSpacing.md, background: MavieColor.sage.opacity(0.6), shadow: .subtle) {
            HStack(alignment: .top, spacing: MavieSpacing.md) {
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
            .fill(MavieColor.deepPlumText.opacity(0.1))
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
                .font(MavieFont.title3.weight(.semibold))
                .foregroundStyle(MavieColor.successSage)
            Text(label)
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
    }
}

#Preview {
    DataStatusCard()
        .padding()
        .background(MavieColor.backgroundCream)
        .modelContainer(Persistence.preview)
}
