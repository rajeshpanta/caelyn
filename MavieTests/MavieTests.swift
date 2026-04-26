import XCTest
import SwiftData
@testable import Mavie

@MainActor
final class MavieTests: XCTestCase {

    static let sharedContainer: ModelContainer = {
        let schema = Schema([CycleEntry.self, UserProfile.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    private var context: ModelContext { Self.sharedContainer.mainContext }

    override func setUp() async throws {
        try context.delete(model: CycleEntry.self)
        try context.delete(model: UserProfile.self)
        try context.save()
    }

    func testCycleEntryRoundTrip() throws {
        let date = Calendar.current.startOfDay(for: Date())

        let entry = CycleEntry(
            date: date,
            flow: .medium,
            pain: 4,
            painTypes: [.cramps, .backPain],
            symptoms: [.cramps, .fatigue],
            mood: .calm,
            note: "First test entry"
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CycleEntry>())
        XCTAssertEqual(fetched.count, 1)

        let stored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(stored.flow, .medium)
        XCTAssertEqual(stored.pain, 4)
        XCTAssertEqual(stored.painTypes, [.cramps, .backPain])
        XCTAssertEqual(stored.symptoms, [.cramps, .fatigue])
        XCTAssertEqual(stored.mood, .calm)
        XCTAssertEqual(stored.note, "First test entry")
        XCTAssertTrue(stored.hasContent)
    }

    func testEmptyCycleEntryHasNoContent() throws {
        let entry = CycleEntry(date: Date())
        XCTAssertFalse(entry.hasContent)
    }

    func testUserProfileDefaults() throws {
        context.insert(UserProfile())
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<UserProfile>())
        let stored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(stored.averageCycleLength, 28)
        XCTAssertEqual(stored.averagePeriodLength, 5)
        XCTAssertFalse(stored.hasOnboarded)
        XCTAssertEqual(stored.theme, .system)
        XCTAssertTrue(stored.privateNotifications)
    }

    func testPreviewDataPopulatesContainer() throws {
        PreviewData.populate(context)

        let entries = try context.fetch(FetchDescriptor<CycleEntry>())
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())

        XCTAssertGreaterThan(entries.count, 30, "Expected at least 30 synthetic entries across 4 cycles")
        XCTAssertEqual(profiles.count, 1)
        XCTAssertTrue(profiles.first?.hasOnboarded ?? false)
    }

    func testCycleEntryDateIsTruncatedToStartOfDay() throws {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 25
        components.hour = 14
        components.minute = 37
        let messyDate = Calendar.current.date(from: components)!
        let entry = CycleEntry(date: messyDate)
        let startOfDay = Calendar.current.startOfDay(for: messyDate)
        XCTAssertEqual(entry.date, startOfDay)
    }

    // MARK: - Phase 7: PredictionEngine

    func testPhaseClassification() {
        // 5-day period, 29-day cycle
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 1, periodLength: 5, cycleLength: 29), .menstrual)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 5, periodLength: 5, cycleLength: 29), .menstrual)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 7, periodLength: 5, cycleLength: 29), .follicular)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 15, periodLength: 5, cycleLength: 29), .ovulation)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 20, periodLength: 5, cycleLength: 29), .luteal)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 26, periodLength: 5, cycleLength: 29), .pms)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 29, periodLength: 5, cycleLength: 29), .pms)
    }

    func testPhaseClassificationDegenerateCycle() {
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 1, periodLength: 5, cycleLength: 0), .unknown)
    }

    func testCurrentCycleDayWraps() {
        let lastPeriod = Calendar.current.date(byAdding: .day, value: -45, to: .now)!
        let day = PredictionEngine.currentCycleDay(lastPeriodStart: lastPeriod, cycleLength: 28)
        XCTAssertGreaterThanOrEqual(day, 1)
        XCTAssertLessThanOrEqual(day, 28)
    }

    func testCurrentCycleDaySameDay() {
        let day = PredictionEngine.currentCycleDay(lastPeriodStart: .now, cycleLength: 28)
        XCTAssertEqual(day, 1)
    }

    func testNextPeriodStartProjectsForward() {
        let lastPeriod = Calendar.current.date(byAdding: .day, value: -40, to: .now)!
        let next = PredictionEngine.nextPeriodStart(lastPeriodStart: lastPeriod, cycleLength: 28)
        XCTAssertGreaterThan(next, .now)
    }

    func testPredictedPeriodWindow() {
        let nextStart = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        let window = PredictionEngine.predictedPeriodWindow(nextPeriodStart: nextStart, periodLength: 5)
        let span = Calendar.current.dateComponents([.day], from: window.lowerBound, to: window.upperBound).day ?? 0
        XCTAssertEqual(span, 4)
    }

    func testOvulationEstimateIs14DaysBefore() {
        let nextStart = Date()
        let ovulation = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart)
        let diff = Calendar.current.dateComponents([.day], from: ovulation, to: nextStart).day ?? 0
        XCTAssertEqual(diff, 14)
    }

    func testPmsWindowIsFiveDaysEndingDayBeforeNextPeriod() {
        let nextStart = Date()
        let window = PredictionEngine.pmsWindow(nextPeriodStart: nextStart)
        let endDiff = Calendar.current.dateComponents([.day], from: window.upperBound, to: nextStart).day ?? 0
        let span = Calendar.current.dateComponents([.day], from: window.lowerBound, to: window.upperBound).day ?? 0
        XCTAssertEqual(endDiff, 1)
        XCTAssertEqual(span, 4)
    }

    func testConfidenceLevels() {
        XCTAssertEqual(PredictionEngine.confidence(cycleCount: 0), .low)
        XCTAssertEqual(PredictionEngine.confidence(cycleCount: 2), .low)
        XCTAssertEqual(PredictionEngine.confidence(cycleCount: 3), .medium)
        XCTAssertEqual(PredictionEngine.confidence(cycleCount: 5), .medium)
        XCTAssertEqual(PredictionEngine.confidence(cycleCount: 6), .high)
        XCTAssertEqual(PredictionEngine.confidence(cycleCount: 100), .high)
    }

    func testAverageCycleLengthFallsBackWhenInsufficientData() {
        let cycles: [Cycle] = [
            Cycle(start: .now, length: 28, periodLength: 5)
        ]
        XCTAssertEqual(PredictionEngine.averageCycleLength(of: cycles, fallback: 30), 30)
    }

    func testAverageCycleLengthAveragesRecent() {
        let now = Date()
        let cycles: [Cycle] = [
            Cycle(start: now, length: 30, periodLength: 5),
            Cycle(start: now, length: 28, periodLength: 5),
            Cycle(start: now, length: 29, periodLength: 5)
        ]
        XCTAssertEqual(PredictionEngine.averageCycleLength(of: cycles, fallback: 0), 29)
    }

    func testCyclesReconstructionFromEntries() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let cycle1Start = cal.date(byAdding: .day, value: -57, to: today)!
        let cycle2Start = cal.date(byAdding: .day, value: -29, to: today)!

        let entries: [CycleEntry] = [
            CycleEntry(date: cycle1Start, flow: .medium),
            CycleEntry(date: cal.date(byAdding: .day, value: 1, to: cycle1Start)!, flow: .medium),
            CycleEntry(date: cal.date(byAdding: .day, value: 2, to: cycle1Start)!, flow: .light),
            CycleEntry(date: cycle2Start, flow: .medium),
            CycleEntry(date: cal.date(byAdding: .day, value: 1, to: cycle2Start)!, flow: .medium)
        ]

        let cycles = PredictionEngine.cycles(from: entries, today: today)
        XCTAssertEqual(cycles.count, 1, "Two flow streaks should produce one completed cycle")
        XCTAssertEqual(cycles[0].length, 28)
        XCTAssertEqual(cycles[0].periodLength, 3)
    }

    func testMostFrequentSymptom() {
        let entries: [CycleEntry] = [
            CycleEntry(date: .now, symptoms: [.cramps, .fatigue]),
            CycleEntry(date: .now, symptoms: [.cramps]),
            CycleEntry(date: .now, symptoms: [.bloating])
        ]
        let result = PredictionEngine.mostFrequentSymptom(in: entries)
        XCTAssertEqual(result?.0, .cramps)
        XCTAssertEqual(result?.1, 2)
    }

    func testCyclePhaseHasDistinctAccentForEveryPhase() {
        let phases: [CyclePhase] = [.menstrual, .follicular, .ovulation, .luteal, .pms]
        for phase in phases {
            XCTAssertFalse(phase.displayName.isEmpty)
            XCTAssertFalse(phase.hint.isEmpty)
            XCTAssertFalse(phase.icon.isEmpty)
        }
    }
}
