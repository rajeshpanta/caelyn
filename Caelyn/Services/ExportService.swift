import Foundation
import UIKit
import PDFKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv, pdf
    var id: String { rawValue }
    var displayName: String { self == .csv ? "CSV" : "PDF" }
    var fileExtension: String { rawValue }
    var systemIcon: String { self == .csv ? "tablecells" : "doc.richtext" }
}

enum ExportRange: String, CaseIterable, Identifiable {
    case last3Months
    case last6Months
    case last12Months
    case all

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .last3Months:  return "Last 3 months"
        case .last6Months:  return "Last 6 months"
        case .last12Months: return "Last 12 months"
        case .all:          return "All time"
        }
    }

    var lookbackDays: Int? {
        switch self {
        case .last3Months:  return 90
        case .last6Months:  return 180
        case .last12Months: return 365
        case .all:          return nil
        }
    }
}

enum ExportService {

    // MARK: - Filter

    static func filterEntries(_ entries: [CycleEntry], range: ExportRange, today: Date = .now) -> [CycleEntry] {
        guard let lookback = range.lookbackDays else { return entries.sorted { $0.date < $1.date } }
        let cutoff = Calendar.current.date(byAdding: .day, value: -lookback, to: today) ?? today
        return entries
            .filter { $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    // MARK: - CSV

    /// Generate a CSV string. Uses RFC 4180-style quoting for fields containing commas, quotes, or newlines.
    static func generateCSV(entries: [CycleEntry], includeNotes: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var headers = ["date", "flow", "pain", "pain_types", "symptoms", "mood", "medication", "basal_temperature", "cervical_mucus"]
        if includeNotes { headers.append("note") }
        var lines: [String] = [headers.joined(separator: ",")]

        for entry in entries {
            var fields: [String] = []
            fields.append(formatter.string(from: entry.date))
            fields.append(entry.flow?.rawValue ?? "")
            fields.append(entry.pain.map(String.init) ?? "")
            fields.append(entry.painTypes.map(\.rawValue).joined(separator: ";"))
            fields.append(entry.symptoms.map(\.rawValue).joined(separator: ";"))
            fields.append(entry.mood?.rawValue ?? "")
            fields.append(escape(entry.medication ?? ""))
            fields.append(entry.basalTemperature.map { String(format: "%.2f", $0) } ?? "")
            fields.append(entry.cervicalMucus?.rawValue ?? "")
            if includeNotes {
                fields.append(escape(entry.note ?? ""))
            }
            lines.append(fields.joined(separator: ","))
        }

        return lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    // MARK: - PDF

    /// Generate a clinical PDF report with color sections, cycle timeline, symptom chart, and entry table.
    static func generatePDF(entries: [CycleEntry], profile: UserProfile?, range: ExportRange, includeNotes: Bool) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "Caelyn",
            kCGPDFContextTitle as String:   "Caelyn Cycle Report",
            kCGPDFContextAuthor as String:  "Caelyn: Period & Cycle Tracker"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        let cycles = PredictionEngine.cycles(from: entries)

        return renderer.pdfData { ctx in
            var page = PDFPageContext(rect: pageRect, margin: 56)
            ctx.beginPage()

            drawReportHeader(page: &page, range: range, ctx: ctx.cgContext)
            drawClinicalSummary(page: &page, entries: entries, cycles: cycles, profile: profile, ctx: ctx.cgContext)
            drawCycleTimeline(page: &page, cycles: cycles, ctx: ctx.cgContext)
            drawSymptomBarChart(page: &page, entries: entries, ctx: ctx.cgContext)
            drawEntryTable(page: &page, entries: entries, ctx: ctx)
            if includeNotes { drawNotes(page: &page, entries: entries, ctx: ctx) }
            drawFooter(page: &page, ctx: ctx.cgContext)
        }
    }

    // MARK: - PDF page context

    private struct PDFPageContext {
        let rect: CGRect
        let margin: CGFloat
        var y: CGFloat

        init(rect: CGRect, margin: CGFloat) {
            self.rect = rect
            self.margin = margin
            self.y = margin
        }

        var contentWidth: CGFloat { rect.width - margin * 2 }
        var contentBottom: CGFloat { rect.height - margin - 20 }
        mutating func advance(_ delta: CGFloat) { y += delta }
    }

    // MARK: - Colors & fonts

    private static let titleFont    = UIFont.systemFont(ofSize: 22, weight: .bold)
    private static let sectionFont  = UIFont.systemFont(ofSize: 13, weight: .semibold)
    private static let bodyFont     = UIFont.systemFont(ofSize: 11, weight: .regular)
    private static let smallFont    = UIFont.systemFont(ofSize: 9.5, weight: .regular)
    private static let captionFont  = UIFont.systemFont(ofSize: 9, weight: .medium)
    private static let plumColor    = UIColor(red: 0x6F/255, green: 0x3D/255, blue: 0x74/255, alpha: 1)
    private static let roseColor    = UIColor(red: 0xE8/255, green: 0x8E/255, blue: 0xA0/255, alpha: 1)
    private static let roseLight    = UIColor(red: 0xE8/255, green: 0x8E/255, blue: 0xA0/255, alpha: 0.2)
    private static let bodyColor    = UIColor(red: 0x2F/255, green: 0x1B/255, blue: 0x32/255, alpha: 1)
    private static let mutedColor   = UIColor(red: 0x2F/255, green: 0x1B/255, blue: 0x32/255, alpha: 0.55)
    private static let dividerColor = UIColor(red: 0x2F/255, green: 0x1B/255, blue: 0x32/255, alpha: 0.12)
    private static let sageColor    = UIColor(red: 0x78/255, green: 0xA1/255, blue: 0x84/255, alpha: 1)

    // MARK: - Header

    private static func drawReportHeader(page: inout PDFPageContext, range: ExportRange, ctx: CGContext) {
        // Plum banner block
        let bannerRect = CGRect(x: 0, y: 0, width: page.rect.width, height: 80)
        ctx.setFillColor(plumColor.cgColor)
        ctx.fill(bannerRect)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.white
        ]
        "Caelyn · Cycle Report".draw(at: CGPoint(x: page.margin, y: 20), withAttributes: titleAttrs)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        let subLine = "Range: \(range.displayName)  ·  Generated \(formatter.string(from: .now))"
        let subAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor.white.withAlphaComponent(0.8)]
        subLine.draw(at: CGPoint(x: page.margin, y: 50), withAttributes: subAttrs)

        page.y = 96
        page.advance(12)

        // Disclaimer
        let disclaimer = "This report is generated from self-reported data and is intended to assist your healthcare provider. It is not a medical diagnosis."
        let paraStyle = NSMutableParagraphStyle()
        paraStyle.lineSpacing = 2
        let dAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: mutedColor, .paragraphStyle: paraStyle]
        let dRect = CGRect(x: page.margin, y: page.y, width: page.contentWidth, height: 24)
        disclaimer.draw(in: dRect, withAttributes: dAttrs)
        page.advance(30)

