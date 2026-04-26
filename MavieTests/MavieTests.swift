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

    // MARK: - Phase 11: CycleAnalytics

    func testSymptomFrequencyIsSortedDescending() {
        let entries: [CycleEntry] = [
            CycleEntry(date: .now, symptoms: [.cramps, .fatigue, .bloating]),
            CycleEntry(date: .now, symptoms: [.cramps, .bloating]),
            CycleEntry(date: .now, symptoms: [.cramps])
        ]
        let result = CycleAnalytics.symptomFrequency(in: entries, limit: 6)
        XCTAssertEqual(result.first?.symptom, .cramps)
        XCTAssertEqual(result.first?.count, 3)
        XCTAssertEqual(result.last?.count, 1)
        XCTAssertEqual(result.count, 3)
    }

    func testMoodFrequencyIgnoresNilMoods() {
        let entries: [CycleEntry] = [
            CycleEntry(date: .now, mood: .calm),
            CycleEntry(date: .now, mood: .calm),
            CycleEntry(date: .now, mood: nil),
            CycleEntry(date: .now, mood: .happy)
        ]
        let result = CycleAnalytics.moodFrequency(in: entries)
        XCTAssertEqual(result.first?.mood, .calm)
        XCTAssertEqual(result.first?.count, 2)
    }

    func testPainSeriesIsSortedAscending() {
        let cal = Calendar.current
        let day1 = cal.date(byAdding: .day, value: -3, to: .now)!
        let day2 = cal.date(byAdding: .day, value: -1, to: .now)!
        let entries: [CycleEntry] = [
            CycleEntry(date: day2, pain: 5),
            CycleEntry(date: day1, pain: 2)
        ]
        let series = CycleAnalytics.painSeries(in: entries)
        XCTAssertEqual(series.count, 2)
        XCTAssertLessThan(series[0].date, series[1].date)
    }

    func testDaysLoggedRespectsLookback() {
        let cal = Calendar.current
        let recent = cal.date(byAdding: .day, value: -5, to: .now)!
        let old = cal.date(byAdding: .day, value: -45, to: .now)!
        let entries: [CycleEntry] = [
            CycleEntry(date: recent, mood: .calm),
            CycleEntry(date: old, mood: .calm)
        ]
        let result = CycleAnalytics.daysLogged(in: entries, lookbackDays: 30)
        XCTAssertEqual(result, 1)
    }

    // MARK: - Phase 10/11: CalendarMath

    func testDaysGridIs42Long() {
        let grid = CalendarMath.daysGrid(for: .now)
        XCTAssertEqual(grid.count, 42)
    }

    func testWeekdaySymbolsRotateByFirstDayOfWeek() {
        let sunday = CalendarMath.weekdaySymbols(firstDayOfWeek: 1)
        let monday = CalendarMath.weekdaySymbols(firstDayOfWeek: 2)
        XCTAssertEqual(sunday.count, 7)
        XCTAssertEqual(monday.count, 7)
        XCTAssertNotEqual(sunday.first, monday.first)
    }

    // MARK: - Phase 12: BiometricService

    func testBiometricKindHasIcon() {
        XCTAssertFalse(BiometricKind.faceID.icon.isEmpty)
        XCTAssertFalse(BiometricKind.touchID.icon.isEmpty)
        XCTAssertFalse(BiometricKind.opticID.icon.isEmpty)
        XCTAssertFalse(BiometricKind.none.icon.isEmpty)
    }

    func testBiometricServiceAvailableKindReturnsValue() {
        // On the Simulator this is typically .none; on a device it could be any.
        // We just assert the API doesn't crash and returns a defined value.
        let kind = BiometricService.availableKind()
        XCTAssertTrue([.none, .faceID, .touchID, .opticID].contains(kind))
    }

    // MARK: - Phase 13: NotificationService

    func testNotificationContentIsPrivateByDefault() {
        let priv = NotificationService.content(for: .periodUpcoming, isPrivate: true)
        XCTAssertEqual(priv.title, "Mavie reminder")
        XCTAssertFalse(priv.body.lowercased().contains("period"))
    }

    func testNotificationContentDescriptiveWhenNotPrivate() {
        let pub = NotificationService.content(for: .periodUpcoming, isPrivate: false)
        XCTAssertNotEqual(pub.title, "Mavie reminder")
        XCTAssertTrue(pub.title.lowercased().contains("period"))
    }

    func testNotificationContentDiffersByCategory() {
        let titles = NotificationService.Category.allCases.map {
            NotificationService.content(for: $0, isPrivate: false).title
        }
        XCTAssertEqual(Set(titles).count, NotificationService.Category.allCases.count)
    }

    func testNotificationCategoryIdentifiersAreNamespaced() {
        for category in NotificationService.Category.allCases {
            XCTAssertTrue(category.rawValue.hasPrefix("mavie."))
        }
    }

    // MARK: - Phase 15: ExportService

    func testCSVHeaderRowMatchesIncludeNotes() {
        let withNotes = ExportService.generateCSV(entries: [], includeNotes: true)
        let withoutNotes = ExportService.generateCSV(entries: [], includeNotes: false)
        XCTAssertTrue(withNotes.split(separator: "\n").first?.contains("note") ?? false)
        XCTAssertFalse(withoutNotes.split(separator: "\n").first?.contains("note") ?? true)
    }

    func testCSVRowsMatchEntryCount() {
        let entries: [CycleEntry] = [
            CycleEntry(date: Date(), flow: .light, mood: .calm),
            CycleEntry(date: Calendar.current.date(byAdding: .day, value: -1, to: .now)!, flow: .medium)
        ]
        let csv = ExportService.generateCSV(entries: entries, includeNotes: false)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 3, "Expected 1 header + 2 entry rows")
    }

    func testCSVEscapesCommasInNotes() {
        let entry = CycleEntry(date: Date(), note: "Hello, world")
        let csv = ExportService.generateCSV(entries: [entry], includeNotes: true)
        XCTAssertTrue(csv.contains("\"Hello, world\""))
    }

    func testCSVEscapesQuotesInNotes() {
        let entry = CycleEntry(date: Date(), note: "She said \"hi\"")
        let csv = ExportService.generateCSV(entries: [entry], includeNotes: true)
        XCTAssertTrue(csv.contains("\"She said \"\"hi\"\"\""))
    }

    func testFilterEntriesByRangeCutoff() {
        let cal = Calendar.current
        let recent = cal.date(byAdding: .day, value: -30, to: .now)!
        let old = cal.date(byAdding: .day, value: -200, to: .now)!
        let entries: [CycleEntry] = [
            CycleEntry(date: recent, mood: .calm),
            CycleEntry(date: old, mood: .calm)
        ]
        let last3Months = ExportService.filterEntries(entries, range: .last3Months)
        XCTAssertEqual(last3Months.count, 1)
        let allTime = ExportService.filterEntries(entries, range: .all)
        XCTAssertEqual(allTime.count, 2)
    }

    func testPDFGenerationProducesData() {
        let entry = CycleEntry(date: Date(), flow: .medium, pain: 4, symptoms: [.cramps], mood: .tired, note: "test note")
        let data = ExportService.generatePDF(entries: [entry], profile: nil, range: .last3Months, includeNotes: true)
        XCTAssertGreaterThan(data.count, 100)
        // PDF files start with "%PDF-"
        let prefix = data.prefix(5)
        XCTAssertEqual(String(data: Data(prefix), encoding: .ascii), "%PDF-")
    }

    func testExportRangeLookbackDays() {
        XCTAssertEqual(ExportRange.last3Months.lookbackDays, 90)
        XCTAssertEqual(ExportRange.last6Months.lookbackDays, 180)
        XCTAssertEqual(ExportRange.last12Months.lookbackDays, 365)
        XCTAssertNil(ExportRange.all.lookbackDays)
    }
}
