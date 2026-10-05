import XCTest
@testable import Caelyn

/// A gap in her history is not a cycle, and Caelyn must not describe it as one.
///
/// **What this protects.** `cycles(from:)` reconstructs a cycle as the span from
/// one period start to the next, which is right — reconstruction should stay
/// faithful. `plausibleCycles` then filters that down to what the statistics are
/// allowed to see, and it had a floor of 15 days and no ceiling at all.
///
/// So a woman who had a baby carried one ~400-day "cycle" in her history
/// permanently. `clampCycleLength` capped the prediction at 45 days and hid the
/// worst of it, but nothing capped anything else: her variation read as ±190
/// days, and `irregularCycleStatus` saw a length over 45 and reported irregular
/// cycles with skipped periods — every time she opened Insights, for good,
/// because the gap never leaves her history.
///
/// The same shape covers the months after birth, breastfeeding, hormonal
/// contraception, PCOS, perimenopause, illness, and simply not having opened the
/// app for a year.
final class LongGapCycleTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func cycle(_ length: Int, periodLength: Int = 5, startingDay: Int = 0) -> Cycle {
        Cycle(start: Date(timeIntervalSince1970: Double(startingDay) * 86_400),
              length: length,
              periodLength: periodLength)
    }

    /// Three ordinary cycles, then a pregnancy, then three more.
    private var afterABaby: [Cycle] {
        [cycle(28, startingDay: 0), cycle(29, startingDay: 28), cycle(27, startingDay: 57),
         cycle(400, startingDay: 84),                                     // the pregnancy
         cycle(28, startingDay: 484), cycle(30, startingDay: 512), cycle(28, startingDay: 542)]
    }

    // MARK: - The filter

    func testAPregnancyGapIsNotTreatedAsACycle() {
        let usable = PredictionEngine.plausibleCycles(afterABaby)
        XCTAssertFalse(usable.contains { $0.length == 400 },
            "a 400-day gap was averaged in as a cycle length")
        XCTAssertEqual(usable.count, 6, "and nothing real was dropped with it")
    }

    func testAGenuinelySkippedPeriodIsStillACycle() {
        let usable = PredictionEngine.plausibleCycles([cycle(28), cycle(52), cycle(30)])
        XCTAssertEqual(usable.count, 3,
            "a 52-day cycle is a skipped period, which is real and worth telling her about — not a gap to discard")
    }

    func testTheFloorStillHolds() {
        let usable = PredictionEngine.plausibleCycles([cycle(28), cycle(3), cycle(30)])
        XCTAssertEqual(usable.count, 2, "a 3-day 'cycle' is a missed log, not a cycle")
    }

    func testTheBoundaryIsInclusive() {
        XCTAssertEqual(PredictionEngine.plausibleCycles([cycle(90)]).count, 1)
        XCTAssertEqual(PredictionEngine.plausibleCycles([cycle(91)]).count, 0)
    }

    // MARK: - What she was actually told

    /// The one that matters: a permanent, false health statement.
    func testSheIsNotToldHerCyclesAreIrregularForeverAfterAPregnancy() {
        let status = PredictionEngine.irregularCycleStatus(from: afterABaby)
        XCTAssertEqual(status, .regular,
            "after having a baby she is told her cycles are irregular with skipped periods, on every visit to Insights, for the rest of her life — because the gap never leaves her history")
    }

    func testTheVariationFigureIsAboutHerCyclesAndNotTheGap() {
        let variation = PredictionEngine.cycleLengthVariation(of: afterABaby)
        XCTAssertLessThanOrEqual(variation, 3,
            "her cycle variation was reported as roughly half the length of her pregnancy")
    }

    func testTheAverageDescribesHerCyclesAgain() {
        let average = PredictionEngine.averageCycleLength(of: afterABaby, fallback: 28)
        XCTAssertTrue((27...30).contains(average),
            "her average cycle length was \\(average) days, which is not a cycle length she has ever had")
    }

    func testHerPeriodLengthIsNotSkewedEither() {
        var cycles = afterABaby
        // The pregnancy "cycle" carries a period length too — the bleeding that
        // started it — and averaging the gap in dragged that along.
        cycles[3] = cycle(400, periodLength: 12, startingDay: 84)
        let average = PredictionEngine.averagePeriodLength(of: cycles, fallback: 5)
        XCTAssertEqual(average, 5)
    }

    /// Still irregular when she genuinely is.
    func testRealIrregularityIsStillReported() {
        let erratic = [cycle(24), cycle(38), cycle(26), cycle(41), cycle(29)]
        XCTAssertNotEqual(PredictionEngine.irregularCycleStatus(from: erratic), .regular,
            "the ceiling must not silence a real irregularity finding")
    }

    func testASkippedPeriodIsStillReportedAsOne() {
        let skipped = [cycle(28), cycle(29), cycle(52), cycle(28)]
        XCTAssertEqual(PredictionEngine.irregularCycleStatus(from: skipped),
                       .irregular(reason: .skippedPeriods))
    }

    // MARK: - End to end, from entries

    /// Reconstruction must stay faithful even though the statistics do not use it:
    /// her calendar and her history still show what actually happened.
    func testTheGapIsStillReconstructedFaithfully() {
        var entries: [CycleEntry] = []
        func logPeriod(dayOffset: Int) {
            for d in 0..<4 {
                let day = calendar.date(byAdding: .day, value: dayOffset + d,
                                        to: Date(timeIntervalSince1970: 1_600_000_000))!
                let e = CycleEntry(date: day)
                e.dayKey = CivilDay.key(for: day, calendar: calendar)
                e.flow = .medium
                entries.append(e)
            }
        }
        logPeriod(dayOffset: 0)
        logPeriod(dayOffset: 28)
        logPeriod(dayOffset: 428)        // back after a pregnancy

        let all = PredictionEngine.cycles(
            from: entries,
            today: calendar.date(byAdding: .day, value: 460, to: Date(timeIntervalSince1970: 1_600_000_000))!,
            calendar: calendar)

        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains { $0.length == 400 },
            "the gap should still be reconstructed — her history is her history")
        XCTAssertEqual(PredictionEngine.plausibleCycles(all).count, 1,
            "but only the real cycle may inform what Caelyn says")
    }
}