        drawDivider(page: &page, ctx: ctx)
    }

    // MARK: - Clinical Summary

    private static func drawClinicalSummary(page: inout PDFPageContext, entries: [CycleEntry], cycles: [Cycle], profile: UserProfile?, ctx: CGContext) {
        guard !cycles.isEmpty else { return }
        let avgCycle  = PredictionEngine.averageCycleLength(of: cycles, fallback: profile?.averageCycleLength ?? 28)
        let avgPeriod = PredictionEngine.averagePeriodLength(of: cycles, fallback: profile?.averagePeriodLength ?? 5)
        let variation = PredictionEngine.cycleLengthVariation(of: cycles)
        let irregular = PredictionEngine.irregularCycleStatus(from: cycles)
        let regularityText: String
        switch irregular {
        case .regular:       regularityText = "Regular (within normal range)"
        case .insufficient:  regularityText = "Insufficient data for assessment"
        case .irregular(let r): regularityText = "Irregular — \(r.rawValue)"
        }

        drawSectionHeader("Clinical Summary", page: &page, ctx: ctx)

        let rows: [(label: String, value: String, note: String?)] = [
            ("Average cycle length", "\(avgCycle) days", "Normal: 21–35 days"),
            ("Average period duration", "\(avgPeriod) days", "Normal: 3–7 days"),
            ("Cycle length variation", "±\(variation) days", variation > 7 ? "Consider evaluation if persistent" : nil),
            ("Cycle regularity", regularityText, nil),
            ("Completed cycles in range", "\(cycles.count)", nil),
            ("Days with data logged", "\(entries.filter { $0.hasContent }.count)", nil),
            ("Most common symptom", PredictionEngine.mostFrequentSymptom(in: entries).map { "\($0.0.displayName) (\($0.1)×)" } ?? "None logged", nil)
        ]

        for row in rows {
            if page.y > page.contentBottom - 24 { breakPage(page: &page, ctx: ctx) }
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: mutedColor]
            let valueAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: bodyColor]
            let noteAttrs:  [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: sageColor]

            row.label.draw(at: CGPoint(x: page.margin, y: page.y), withAttributes: labelAttrs)
            let valX = page.margin + 180
            row.value.draw(at: CGPoint(x: valX, y: page.y), withAttributes: valueAttrs)
            if let note = row.note {
                note.draw(at: CGPoint(x: valX + 150, y: page.y + 1), withAttributes: noteAttrs)
            }
            page.advance(17)
        }
        page.advance(8)
        drawDivider(page: &page, ctx: ctx)
    }

    // MARK: - Cycle Timeline

    private static func drawCycleTimeline(page: inout PDFPageContext, cycles: [Cycle], ctx: CGContext) {
        guard cycles.count >= 1 else { return }
        if page.y > page.contentBottom - 80 { breakPage(page: &page, ctx: ctx) }

        drawSectionHeader("Cycle Timeline", page: &page, ctx: ctx)

        let barH: CGFloat = 12
        let spacing: CGFloat = 6
        let maxWidth: CGFloat = page.contentWidth
        let maxLen = max(cycles.map(\.length).max() ?? 28, 1)
        let scale = maxWidth / CGFloat(maxLen)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        for cycle in cycles.suffix(8) {
            if page.y > page.contentBottom - 20 { breakPage(page: &page, ctx: ctx) }

            let totalW = CGFloat(cycle.length) * scale
            let periodW = min(CGFloat(cycle.periodLength) * scale, totalW)

            // Cycle background (full length)
            let cycleRect = CGRect(x: page.margin, y: page.y, width: totalW, height: barH)
            ctx.setFillColor(roseLight.cgColor)
            ctx.fill(cycleRect)

            // Period portion (highlighted)
            let periodRect = CGRect(x: page.margin, y: page.y, width: periodW, height: barH)
            ctx.setFillColor(roseColor.cgColor)
            ctx.fill(periodRect)

            // Date label
            let label = formatter.string(from: cycle.start) + "  (\(cycle.length)d cycle, \(cycle.periodLength)d period)"
            let labelAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: mutedColor]
            label.draw(at: CGPoint(x: page.margin, y: page.y + barH + 2), withAttributes: labelAttrs)
            page.advance(barH + 16 + spacing)
        }

        if cycles.count > 8 {
            let note = "Showing most recent 8 of \(cycles.count) cycles."
            note.draw(at: CGPoint(x: page.margin, y: page.y), withAttributes: [.font: captionFont, .foregroundColor: mutedColor])
            page.advance(14)
        }

        page.advance(4)
        drawDivider(page: &page, ctx: ctx)
    }

    // MARK: - Symptom Bar Chart

    private static func drawSymptomBarChart(page: inout PDFPageContext, entries: [CycleEntry], ctx: CGContext) {
        let counts = CycleAnalytics.symptomFrequency(in: entries, limit: 6)
        guard !counts.isEmpty else { return }
        if page.y > page.contentBottom - 80 { breakPage(page: &page, ctx: ctx) }

        drawSectionHeader("Top Symptoms (by frequency)", page: &page, ctx: ctx)

        let barH: CGFloat = 13
        let spacing: CGFloat = 7
        let maxWidth: CGFloat = page.contentWidth * 0.55
        let maxCount = max(counts.map(\.count).max() ?? 1, 1)
        let labelW: CGFloat = 110

        for item in counts {
            if page.y > page.contentBottom - 20 { breakPage(page: &page, ctx: ctx) }
            let barW = CGFloat(item.count) / CGFloat(maxCount) * maxWidth

            // Label
            let lAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: bodyColor]
            item.symptom.displayName.draw(at: CGPoint(x: page.margin, y: page.y + 2), withAttributes: lAttrs)

            // Bar
            let barX = page.margin + labelW
            ctx.setFillColor(plumColor.withAlphaComponent(0.18).cgColor)
            ctx.fill(CGRect(x: barX, y: page.y, width: maxWidth, height: barH))
            ctx.setFillColor(plumColor.cgColor)
            ctx.fill(CGRect(x: barX, y: page.y, width: barW, height: barH))

            // Count label
            let cAttrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: UIColor.white]
            "\(item.count)×".draw(at: CGPoint(x: barX + 4, y: page.y + 2), withAttributes: cAttrs)

            page.advance(barH + spacing)
        }
        page.advance(8)
        drawDivider(page: &page, ctx: ctx)
    }

    // MARK: - Entry table

    private static func drawEntryTable(page: inout PDFPageContext, entries: [CycleEntry], ctx: UIGraphicsPDFRendererContext) {
        if page.y > page.contentBottom - 60 { breakPage(page: &page, ctx: ctx.cgContext) }
        drawSectionHeader("Detailed Entries", page: &page, ctx: ctx.cgContext)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let columns: [(title: String, width: CGFloat)] = [
            ("Date", 90), ("Flow", 52), ("Pain", 38), ("Symptoms", 180), ("Mood", 82), ("Energy", 70)
        ]

        drawTableRow(cells: columns.map(\.title), widths: columns.map(\.width),
                     page: &page, font: sectionFont, color: plumColor)
        drawDivider(page: &page, ctx: ctx.cgContext, thin: true)

        for (i, entry) in entries.enumerated() {
            if page.y > page.contentBottom - 20 {
                ctx.beginPage()
                page.y = page.margin
                drawTableRow(cells: columns.map(\.title), widths: columns.map(\.width),
                             page: &page, font: sectionFont, color: plumColor)
                drawDivider(page: &page, ctx: ctx.cgContext, thin: true)
            }

            let bg = i.isMultiple(of: 2) ? UIColor(white: 0.975, alpha: 1) : UIColor.white
            ctx.cgContext.setFillColor(bg.cgColor)
            ctx.cgContext.fill(CGRect(x: page.margin - 4, y: page.y - 2, width: page.contentWidth + 8, height: 16))

            let allSymptoms = entry.symptoms.map(\.displayName)
                + (entry.loggedCustomSymptoms.isEmpty ? [] : entry.loggedCustomSymptoms)
            let cells = [
                formatter.string(from: entry.date),
                entry.flow?.displayName ?? "—",
                entry.pain.map { "\($0)/10" } ?? "—",
                allSymptoms.isEmpty ? "—" : allSymptoms.joined(separator: ", "),
                entry.mood?.displayName ?? "—",
                entry.energyLevel?.displayName ?? "—"
            ]
            drawTableRow(cells: cells, widths: columns.map(\.width), page: &page, font: smallFont, color: bodyColor)
        }
        page.advance(12)
    }

    // MARK: - Notes

    private static func drawNotes(page: inout PDFPageContext, entries: [CycleEntry], ctx: UIGraphicsPDFRendererContext) {
        let withNotes = entries.compactMap { e -> (Date, String)? in
            guard let note = e.note, !note.isEmpty else { return nil }
            return (e.date, note)
        }
        guard !withNotes.isEmpty else { return }

        if page.y > page.contentBottom - 60 { breakPage(page: &page, ctx: ctx.cgContext) }
        drawSectionHeader("Notes", page: &page, ctx: ctx.cgContext)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        for (date, note) in withNotes {
            if page.y > page.contentBottom - 40 { ctx.beginPage(); page.y = page.margin }
            let hdr = formatter.string(from: date)
            hdr.draw(at: CGPoint(x: page.margin, y: page.y), withAttributes: [.font: sectionFont, .foregroundColor: plumColor])
            page.advance(16)
            let textRect = CGRect(x: page.margin, y: page.y, width: page.contentWidth, height: page.contentBottom - page.y)
            NSAttributedString(string: note, attributes: [.font: bodyFont, .foregroundColor: bodyColor]).draw(in: textRect)
            page.advance(36)
        }
    }

    // MARK: - Footer

    private static func drawFooter(page: inout PDFPageContext, ctx: CGContext) {
        let footerY = page.rect.height - 28
        let footerText = "Generated by Caelyn · All data is self-reported and stored privately on your device."
        let attrs: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: mutedColor]
        footerText.draw(at: CGPoint(x: page.margin, y: footerY), withAttributes: attrs)
    }

    // MARK: - Drawing helpers

    private static func drawSectionHeader(_ title: String, page: inout PDFPageContext, ctx: CGContext) {
        let bgRect = CGRect(x: page.margin - 4, y: page.y, width: page.contentWidth + 8, height: 20)
        ctx.setFillColor(plumColor.withAlphaComponent(0.08).cgColor)
        ctx.fill(bgRect)

        title.draw(
            at: CGPoint(x: page.margin, y: page.y + 3),
            withAttributes: [.font: sectionFont, .foregroundColor: plumColor]
        )
        page.advance(26)
    }

    private static func drawDivider(page: inout PDFPageContext, ctx: CGContext, thin: Bool = false) {
        ctx.setStrokeColor(dividerColor.cgColor)
        ctx.setLineWidth(thin ? 0.5 : 1)
        ctx.move(to: CGPoint(x: page.margin, y: page.y))
        ctx.addLine(to: CGPoint(x: page.rect.width - page.margin, y: page.y))
        ctx.strokePath()
        page.advance(thin ? 4 : 10)
    }

    private static func breakPage(page: inout PDFPageContext, ctx: CGContext) {
        page.y = page.margin
    }

    private static func drawTableRow(cells: [String], widths: [CGFloat], page: inout PDFPageContext, font: UIFont, color: UIColor) {
        var x = page.margin
        for (cell, width) in zip(cells, widths) {
            let rect = CGRect(x: x, y: page.y, width: width - 6, height: 14)
            cell.draw(in: rect, withAttributes: [.font: font, .foregroundColor: color])
            x += width
        }
        page.advance(16)
    }

    // MARK: - Files

    /// Write export data to a temp file. Returns the URL — caller hands it to `ShareLink`.
    static func writeToTempFile(data: Data, format: ExportFormat, range: ExportRange) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let basename = "Caelyn-\(rangeFilenameFragment(range))-\(formatter.string(from: .now))"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(basename)
            .appendingPathExtension(format.fileExtension)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private static func rangeFilenameFragment(_ range: ExportRange) -> String {
        switch range {
        case .last3Months:  return "3mo"
        case .last6Months:  return "6mo"
        case .last12Months: return "12mo"
        case .all:          return "all"
        }
    }
}
