import Foundation
import SwiftData

enum PreviewData {
    static func populate(_ context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let profile = UserProfile(
            averageCycleLength: 29,
            averagePeriodLength: 5,
            trackingGoals: [.period, .symptoms, .mood, .pms],
            hasOnboarded: true,
            lastPeriodStart: calendar.date(byAdding: .day, value: -17, to: today)
        )
        context.insert(profile)

        let cycleSpecs: [(daysAgo: Int, cycleLength: Int, periodLength: Int, isCurrent: Bool)] = [
            (daysAgo: 17,  cycleLength: 29, periodLength: 5, isCurrent: true),
            (daysAgo: 46,  cycleLength: 28, periodLength: 5, isCurrent: false),
            (daysAgo: 76,  cycleLength: 30, periodLength: 6, isCurrent: false),
            (daysAgo: 103, cycleLength: 27, periodLength: 4, isCurrent: false)
        ]

        for spec in cycleSpecs {
            guard let cycleStart = calendar.date(byAdding: .day, value: -spec.daysAgo, to: today) else { continue }
            let logUntilDay = spec.isCurrent ? min(spec.daysAgo, spec.cycleLength) : spec.cycleLength
            for dayOffset in 0..<logUntilDay {
                let cycleDay = dayOffset + 1
                guard let date = calendar.date(byAdding: .day, value: dayOffset, to: cycleStart) else { continue }
                let entry = makeEntry(date: date, cycleDay: cycleDay, periodLength: spec.periodLength, cycleLength: spec.cycleLength)
                if entry.hasContent {
                    context.insert(entry)
                }
            }
        }

        try? context.save()
    }

    private static func makeEntry(date: Date, cycleDay: Int, periodLength: Int, cycleLength: Int) -> CycleEntry {
        let entry = CycleEntry(date: date)
        let ovulationDay = cycleLength - 14
        let pmsStart = max(1, cycleLength - 4)

        if cycleDay <= periodLength {
            entry.flow = flow(forPeriodDay: cycleDay, periodLength: periodLength)
            entry.pain = pain(forPeriodDay: cycleDay)
            entry.painTypes = cycleDay <= 2 ? [.cramps, .backPain] : [.cramps]
            entry.symptoms = cycleDay <= 2 ? [.cramps, .fatigue] : [.cramps]
            entry.mood = cycleDay <= 2 ? .tired : .calm
            if cycleDay == 1 {
                entry.note = "Period started today."
            }
        } else if abs(cycleDay - ovulationDay) <= 1 {
            entry.symptoms = [.cravings]
            entry.mood = .energetic
            entry.cervicalMucus = .eggWhite
        } else if cycleDay >= pmsStart {
            entry.symptoms = pmsSymptoms(daysFromEnd: cycleLength - cycleDay)
            entry.mood = cycleDay >= cycleLength - 1 ? .moody : .sensitive
            entry.pain = 2
        } else if cycleDay % 5 == 0 {
            entry.mood = .calm
        }

        return entry
    }

    private static func flow(forPeriodDay day: Int, periodLength: Int) -> FlowLevel {
        switch day {
        case 1:                                     return .light
        case 2:                                     return .heavy
        case 3:                                     return .medium
        case _ where day == periodLength:           return .spotting
        default:                                    return .light
        }
    }

    private static func pain(forPeriodDay day: Int) -> Int {
        switch day {
        case 1: return 4
        case 2: return 6
        case 3: return 4
        default: return 2
        }
    }

    private static func pmsSymptoms(daysFromEnd: Int) -> [Symptom] {
        switch daysFromEnd {
        case 0, 1: return [.bloating, .acne, .cravings]
        case 2:    return [.bloating, .acne]
        default:   return [.bloating]
        }
    }
}
