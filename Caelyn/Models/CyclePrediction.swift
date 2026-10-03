import Foundation
import SwiftUI

struct Cycle: Equatable {
    let start: Date
    let length: Int
    let periodLength: Int
}

enum CyclePhase: String, CaseIterable, Identifiable {
    case menstrual
    case follicular
    case ovulation
    case luteal
    case pms
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .menstrual:  return "Menstrual"
        case .follicular: return "Follicular"
        case .ovulation:  return "Ovulation window"
        case .luteal:     return "Luteal"
        case .pms:        return "PMS window"
        case .unknown:    return "Cycle"
        }
    }

    var hint: String {
        switch self {
        case .menstrual:  return "Take it easy today."
        case .follicular: return "A fresh-energy phase."
        // Not "Estimated ovulation window" — that is already the headline
        // directly above it on Home, and for anyone without a completed cycle
        // there is no personalised line to replace this one, so she saw the same
        // sentence twice. Which is roughly every new user, two weeks in.
        case .ovulation:  return "Your most fertile days, estimated."
        case .luteal:     return "Your body is settling in."
        case .pms:        return "Be gentle with yourself."
        case .unknown:    return "Log a cycle to learn your patterns."
        }
    }

    var accentColor: Color {
        switch self {
        case .menstrual:  return CaelynColor.softRose
        case .follicular: return CaelynColor.warmSand
        case .ovulation:  return CaelynColor.successSage
        case .luteal:     return CaelynColor.warmSand
        case .pms:        return CaelynColor.primaryPlum
        case .unknown:    return CaelynColor.primaryPlum
        }
    }

    var tintBackground: Color {
        switch self {
        case .menstrual:  return CaelynColor.blush
        case .follicular: return CaelynColor.warmSand.opacity(0.45)
        case .ovulation:  return CaelynColor.sage
        case .luteal:     return CaelynColor.warmSand.opacity(0.4)
        case .pms:        return CaelynColor.lavender
        case .unknown:    return CaelynColor.lavender.opacity(0.6)
        }
    }

    var icon: String {
        switch self {
        case .menstrual:  return "drop.fill"
        case .follicular: return "leaf.fill"
        case .ovulation:  return "sun.max.fill"
        case .luteal:     return "moon.fill"
        case .pms:        return "cloud.fill"
        case .unknown:    return "circle.dotted"
        }
    }
}

// MARK: - Irregular Cycle

enum IrregularCycleReason: String {
    case highVariation   = "High cycle-length variation"
    case longCycles      = "Consistently long cycles"
    case shortCycles     = "Consistently short cycles"
    case skippedPeriods  = "Infrequent periods (gaps > 45 days)"
    case increasingShift = "Cycles becoming noticeably longer or shorter"

    var note: String {
        switch self {
        case .highVariation:
            return "Your cycle length varies significantly between months, which can make predictions less accurate. This is common and may indicate hormonal fluctuation."
        case .longCycles:
            return "Your cycles are consistently longer than 35 days. This is sometimes associated with conditions like PCOS. It's worth discussing with your doctor."
        case .shortCycles:
            return "Your cycles are consistently shorter than 21 days. A healthcare provider can help determine if this is within normal range for you."
        case .skippedPeriods:
            return "Caelyn has detected gaps of 45 days or more, suggesting some periods may have been missed or skipped."
        case .increasingShift:
            return "Your cycles have been progressively shifting in length. This can be a normal change or an early sign of hormonal shifts — worth tracking closely."
        }
    }
}

enum IrregularCycleStatus: Equatable {
    case regular
    case irregular(reason: IrregularCycleReason)
    case insufficient  // fewer than 3 completed cycles
}

enum Confidence: String {
    case low      // < 3 cycles logged
    case medium   // 3–5 cycles
    case high     // 6+ cycles

    var displayText: String {
        switch self {
        case .low:    return "Caelyn is still learning your pattern."
        case .medium: return "Predictions are warming up."
        case .high:   return "Predictions are confident."
        }
    }
}

// MARK: - The one description of her cycle

