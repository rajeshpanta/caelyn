import Foundation

/// Small helper every source uses to emit observations, so record identity and
/// provenance are derived one way rather than five slightly different ways.
struct ObservationBuilder {

    let source: ImportSourceID
    let calendar: Calendar
    private(set) var observations: [ImportObservation] = []

    init(source: ImportSourceID, calendar: Calendar) {
        self.source = source
        self.calendar = calendar
    }

    /// Bundle identifier recorded for file imports.
    ///
    /// Prefixed so it can never equal Caelyn's own bundle ID — the reconciler
    /// drops observations carrying that during an incremental sync, and a file
    /// import must never be silently discarded by the loop breaker.
    var sourceBundleID: String { "import.\(source.rawValue)" }

    mutating func add(day: Date, field: ImportObservation.Field, value: ImportObservation.Value) {
        let normalizedDay = calendar.startOfDay(for: day)
        let dayKey = ImportLedger.dayKey(normalizedDay, calendar: calendar)
        observations.append(ImportObservation(
            day: normalizedDay,
            field: field,
            value: value,
            recordID: ImportRecordID.make(source: source, dayKey: dayKey, fieldKey: field.ledgerKey),
            sourceBundleID: sourceBundleID,
            sourceName: source.displayName,
            // A file carries no separate "recorded at" clock, so the day itself
            // is the honest stand-in. Ties then resolve by import order, and a
            // value she typed still beats both.
            recordedAt: normalizedDay
        ))
    }
}
