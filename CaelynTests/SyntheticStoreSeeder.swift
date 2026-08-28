import SwiftData
import XCTest
@testable import Caelyn

/// Builds the Test 1 synthetic store as a real file, so it can be pushed straight
/// onto a device instead of being typed in by hand.
///
/// **This is a tool, not a test.** It does nothing unless `CAELYN_SEED_STORE` names
/// an output directory, so a normal suite run skips it entirely and the test count
/// is unaffected. It exists because Test 1 is about *synchronisation*, and hand-
/// entering the same seven days repeatedly is error-prone setup for a question the
/// tapping does not answer. The data-entry paths are already covered by the unit
/// suite.
///
/// Everything it writes is synthetic and deliberately recognisable.
@MainActor
final class SyntheticStoreSeeder: XCTestCase {

    func testSeedSyntheticStoreWhenRequested() throws {
        guard let outDir = ProcessInfo.processInfo.environment["CAELYN_SEED_STORE"] else {
            throw XCTSkip("Set CAELYN_SEED_STORE to emit a seeded store.")
        }

        let dir = URL(fileURLWithPath: outDir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appending(path: "default.store")
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }

        // Local store only. A seeded fixture must never talk to CloudKit.
        let config = ModelConfiguration(schema: Persistence.schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Persistence.schema, configurations: [config])
        let context = container.mainContext

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        func day(_ d: Int) -> Date {
            calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 3, day: d))!)
        }

        // --- The three "manual" days ---
        let mar1 = CycleEntry(date: day(1))
        mar1.date = day(1)
        mar1.flow = .heavy
        mar1.symptoms = [.cramps, .bloating]
        mar1.pain = 4
        mar1.mood = .sad
        mar1.note = "synthetic day one"
        context.insert(mar1)

        let mar2 = CycleEntry(date: day(2))
        mar2.date = day(2)
        mar2.flow = .medium
        mar2.symptoms = [.cramps]
        mar2.pain = 3
        context.insert(mar2)

        let mar3 = CycleEntry(date: day(3))
        mar3.date = day(3)
        mar3.flow = .light
        mar3.symptoms = [.fatigue]
        mar3.mood = .tired
        context.insert(mar3)

        // --- The four "imported" days, matching caelyn-synthetic-test.csv ---
        let mar4 = CycleEntry(date: day(4))
        mar4.date = day(4)
        mar4.flow = .spotting
        context.insert(mar4)

        let mar8 = CycleEntry(date: day(8))        // US DST spring-forward
        mar8.date = day(8)
        mar8.symptoms = [.headache]
        mar8.note = "synthetic dst boundary"
        context.insert(mar8)

        // The one value that cannot be created by tapping: she bled, amount unknown.
        let mar20 = CycleEntry(date: day(20))
        mar20.date = day(20)
        mar20.flow = .unspecified
        mar20.note = "synthetic unspecified flow"
        context.insert(mar20)

        let mar31 = CycleEntry(date: day(31))      // month end
        mar31.date = day(31)
        mar31.flow = .medium
        mar31.symptoms = [.cramps]
        mar31.note = "synthetic month end"
        context.insert(mar31)

        // --- Profile: onboarded, with the two synced settings under test ---
        let profile = UserProfile()
        profile.hasOnboarded = true
        profile.averageCycleLength = 31
        profile.averagePeriodLength = 6
        profile.firstDayOfWeek = 2                 // Monday
        // Deliberately no preferred name — Test 2 needs that question unanswered.
        profile.preferredName = nil
        profile.hasConfirmedPreferredName = false
        context.insert(profile)

        try context.save()

        let entries = try context.fetch(FetchDescriptor<CycleEntry>())
        XCTAssertEqual(entries.count, 7)
        XCTAssertEqual(entries.filter { $0.flow == .unspecified }.count, 1)
        print("SEEDED_STORE_AT: \(url.path)")
    }
}
