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

    /// Generate a PDF report. Title page + summary stats + entry table + optional notes.
    static func generatePDF(entries: [CycleEntry], profile: UserProfile?, range: ExportRange, includeNotes: Bool) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)  // US Letter, 72 dpi
        let metadata: [String: Any] = [
            kCGPDFContextCreator as String: "Caelyn",
            kCGPDFContextTitle as String:   "Caelyn Cycle Report",
            kCGPDFContextAuthor as String:  "Caelyn: Period & Cycle Tracker"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = metadata
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        return renderer.pdfData { ctx in
            var page = PDFPageContext(rect: pageRect, margin: 56)
            ctx.beginPage()

            drawHeader(page: &page, range: range)
            drawSummary(page: &page, entries: entries, profile: profile)
            drawEntryTable(page: &page, entries: entries, ctx: ctx)
            if includeNotes {
                drawNotes(page: &page, entries: entries, ctx: ctx)
            }
        }
    }

    // MARK: - PDF helpers

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
        var contentBottom: CGFloat { rect.height - margin }
        mutating func advance(_ delta: CGFloat) { y += delta }
    }

    private static let titleFont: UIFont = .systemFont(ofSize: 28, weight: .semibold)
    private static let sectionFont: UIFont = .systemFont(ofSize: 14, weight: .semibold)
    private static let bodyFont: UIFont = .systemFont(ofSize: 11, weight: .regular)
    private static let smallFont: UIFont = .systemFont(ofSize: 10, weight: .regular)
    private static let plumColor = UIColor(red: 0x6F / 255, green: 0x3D / 255, blue: 0x74 / 255, alpha: 1)
    private static let bodyColor = UIColor(red: 0x2F / 255, green: 0x1B / 255, blue: 0x32 / 255, alpha: 1)
    private static let mutedColor = UIColor(red: 0x2F / 255, green: 0x1B / 255, blue: 0x32 / 255, alpha: 0.6)

    private static func drawHeader(page: inout PDFPageContext, range: ExportRange) {
        let title = "Caelyn · Cycle Report"
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: plumColor]
        title.draw(at: CGPoint(x: page.margin, y: page.y), withAttributes: titleAttrs)
        page.advance(36)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        let subtitle = "Range: \(range.displayName)  ·  Generated \(formatter.string(from: .now))"
        let subAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: mutedColor]
        subtitle.draw(at: CGPoint(x: page.margin, y: page.y), withAttributes: subAttrs)
        page.advance(32)
    }

    private static func drawSummary(page: inout PDFPageContext, entries: [CycleEntry], profile: UserProfile?) {
        let cycles = PredictionEngine.cycles(from: entries)
        let avgCycle = PredictionEngine.averageCycleLength(of: cycles, fallback: profile?.averageCycleLength ?? 28)
        let avgPeriod = PredictionEngine.averagePeriodLength(of: cycles, fallback: profile?.averagePeriodLength ?? 5)

        drawSectionTitle("Summary", at: &page)

        let lines = [
            "Entries logged: \(entries.filter { $0.hasContent }.count)",
            "Cycles detected: \(cycles.count)",
            "Average cycle length: \(avgCycle) days",
            "Average period length: \(avgPeriod) days"
        ]
        for line in lines {
            line.draw(
                at: CGPoint(x: page.margin, y: page.y),
                withAttributes: [.font: bodyFont, .foregroundColor: bodyColor]
            )
            page.advance(16)
        }
        page.advance(12)
    }

    private static func drawEntryTable(page: inout PDFPageContext, entries: [CycleEntry], ctx: UIGraphicsPDFRendererContext) {
        drawSectionTitle("Entries", at: &page)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let columns: [(title: String, width: CGFloat)] = [
            ("Date", 80), ("Flow", 60), ("Pain", 40), ("Symptoms", 180), ("Mood", 80)
        ]

        // header row
        drawTableRow(
            cells: columns.map(\.title),
            widths: columns.map(\.width),
            page: &page,
            font: sectionFont,
            color: plumColor
        )

        for entry in entries {
            // page break if we're close to the bottom
            if page.y > page.contentBottom - 40 {
                ctx.beginPage()
                page.y = page.margin
            }

            let cells = [
                formatter.string(from: entry.date),
                entry.flow?.displayName ?? "—",
                entry.pain.map { "\($0)/10" } ?? "—",
                entry.symptoms.map(\.displayName).joined(separator: ", "),
                entry.mood?.displayName ?? "—"
            ]
            drawTableRow(cells: cells, widths: columns.map(\.width), page: &page, font: smallFont, color: bodyColor)
        }
        page.advance(12)
    }

    private static func drawNotes(page: inout PDFPageContext, entries: [CycleEntry], ctx: UIGraphicsPDFRendererContext) {
        let withNotes = entries.compactMap { entry -> (Date, String)? in
            guard let note = entry.note, !note.isEmpty else { return nil }
            return (entry.date, note)
        }
        guard !withNotes.isEmpty else { return }

        if page.y > page.contentBottom - 60 {
            ctx.beginPage()
            page.y = page.margin
        }

        drawSectionTitle("Notes", at: &page)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        for (date, note) in withNotes {
            if page.y > page.contentBottom - 40 {
                ctx.beginPage()
                page.y = page.margin
            }
            let header = formatter.string(from: date)
            header.draw(at: CGPoint(x: page.margin, y: page.y), withAttributes: [.font: sectionFont, .foregroundColor: plumColor])
            page.advance(16)
            let textRect = CGRect(x: page.margin, y: page.y, width: page.contentWidth, height: page.contentBottom - page.y)
            let attributed = NSAttributedString(
                string: note,
                attributes: [.font: bodyFont, .foregroundColor: bodyColor]
            )
            attributed.draw(in: textRect)
            page.advance(36)
        }
    }

    private static func drawSectionTitle(_ title: String, at page: inout PDFPageContext) {
        title.draw(
            at: CGPoint(x: page.margin, y: page.y),
            withAttributes: [.font: sectionFont, .foregroundColor: plumColor]
        )
        page.advance(22)
    }

    private static func drawTableRow(cells: [String], widths: [CGFloat], page: inout PDFPageContext, font: UIFont, color: UIColor) {
        var x = page.margin
        for (cell, width) in zip(cells, widths) {
            let attributed = NSAttributedString(
                string: cell,
                attributes: [.font: font, .foregroundColor: color]
            )
            let rect = CGRect(x: x, y: page.y, width: width - 6, height: 14)
            attributed.draw(in: rect)
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
