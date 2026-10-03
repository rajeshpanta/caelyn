import Foundation

/// A calendar day as she means it — "the first of June" — rather than an instant
/// in time that happens to fall on it.
///
/// **Why this exists.** A `CycleEntry` stored the *instant* of local midnight at
/// the moment it was written, and every reader worked out which day that was by
/// truncating it again with whatever calendar was current at read time. Those are
/// not the same question. Midnight on 1 June in Tokyo is 15:00 UTC on 31 May; read
/// back in New York, that instant falls on 31 May, so a period she logged on the
/// first read as starting on the thirty-first the moment she landed — and her
/// cycle day, her prediction, her calendar colours and her widget all moved with
/// it. Editing that day then created a *second* row, because the lookup matched on
/// the exact stored instant and the instant was no longer the start of any day.
/// The launch dedupe could not repair it either: in New York those two rows really
/// were different days. It only healed when she flew home.
///
/// So the day is stored rather than inferred. `dayKey` is a plain `yyyyMMdd`
/// integer — 1 June 2026 is `20260601` — written once, in the calendar she was
/// living in when she logged it, and never recomputed. Travel cannot move it,
/// daylight saving cannot move it, and two entries are the same day exactly when
/// their keys match.
///
/// `localDate(for:)` turns a key back into local midnight, so everything
/// downstream — date arithmetic, `DateFormatter`, charts, exports — keeps working
/// in exactly the space it always has. The key is the identity; the date is still
/// the date.
enum CivilDay {

    /// The day `date` falls on, in `calendar`. Call this at the moment of writing,
    /// where the calendar is the one she is actually living in.
    static func key(for date: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// Local midnight on the day `key` names.
    ///
    /// `startOfDay` rather than `date(from:)` alone because a civil day's local
    /// midnight does not always exist: Brazil used to begin daylight saving at
    /// 00:00, so on those dates there is no such instant and the day starts at
    /// 01:00. Both answers are "the start of that day here", which is what every
    /// caller wants.
    static func localDate(for key: Int, calendar: Calendar = .current) -> Date {
        guard key > 0 else { return .distantPast }
        var c = DateComponents()
        c.year = key / 10_000
        c.month = (key / 100) % 100
        c.day = key % 100
        guard let d = calendar.date(from: c) else { return .distantPast }
        return calendar.startOfDay(for: d)
    }

    /// The key `days` after `key`.
    static func key(_ key: Int, offsetBy days: Int, calendar: Calendar = .current) -> Int {
        let base = localDate(for: key, calendar: calendar)
        guard let moved = calendar.date(byAdding: .day, value: days, to: base) else { return key }
        return Self.key(for: moved, calendar: calendar)
    }

    /// Whole days from `from` to `to`. Negative when `to` is earlier.
    static func days(from: Int, to: Int, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day],
                                from: localDate(for: from, calendar: calendar),
                                to: localDate(for: to, calendar: calendar)).day ?? 0
    }
}
