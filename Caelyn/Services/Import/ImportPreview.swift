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

    var hasChanges: Bool { summary.changeCount > 0 }

    /// True when Caelyn recognised the app, rather than reading the file as a
    /// plain table.
    var recognisedTheApp: Bool { confidence == .certain && ambiguousWith.isEmpty }

    // MARK: - Copy

    /// "Found 3 years of history in your Clue export".
    var headline: String {
        guard hasChanges else {
            return summary.keptUserValue > 0
                ? "Everything in this file is already in Caelyn"
                : "Nothing in this file to bring over"
        }
        return "Found \(summary.daysAffected) day\(summary.daysAffected == 1 ? "" : "s") of history"
    }

    /// Where Caelyn thinks it came from, in her words.
    var sourceLine: String {
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
                .sorted { $0.value > $1.value }
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
