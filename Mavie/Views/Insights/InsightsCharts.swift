import SwiftUI
import Charts

// MARK: - Cycle Length Trend

struct CycleLengthChart: View {
    let series: [CycleLengthPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            chartHeader(title: "Cycle length", subtitle: "Recent cycles")
            MavieCard(padding: MavieSpacing.md) {
                Chart(series) { point in
                    LineMark(
                        x: .value("Cycle", point.cycleStartDate),
                        y: .value("Length", point.length)
                    )
                    .foregroundStyle(MavieColor.primaryPlum)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Cycle", point.cycleStartDate),
                        y: .value("Length", point.length)
                    )
                    .foregroundStyle(MavieColor.primaryPlum)
                    .symbolSize(60)
                }
                .chartYScale(domain: yDomain)
                .chartYAxis { AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(MavieColor.deepPlumText.opacity(0.06))
                    AxisValueLabel().foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
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
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            chartHeader(title: "Period length", subtitle: "Recent cycles")
            MavieCard(padding: MavieSpacing.md) {
                Chart(series) { point in
                    BarMark(
                        x: .value("Cycle", point.cycleStartDate, unit: .month),
                        y: .value("Length", point.length),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [MavieColor.softRose, MavieColor.alertRose.opacity(0.85)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .chartYAxis { AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(MavieColor.deepPlumText.opacity(0.06))
                    AxisValueLabel().foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
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
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            chartHeader(title: "Symptoms", subtitle: "Most logged in your history")
            MavieCard(padding: MavieSpacing.md) {
                if counts.isEmpty {
                    emptyChartCopy("No symptoms logged yet.")
                } else {
                    Chart(counts) { row in
                        BarMark(
                            x: .value("Count", row.count),
                            y: .value("Symptom", row.symptom.displayName)
                        )
                        .foregroundStyle(MavieColor.primaryPlum.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .annotation(position: .trailing) {
                            Text("\(row.count)")
                                .font(MavieFont.caption.monospacedDigit())
                                .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis { AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.7))
                            .font(MavieFont.caption)
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
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            chartHeader(title: "Mood", subtitle: "How you've been feeling")
            MavieCard(padding: MavieSpacing.md) {
                if counts.isEmpty {
                    emptyChartCopy("No moods logged yet.")
                } else {
                    Chart(counts) { row in
                        BarMark(
                            x: .value("Count", row.count),
                            y: .value("Mood", row.mood.displayName)
                        )
                        .foregroundStyle(MavieColor.successSage.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .annotation(position: .trailing) {
                            Text("\(row.count)")
                                .font(MavieFont.caption.monospacedDigit())
                                .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis { AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.7))
                            .font(MavieFont.caption)
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
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            chartHeader(title: "Pain", subtitle: "Daily levels over time")
            MavieCard(padding: MavieSpacing.md) {
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
                                colors: [MavieColor.alertRose.opacity(0.5), MavieColor.alertRose.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Pain", point.pain)
                        )
                        .foregroundStyle(MavieColor.alertRose)
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .chartYScale(domain: 0...10)
                    .chartYAxis { AxisMarks(position: .leading, values: [0, 5, 10]) { _ in
                        AxisGridLine().foregroundStyle(MavieColor.deepPlumText.opacity(0.06))
                        AxisValueLabel().foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                    } }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
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
            .font(MavieFont.headline)
            .foregroundStyle(MavieColor.deepPlumText)
        Text(subtitle)
            .font(MavieFont.subheadline)
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
    }
}

private func emptyChartCopy(_ text: String) -> some View {
    HStack(spacing: 8) {
        Image(systemName: "sparkles")
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.4))
        Text(text)
            .font(MavieFont.body)
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
    }
    .frame(maxWidth: .infinity, minHeight: 80)
}