/// Everything Caelyn knows about where she is in her cycle and what happens next,
/// derived once from her actual history.
///
/// **Why this type exists.** The same history used to produce two different
/// answers. Home, Insights, the widget and the PDF report asked
/// `PredictionEngine.averageCycleLength(of:fallback:)` — the length *learned* from
/// her logs. The calendar grid, the Log tab, the notification scheduler and
/// `PatternEngine` read `profile.averageCycleLength` — the number she typed during
/// onboarding, which nothing ever updated. For a woman whose real cycles run 33
/// days after answering "28", Home predicted 19 September while the calendar
/// highlighted 14–18 September and the reminder fired on the 12th. The two
/// predicted windows did not even overlap.
///
/// So there is now exactly one derivation, and every surface reads it. Nothing
/// here recomputes a prediction differently to make the numbers agree — it is the
/// same `PredictionEngine` maths, performed once.
///
/// **The anchor.** `profile.lastPeriodStart` used to be a stored fact that every
/// write path was supposed to remember to update, and most of them didn't: logging
/// a period from the Log tab, the calendar day sheet, the Watch or an import all
/// left it behind. A woman who logged three periods from the Log tab was still
/// anchored to her onboarding answer, and Home told her "Caelyn hasn't seen your
/// period this cycle" every day for months.
///
/// The anchor is therefore *derived* from logged bleeding, and the stored value is
/// kept only as the seed it always should have been: what she told Caelyn before
/// she had logged anything. Where both exist, the later one wins — both are
/// statements about when her most recent period began, and the newer cannot be
/// contradicted by older logged flow. That keeps an explicit "my period started on
/// the 20th" (onboarding, Settings, or Home's *Change date*) standing over an
/// import that only reaches May, while a stale seed can never outrank a period she
/// has actually logged since.
struct CycleModel {

    /// Completed cycles that can actually be true — implausibly short
    /// reconstructions are filtered out before anything is averaged or diagnosed.
    let cycles: [Cycle]

    /// The effective start of her most recent period, or nil when Caelyn has
    /// nothing to go on and must say so instead of guessing.
    let anchor: Date?

    let cycleLength: Int
    let periodLength: Int
    let variation: Int

    /// The period she appears to be in right now, if any.
    let activePeriodWindow: ClosedRange<Date>?

    /// Held so the *learned* values below can be computed only when something
    /// actually asks for them. See the note on `lutealLength`.
    private let entries: [CycleEntry]
    private let today: Date
    private let calendar: Calendar

    // MARK: - Learned on demand

    /// Her personal luteal length, learned from confirmed ovulation signals.
    ///
    /// **Deliberately computed on access rather than in `make`.** Reading it
    /// touches `ovulationTestResult` on every entry, and SwiftData observation is
    /// per-property: any view whose body reads this is re-rendered whenever any of
    /// those values changes. Computing it eagerly meant the Log tab — which only
    /// wants "Cycle day N" — subscribed to every entry's ovulation tests, symptoms
    /// and moods, and re-laid-out the whole screen on each chip tap. That is how it
    /// stole keyboard focus from the medication field mid-typing.
    ///
    /// So the rule is: a surface observes exactly what it reads. Home reads this
    /// (its fertile window depends on it) and is re-rendered when it changes, which
    /// is correct. The Log tab never touches it.
    var lutealLength: Int {
        PredictionEngine.learnedLutealLength(entries: entries, cycles: cycles, calendar: calendar) ?? 14
    }

    /// How many days before her period PMS actually starts for her. Lazy for the
    /// same reason: it reads `symptoms` and `mood` on every entry.
    var pmsDaysBefore: Int {
        PredictionEngine.adaptivePmsDaysBefore(entries: entries, cycles: cycles, calendar: calendar) ?? 5
    }

    // MARK: - Building

