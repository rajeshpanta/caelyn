import SwiftUI
import Charts

// MARK: - Cycle Length Trend

struct CycleLengthChart: View {
    let series: [CycleLengthPoint]

    private var a11yLabel: String {
        guard !series.isEmpty else { return "Cycle length chart. No data yet." }
        let avg = series.map(\.length).reduce(0, +) / series.count
        return "Cycle length chart. \(series.count) cycle\(series.count == 1 ? "" : "s") shown. Average \(avg) days."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Cycle length", subtitle: "Recent cycles")
            CaelynCard(padding: CaelynSpacing.md) {
                if series.isEmpty {
                    emptyChartCopy("No cycle data yet.")
                } else {
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
                    .accessibilityLabel(a11yLabel)
                }
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

    private var a11yLabel: String {
        guard !series.isEmpty else { return "Period length chart. No data yet." }
        let avg = series.map(\.length).reduce(0, +) / series.count
        return "Period length chart. \(series.count) cycle\(series.count == 1 ? "" : "s") shown. Average \(avg) days."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Period length", subtitle: "Recent cycles")
            CaelynCard(padding: CaelynSpacing.md) {
                if series.isEmpty {
                    emptyChartCopy("No period data yet.")
                } else {
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
                    .accessibilityLabel(a11yLabel)
                }
            }
        }
    }
}

// MARK: - Symptom Frequency

struct SymptomFrequencyChart: View {
    let counts: [SymptomCount]

    private var a11yLabel: String {
        guard !counts.isEmpty else { return "Symptom frequency chart. No symptoms logged yet." }
        let top = counts.prefix(3).map { "\($0.symptom.displayName) \($0.count) times" }.joined(separator: ", ")
        return "Symptom frequency chart. Most logged: \(top)."
    }

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
                    .accessibilityLabel(a11yLabel)
                }
            }
        }
    }
}

// MARK: - Mood Pattern

struct MoodPatternChart: View {
    let counts: [MoodCount]

    private var a11yLabel: String {
        guard !counts.isEmpty else { return "Mood pattern chart. No moods logged yet." }
        let top = counts.prefix(3).map { "\($0.mood.displayName) \($0.count) times" }.joined(separator: ", ")
        return "Mood pattern chart. Most logged: \(top)."
    }

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
                    .accessibilityLabel(a11yLabel)
                }
            }
        }
    }
}

// MARK: - Pain Trend

struct PainTrendChart: View {
    let series: [PainPoint]

    private var a11yLabel: String {
        guard !series.isEmpty else { return "Pain trend chart. No pain data logged yet." }
        let avg = series.map(\.pain).reduce(0, +) / series.count
        return "Pain trend chart. \(series.count) day\(series.count == 1 ? "" : "s") of data. Average pain level \(avg) out of 10."
    }

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
                    .accessibilityLabel(a11yLabel)
                }
            }
        }
    }
}

// MARK: - BBT Chart

struct BBTChart: View {
    let series: [BBTPoint]

    private var a11yLabel: String {
        guard !series.isEmpty else { return "Basal body temperature chart. No BBT readings yet." }
        let recent = series.last.map { String(format: "Most recent reading: %.1f°C.", $0.temperature) } ?? ""
        return "Basal body temperature chart. \(series.count) reading\(series.count == 1 ? "" : "s") shown. \(recent)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            chartHeader(title: "Basal Body Temperature", subtitle: "°C over time — rise signals ovulation")
            CaelynCard(padding: CaelynSpacing.md) {
                if series.isEmpty {
                    emptyChartCopy("No BBT readings logged yet.")
                } else {
                    Chart {
                        RuleMark(y: .value("Threshold", 36.4))
                            .foregroundStyle(CaelynColor.successSage.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .trailing, alignment: .leading) {
                                Text("36.4°")
                                    .font(CaelynFont.caption)
                                    .foregroundStyle(CaelynColor.successSage)
                            }
                        ForEach(series) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Temp", point.temperature)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [CaelynColor.primaryPlum.opacity(0.18), CaelynColor.primaryPlum.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.monotone)
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Temp", point.temperature)
                            )
                            .foregroundStyle(CaelynColor.primaryPlum)
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Temp", point.temperature)
                            )
                            .foregroundStyle(CaelynColor.primaryPlum)
                            .symbolSize(55)
                        }
                    }
                    .chartYAxis { AxisMarks(position: .leading) { value in
                        AxisGridLine().foregroundStyle(CaelynColor.deepPlumText.opacity(0.06))
                        if let temp = value.as(Double.self) {
                            AxisValueLabel(String(format: "%.1f", temp))
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                        }
                    } }
                    .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    } }
                    .frame(height: 180)
                    .accessibilityLabel(a11yLabel)
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
