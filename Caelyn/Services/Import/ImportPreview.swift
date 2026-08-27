import Foundation

/// Everything the confirmation screen needs, and nothing it would have to
/// translate.
///
/// The counts here are the counts that will actually be written — they come from
/// the same decision list `commit` replays, not from a second pass that could
/// disagree with it. A preview that promises 54 days and delivers 51 is worse than
/// no preview at all.
struct ImportPreview {

    let source: ImportSourceID
    let confidence: ImportDetection
    /// Sources that also claimed the file. Non-empty means Caelyn deliberately
    /// declined to choose between them and read the file generically instead.
    let ambiguousWith: [ImportSourceID]

    let summary: ImportReconciler.Summary
    let parsed: ParsedImport
    /// Carried through to `commit` so the preview and the write are the same plan.
    let decisions: [ImportReconciler.Decision]
    let batchID: UUID
    /// Set when an Apple Health read was narrowed to one app, so the screen can
    /// name that app rather than saying "Apple Health" for everything.
    var healthSourceLabel: String?
    /// That app's own name, for sentences that read better without "via Apple Health".
    var healthAppName: String?

    var hasChanges: Bool { summary.changeCount > 0 }

    /// Whether this is the Apple Health route rather than a file.
    var isAppleHealth: Bool { source == .appleHealth }

    /// Oldest and newest day this import would touch, if any.
    var dateRange: ClosedRange<Date>? {
        let days = decisions.compactMap { decision -> Date? in
            switch decision.action {
            case .fill, .update, .clear: return decision.day
            default: return nil
            }
        }
        guard let first = days.min(), let last = days.max() else { return nil }
        return first...last
    }

    /// "4 years of history", "8 months of history" — measured from the actual
    /// span of the data, never rounded up into a claim the file cannot support.
    /// Nil when the span is too short to describe honestly.
    func spanDescription(calendar: Calendar = .current) -> String? {
        guard let range = dateRange else { return nil }
        let days = calendar.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 0
        switch days {
        case ..<45:
            return nil
        case 45..<365:
            let months = max(2, Int((Double(days) / 30.44).rounded(.down)))
            return "\(months) months of history"
        default:
            let years = Int((Double(days) / 365.25).rounded(.down))
            return years <= 1 ? "a year of history" : "\(years) years of history"
        }
    }

    /// True when Caelyn recognised the app, rather than reading the file as a
    /// plain table.
    var recognisedTheApp: Bool { confidence == .certain && ambiguousWith.isEmpty }

    // MARK: - Copy

    /// "Found 3 years of history in your Clue export".
    var headline: String {
        guard hasChanges else {
            // "this file" is wrong for an Apple Health read — there is no file —
            // and it is the first line she sees when a route finds nothing, which
            // is exactly when the wording has to make sense.
            let subject = isAppleHealth ? (healthAppName ?? "Apple Health") : "this file"
            return summary.keptUserValue > 0
                ? "Everything in \(subject) is already in Caelyn"
                : "Nothing new to bring over"
        }
        return "Found \(summary.daysAffected) day\(summary.daysAffected == 1 ? "" : "s") of history"
    }

    /// Where Caelyn thinks it came from, in her words.
    var sourceLine: String {
        if isAppleHealth {
            if let app = healthAppName {
                return "From what \(app) has put into Apple Health on this iPhone."
            }
            return "From the cycle and fertility history already stored on your iPhone."
        }
        switch (recognisedTheApp, source) {
        case (true, .caelyn):  return "This is a Caelyn backup."
        case (true, let app):  return "This looks like a \(app.displayName) export."
        case (false, .genericJSON), (false, .genericCSV):
            return "Caelyn didn't recognise which app made this, so it read it as a plain table and brought across what it could match."
        default:
            return "Caelyn read this as a plain table."
        }
    }

    /// "54 period days", "214 symptoms", … — the lines under the headline.
    var breakdown: [String] { ImportCopy.breakdown(summary) }

    /// The reassurance that matters most, and the reason anyone trusts an import.
    var safetyLine: String {
        summary.keptUserValue > 0
            ? "Nothing you logged in Caelyn will change. \(summary.keptUserValue) value\(summary.keptUserValue == 1 ? "" : "s") in this file differ\(summary.keptUserValue == 1 ? "s" : "") from what you wrote — Caelyn is keeping yours."
            : "Nothing you already logged in Caelyn will change."
    }

    /// Build a preview from an Apple Health read, so both routes reach the same
    /// confirmation screen and the same undo. The Health path was already split
    /// into plan-then-apply, so nothing about it had to change to get here.
    static func fromHealth(_ plan: HealthSyncService.Plan,
                           sourceFilter: HealthSyncService.SourceFilter? = nil) -> ImportPreview {
        var parsed = ParsedImport()
        parsed.observations = plan.readResult.observations
        if !plan.unreadableTypes.isEmpty {
            parsed.assumptions.append(
                "Some of what you asked Caelyn to read wasn't available, so it brought across everything else."
            )
        }
        return ImportPreview(
            source: .appleHealth,
            confidence: .certain,
            ambiguousWith: [],
            summary: plan.summary,
            parsed: parsed,
            decisions: plan.decisions,
            batchID: UUID(),
            healthSourceLabel: sourceFilter?.label,
            healthAppName: sourceFilter?.appName
        )
    }

    /// Assumptions the format forced, plus anything Caelyn had to skip. Shown
    /// before she confirms, not after.
    var caveats: [String] {
        var lines = parsed.assumptions
        if summary.duplicates > 0 {
            lines.append("\(summary.duplicates) entr\(summary.duplicates == 1 ? "y is" : "ies are") already in Caelyn and will be skipped.")
        }
        if summary.rejected > 0 {
            lines.append("\(summary.rejected) entr\(summary.rejected == 1 ? "y" : "ies") couldn't be read and will be left out.")
        }
        if parsed.rowsSkipped > 0 {
            let reasons = parsed.skipReasons
                // Count first, then name, so equally-common reasons don't reorder
                // themselves between one reading of the same file and the next.
                .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
                .prefix(3)
                .map { "\($0.value) \($0.key)" }
            if !reasons.isEmpty {
                lines.append("Skipped: " + reasons.joined(separator: ", ") + ".")
            }
        }
        if !parsed.unmappedFields.isEmpty {
            let names = parsed.unmappedFields
                .sorted { $0.value > $1.value }
                .prefix(4)
                .map(\.key)
            lines.append("Caelyn doesn't have a place for " + ImportCopy.list(Array(names)) + ", so \(names.count == 1 ? "it was" : "they were") left out.")
        }
        if !ambiguousWith.isEmpty {
            lines.append("This file looked like it could be from more than one app, so Caelyn read it cautiously rather than guessing.")
        }
        return lines
    }
}
