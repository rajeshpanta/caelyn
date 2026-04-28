import Foundation

struct CycleLengthPoint: Identifiable {
    let id = UUID()
    let cycleStartDate: Date
    let length: Int
}

struct PeriodLengthPoint: Identifiable {
    let id = UUID()
    let cycleStartDate: Date
    let length: Int
}

struct SymptomCount: Identifiable {
    let id: String
    let symptom: Symptom
    let count: Int
    init(symptom: Symptom, count: Int) {
        self.id = symptom.rawValue
        self.symptom = symptom
        self.count = count
    }
}

struct MoodCount: Identifiable {
    let id: String
    let mood: Mood
    let count: Int
    init(mood: Mood, count: Int) {
        self.id = mood.rawValue
        self.mood = mood
        self.count = count
    }
}

struct PainPoint: Identifiable {
    let id = UUID()
    let date: Date
    let pain: Int
}

struct PhaseSymptomCount {
    let symptom: Symptom
    let phase: CyclePhase
    let count: Int
}

enum CycleAnalytics {

    /// Cycle length series for chart, oldest → newest.
    static func cycleLengthSeries(from cycles: [Cycle]) -> [CycleLengthPoint] {
        cycles.map { CycleLengthPoint(cycleStartDate: $0.start, length: $0.length) }
    }

    static func periodLengthSeries(from cycles: [Cycle]) -> [PeriodLengthPoint] {
        cycles.map { PeriodLengthPoint(cycleStartDate: $0.start, length: $0.periodLength) }
    }

    /// Top symptoms by count, sorted descending.
    static func symptomFrequency(in entries: [CycleEntry], limit: Int = 6) -> [SymptomCount] {
        var counts: [Symptom: Int] = [:]
        for entry in entries {
            for s in entry.symptoms { counts[s, default: 0] += 1 }
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { SymptomCount(symptom: $0.key, count: $0.value) }
    }

    /// Mood distribution, sorted descending.
    static func moodFrequency(in entries: [CycleEntry]) -> [MoodCount] {
        var counts: [Mood: Int] = [:]
        for entry in entries {
            if let mood = entry.mood { counts[mood, default: 0] += 1 }
        }
        return counts
            .sorted { $0.value > $1.value }
            .map { MoodCount(mood: $0.key, count: $0.value) }
    }

    /// Pain over time, oldest → newest, only entries with pain logged.
    static func painSeries(in entries: [CycleEntry]) -> [PainPoint] {
        entries
            .compactMap { entry -> PainPoint? in
                guard let pain = entry.pain else { return nil }
                return PainPoint(date: entry.date, pain: pain)
            }
            .sorted { $0.date < $1.date }
    }

    /// "Most common day-1 symptom" — what symptom shows up most in entries
    /// that fall in the first 2 days of any cycle.
    static func mostCommonEarlyPeriodSymptom(entries: [CycleEntry], cycles: [Cycle]) -> Symptom? {
        guard !cycles.isEmpty else { return nil }
        let cal = Calendar.current
        var dates: Set<Date> = []
        for cycle in cycles {
            for offset in 0..<min(2, cycle.periodLength) {
                if let d = cal.date(byAdding: .day, value: offset, to: cycle.start) {
                    dates.insert(cal.startOfDay(for: d))
                }
            }
        }
        var counts: [Symptom: Int] = [:]
        for entry in entries where dates.contains(cal.startOfDay(for: entry.date)) {
            for s in entry.symptoms { counts[s, default: 0] += 1 }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Average pain on period days.
    static func averagePeriodPain(entries: [CycleEntry], cycles: [Cycle]) -> Double? {
        guard !cycles.isEmpty else { return nil }
        let cal = Calendar.current
        var periodDays: Set<Date> = []
        for cycle in cycles {
            for offset in 0..<cycle.periodLength {
                if let d = cal.date(byAdding: .day, value: offset, to: cycle.start) {
                    periodDays.insert(cal.startOfDay(for: d))
                }
            }
        }
        let pains = entries
            .filter { periodDays.contains(cal.startOfDay(for: $0.date)) }
            .compactMap(\.pain)
        guard !pains.isEmpty else { return nil }
        return Double(pains.reduce(0, +)) / Double(pains.count)
    }

    /// Days logged in the recent N days.
    static func daysLogged(in entries: [CycleEntry], lookbackDays: Int = 30, today: Date = .now) -> Int {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -lookbackDays, to: cal.startOfDay(for: today)) else { return 0 }
        return entries.filter { $0.hasContent && $0.date >= start }.count
    }
}
