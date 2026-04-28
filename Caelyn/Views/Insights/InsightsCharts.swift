import SwiftUI
import Charts

// MARK: - Cycle Length Trend

struct CycleLengthChart: View {
    let series: [CycleLengthPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Cycle length", subtitle: "Recent cycles")
            CaelynCard(padding: CaelynSpacing.md) {
                Chart(series) { point in
                    LineMark(
                        x: .value("Cycle", point.cycleStartDate),
                        y: .value("Length", point.length)
                    )
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Cycle", point.cycleStartDate),
                        y: .value("Length", point.length)
                    )
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .symbolSize(60)
                }
                .chartYScale(domain: yDomain)
                .chartYAxis { AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(CaelynColor.deepPlumText.opacity(0.06))
                    AxisValueLabel().foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                } }
                .frame(height: 160)
            }
        }
    }

    private var yDomain: ClosedRange<Int> {
        let values = series.map(\.length)
        guard let min = values.min(), let max = values.max() else { return 24...32 }
        return (min - 2)...(max + 2)
    }
}

// MARK: - Period Length Trend

struct PeriodLengthChart: View {
    let series: [PeriodLengthPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Period length", subtitle: "Recent cycles")
            CaelynCard(padding: CaelynSpacing.md) {
                Chart(series) { point in
                    BarMark(
                        x: .value("Cycle", point.cycleStartDate, unit: .month),
                        y: .value("Length", point.length),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CaelynColor.softRose, CaelynColor.alertRose.opacity(0.85)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .chartYAxis { AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(CaelynColor.deepPlumText.opacity(0.06))
                    AxisValueLabel().foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                } }
                .frame(height: 160)
            }
        }
    }
}

// MARK: - Symptom Frequency

struct SymptomFrequencyChart: View {
    let counts: [SymptomCount]

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Symptoms", subtitle: "Most logged in your history")
            CaelynCard(padding: CaelynSpacing.md) {
                if counts.isEmpty {
                    emptyChartCopy("No symptoms logged yet.")
                } else {
                    Chart(counts) { row in
                        BarMark(
                            x: .value("Count", row.count),
                            y: .value("Symptom", row.symptom.displayName)
                        )
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .annotation(position: .trailing) {
                            Text("\(row.count)")
                                .font(CaelynFont.caption.monospacedDigit())
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis { AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                            .font(CaelynFont.caption)
                    } }
                    .frame(height: CGFloat(counts.count) * 28 + 20)
                }
            }
        }
    }
}

// MARK: - Mood Pattern

struct MoodPatternChart: View {
    let counts: [MoodCount]

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Mood", subtitle: "How you've been feeling")
            CaelynCard(padding: CaelynSpacing.md) {
                if counts.isEmpty {
                    emptyChartCopy("No moods logged yet.")
                } else {
                    Chart(counts) { row in
                        BarMark(
                            x: .value("Count", row.count),
                            y: .value("Mood", row.mood.displayName)
                        )
                        .foregroundStyle(CaelynColor.successSage.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .annotation(position: .trailing) {
                            Text("\(row.count)")
                                .font(CaelynFont.caption.monospacedDigit())
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis { AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                            .font(CaelynFont.caption)
                    } }
                    .frame(height: CGFloat(counts.count) * 28 + 20)
                }
            }
        }
    }
}

// MARK: - Pain Trend

struct PainTrendChart: View {
    let series: [PainPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Pain", subtitle: "Daily levels over time")
            CaelynCard(padding: CaelynSpacing.md) {
                if series.isEmpty {
                    emptyChartCopy("No pain levels logged yet.")
                } else {
                    Chart(series) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Pain", point.pain)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CaelynColor.alertRose.opacity(0.5), CaelynColor.alertRose.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Pain", point.pain)
                        )
                        .foregroundStyle(CaelynColor.alertRose)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartYScale(domain: 0...10)
                    .chartYAxis { AxisMarks(position: .leading, values: [0, 5, 10]) { _ in
                        AxisGridLine().foregroundStyle(CaelynColor.deepPlumText.opacity(0.06))
                        AxisValueLabel().foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    } }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    } }
                    .frame(height: 160)
                }
            }
        }
    }
}

// MARK: - Helpers

private func chartHeader(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(CaelynFont.headline)
            .foregroundStyle(CaelynColor.deepPlumText)
        Text(subtitle)
            .font(CaelynFont.subheadline)
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
    }
}

private func emptyChartCopy(_ text: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: "sparkles")
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
        Text(text)
            .font(CaelynFont.body)
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
    }
    .frame(maxWidth: .infinity, minHeight: 80)
}
