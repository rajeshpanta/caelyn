import SwiftUI

struct MonthSummaryCard: View {
    let month: Date
    let entries: [CycleEntry]

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f.string(from: month)
    }

    private var entriesInMonth: [CycleEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    private var periodDays: [Date] {
        entriesInMonth
            .filter { $0.flow != nil && $0.flow != .none }
            .map(\.date)
            .sorted()
    }

    private var periodRangeLabel: String? {
        guard let first = periodDays.first, let last = periodDays.last else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        if first == last { return f.string(from: first) }
        return "\(f.string(from: first))–\(f.string(from: last))"
    }

    private var topSymptoms: [(Symptom, Int)] {
        var counts: [Symptom: Int] = [:]
        for entry in entriesInMonth {
            for s in entry.symptoms {
                counts[s, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }.prefix(3).map { ($0.key, $0.value) }
    }

    private var totalLogged: Int {
        entriesInMonth.filter { $0.hasContent }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "\(monthLabel) summary")

            if totalLogged == 0 {
                CaelynCard {
                    HStack(spacing: CaelynSpacing.sm) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
                        Text("Nothing logged this month yet.")
                            .font(CaelynFont.body)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    }
                }
            } else {
                CaelynCard {
                    VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                        if let range = periodRangeLabel {
                            summaryRow(icon: "drop.fill", iconColor: CaelynColor.alertRose, label: "Period", value: range)
                        }
                        summaryRow(
                            icon: "square.and.pencil",
                            iconColor: CaelynColor.primaryPlum,
                            label: "Days logged",
                            value: "\(totalLogged)"
                        )
                        if !topSymptoms.isEmpty {
                            summaryRow(
                                icon: "sparkles",
                                iconColor: CaelynColor.successSage,
                                label: "Most logged",
                                value: topSymptoms.map { $0.0.displayName.lowercased() }.joined(separator: ", ")
                            )
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: CaelynSpacing.sm) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: CaelynIconSize.sm, height: CaelynIconSize.sm)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    .tracking(0.4)
                Text(value)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
