import Foundation
import HealthKit

/// The one place that says which Apple Health types Caelyn reads, where each one
/// lands, and why it is worth asking for.
///
/// Every entry here has a home in `CycleEntry` and a visible use in the app. That
/// is not tidiness — App Review 5.1.1 requires each requested health type to have
/// a clear, disclosed purpose, so a type with nowhere to go must not be listed.
///
/// ## Deliberate omissions
///
/// * **Sleep, resting heart rate, HRV, respiratory rate.** Caelyn has no engine
///   that consumes them, and wiring them into predictions would be inventing a
///   correlation rather than reporting one. Left out until a feature genuinely
///   needs them.
/// * **Progesterone tests, contraceptive use, lactation.** Real HealthKit types
///   with no field in `CycleEntry` yet — asking for them before they have a home
///   would be asking for data Caelyn cannot show or use.
/// * **Irregular / infrequent / prolonged cycle flags.** Apple's own cycle-deviation
///   notifications. Caelyn detects irregularity from her actual logs; importing
///   Apple's verdict would silently change which banner she sees.
///
/// Pure mapping, no shared state — deliberately not actor-isolated, so the reader
/// can translate samples on whatever queue HealthKit hands them back on.
enum HealthDataCatalog {

    // MARK: - Category reads

    /// HealthKit symptom categories → Caelyn symptoms.
    ///
    /// This is the read direction of `HealthKitService.symptomCategoryMap`. Note
    /// that abdominal cramps, lower-back pain, headache and breast pain appear in
    /// Caelyn *twice* — once as a symptom, once as a pain type. On the way in they
    /// resolve to the **symptom**, because that side carries severity; only pelvic
    /// pain, which has no symptom counterpart, arrives as a pain type. Caelyn's
    /// write side still writes both, so a value written and read back is stable.
    static var symptomReads: [HKCategoryTypeIdentifier: Symptom] {
        [
            .bloating:            .bloating,
            .acne:                .acne,
            .fatigue:             .fatigue,
            .nausea:              .nausea,
            .dizziness:           .dizziness,
            .sleepChanges:        .sleepChanges,
            .breastPain:          .tenderBreasts,
            .headache:            .headache,
            .lowerBackPain:       .backPain,
            .abdominalCramps:     .cramps,
            // Spotting between periods. Emphatically NOT mapped to `flow`:
            // `PredictionEngine.cycles(from:)` treats any non-nil flow as a bleed
            // day, so importing intermenstrual bleeding as flow would invent period
            // starts and skew every cycle average she has.
            .intermenstrualBleeding: .irregularBleed
        ]
    }

    /// The one pain category with no symptom equivalent.
    static var painReads: [HKCategoryTypeIdentifier: PainType] {
        [.pelvicPain: .pelvicPain]
    }

    // MARK: - Type sets

    /// Every type Caelyn asks to read, grouped so the user's toggles map onto
    /// something meaningful rather than onto raw HealthKit identifiers.
    enum ReadGroup: CaseIterable {
        /// Period history — the reason most people connect at all.
        case flow
        /// Symptoms and pain she may already be logging elsewhere.
        case symptoms
        /// Fertility signals that feed Caelyn's existing TTC and ovulation logic.
        case fertility
        /// Apple Watch sleeping wrist temperature, read-only.
        case wristTemperature

