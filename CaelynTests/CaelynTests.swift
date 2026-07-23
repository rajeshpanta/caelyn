import XCTest
import SwiftData
import HealthKit
@testable import Caelyn

@MainActor
final class CaelynTests: XCTestCase {

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

    /// A cycle short enough that ovulation (cycleLength − 14) would land on
    /// or before the period ends collapses the standard luteal model. We
    /// report menstrual while bleeding and unknown for the rest, instead
    /// of overlapping phase labels.
    func testPhaseClassificationShortCycleDoesNotOverlap() {
        // 5-day period, 18-day cycle → ovulation would be day 4, inside the
        // period. Old behavior reported luteal/pms here; new behavior is
        // menstrual then unknown.
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 1,  periodLength: 5, cycleLength: 18), .menstrual)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 5,  periodLength: 5, cycleLength: 18), .menstrual)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 6,  periodLength: 5, cycleLength: 18), .unknown)
        XCTAssertEqual(PredictionEngine.phase(forCycleDay: 14, periodLength: 5, cycleLength: 18), .unknown)
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
        XCTAssertEqual(priv.title, "Caelyn reminder")
        XCTAssertFalse(priv.body.lowercased().contains("period"))
    }

    func testNotificationContentDescriptiveWhenNotPrivate() {
        let pub = NotificationService.content(for: .periodUpcoming, isPrivate: false)
        XCTAssertNotEqual(pub.title, "Caelyn reminder")
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
            XCTAssertTrue(category.rawValue.hasPrefix("caelyn."))
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

    // MARK: - Phase 14: HealthKitService

    func testHealthKitSymptomMapHasSomeEntries() {
        XCTAssertFalse(HealthKitService.symptomCategoryMap.isEmpty)
        XCTAssertNotNil(HealthKitService.symptomCategoryMap[.bloating])
        XCTAssertNotNil(HealthKitService.symptomCategoryMap[.fatigue])
    }

    func testHealthKitPainMapCoversAllPainTypes() {
        for pain in PainType.allCases {
            XCTAssertNotNil(
                HealthKitService.painCategoryMap[pain],
                "Missing HK mapping for pain type \(pain)"
            )
        }
    }

    func testHealthKitSeverityFromPain() {
        XCTAssertEqual(HealthKitService.severity(forPain: 0), .notPresent)
        XCTAssertEqual(HealthKitService.severity(forPain: 1), .mild)
        XCTAssertEqual(HealthKitService.severity(forPain: 3), .mild)
        XCTAssertEqual(HealthKitService.severity(forPain: 4), .moderate)
        XCTAssertEqual(HealthKitService.severity(forPain: 6), .moderate)
        XCTAssertEqual(HealthKitService.severity(forPain: 7), .severe)
        XCTAssertEqual(HealthKitService.severity(forPain: 10), .severe)
    }

    func testHealthKitWritableTypesIncludesMenstrualFlow() {
        let writable = HealthKitService.allWritableTypes
        XCTAssertTrue(writable.contains(HealthKitService.menstrualFlowType))
    }

    func testHealthKitMakeFlowSampleEmbedsCycleStartMetadata() {
        let sample = HealthKitService.makeFlowSample(date: .now, flow: .medium, isCycleStart: true)
        XCTAssertEqual(sample.metadata?[HKMetadataKeyMenstrualCycleStart] as? Bool, true)
    }

    // MARK: - Phase 16: PurchaseService

    func testYearlySavingsPercentForOurPricing() {
        // Monthly $3.99 × 12 = $47.88 vs yearly $19.99 → ~58% off.
        let percent = PurchaseService.savingsPercent(
            monthlyPrice: Decimal(string: "3.99")!,
            yearlyPrice: Decimal(string: "19.99")!
        )
        XCTAssertEqual(percent, 58)
    }

    func testYearlySavingsPercentZeroWhenSamePrice() {
        let percent = PurchaseService.savingsPercent(
            monthlyPrice: Decimal(string: "3.99")!,
            yearlyPrice: Decimal(string: "47.88")!
        )
        XCTAssertEqual(percent, 0)
    }

    func testYearlySavingsPercentZeroOnZeroMonthly() {
        let percent = PurchaseService.savingsPercent(monthlyPrice: 0, yearlyPrice: 19.99)
        XCTAssertEqual(percent, 0)
    }

    func testProductIDRawValuesAreNamespaced() {
        XCTAssertEqual(PurchaseService.ProductID.monthly.rawValue, "smallpanta-icould.com.caelynperiodtracker.pro.monthly")
        XCTAssertEqual(PurchaseService.ProductID.yearly.rawValue, "smallpanta-icould.com.caelynperiodtracker.pro.yearly")
    }

    func testPurchaseOutcomeEquality() {
        XCTAssertEqual(PurchaseOutcome.success, .success)
        XCTAssertEqual(PurchaseOutcome.cancelled, .cancelled)
        XCTAssertEqual(PurchaseOutcome.failed("x"), .failed("x"))
        XCTAssertNotEqual(PurchaseOutcome.failed("x"), .failed("y"))
    }

    // MARK: - Phase 17: Polish — UserProfile schema additions

    func testUserProfileNewReminderTimeDefaults() throws {
        context.insert(UserProfile())
        try context.save()
        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(stored.dailyCheckInHour, 20)
        XCTAssertEqual(stored.dailyCheckInMinute, 0)
        XCTAssertEqual(stored.medicationHour, 9)
        XCTAssertEqual(stored.medicationMinute, 0)
    }

    func testUserProfileHKDefaultsAreOff() throws {
        context.insert(UserProfile())
        try context.save()
        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertFalse(stored.hkReadFlow)
        XCTAssertFalse(stored.hkWriteFlow)
        XCTAssertFalse(stored.hkReadSymptoms)
        XCTAssertFalse(stored.hkWriteSymptoms)
        XCTAssertFalse(stored.healthKitConnected)
    }

    // MARK: - Active period window detection

    func testActivePeriodWindowFromSingleLoggedDay() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let entries: [CycleEntry] = [
            CycleEntry(date: today, flow: .medium)
        ]
        let window = CalendarMath.activePeriodWindow(in: entries, periodLength: 5, today: today)
        let unwrappedWindow = try? XCTUnwrap(window)
        XCTAssertNotNil(unwrappedWindow)
        XCTAssertEqual(unwrappedWindow?.lowerBound, today)
        XCTAssertEqual(
            unwrappedWindow?.upperBound,
            cal.date(byAdding: .day, value: 4, to: today)
        )
    }

    func testActivePeriodWindowSpansFromStreakStart() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let day1 = cal.date(byAdding: .day, value: -2, to: today)!
        let day2 = cal.date(byAdding: .day, value: -1, to: today)!
        let entries: [CycleEntry] = [
            CycleEntry(date: day1, flow: .light),
            CycleEntry(date: day2, flow: .heavy)
        ]
        let window = CalendarMath.activePeriodWindow(in: entries, periodLength: 5, today: today)
        XCTAssertEqual(window?.lowerBound, day1)
        XCTAssertEqual(window?.upperBound, cal.date(byAdding: .day, value: 4, to: day1))
    }

    func testActivePeriodWindowReturnsNilWhenStreakIsOld() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let oldFlow = cal.date(byAdding: .day, value: -20, to: today)!
        let entries: [CycleEntry] = [
            CycleEntry(date: oldFlow, flow: .medium)
        ]
        let window = CalendarMath.activePeriodWindow(in: entries, periodLength: 5, today: today)
        XCTAssertNil(window)
    }

    func testActivePeriodWindowReturnsNilWhenNoFlowLogged() {
        let entries: [CycleEntry] = [
            CycleEntry(date: .now, mood: .calm)  // mood logged, no flow
        ]
        let window = CalendarMath.activePeriodWindow(in: entries, periodLength: 5)
        XCTAssertNil(window)
    }

    func testActivePeriodWindowGapBreaksStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let firstDay = cal.date(byAdding: .day, value: -7, to: today)!
        let secondDay = cal.date(byAdding: .day, value: -1, to: today)!
        // Two flow days, large gap → second day is its own streak.
        let entries: [CycleEntry] = [
            CycleEntry(date: firstDay, flow: .light),
            CycleEntry(date: secondDay, flow: .light)
        ]
        let window = CalendarMath.activePeriodWindow(in: entries, periodLength: 5, today: today)
        XCTAssertEqual(window?.lowerBound, secondDay, "Most recent streak start should win when there's a wide gap")
    }

    /// Real-world scenario: user logs Day 1, forgets Day 2, logs Day 3.
    /// We tolerate 1-day gaps so this still counts as one streak starting Day 1.
    func testActivePeriodWindowToleratesOneMissedDay() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let day1 = cal.date(byAdding: .day, value: -2, to: today)!
        // day2 (yesterday) intentionally not logged
        let day3 = today
        let entries: [CycleEntry] = [
            CycleEntry(date: day1, flow: .light),
            CycleEntry(date: day3, flow: .medium)
        ]
        let window = CalendarMath.activePeriodWindow(in: entries, periodLength: 5, today: today)
        XCTAssertEqual(
            window?.lowerBound,
            day1,
            "1-day gap (logged Day 1, skipped Day 2, logged Day 3) should still be one streak starting Day 1"
        )
    }

    // MARK: - Phase 0 regressions (P0 fixes)

    /// stz-014: a future-dated flow tap must not be reconstructed into a cycle
    /// (otherwise it fabricates a huge phantom cycle that skews every average).
    func testCyclesExcludeFutureDatedFlow() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let c1 = cal.date(byAdding: .day, value: -57, to: today)!
        let c2 = cal.date(byAdding: .day, value: -29, to: today)!
        let future = cal.date(byAdding: .day, value: 30, to: today)!
        let entries: [CycleEntry] = [
            CycleEntry(date: c1, flow: .medium),
            CycleEntry(date: c2, flow: .medium),
            CycleEntry(date: future, flow: .medium)   // future tap — must be ignored
        ]
        let cycles = PredictionEngine.cycles(from: entries, today: today)
        XCTAssertEqual(cycles.count, 1, "Future flow must not add a phantom cycle")
        XCTAssertEqual(cycles[0].length, 28)
    }

    /// stz-009: expected start is NOT rolled past today, so it can be in the past
    /// — which is what makes late-period detection possible.
    func testExpectedPeriodStartIsUnrolled() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let last = cal.date(byAdding: .day, value: -40, to: today)!   // 28-day cycle → overdue
        let expected = PredictionEngine.expectedPeriodStart(lastPeriodStart: last, cycleLength: 28)
        XCTAssertEqual(expected, cal.date(byAdding: .day, value: 28, to: cal.startOfDay(for: last)))
        XCTAssertLessThan(expected, today, "Expected start should be in the past for an overdue cycle")
    }

    /// stz-009: daysLate is positive for an overdue cycle and zero otherwise.
    func testDaysLateDetectsOverdue() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let overdue = cal.date(byAdding: .day, value: -40, to: today)!   // 12 days late
        XCTAssertEqual(PredictionEngine.daysLate(lastPeriodStart: overdue, today: today, cycleLength: 28), 12)
        let onTime = cal.date(byAdding: .day, value: -20, to: today)!    // not yet due
        XCTAssertEqual(PredictionEngine.daysLate(lastPeriodStart: onTime, today: today, cycleLength: 28), 0)
    }

    /// priv-5: private-mode notifications never leak a health term for ANY category.
    func testPrivateNotificationsNeverLeakHealthTerms() {
        let leaks = ["period", "ovulat", "medication", "birth control", "fertil", "pregnan"]
        for category in NotificationService.Category.allCases {
            let content = NotificationService.content(for: category, isPrivate: true)
            let text = (content.title + " " + content.body).lowercased()
            for term in leaks {
                XCTAssertFalse(text.contains(term), "Private \(category.rawValue) notification leaked '\(term)': \(text)")
            }
        }
    }

    // MARK: - Phase 1 regressions (plat-13 export, plat-1 shared math)

    /// plat-13: a custom symptom containing a comma must be CSV-quoted so it
    /// doesn't break the row.
    func testCSVEscapesCommasInCustomSymptoms() {
        let entry = CycleEntry(date: Date())
        entry.loggedCustomSymptoms = ["Joint pain, knees"]
        let csv = ExportService.generateCSV(entries: [entry], includeNotes: false)
        XCTAssertTrue(csv.contains("\"Joint pain, knees\""), "Comma in a custom symptom must be quoted")
    }

    /// plat-13: machine-readable CSV dates are Gregorian yyyy-MM-dd.
    func testCSVDateUsesGregorianYYYYMMDD() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 3, day: 5))!
        let entry = CycleEntry(date: date, flow: .light)
        let csv = ExportService.generateCSV(entries: [entry], includeNotes: false)
        XCTAssertTrue(csv.contains("2026-03-05"), "CSV should emit Gregorian yyyy-MM-dd")
    }

    /// plat-13: the boundary day is included even when "now" has a time component.
    func testFilterEntriesIncludesBoundaryDay() {
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        let boundary = cal.startOfDay(for: cal.date(byAdding: .day, value: -90, to: now)!)
        let entry = CycleEntry(date: boundary, mood: .calm)
        let filtered = ExportService.filterEntries([entry], range: .last3Months, today: now)
        XCTAssertEqual(filtered.count, 1, "Boundary day (90 days ago) should be included")
    }

    /// plat-1: the shared widget/watch recompute matches PredictionEngine for the
    /// day-sensitive fields, so the two never diverge.
    func testWidgetCycleMathMatchesPredictionEngine() {
        for cycleLength in [21, 26, 28, 31, 35] {
            for periodLength in [3, 5, 7] {
                for day in 1...cycleLength {
                    let engine = PredictionEngine.phase(forCycleDay: day, periodLength: periodLength, cycleLength: cycleLength).rawValue
                    let shared = WidgetCycleMath.phaseRaw(cycleDay: day, periodLength: periodLength, cycleLength: cycleLength)
                    XCTAssertEqual(shared, engine, "phase mismatch at day \(day), period \(periodLength), cycle \(cycleLength)")
                }
            }
        }
    }

    /// plat-1/3/4: recompute advances the cycle day as the date moves past midnight.
    func testWidgetSnapshotRecomputesDayAcrossMidnight() {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: cal.date(byAdding: .day, value: -3, to: .now)!)
        var snap = WidgetSnapshot.placeholder()
        snap.anchorPeriodStart = anchor
        snap.cycleLength = 28
        snap.periodLength = 5
        let today = cal.startOfDay(for: .now)
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        XCTAssertEqual(snap.recomputed(for: today).cycleDay, 4)       // day 0..3 → cycle day 4
        XCTAssertEqual(snap.recomputed(for: tomorrow).cycleDay, 5)    // advances across midnight
    }

    // MARK: - qa-4: Date / time-zone / DST / leap / year-boundary robustness

    private func snapshot(anchor: Date, cycleLength: Int = 28, periodLength: Int = 5) -> WidgetSnapshot {
        var s = WidgetSnapshot.placeholder()
        s.anchorPeriodStart = anchor
        s.cycleLength = cycleLength
        s.periodLength = periodLength
        return s
    }

    func testRecomputeStableAcrossTimeZones() {
        for tzID in ["America/New_York", "Asia/Tokyo", "Pacific/Kiritimati" /* UTC+14 */, "Pacific/Honolulu"] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: tzID)!
            let anchor = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
            let later = cal.date(from: DateComponents(year: 2026, month: 1, day: 6))!  // +5 days
            XCTAssertEqual(snapshot(anchor: anchor).recomputed(for: later, calendar: cal).cycleDay, 6, "TZ \(tzID)")
        }
    }

    func testRecomputeAcrossDSTSpringForward() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!   // DST begins 2026-03-08
        let anchor = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let snap = snapshot(anchor: anchor)
        let mar7 = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let mar9 = cal.date(from: DateComponents(year: 2026, month: 3, day: 9))!
        XCTAssertEqual(snap.recomputed(for: mar7, calendar: cal).cycleDay, 7)
        XCTAssertEqual(snap.recomputed(for: mar9, calendar: cal).cycleDay, 9, "Day count must survive the DST transition")
    }

    func testRecomputeAcrossLeapDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let anchor = cal.date(from: DateComponents(year: 2028, month: 2, day: 26))! // 2028 is a leap year
        let mar2 = cal.date(from: DateComponents(year: 2028, month: 3, day: 2))!    // 26→Mar2 spans Feb 29 = 5 days
        XCTAssertEqual(snapshot(anchor: anchor, cycleLength: 30).recomputed(for: mar2, calendar: cal).cycleDay, 6)
    }

    func testRecomputeAcrossYearBoundary() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let anchor = cal.date(from: DateComponents(year: 2026, month: 12, day: 28))!
        let jan3 = cal.date(from: DateComponents(year: 2027, month: 1, day: 3))!     // +6 days across New Year
        XCTAssertEqual(snapshot(anchor: anchor).recomputed(for: jan3, calendar: cal).cycleDay, 7)
    }

    func testRecomputeDaysUntilPeriodNonNegativeAcrossTimeZones() {
        for tzID in ["Asia/Tokyo", "Pacific/Kiritimati", "America/Los_Angeles"] {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: tzID)!
            let anchor = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
            let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 20))!
            let r = snapshot(anchor: anchor).recomputed(for: now, calendar: cal)
            XCTAssertGreaterThanOrEqual(r.daysUntilPeriod, 0, "TZ \(tzID)")
            XCTAssertLessThanOrEqual(r.daysUntilPeriod, 28, "TZ \(tzID)")
        }
    }

    // MARK: - Review fixes: anchor recovery + fertility parity

    /// HIGH fix: undoing today's period log must recover the prior baseline, not nil it.
    /// mostRecentPeriodStart is the fallback that recovers the anchor from flow history.
    func testMostRecentPeriodStartFindsStreakStart() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let priorStart = cal.date(byAdding: .day, value: -28, to: today)!
        let entries: [CycleEntry] = [
            CycleEntry(date: priorStart, flow: .medium),
            CycleEntry(date: cal.date(byAdding: .day, value: 1, to: priorStart)!, flow: .light)
        ]
        XCTAssertEqual(PredictionEngine.mostRecentPeriodStart(from: entries, today: today), priorStart)
    }

    func testMostRecentPeriodStartNilWhenNoFlow() {
        let entries = [CycleEntry(date: .now, mood: .calm)]   // no flow
        XCTAssertNil(PredictionEngine.mostRecentPeriodStart(from: entries))
    }

    func testMostRecentPeriodStartExcludesFutureFlow() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let future = cal.date(byAdding: .day, value: 5, to: today)!
        let entries = [CycleEntry(date: future, flow: .medium)]
        XCTAssertNil(PredictionEngine.mostRecentPeriodStart(from: entries, today: today),
                     "Future-dated flow must not become the recovered anchor")
    }

    /// Review fix: watch/widget fertility status aligns with the app's date-based
    /// fertile window (ovulation cycle day = cycleLength − 13).
    func testFertilityStatusMatchesDateBasedFertileWindow() {
        let cal = Calendar.current
        let cycleLength = 28
        let lastStart = cal.startOfDay(for: cal.date(byAdding: .day, value: -2, to: .now)!)
        let today = cal.startOfDay(for: .now)
        let nextStart = PredictionEngine.nextPeriodStart(lastPeriodStart: lastStart, today: today, cycleLength: cycleLength)
        let fertile = PredictionEngine.fertileWindow(nextPeriodStart: nextStart)
        let ovulationDate = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart)
        func cycleDay(_ d: Date) -> Int {
            let days = cal.dateComponents([.day], from: lastStart, to: cal.startOfDay(for: d)).day ?? 0
            return ((days % cycleLength + cycleLength) % cycleLength) + 1
        }
        XCTAssertEqual(WidgetCycleMath.fertilityStatus(cycleDay: cycleDay(ovulationDate), cycleLength: cycleLength), "ovulation")
        XCTAssertEqual(WidgetCycleMath.fertilityStatus(cycleDay: cycleDay(fertile.lowerBound), cycleLength: cycleLength), "fertile")
    }

    // MARK: - Phase 4 (int-1): adaptive prediction engine

    func testAverageCycleLengthClampedToRealisticBounds() {
        let longCycles = [Cycle(start: .now, length: 90, periodLength: 5), Cycle(start: .now, length: 90, periodLength: 5)]
        XCTAssertEqual(PredictionEngine.averageCycleLength(of: longCycles, fallback: 28), 45, "clamped to max 45")
        let shortCycles = [Cycle(start: .now, length: 5, periodLength: 2), Cycle(start: .now, length: 5, periodLength: 2)]
        XCTAssertEqual(PredictionEngine.averageCycleLength(of: shortCycles, fallback: 28), 18, "clamped to min 18")
    }

    func testCycleLengthVariationRoundsNotTruncates() {
        // spread 15 (21…36) → 7.5 → rounds to 8 (was truncated to 7).
        let cycles = [Cycle(start: .now, length: 21, periodLength: 5), Cycle(start: .now, length: 36, periodLength: 5)]
        XCTAssertEqual(PredictionEngine.cycleLengthVariation(of: cycles), 8)
    }

    func testLearnedLutealLengthFromLHSignals() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: cal.date(byAdding: .day, value: -120, to: .now)!)
        var cycles: [Cycle] = []
        var entries: [CycleEntry] = []
        for i in 0..<3 {
            let start = cal.date(byAdding: .day, value: i * 28, to: base)!
            cycles.append(Cycle(start: start, length: 28, periodLength: 5))
            let lhDay = cal.date(byAdding: .day, value: 15, to: start)!   // luteal = 28 − 15 = 13
            let e = CycleEntry(date: lhDay)
            e.ovulationTestResult = .positive
            entries.append(e)
        }
        XCTAssertEqual(PredictionEngine.learnedLutealLength(entries: entries, cycles: cycles), 13)
    }

    func testLearnedLutealLengthNilWithoutEnoughSignals() {
        let cycles = [Cycle(start: .now, length: 28, periodLength: 5)]
        XCTAssertNil(PredictionEngine.learnedLutealLength(entries: [], cycles: cycles))
    }

    func testLearnedLutealShiftsOvulationEstimate() {
        let cal = Calendar.current
        let nextStart = cal.startOfDay(for: cal.date(byAdding: .day, value: 10, to: .now)!)
        let def = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart)                       // −14
        let learned = PredictionEngine.ovulationEstimate(nextPeriodStart: nextStart, lutealLength: 12) // −12
        XCTAssertEqual(cal.dateComponents([.day], from: def, to: learned).day, 2)
    }

    // MARK: - Phase 4 (int-2): lag-aware cross-metric correlation

    func testSymptomLeadTimeCorrelation() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: cal.date(byAdding: .day, value: -120, to: .now)!)
        var cycles: [Cycle] = []
        var entries: [CycleEntry] = []
        for i in 0..<3 {
            let start = cal.date(byAdding: .day, value: i * 28, to: base)!
            cycles.append(Cycle(start: start, length: 28, periodLength: 5))
            // Headache consistently 2 days before the next period start.
            let day = cal.date(byAdding: .day, value: 26, to: start)!
            entries.append(CycleEntry(date: day, symptoms: [.headache]))
        }
        let results = PatternEngine.insights(from: entries, cycles: cycles, profile: UserProfile())
        XCTAssertTrue(
            results.contains { ($0.supportingValue?.contains("~2d") ?? false) },
            "Expected a ~2-day lead-time correlation insight"
        )
    }

    // MARK: - Phase 4 (int-5): condition-mode insights

    func testConditionInsightsSurfaceForEnabledModes() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: cal.date(byAdding: .day, value: -90, to: .now)!)
        let cycles = [
            Cycle(start: base, length: 28, periodLength: 5),
            Cycle(start: cal.date(byAdding: .day, value: 28, to: base)!, length: 30, periodLength: 5)
        ]
        let profile = UserProfile()
        profile.pcosEnabled = true
        let results = PatternEngine.insights(from: [], cycles: cycles, profile: profile)
        XCTAssertTrue(results.contains { $0.category == .condition }, "PCOS mode should surface a condition insight")

        let noMode = UserProfile()
        let none = PatternEngine.insights(from: [], cycles: cycles, profile: noMode)
        XCTAssertFalse(none.contains { $0.category == .condition }, "No condition insight without an enabled mode")
    }

    // MARK: - Phase 4 (int-3): wrist-temp biphasic shift

    func testWristTempBiphasicShiftDetected() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: cal.date(byAdding: .day, value: -20, to: .now)!)
        let temps = [36.30, 36.32, 36.28, 36.31, 36.29, 36.33, 36.58, 36.60, 36.62, 36.59]
        let series = temps.enumerated().map { (i, t) in
            (date: cal.date(byAdding: .day, value: i, to: base)!, temp: t)
        }
        let r = WristTempOvulationEngine.detectShift(in: series)
        XCTAssertTrue(r.detected)
        XCTAssertEqual(r.shiftDate, cal.date(byAdding: .day, value: 6, to: base))
        XCTAssertEqual(r.estimatedOvulation, cal.date(byAdding: .day, value: 5, to: base))
    }

    func testWristTempNoShiftOnFlatSeries() {
        let cal = Calendar.current
        let base = cal.startOfDay(for: .now)
        let series = (0..<12).map { (date: cal.date(byAdding: .day, value: $0, to: base)!, temp: 36.3) }
        XCTAssertFalse(WristTempOvulationEngine.detectShift(in: series).detected)
    }

    // MARK: - Phase 4 (int-4): on-device summary fallback

    func testCycleSummaryFallbackProducesUsableText() {
        let facts = CycleSummaryService.Facts(
            avgCycle: 29, avgPeriod: 5, variation: 2,
            phaseName: "Luteal", cycleDay: 22, daysUntilPeriod: 7,
            topInsight: "Headache tends to appear ~2 days before your period."
        )
        let text = CycleSummaryService.fallback(facts: facts)
        XCTAssertTrue(text.contains("day 22"))
        XCTAssertTrue(text.contains("luteal"))
        XCTAssertTrue(text.contains("7 day"))
        XCTAssertFalse(text.isEmpty)
    }

    // MARK: - Phase 5: secure wipe

    func testSecureWipeClearsSwiftData() async throws {
        context.insert(CycleEntry(date: .now, flow: .medium))
        context.insert(UserProfile())
        try context.save()
        await SecureWipeService.wipeEverything(modelContext: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<CycleEntry>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 0)
    }

    // MARK: - Phase 5: PIN hashing + auto-sweep window

    func testPINHashIsDeterministicAndSaltSensitive() {
        let salt1 = Data(repeating: 7, count: 32)
        let salt2 = Data(repeating: 9, count: 32)
        XCTAssertEqual(PINService.hash("1234", salt: salt1), PINService.hash("1234", salt: salt1))
        XCTAssertNotEqual(PINService.hash("1234", salt: salt1), PINService.hash("1234", salt: salt2), "salt must change the hash")
        XCTAssertNotEqual(PINService.hash("1234", salt: salt1), PINService.hash("9999", salt: salt1), "different PIN → different hash")
        XCTAssertEqual(PINService.hash("1234", salt: salt1).count, 32, "SHA-256 is 32 bytes")
    }

    func testAutoSweepWindow() {
        let cal = Calendar.current
        let last = cal.startOfDay(for: cal.date(byAdding: .day, value: -40, to: .now)!)
        let now = Date()
        XCTAssertTrue(AutoSweepService.shouldSweep(autoWipeEnabled: true, autoWipeAfterDays: 30, lastActiveAt: last, now: now))
        XCTAssertFalse(AutoSweepService.shouldSweep(autoWipeEnabled: true, autoWipeAfterDays: 60, lastActiveAt: last, now: now))
        XCTAssertFalse(AutoSweepService.shouldSweep(autoWipeEnabled: false, autoWipeAfterDays: 1, lastActiveAt: last, now: now))
    }

    // MARK: - Phase 6: iCloud sync is opt-in (off by default)

    func testSyncIsOptInByDefault() {
        UserDefaults.standard.removeObject(forKey: Persistence.syncEnabledKey)
        XCTAssertFalse(Persistence.isSyncEnabled, "iCloud sync must be OFF on a fresh install — the privacy default")
    }

    // MARK: - Note-to-self reminder resolver

    func testNoteReminderFireDate() {
        let cal = Calendar.current
        let next = cal.date(byAdding: .day, value: 10, to: cal.startOfDay(for: .now))!

        let before = NoteReminder.fireDate(rule: .beforePeriod, chosenDate: nil, nextPeriodStart: next)
        XCTAssertNotNil(before)
        let gap = cal.dateComponents([.day], from: cal.startOfDay(for: before!), to: cal.startOfDay(for: next)).day
        XCTAssertEqual(gap, 2, "beforePeriod resolves to 2 days before the predicted period")

        let at = NoteReminder.fireDate(rule: .atPeriod, chosenDate: nil, nextPeriodStart: next)
        XCTAssertTrue(cal.isDate(at!, inSameDayAs: next), "atPeriod resolves to the period day")

        let chosen = cal.date(byAdding: .day, value: 3, to: .now)!
        XCTAssertEqual(NoteReminder.fireDate(rule: .date, chosenDate: chosen, nextPeriodStart: nil), chosen)

        // No prediction yet → cycle-relative rules resolve to nil (nothing scheduled).
        XCTAssertNil(NoteReminder.fireDate(rule: .beforePeriod, chosenDate: nil, nextPeriodStart: nil))
        XCTAssertNil(NoteReminder.fireDate(rule: .atPeriod, chosenDate: nil, nextPeriodStart: nil))
    }

    // MARK: - Tutor: TypicalRanges ("Is this normal?")

    func testTypicalRangesCycleLength() {
        XCTAssertEqual(TypicalRanges.cycleLength(28).status, .inRange)
        XCTAssertEqual(TypicalRanges.cycleLength(21).status, .inRange)
        XCTAssertEqual(TypicalRanges.cycleLength(35).status, .inRange)
        if case .watch = TypicalRanges.cycleLength(40).status {} else { XCTFail("40-day adult cycle should be a gentle 'watch'") }
        // Gentle mode widens the reassuring range to 45.
        XCTAssertEqual(TypicalRanges.cycleLength(40, gentle: true).status, .inRange)
        // Unknown data never looks broken.
        XCTAssertEqual(TypicalRanges.cycleLength(nil).status, .learning)
        XCTAssertFalse(TypicalRanges.cycleLength(nil).known)
        // Never uses the word "abnormal".
        XCTAssertFalse(TypicalRanges.cycleLength(40).status.text.lowercased().contains("abnormal"))
    }

    func testTypicalRangesPeriodAndPain() {
        XCTAssertEqual(TypicalRanges.periodLength(5).status, .inRange)
        if case .watch = TypicalRanges.periodLength(9).status {} else { XCTFail("9-day period should be a 'watch'") }
        XCTAssertNil(TypicalRanges.pain(nil), "no pain logged → no pain row")
        XCTAssertNil(TypicalRanges.pain(0))
        XCTAssertEqual(TypicalRanges.pain(4)?.status, .inRange)
        if case .watch = TypicalRanges.pain(9)?.status {} else { XCTFail("severe pain should encourage a doctor chat") }
    }

    func testGuideQuestionsPhaseFirstAndProviderForward() {
        let qs = GuideQuestions.forToday(phase: .pms, avgCycle: 29, variation: 3, gentle: false)
        XCTAssertFalse(qs.isEmpty)
        XCTAssertEqual(qs.first?.id, "mood-low", "PMS-relevant question should sort first")
        // The safety-net "when to see a doctor" question is always present.
        XCTAssertTrue(qs.contains { $0.id == "see-doctor" })
        // Her real number is woven into the length answer.
        XCTAssertTrue(qs.contains { $0.answer.contains("29 days") })
    }

    func testGentleModeWidensReassurance() {
        // The "normal cycle" answer adapts to gentle (first-years) framing.
        let adult = GuideQuestions.forToday(phase: .unknown, avgCycle: 30, variation: 3, gentle: false)
        let teen = GuideQuestions.forToday(phase: .unknown, avgCycle: 30, variation: 3, gentle: true)
        XCTAssertTrue(adult.first { $0.id == "normal-length" }!.answer.contains("21 to 35"))
        XCTAssertTrue(teen.first { $0.id == "normal-length" }!.answer.contains("45"))
    }

    // MARK: - Tutor: daily teaching line

    func testDailyTeachingFallback() {
        let luteal = CycleSummaryService.TeachingFacts(
            phase: .luteal, cycleDay: 22, cycleCount: 5,
            topPatternLine: "You've logged low energy here in 4 of 5 cycles.", gentle: false)
        let line = CycleSummaryService.teachingFallback(facts: luteal)
        XCTAssertTrue(line.contains("Day 22"))
        XCTAssertTrue(line.contains("4 of 5"))
        XCTAssertTrue(line.contains("your pattern, not a flaw"))

        // Gentle variant softens the framing.
        let gentle = CycleSummaryService.teachingFallback(facts:
            .init(phase: .menstrual, cycleDay: 2, cycleCount: 3, topPatternLine: nil, gentle: true))
        XCTAssertTrue(gentle.lowercased().contains("rest and warmth"))
    }

    func testDailyTeachingNilAtColdStartAndUnknown() async {
        let none = await CycleSummaryService.dailyTeaching(facts:
            .init(phase: .luteal, cycleDay: 22, cycleCount: 0, topPatternLine: nil, gentle: false))
        XCTAssertNil(none, "with <1 cycle the caller keeps the static phase hint")
        let unknown = await CycleSummaryService.dailyTeaching(facts:
            .init(phase: .unknown, cycleDay: 1, cycleCount: 3, topPatternLine: nil, gentle: false))
        XCTAssertNil(unknown, "unknown phase → no teaching line")
    }

    // MARK: - Stand-out plan: CSV import (Switch Kit)

    func testImportRoundTripsCaelynCSV() throws {
        let cal = Calendar.current
        let day = cal.startOfDay(for: cal.date(byAdding: .day, value: -40, to: .now)!)
        let e = CycleEntry(date: day, flow: .heavy, pain: 6, painTypes: [.cramps],
                           symptoms: [.headache, .bloating], mood: .irritable,
                           note: "rough day, extra \"quotes\" and, commas")
        e.basalTemperature = 36.42
        e.cervicalMucus = .eggWhite
        e.sexualActivity = true
        e.ovulationTestResult = .positive
        e.pregnancyTest = false
        context.insert(e)
        try context.save()

        let csv = ExportService.generateCSV(entries: [e], includeNotes: true)
        try context.delete(model: CycleEntry.self)
        try context.save()

        let result = try ImportService.importCSV(text: csv, into: context)
        XCTAssertEqual(result.entriesCreated, 1)
        let imported = try context.fetch(FetchDescriptor<CycleEntry>())
        XCTAssertEqual(imported.count, 1)
        let i = imported[0]
        XCTAssertEqual(i.flow, .heavy)
        XCTAssertEqual(i.pain, 6)
        XCTAssertEqual(Set(i.symptoms), Set([.headache, .bloating]))
        XCTAssertEqual(i.mood, .irritable)
        XCTAssertEqual(i.basalTemperature ?? 0, 36.42, accuracy: 0.001)
        XCTAssertEqual(i.cervicalMucus, .eggWhite)
        XCTAssertEqual(i.sexualActivity, true)
        XCTAssertEqual(i.ovulationTestResult, .positive)
        XCTAssertEqual(i.pregnancyTest, false)
        XCTAssertEqual(i.note, "rough day, extra \"quotes\" and, commas")
        XCTAssertEqual(cal.startOfDay(for: i.date), day)
    }

    func testImportGenericAppCSV() throws {
        let csv = """
        Date,Period Intensity,Notes
        2025-03-02,heavy,whatever
        2025-03-03,medium,
        2025-03-04,LIGHT,
        2025-03-20,,
        """
        let result = try ImportService.importCSV(text: csv, into: context)
        XCTAssertEqual(result.entriesCreated, 3, "three rows carry usable flow data")
        XCTAssertEqual(result.rowsSkipped, 1, "the empty-flow row is skipped, not fabricated")
        let flows = try context.fetch(FetchDescriptor<CycleEntry>())
            .sorted { $0.date < $1.date }
            .compactMap(\.flow)
        XCTAssertEqual(flows, [.heavy, .medium, .light])
    }

    func testImportNeverOverwritesLoggedData() throws {
        let day = Calendar.current.startOfDay(for: .now)
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        context.insert(CycleEntry(date: day, flow: .light))
        try context.save()

        let csv = "date,period\n\(f.string(from: day)),heavy"
        XCTAssertThrowsError(try ImportService.importCSV(text: csv, into: context),
                             "a row that can't change anything imports nothing")
        let all = try context.fetch(FetchDescriptor<CycleEntry>())
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].flow, .light, "import must never overwrite hand-logged data")
    }

    // MARK: - Stand-out plan: streak grace (S6)

    func testLoggingStreakGrace() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func logged(_ daysAgo: Int) -> CycleEntry {
            let e = CycleEntry(date: cal.date(byAdding: .day, value: -daysAgo, to: today)!)
            e.mood = .calm
            return e
        }
        // Today unlogged: the day isn't over — yesterday's run still counts.
        XCTAssertEqual(CycleAnalytics.loggingStreak(in: [logged(1), logged(2)], today: today), 2)
        // A single missed day freezes the streak instead of resetting it.
        XCTAssertEqual(CycleAnalytics.loggingStreak(in: [logged(1), logged(2), logged(4), logged(5)], today: today), 4)
        // Two consecutive missed days do end the run.
        XCTAssertEqual(CycleAnalytics.loggingStreak(in: [logged(1), logged(4)], today: today), 1)
    }

    // MARK: - Stand-out plan: free-tier caps (S1)

    func testFreeTierCaps() {
        XCTAssertEqual(PatternInsightsSection.freeInsightCap, 5, "free users see up to 5 insights")
    }

    // MARK: - Phase 6 hardening: same-day dedup (post .unique removal)

    func testDedupeMergesSameDayDuplicates() throws {
        let day = Calendar.current.startOfDay(for: .now)
        let a = CycleEntry(date: day)
        a.flow = .medium
        a.pain = 3
        a.symptoms = [.cramps]
        a.createdAt = Date(timeIntervalSince1970: 100)
        a.updatedAt = Date(timeIntervalSince1970: 100)
        let b = CycleEntry(date: day)          // same calendar day, created later
        b.symptoms = [.headache]
        b.basalTemperature = 36.5
        b.createdAt = Date(timeIntervalSince1970: 200)
        b.updatedAt = Date(timeIntervalSince1970: 200)
        context.insert(a)
        context.insert(b)
        try context.save()

        let removed = CycleStore.dedupeSameDay(in: context)
        XCTAssertEqual(removed, 1, "one duplicate should be merged away")
        let remaining = try context.fetch(FetchDescriptor<CycleEntry>())
        XCTAssertEqual(remaining.count, 1, "exactly one entry per day survives")
        let merged = remaining[0]
        XCTAssertEqual(merged.flow, .medium)
        XCTAssertEqual(merged.pain, 3)
        XCTAssertEqual(merged.basalTemperature, 36.5)
        XCTAssertEqual(Set(merged.symptoms), Set([.cramps, .headache]), "symptoms are unioned, not lost")
    }
}
