import SwiftUI

struct CycleHistorySection: View {
    let cycles: [Cycle]
    let entries: [CycleEntry]

    private var sortedCycles: [Cycle] { cycles.reversed() }

    var body: some View {
        if cycles.isEmpty { return AnyView(EmptyView()) }
        return AnyView(content)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(
                title: "Cycle History",
                subtitle: "\(cycles.count) recorded cycle\(cycles.count == 1 ? "" : "s")"
            )

            VStack(spacing: 0) {
                ForEach(Array(sortedCycles.enumerated()), id: \.offset) { i, cycle in
                    CycleHistoryRow(
                        cycle: cycle,
                        entries: entries,
                        isLast: i == sortedCycles.count - 1
                    )
                }
            }
        }
    }
}

// MARK: - Single row

private struct CycleHistoryRow: View {
    let cycle: Cycle
    let entries: [CycleEntry]
    let isLast: Bool

    private let cal = Calendar.current

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f.string(from: cycle.start)
    }

    private var cycleEntries: [CycleEntry] {
        entries.filter { entry in
            let d = cal.startOfDay(for: entry.date)
            guard let end = cal.date(byAdding: .day, value: cycle.length, to: cycle.start) else { return false }
            return d >= cycle.start && d < end
        }
    }

    private var topSymptom: String? {
        var counts: [Symptom: Int] = [:]
        for e in cycleEntries {
            for s in e.symptoms { counts[s, default: 0] += 1 }
        }
        return counts.max(by: { $0.value < $1.value })?.key.displayName
    }

    private var avgPain: Double? {
        let pains = cycleEntries.compactMap(\.pain)
        guard !pains.isEmpty else { return nil }
        return Double(pains.reduce(0, +)) / Double(pains.count)
    }

    var body: some View {
        HStack(alignment: .top, spacing: CaelynSpacing.sm) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(CaelynColor.softRose)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(CaelynColor.deepPlumText.opacity(0.1))
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(monthLabel)
                    .font(CaelynFont.callout.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)

                HStack(spacing: CaelynSpacing.sm) {
                    cycleChip("\(cycle.length)d cycle", color: CaelynColor.primaryPlum)
                    cycleChip("\(cycle.periodLength)d period", color: CaelynColor.softRose)
                    if let sym = topSymptom {
                        cycleChip(sym, color: CaelynColor.warmSand)
                    }
                    if let pain = avgPain {
                        cycleChip("Pain \(String(format: "%.1f", pain))/10", color: CaelynColor.alertRose)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : CaelynSpacing.md)
        }
        .padding(.horizontal, 4)
    }

    private func cycleChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(CaelynFont.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
