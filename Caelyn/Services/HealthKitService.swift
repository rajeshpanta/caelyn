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
    var total: Int { entriesCreated + entriesUpdated }
}

@MainActor
enum HealthKitService {

    private static let store = HKHealthStore()

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

    static var allReadableTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = [menstrualFlowType]
        for type in symptomCategoryMap.values { set.insert(type) }
        for type in painCategoryMap.values { set.insert(type) }
        return set
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

    // MARK: - Backfill: Caelyn → Health

    /// Write all logged flow days to Health, marking the first day of each
    /// streak as a cycle start (HKMetadataKeyMenstrualCycleStart).
    @discardableResult
    static func backfillFlowToHealth(entries: [CycleEntry]) async throws -> Int {
        guard isAvailable else { throw HealthKitError.notAvailable }
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

    /// Write all symptom + pain entries to Health, mapping pain levels to severity.
    @discardableResult
    static func backfillSymptomsToHealth(entries: [CycleEntry]) async throws -> Int {
        guard isAvailable else { throw HealthKitError.notAvailable }
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
    static func syncEntryToHealth(_ entry: CycleEntry, in entries: [CycleEntry], profile: UserProfile) async {
        guard profile.healthKitConnected, isAvailable else { return }

        var samples: [HKCategorySample] = []

        if profile.hkWriteFlow, let flow = entry.flow {
            let isStart = isCycleStart(for: entry, in: entries)
            samples.append(makeFlowSample(date: entry.date, flow: flow, isCycleStart: isStart))
        }
        if profile.hkWriteSymptoms {
            samples.append(contentsOf: symptomSamples(from: entry))
        }

        guard !samples.isEmpty else { return }
        try? await store.save(samples)
    }

    // MARK: - Import: Health → Caelyn

    /// Read flow samples from Health and create or update Caelyn CycleEntries.
    @discardableResult
    static func importFlowFromHealth(into context: ModelContext) async throws -> ImportResult {
        guard isAvailable else { throw HealthKitError.notAvailable }
        let samples = try await fetchAllMenstrualFlowSamples()
        let cal = Calendar.current
        let existing = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var created = 0
        var updated = 0

        for sample in samples {
            let day = cal.startOfDay(for: sample.startDate)
            guard let caelynFlow = caelynFlow(fromHKRawValue: sample.value) else { continue }
            if let entry = existing.first(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                if entry.flow != caelynFlow {
                    entry.flow = caelynFlow
                    entry.updatedAt = .now
                    updated += 1
                }
            } else {
                let entry = CycleEntry(date: day, flow: caelynFlow)
                context.insert(entry)
                created += 1
            }
        }
        try? context.save()
        return ImportResult(entriesCreated: created, entriesUpdated: updated)
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

    static func makeFlowSample(date: Date, flow: FlowLevel, isCycleStart: Bool) -> HKCategorySample {
        let value = mapFlowToHK(flow)
        let metadata: [String: Any] = [HKMetadataKeyMenstrualCycleStart: isCycleStart]
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

        // Symptoms (severity defaults to mild — Caelyn doesn't track severity per symptom)
        for symptom in entry.symptoms {
            guard let type = symptomCategoryMap[symptom] else { continue }
            samples.append(HKCategorySample(
                type: type,
                value: HKCategoryValueSeverity.mild.rawValue,
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
