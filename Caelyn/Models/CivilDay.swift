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
/// integer — 1 June 2026 is `20260601` — written once and never recomputed.
/// Travel cannot move it, daylight saving cannot move it, and two entries are the
/// same day exactly when their keys match.
///
/// `localDate(for:)` turns a key back into local midnight, so everything
/// downstream — date arithmetic, `DateFormatter`, charts, exports — keeps working
/// in exactly the space it always has. The key is the identity; the date is still
/// the date.
///
/// **The key is always Gregorian.** A `Calendar` is two things at once: a time
/// zone and a calendar *system*. The time zone is what the key is meant to
/// capture — it is why she logged "the first" and not "the thirty-first". The
/// system is not: on an iPhone set to the Thai Buddhist calendar, which is an
/// ordinary Settings → General → Language & Region choice, 2026 is the year 2569
/// and `dateComponents` says so, so the same day would be filed as `25690601`.
/// That number round-trips on her own phone, because the same wrong calendar
/// decodes it, and is meaningless everywhere else: on her iPad, in an export, in
/// a `#Predicate` against rows written before she changed the setting. So every
/// function here reads the caller's time zone and ignores the caller's calendar
/// system. `date` keeps the instant; display stays the caller's business, and her
/// Buddhist dates still render as Buddhist dates.
enum CivilDay {

    /// The caller's time zone, under the one calendar system a stored key can mean
    /// the same thing in on every device.
    ///
    /// Not a `static let` with the zone assigned per call: `Calendar` is a value
    /// type, but building one is cheap next to the `dateComponents` work that
    /// follows, and a shared mutable instance would be a data race.
    static func gregorian(_ calendar: Calendar) -> Calendar {
        if calendar.identifier == .gregorian { return calendar }
        var g = Calendar(identifier: .gregorian)
        g.timeZone = calendar.timeZone
        g.locale = calendar.locale
        return g
    }

    /// The day `date` falls on, in `calendar`'s time zone. Call this at the moment
    /// of writing, where the zone is the one she is actually living in.
    static func key(for date: Date, calendar: Calendar = .current) -> Int {
        let c = gregorian(calendar).dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// Whether `key` names a day that could exist. Guards against two things: a 0
    /// from a row written before `dayKey` existed, and a key minted by the first
    /// version of this type, which took the device's calendar system and so wrote
    /// year 2569 on a Thai phone or year 8 on a Japanese one.
    static func isPlausible(_ key: Int) -> Bool {
        let year = key / 10_000, month = (key / 100) % 100, day = key % 100
        return (1900...2200).contains(year) && (1...12).contains(month) && (1...31).contains(day)
    }

    /// Local midnight on the day `key` names.
    ///
    /// `startOfDay` rather than `date(from:)` alone because a civil day's local
    /// midnight does not always exist: Brazil used to begin daylight saving at
    /// 00:00, so on those dates there is no such instant and the day starts at
    /// 01:00. Both answers are "the start of that day here", which is what every
    /// caller wants.
    ///
    /// Returns `nil` for a key that names no day, so a caller has to decide what
    /// to do about it. The first version returned `.distantPast`, which is a real
    /// `Date` that passes every reader's filters: a single unkeyed row anchored
    /// the prediction to the year 1, and the cycle-day arithmetic then reported
    /// numbers in the hundreds of thousands.
    static func localDate(for key: Int, calendar: Calendar = .current) -> Date? {
        guard isPlausible(key) else { return nil }
        let cal = gregorian(calendar)
        var c = DateComponents()
        c.year = key / 10_000
        c.month = (key / 100) % 100
        c.day = key % 100
        guard let d = cal.date(from: c) else { return nil }
        // February 30th parses by rolling over into March; it is not a day.
        let readBack = cal.dateComponents([.year, .month, .day], from: d)
        guard readBack.year == c.year, readBack.month == c.month, readBack.day == c.day else { return nil }
        return cal.startOfDay(for: d)
    }

    /// The key `days` after `key`.
    static func key(_ key: Int, offsetBy days: Int, calendar: Calendar = .current) -> Int {
        let cal = gregorian(calendar)
        guard let base = localDate(for: key, calendar: cal),
              let moved = cal.date(byAdding: .day, value: days, to: base) else { return key }
        return Self.key(for: moved, calendar: cal)
    }

    /// Whole days from `from` to `to`. Negative when `to` is earlier, and 0 when
    /// either key names no day.
    static func days(from: Int, to: Int, calendar: Calendar = .current) -> Int {
        let cal = gregorian(calendar)
        guard let a = localDate(for: from, calendar: cal),
              let b = localDate(for: to, calendar: cal) else { return 0 }
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    // MARK: - Recovering a key from a row that never had one

    /// The day an instant *was stored as*, recovered from the instant alone.
    ///
    /// Every write path before `dayKey` existed stored `startOfDay` in the zone
    /// that wrote it, so the instant itself still says which day she meant: there
    /// is normally exactly one UTC offset at which it reads as 00:00, and that
    /// offset is the one she was living in. Reading it back that way is what makes
    /// the upgrade stable — asking `Calendar.current` instead would key her whole
    /// history to wherever she happened to be standing the morning she installed
    /// the update, and that guess is unrecoverable afterwards.
    ///
    /// Falls back to `calendar`'s own zone when the instant is midnight nowhere,
    /// which is what a row from a sideways import or a hand-edited store looks
    /// like. There is no better evidence available for those.
    static func recoveredKey(for date: Date, calendar: Calendar = .current) -> Int {
        let legal = -12 * 3_600 ... 14 * 3_600
        let seconds = Int(date.timeIntervalSince1970.rounded())
        let remainder = ((-seconds) % 86_400 + 86_400) % 86_400

        // Offsets differ by a whole day, so at most two can be legal — and both
        // only in the +12…+14 band, where midnight in Auckland is the same instant
        // as midnight a day earlier in Baker Island. Nothing in the data separates
        // those, so prefer the zone nearest the one she is in now.
        let here = calendar.timeZone.secondsFromGMT(for: date)
        let candidate = [remainder, remainder - 86_400]
            .filter { legal.contains($0) }
            .min { abs($0 - here) < abs($1 - here) }

        guard let candidate, let zone = TimeZone(secondsFromGMT: candidate) else {
            return key(for: date, calendar: calendar)
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        return key(for: date, calendar: cal)
    }
}
