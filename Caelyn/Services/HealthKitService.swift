import Foundation
import HealthKit
import SwiftData

enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case authorizationFailed(String)
    case writeFailed(String)
    case readFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:                return "Apple Health isn't available on this device."
        case .authorizationFailed(let s):  return s
        case .writeFailed(let s):          return s
        case .readFailed(let s):           return s
        }
    }
}

struct ImportResult {
    let entriesCreated: Int
    let entriesUpdated: Int
    /// Values Apple Health also had, where Caelyn kept what she had logged
    /// herself. Reported so an import can be honest about what it left alone.
    var keptYourValue: Int = 0
    var total: Int { entriesCreated + entriesUpdated }
}

@MainActor
enum HealthKitService {

    // HealthKit delivers query callbacks on its own queues. HKHealthStore is
    // designed to be shared across those callbacks, so this reference must not
    // inherit the service's MainActor isolation.
    nonisolated private static let store = HKHealthStore()

    /// The same store, for the read pipeline in `Services/Health/`. Exposed rather
    /// than duplicated: `HKHealthStore` is designed to be shared, and two stores
    /// would mean two independent authorization caches.
    nonisolated static var sharedStore: HKHealthStore { store }

    // MARK: - Type catalog

    static var menstrualFlowType: HKCategoryType {
        HKCategoryType(.menstrualFlow)
    }

    /// Caelyn symptoms that map to HK category types. Cravings (no good HK match)
    /// is intentionally absent.
    static let symptomCategoryMap: [Symptom: HKCategoryType] = [
        .bloating:      HKCategoryType(.bloating),
        .acne:          HKCategoryType(.acne),
        .fatigue:       HKCategoryType(.fatigue),
        .nausea:        HKCategoryType(.nausea),
        .dizziness:     HKCategoryType(.dizziness),
        .sleepChanges:  HKCategoryType(.sleepChanges),
        .tenderBreasts: HKCategoryType(.breastPain),
        .headache:      HKCategoryType(.headache),
        .backPain:      HKCategoryType(.lowerBackPain),
        .cramps:        HKCategoryType(.abdominalCramps)
    ]

    /// Pain types that also live in HealthKit.
    static let painCategoryMap: [PainType: HKCategoryType] = [
        .cramps:           HKCategoryType(.abdominalCramps),
        .backPain:         HKCategoryType(.lowerBackPain),
        .headache:         HKCategoryType(.headache),
        .breastTenderness: HKCategoryType(.breastPain),
        .pelvicPain:       HKCategoryType(.pelvicPain)
    ]

    static var allWritableTypes: Set<HKSampleType> {
        var set: Set<HKSampleType> = [menstrualFlowType]
        for type in symptomCategoryMap.values { set.insert(type) }
        for type in painCategoryMap.values { set.insert(type) }
        return set
    }

    /// Everything Caelyn asks to read. Defined by `HealthDataCatalog`, which is
    /// also what the merge engine maps from — so a type can never be requested
    /// without somewhere for its values to land.
    static var allReadableTypes: Set<HKObjectType> {
        HealthDataCatalog.allReadTypes
    }

    // MARK: - Availability + Auth