    static func make(
        entries: [CycleEntry],
        profile: UserProfile?,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> CycleModel {
        let day = calendar.startOfDay(for: today)
        let allCycles = PredictionEngine.cycles(from: entries, today: day, calendar: calendar)
        let cycles = PredictionEngine.plausibleCycles(allCycles)

        let cycleLength = PredictionEngine.averageCycleLength(
            of: cycles, fallback: profile?.averageCycleLength ?? 28)
        let periodLength = PredictionEngine.averagePeriodLength(
            of: cycles, fallback: profile?.averagePeriodLength ?? 5)

        // Logged bleeding is the truth; the profile value is the seed she gave
        // before there was any. The later of the two wins — see the type's note.
        let logged = PredictionEngine.mostRecentPeriodStart(from: entries, today: day, calendar: calendar)
        let seed = profile?.lastPeriodStart.map { calendar.startOfDay(for: $0) }
        let anchor: Date?
        switch (logged, seed) {
        case let (logged?, seed?): anchor = max(logged, seed)
        case let (logged?, nil):   anchor = logged
        case let (nil, seed?):     anchor = seed
        case (nil, nil):           anchor = nil
        }

        return CycleModel(
            cycles: cycles,
            anchor: anchor,
            cycleLength: cycleLength,
            periodLength: periodLength,
            variation: PredictionEngine.cycleLengthVariation(of: cycles),
            activePeriodWindow: CalendarMath.activePeriodWindow(
                in: entries, periodLength: periodLength, today: day, calendar: calendar),
            entries: entries,
            today: day,
            calendar: calendar
        )
    }

    /// An empty model, for the moment before any profile or history exists.
    static func empty(today: Date = .now, calendar: Calendar = .current) -> CycleModel {
        CycleModel(cycles: [], anchor: nil, cycleLength: 28, periodLength: 5,
                   variation: 0, activePeriodWindow: nil, entries: [],
                   today: calendar.startOfDay(for: today), calendar: calendar)
    }

    // MARK: - Where she is

    /// True once Caelyn has an anchor and may speak about timing at all.
    var hasPrediction: Bool { anchor != nil }

    var confidence: Confidence { PredictionEngine.confidence(cycleCount: cycles.count) }

    var irregularStatus: IrregularCycleStatus { PredictionEngine.irregularCycleStatus(from: cycles) }

    var cycleDay: Int {
        guard let anchor else { return 1 }
        return PredictionEngine.currentCycleDay(
            lastPeriodStart: anchor, today: today, cycleLength: cycleLength, calendar: calendar)
    }

    var phase: CyclePhase {
        guard hasPrediction else { return .unknown }
        return PredictionEngine.phase(
            forCycleDay: cycleDay, periodLength: periodLength,
            cycleLength: cycleLength, lutealLength: lutealLength)
    }

    // MARK: - What happens next

    var nextPeriodStart: Date? {
        guard let anchor else { return nil }
        return PredictionEngine.nextPeriodStart(
            lastPeriodStart: anchor, today: today, cycleLength: cycleLength, calendar: calendar)
    }

    /// The un-rolled expected start — may be in the past, which is what lateness
    /// is measured against.
    var expectedPeriodStart: Date? {
        guard let anchor else { return nil }
        return PredictionEngine.expectedPeriodStart(lastPeriodStart: anchor, cycleLength: cycleLength,
                                                    calendar: calendar)
    }

    var predictedPeriodWindow: ClosedRange<Date>? {
        nextPeriodStart.map {
            PredictionEngine.predictedPeriodWindow(nextPeriodStart: $0, periodLength: periodLength,
                                                   calendar: calendar)
        }
    }

    var ovulationEstimate: Date? {
        nextPeriodStart.map {
            PredictionEngine.ovulationEstimate(nextPeriodStart: $0, lutealLength: lutealLength,
                                               calendar: calendar)
        }
    }

    var fertileWindow: ClosedRange<Date>? {
        nextPeriodStart.map {
            PredictionEngine.fertileWindow(nextPeriodStart: $0, lutealLength: lutealLength,
                                           calendar: calendar)
        }
    }

    var pmsWindow: ClosedRange<Date>? {
        nextPeriodStart.map {
            PredictionEngine.pmsWindow(nextPeriodStart: $0, daysBefore: pmsDaysBefore,
                                       calendar: calendar)
        }
    }

    var daysUntilPeriod: Int {
        nextPeriodStart.map { PredictionEngine.daysUntil($0, from: today, calendar: calendar) } ?? 0
    }

    var daysUntilPMS: Int {
        pmsWindow.map { PredictionEngine.daysUntil($0.lowerBound, from: today, calendar: calendar) } ?? 0
    }

    var daysUntilOvulation: Int {
        ovulationEstimate.map { PredictionEngine.daysUntil($0, from: today, calendar: calendar) } ?? 0
    }

    var daysUntilFertileWindowStart: Int {
        fertileWindow.map { PredictionEngine.daysUntil($0.lowerBound, from: today, calendar: calendar) } ?? 0
    }

    // MARK: - Lateness

    var isInActivePeriodWindow: Bool { activePeriodWindow?.contains(today) ?? false }

    /// Which day of the current period she is on, if she is in one.
    var dayInPeriod: Int? {
        guard let window = activePeriodWindow else { return nil }
        return (calendar.dateComponents([.day], from: window.lowerBound, to: today).day ?? 0) + 1
    }

    var daysLate: Int {
        guard let anchor else { return 0 }
        return PredictionEngine.daysLate(
            lastPeriodStart: anchor, today: today, cycleLength: cycleLength, calendar: calendar)
    }

    /// Late means past the expected start with no bleeding logged since. Both
    /// halves matter: without the window check Caelyn calls her late while she is
    /// visibly having her period.
    var isPeriodLate: Bool {
        guard let expected = expectedPeriodStart else { return false }
        return today > expected && activePeriodWindow == nil
    }
}