        var identifiers: [HKObjectType] {
            switch self {
            case .flow:
                return [HKCategoryType(.menstrualFlow)]
            case .symptoms:
                return HealthDataCatalog.symptomReads.keys.map { HKCategoryType($0) }
                     + HealthDataCatalog.painReads.keys.map { HKCategoryType($0) }
            case .fertility:
                var types: [HKObjectType] = [
                    HKCategoryType(.cervicalMucusQuality),
                    HKCategoryType(.ovulationTestResult),
                    HKCategoryType(.sexualActivity)
                ]
                if let bbt = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature) {
                    types.append(bbt)
                }
                if #available(iOS 15.0, *) {
                    types.append(HKCategoryType(.pregnancyTestResult))
                }
                return types
            case .wristTemperature:
                guard let wrist = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) else { return [] }
                return [wrist]
            }
        }
    }

    static var allReadTypes: Set<HKObjectType> {
        Set(ReadGroup.allCases.flatMap(\.identifiers))
    }

    /// Sample types the incremental reader watches. Wrist temperature is excluded:
    /// it is consumed as a series by `WristTempOvulationEngine`, not merged into
    /// day fields, so it has no provenance to track.
    static var syncedSampleTypes: [HKSampleType] {
        (ReadGroup.flow.identifiers + ReadGroup.symptoms.identifiers + ReadGroup.fertility.identifiers)
            .compactMap { $0 as? HKSampleType }
    }

    // MARK: - Sample → observation

    /// Metadata key that preserves Caelyn's spotting/light distinction, which
    /// HealthKit's flow values cannot express.
    static let flowLevelMetadataKey = "CaelynFlowLevel"

    /// HealthKit collapses "positive" and "LH surge" onto the same raw value, so a
    /// round trip through Health would otherwise lose which one she picked.
    static let ovulationResultMetadataKey = "CaelynOvulationResult"

    /// Translate one HealthKit sample into zero or one observation.
    ///
    /// Returns nil for anything Caelyn has no honest home for — an indeterminate
    /// test result, a "symptom not present" marker, an unspecified flow — rather
    /// than guessing a value.
    static func observation(from sample: HKSample, calendar: Calendar = .current) -> ImportObservation? {
        let day = calendar.startOfDay(for: sample.startDate)
        let source = sample.sourceRevision.source

        func make(_ field: ImportObservation.Field, _ value: ImportObservation.Value) -> ImportObservation {
            ImportObservation(
                day: day,
                field: field,
                value: value,
                recordID: sample.uuid,
                sourceBundleID: source.bundleIdentifier ?? "",
                sourceName: source.name,
                recordedAt: sample.startDate
            )
        }

        if let quantity = sample as? HKQuantitySample {
            guard quantity.quantityType == HKQuantityType(.basalBodyTemperature) else { return nil }
            return make(.basalTemperature, .temperature(quantity.quantity.doubleValue(for: .degreeCelsius())))
        }

        guard let category = sample as? HKCategorySample else { return nil }
        let identifier = HKCategoryTypeIdentifier(rawValue: category.categoryType.identifier)

        switch identifier {
        case .menstrualFlow:
            guard let level = flowLevel(from: category) else { return nil }
            return make(.flow, .flow(level))

        case .cervicalMucusQuality:
            guard let mucus = mucus(fromRawValue: category.value) else { return nil }
            return make(.cervicalMucus, .mucus(mucus))

        case .ovulationTestResult:
            guard let result = ovulationResult(from: category) else { return nil }
            return make(.ovulationTest, .ovulation(result))

        case .sexualActivity:
            return make(.sexualActivity, .boolean(true))

        default:
            break
        }

        if #available(iOS 15.0, *), identifier == .pregnancyTestResult {
            switch category.value {
            case HKCategoryValuePregnancyTestResult.positive.rawValue: return make(.pregnancyTest, .boolean(true))
            case HKCategoryValuePregnancyTestResult.negative.rawValue: return make(.pregnancyTest, .boolean(false))
            default: return nil   // indeterminate — no honest mapping
            }
        }

        if let symptom = symptomReads[identifier] {
            guard let severity = severityLevel(from: category.value) else { return nil }
            return make(.symptom(symptom), .symptomSeverity(severity))
        }

        if let pain = painReads[identifier] {
            guard severityLevel(from: category.value) != nil else { return nil }
            return make(.painType(pain), .present)
        }

        return nil
    }

    // MARK: - Value mapping

    /// Flow raw values are shared between the iOS 18 `HKCategoryValueVaginalBleeding`
    /// enum and the deprecated `HKCategoryValueMenstrualFlow` it replaced
    /// (unspecified 1, light 2, medium 3, heavy 4, none 5), so matching on the raw
    /// value works on every supported OS without a deprecation warning.
    static func flowLevel(from sample: HKCategorySample) -> FlowLevel? {
        // Caelyn's own samples carry the exact level she picked.
        if let raw = sample.metadata?[flowLevelMetadataKey] as? String,
           let level = FlowLevel(rawValue: raw) {
            return level
        }
        return flowLevel(fromRawValue: sample.value)
    }

    static func flowLevel(fromRawValue value: Int) -> FlowLevel? {
        switch value {
        case 2:  return .light
        case 3:  return .medium
        case 4:  return .heavy
        default: return nil   // unspecified / none / unknown — not a flow reading
        }
    }

    static func mucus(fromRawValue value: Int) -> CervicalMucus? {
        switch HKCategoryValueCervicalMucusQuality(rawValue: value) {
        case .dry:      return .dry
        case .sticky:   return .sticky
        case .creamy:   return .creamy
        case .watery:   return .watery
        case .eggWhite: return .eggWhite
        default:        return nil
        }
    }

    static func ovulationResult(from sample: HKCategorySample) -> OvulationTestResult? {
        if let raw = sample.metadata?[ovulationResultMetadataKey] as? String,
           let result = OvulationTestResult(rawValue: raw) {
            return result
        }
        return ovulationResult(fromRawValue: sample.value)
    }

    static func ovulationResult(fromRawValue value: Int) -> OvulationTestResult? {
        switch HKCategoryValueOvulationTestResult(rawValue: value) {
        case .negative:               return .negative
        // `.positive` is the same raw value as `.luteinizingHormoneSurge`; without
        // Caelyn's metadata the surge reading is the accurate description.
        case .luteinizingHormoneSurge: return .lhSurge
        case .estrogenSurge:          return .rising
        default:                      return nil   // indeterminate
        }
    }

    /// HealthKit severity → Caelyn's 1/2/3. Returns nil for "not present", which
    /// records the *absence* of a symptom and must not add it to her log.
    static func severityLevel(from rawValue: Int) -> Int? {
        switch HKCategoryValueSeverity(rawValue: rawValue) {
        case .mild:        return 1
        case .moderate:    return 2
        case .severe:      return 3
        case .unspecified: return 2   // logged, but no severity given
        case .notPresent:  return nil
        default:           return nil
        }
    }
}