    /// True only if BOTH the device supports HealthKit AND this build is configured
    /// for it (entitlement + privacy strings present). Without the privacy string,
    /// requestAuthorization will fail at runtime — better to disable the entry point.
    static var isAvailable: Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let info = Bundle.main.infoDictionary
        let hasShareString = info?["NSHealthShareUsageDescription"] != nil
        let hasUpdateString = info?["NSHealthUpdateUsageDescription"] != nil
        return hasShareString && hasUpdateString
    }

    /// Read-only authorization, for the onboarding import. That screen only ever
    /// offers to READ existing history, so asking to write twelve categories there
    /// (acne, pelvic pain, and the rest) is disproportionate to what it promises.
    /// Writing is requested later, from Settings, where the user opts into sync.
    static func requestReadAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        do {
            try await store.requestAuthorization(toShare: [], read: allReadableTypes)
        } catch {
            throw HealthKitError.authorizationFailed(error.localizedDescription)
        }
    }

    /// Trigger the iOS permission dialog for Caelyn's HK types.
    /// Apple does not tell us what the user picked; we proceed and gracefully handle write failures.
    static func requestAuthorization() async throws {
        guard isAvailable else { throw HealthKitError.notAvailable }
        do {
            try await store.requestAuthorization(toShare: allWritableTypes, read: allReadableTypes)
        } catch {
            throw HealthKitError.authorizationFailed(error.localizedDescription)
        }
    }

    /// Probe-style check: are we authorized to write menstrual flow at all?
    /// Used purely as a status hint — not a substitute for handling write errors.
    static func canWriteMenstrualFlow() -> Bool {
        store.authorizationStatus(for: menstrualFlowType) == .sharingAuthorized
    }

    // MARK: - Wrist temperature (int-3)

    /// Apple Watch sleeping wrist-temperature samples (°C) in [start, end], sorted
    /// ascending. Returns empty when HealthKit is unavailable, unauthorized, or no
    /// samples exist (e.g. no temperature-capable Apple Watch).
    static func fetchWristTemperatures(from start: Date, to end: Date) async -> [(date: Date, temp: Double)] {
        guard isAvailable,
              let type = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature)
        else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        return await withCheckedContinuation { (cont: CheckedContinuation<[(date: Date, temp: Double)], Never>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, _ in
                let out = (samples as? [HKQuantitySample] ?? []).map {
                    (date: $0.startDate, temp: $0.quantity.doubleValue(for: .degreeCelsius()))
                }
                cont.resume(returning: out)
            }
            store.execute(query)
        }
    }

    // MARK: - Backfill: Caelyn → Health

    /// Write all logged flow days to Health, marking the first day of each
    /// streak as a cycle start (HKMetadataKeyMenstrualCycleStart).
    /// Deletes all existing Caelyn-written flow samples first to prevent duplicates.
    @discardableResult
    static func backfillFlowToHealth(entries: [CycleEntry]) async throws -> Int {
        guard isAvailable else { throw HealthKitError.notAvailable }

        // Delete all existing samples we wrote before re-writing to avoid duplicates.
        await deleteAllOwnFlowSamples()

        let flowEntries = entries
            .filter { $0.flow != nil }
            .sorted { $0.date < $1.date }

        var samples: [HKCategorySample] = []
        let cal = Calendar.current
        var prevDate: Date?

        for entry in flowEntries {
            guard let flow = entry.flow else { continue }
            let isStart: Bool = {
                guard let prev = prevDate else { return true }
                let dayDiff = cal.dateComponents([.day], from: prev, to: entry.date).day ?? 0
                return dayDiff > 1
            }()
            samples.append(makeFlowSample(date: entry.date, flow: flow, isCycleStart: isStart))
            prevDate = entry.date
        }

        guard !samples.isEmpty else { return 0 }
        do {
            try await store.save(samples)
            return samples.count
        } catch {
            throw HealthKitError.writeFailed(error.localizedDescription)
        }
    }

    /// Delete EVERY Caelyn-authored sample (flow + symptoms + pain) from Apple
    /// Health — used by the secure wipe. Only removes samples this app wrote.
    static func deleteAllOwnSamples() async {
        guard isAvailable else { return }
        await deleteAllOwnFlowSamples()
        await deleteAllOwnSymptomSamples()
    }

    private static func deleteAllOwnFlowSamples() async {
        guard isAvailable else { return }
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: menstrualFlowType,
                predicate: nil,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let ours = (samples as? [HKCategorySample] ?? [])
                    .filter { $0.sourceRevision.source.bundleIdentifier == bundleID }
                guard !ours.isEmpty else { continuation.resume(); return }
                store.delete(ours) { _, _ in continuation.resume() }
            }
            store.execute(query)
        }
    }

    /// Removes every symptom + pain category sample *this app* wrote, across all
    /// dates. Used before a full symptom backfill so re-running it can't create
    /// duplicates. Only deletes samples whose source bundle ID matches ours —
    /// never samples the user added manually in Health.
    private static func deleteAllOwnSymptomSamples() async {
        guard isAvailable else { return }
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let types = Array(Set(Array(symptomCategoryMap.values) + Array(painCategoryMap.values)))
        await withTaskGroup(of: Void.self) { group in
            for type in types {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        let query = HKSampleQuery(
                            sampleType: type,
                            predicate: nil,
                            limit: HKObjectQueryNoLimit,
                            sortDescriptors: nil
                        ) { _, samples, _ in
                            let ours = (samples as? [HKCategorySample] ?? [])
                                .filter { $0.sourceRevision.source.bundleIdentifier == bundleID }
                            guard !ours.isEmpty else { continuation.resume(); return }
                            store.delete(ours) { _, _ in continuation.resume() }
                        }
                        store.execute(query)
                    }
                }
            }
        }
    }

    /// Write all symptom + pain entries to Health, mapping pain levels to severity.
    @discardableResult
    static func backfillSymptomsToHealth(entries: [CycleEntry]) async throws -> Int {
        guard isAvailable else { throw HealthKitError.notAvailable }
        // Remove our previously-written samples first so re-running Backfill can't
        // duplicate symptom/pain samples in Health (mirrors the flow path) (stz-015).
        await deleteAllOwnSymptomSamples()
        var samples: [HKCategorySample] = []
        for entry in entries {
            samples.append(contentsOf: symptomSamples(from: entry))
        }
        guard !samples.isEmpty else { return 0 }
        do {
            try await store.save(samples)
            return samples.count
        } catch {
            throw HealthKitError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Single-entry sync

    /// Write the latest version of one entry to Health. Caller passes the full
    /// entries list so we can determine if this entry is a cycle start.
    /// When flow is nil (cleared), removes any Caelyn-written flow sample for
    /// that date so HealthKit stays in sync with the user's actual log.
    static func syncEntryToHealth(_ entry: CycleEntry, in entries: [CycleEntry], profile: UserProfile) async {
        guard profile.healthKitConnected, isAvailable else { return }

        var samples: [HKCategorySample] = []

        if profile.hkWriteFlow {
            if let flow = entry.flow {
                let isStart = isCycleStart(for: entry, in: entries)
                samples.append(makeFlowSample(date: entry.date, flow: flow, isCycleStart: isStart))
            } else {
                await deleteOwnFlowSamples(on: entry.date)
            }
        }
        if profile.hkWriteSymptoms {
            // Delete-then-rewrite: removes any stale samples for symptoms the
            // user may have unchecked since the last sync.
            await deleteOwnSymptomSamples(on: entry.date)
            samples.append(contentsOf: symptomSamples(from: entry))
        }

        guard !samples.isEmpty else { return }
        try? await store.save(samples)
    }

    /// Removes any menstrual-flow samples *this app* wrote for the given date.
    /// Only deletes samples whose source bundle ID matches ours — never touches
    /// samples the user added manually in the Health app.
    static func deleteOwnFlowSamples(on date: Date) async {
        guard isAvailable else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(
                sampleType: menstrualFlowType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let bundleID = Bundle.main.bundleIdentifier ?? ""
                let ours = (samples as? [HKCategorySample] ?? [])
                    .filter { $0.sourceRevision.source.bundleIdentifier == bundleID }
                guard !ours.isEmpty else { continuation.resume(); return }
                store.delete(ours) { _, _ in continuation.resume() }
            }
            store.execute(query)
        }
    }

    /// Removes all symptom + pain category samples *this app* wrote for the given date.
    /// Queries each mapped HK type in parallel, filtered by bundle ID.
    static func deleteOwnSymptomSamples(on date: Date) async {
        guard isAvailable else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let bundleID = Bundle.main.bundleIdentifier ?? ""

        // Deduplicate types shared between the two maps (cramps, backPain, headache)
        let types = Array(Set(Array(symptomCategoryMap.values) + Array(painCategoryMap.values)))

        await withTaskGroup(of: Void.self) { group in
            for type in types {
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        let query = HKSampleQuery(
                            sampleType: type,
                            predicate: predicate,
                            limit: HKObjectQueryNoLimit,
                            sortDescriptors: nil
                        ) { _, samples, _ in
                            let ours = (samples as? [HKCategorySample] ?? [])
                                .filter { $0.sourceRevision.source.bundleIdentifier == bundleID }
                            guard !ours.isEmpty else { continuation.resume(); return }
                            store.delete(ours) { _, _ in continuation.resume() }
                        }
                        store.execute(query)
                    }
                }
            }
        }
    }

    // MARK: - Import: Health → Caelyn

    /// Import her period history from Apple Health.
    ///
    /// Delegates to the merge engine rather than writing directly, which is what
    /// makes it safe: a day she has already logged herself is never overwritten by
    /// whatever another app put in Health for the same day. Caelyn's own past
    /// samples are accepted here on purpose — after a reinstall they are the only
    /// surviving copy of her history.
    @discardableResult
    static func importFlowFromHealth(
        into context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) async throws -> ImportResult {
        guard isAvailable else { throw HealthKitError.notAvailable }
        let samples = try await fetchAllMenstrualFlowSamples()
        let observations = samples.compactMap { HealthDataCatalog.observation(from: $0, calendar: calendar) }

        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for entry in entries { byDay[calendar.startOfDay(for: entry.date)] = entry }

        let decisions = ImportReconciler.plan(
            observations: observations,
            currentValue: { day, field in byDay[calendar.startOfDay(for: day)]?.value(for: field) },
            ledger: ledger,
            ownBundleID: Bundle.main.bundleIdentifier ?? "",
            acceptOwnSource: true,
            calendar: calendar,
            today: today
        )
        let summary = ImportReconciler.commit(decisions, into: context, ledger: ledger, calendar: calendar).summary
        return ImportResult(
            entriesCreated: summary.filled,
            entriesUpdated: summary.updated,
            keptYourValue: summary.keptUserValue
        )
    }

    private static func fetchAllMenstrualFlowSamples() async throws -> [HKCategorySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: nil, end: nil)
            let query = HKSampleQuery(
                sampleType: menstrualFlowType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.readFailed(error.localizedDescription))
                    return
                }
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Mapping helpers (internal — exposed for tests)

    /// Same constant the read side matches on. Defined once, in the catalog, so
    /// the two halves of the round trip cannot drift apart.
    private static let metadataFlowLevelKey = HealthDataCatalog.flowLevelMetadataKey

    static func makeFlowSample(date: Date, flow: FlowLevel, isCycleStart: Bool) -> HKCategorySample {
        let value = mapFlowToHK(flow)
        let metadata: [String: Any] = [
            HKMetadataKeyMenstrualCycleStart: isCycleStart,
            metadataFlowLevelKey: flow.rawValue
        ]
        return HKCategorySample(
            type: menstrualFlowType,
            value: value.rawValue,
            start: date,
            end: date,
            metadata: metadata
        )
    }

    static func mapFlowToHK(_ flow: FlowLevel) -> HKCategoryValueMenstrualFlow {
        switch flow {
        case .spotting: return .light
        case .light:    return .light
        case .medium:   return .medium
        case .heavy:    return .heavy
        }
    }

    static func caelynFlow(fromSample sample: HKCategorySample) -> FlowLevel? {
        // Check our custom metadata key first — preserves spotting vs light distinction.
        if let rawString = sample.metadata?[metadataFlowLevelKey] as? String,
           let level = FlowLevel(rawValue: rawString) {
            return level
        }
        return caelynFlow(fromHKRawValue: sample.value)
    }

    static func caelynFlow(fromHKRawValue rawValue: Int) -> FlowLevel? {
        guard let hkValue = HKCategoryValueMenstrualFlow(rawValue: rawValue) else { return nil }
        switch hkValue {
        case .light:        return .light
        case .medium:       return .medium
        case .heavy:        return .heavy
        case .unspecified:  return nil
        case .none:         return nil
        @unknown default:   return nil
        }
    }

    static func severity(forPain pain: Int) -> HKCategoryValueSeverity {
        switch pain {
        case 0:     return .notPresent
        case 1...3: return .mild
        case 4...6: return .moderate
        default:    return .severe
        }
    }

    private static func symptomSamples(from entry: CycleEntry) -> [HKCategorySample] {
        var samples: [HKCategorySample] = []

        for symptom in entry.symptoms {
            guard let type = symptomCategoryMap[symptom] else { continue }
            let severityLevel = entry.symptomSeverity[symptom.rawValue] ?? 2
            let hkSeverity: HKCategoryValueSeverity = {
                switch severityLevel {
                case 1:  return .mild
                case 3:  return .severe
                default: return .moderate
                }
            }()
            samples.append(HKCategorySample(
                type: type,
                value: hkSeverity.rawValue,
                start: entry.date,
                end: entry.date
            ))
        }

        // Pain types — severity from pain level
        let painSeverity = entry.pain.map(severity(forPain:)) ?? .moderate
        guard painSeverity != .notPresent else { return samples }
        for painType in entry.painTypes {
            guard let type = painCategoryMap[painType] else { continue }
            samples.append(HKCategorySample(
                type: type,
                value: painSeverity.rawValue,
                start: entry.date,
                end: entry.date
            ))
        }

        return samples
    }

    private static func isCycleStart(for entry: CycleEntry, in entries: [CycleEntry]) -> Bool {
        let cal = Calendar.current
        let prevDay = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: entry.date)) ?? entry.date
        return !entries.contains { cal.isDate($0.date, inSameDayAs: prevDay) && $0.flow != nil }
    }
}
