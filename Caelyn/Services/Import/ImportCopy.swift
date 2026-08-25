import Foundation

/// Turns a merge summary into something worth reading, for Apple Health syncs and
/// file imports alike.
///
/// The rule for everything in here: no HealthKit vocabulary, no field names, no
/// counts of "records". She thinks in periods, symptoms and temperatures, so that
/// is what the numbers are labelled with — and the line that matters most is the
/// one saying what Caelyn *didn't* touch.
enum ImportCopy {

    /// Human labels for the merge engine's field groupings, singular and plural.
    private static let labels: [String: (one: String, many: String)] = [
        "flow":           ("period day", "period days"),
        "temperature":    ("temperature reading", "temperature readings"),
        "mucus":          ("cervical mucus note", "cervical mucus notes"),
        "ovulationTest":  ("ovulation test", "ovulation tests"),
        "pregnancyTest":  ("pregnancy test", "pregnancy tests"),
        "sexualActivity": ("intimacy log", "intimacy logs"),
        "symptom":        ("symptom", "symptoms"),
        "pain":           ("pain note", "pain notes")
    ]

    /// Stable display order, most-to-least central to a cycle tracker.
    private static let order = [
        "flow", "symptom", "pain", "temperature", "mucus",
        "ovulationTest", "pregnancyTest", "sexualActivity"
    ]

    /// "54 period days", "214 symptoms", … for the confirmation screen.
    static func breakdown(_ summary: ImportReconciler.Summary) -> [String] {
        order.compactMap { key in
            guard let count = summary.byField[key], count > 0, let label = labels[key] else { return nil }
            return "\(count) \(count == 1 ? label.one : label.many)"
        }
    }

    /// One-line result for the banner after an import runs.
    static func importResult(_ summary: ImportReconciler.Summary) -> String {
        guard !summary.isEmpty else {
            return summary.keptUserValue > 0
                ? "Everything Apple Health has is already in Caelyn — your own entries were left exactly as you wrote them."
                : "Nothing new to bring over."
        }

        var sentence = "Brought over \(days(summary.daysAffected)) of history"
        let parts = breakdown(summary)
        if !parts.isEmpty { sentence += " — " + list(parts) }
        sentence += "."

        if summary.keptUserValue > 0 {
            sentence += " Apple Health had different values in \(places(summary.keptUserValue)); Caelyn kept yours."
        }
        if summary.cleared > 0 {
            sentence += " \(places(summary.cleared).capitalizedFirst) were removed because another app deleted them."
        }
        return sentence
    }

    /// Shown before committing, so she decides with the numbers in front of her.
    static func previewHeadline(_ summary: ImportReconciler.Summary) -> String {
        summary.isEmpty
            ? "Nothing new to bring over"
            : "Found \(days(summary.daysAffected)) of history"
    }

    /// The one line worth spelling out on the confirmation screen: an import can
    /// only ever add to what she wrote.
    static func previewReassurance(_ summary: ImportReconciler.Summary) -> String {
        summary.keptUserValue > 0
            ? "Anything you logged yourself stays exactly as it is — including \(places(summary.keptUserValue)) where Apple Health says something different."
            : "Anything you logged yourself stays exactly as it is."
    }

    // MARK: - Small helpers

    private static func days(_ count: Int) -> String {
        "\(count) day\(count == 1 ? "" : "s")"
    }

    private static func places(_ count: Int) -> String {
        "\(count) place\(count == 1 ? "" : "s")"
    }

    static func list(_ parts: [String]) -> String {
        switch parts.count {
        case 0:  return ""
        case 1:  return parts[0]
        case 2:  return "\(parts[0]) and \(parts[1])"
        default: return parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}
