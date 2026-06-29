import SwiftUI

struct MonthSummaryCard: View {
    let month: Date
    let entries: [CycleEntry]

    private var monthLabel: String {
        month.formatted(.dateTime.month(.wide))   // cached, locale-aware (plat-9)
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
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()   // cached (plat-9)
        if first == last { return first.formatted(style) }
        return "\(first.formatted(style))–\(last.formatted(style))"
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

    private var isFutureMonth: Bool {
        let cal = Calendar.current
        return cal.compare(month, to: .now, toGranularity: .month) == .orderedDescending
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "\(monthLabel) summary")

            if isFutureMonth {
                CaelynCard {
                    HStack(spacing: CaelynSpacing.sm) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
                        Text("This month hasn't started yet.")
                            .font(CaelynFont.body)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    }
                }
            } else if totalLogged == 0 {
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
