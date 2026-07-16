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

struct BBTPoint: Identifiable {
    let id = UUID()
    let date: Date
    let temperature: Double
}

struct EnergyCount: Identifiable {
    let id: String
    let level: EnergyLevel
    let count: Int
    init(level: EnergyLevel, count: Int) {
        self.id = level.rawValue
        self.level = level
        self.count = count
    }
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

    /// Energy level distribution, sorted by level order (low → high).
    static func energyFrequency(in entries: [CycleEntry]) -> [EnergyCount] {
        var counts: [EnergyLevel: Int] = [:]
        for entry in entries {
            if let level = entry.energyLevel { counts[level, default: 0] += 1 }
        }
        return EnergyLevel.allCases.compactMap { level in
            guard let count = counts[level] else { return nil }
            return EnergyCount(level: level, count: count)
        }
    }

    /// BBT data points oldest → newest, only entries where temperature was logged.
    static func bbtSeries(in entries: [CycleEntry]) -> [BBTPoint] {
        entries
            .compactMap { entry -> BBTPoint? in
                guard let temp = entry.basalTemperature else { return nil }
                return BBTPoint(date: entry.date, temperature: temp)
            }
            .sorted { $0.date < $1.date }
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

    /// Current logging streak with GRACE (stand-out plan S6): an unlogged *today*
    /// doesn't zero the streak (the day isn't over yet), and one missed day inside
    /// the run freezes the count instead of resetting it. Bodies and lives are
    /// irregular — punishing a single gap is how other apps lose people.
    static func loggingStreak(in entries: [CycleEntry], today: Date = .now) -> Int {
        let cal = Calendar.current
        let loggedDays = Set(
            entries
                .filter { $0.hasContent }
                .map { cal.startOfDay(for: $0.date) }
        )
        var cursor = cal.startOfDay(for: today)
        // Today not logged yet? Start counting from yesterday — no penalty.
        if !loggedDays.contains(cursor) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var streak = 0
        var graceUsed = false
        while true {
            if loggedDays.contains(cursor) {
                streak += 1
            } else if streak > 0 && !graceUsed {
                graceUsed = true   // freeze across one missed day instead of resetting
            } else {
                break
            }
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// The last N days as start-of-day dates, newest first.
    static func recentDayStates(in entries: [CycleEntry], days: Int = 14, today: Date = .now) -> [(date: Date, logged: Bool)] {
        let cal = Calendar.current
        let loggedDays = Set(
            entries
                .filter { $0.hasContent }
                .map { cal.startOfDay(for: $0.date) }
        )
        return (0..<days).compactMap { offset -> (Date, Bool)? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: today)) else { return nil }
            return (date, loggedDays.contains(date))
        }
    }
}
