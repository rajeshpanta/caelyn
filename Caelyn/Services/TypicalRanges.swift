import Foundation

/// The "Is this normal?" layer — pairs HER number with a common range and a plain,
/// reassuring, provider-forward status. It NEVER says "abnormal" and NEVER names a
/// condition. Caelyn is not a medical device; these are observational reference
/// points only.
///
/// Ranges follow mainstream clinical guidance (ACOG Committee Opinion 651,
/// "Menstruation in Girls and Adolescents: Using the Menstrual Cycle as a Vital
/// Sign"): adult cycles commonly 21–35 days, periods 2–7 days, a few days of
/// cycle-to-cycle variation is normal. In the first 1–3 years after a first period,
/// cycles of 21–45 days and occasional skipped cycles are expected — that's the
/// "gentle" variant.
enum TypicalRanges {

    enum Status: Equatable {
        case inRange
        case watch(String)   // gentle, provider-forward note
        case learning        // not enough data yet

        var text: String {
            switch self {
            case .inRange:      return "✓ In a common range"
            case .watch(let s): return s
            case .learning:     return "Your number appears after your first logged cycle"
            }
        }
    }

    struct Frame: Equatable {
        let title: String
        let herValue: String   // "31 days" or "—" when unknown
        let typical: String    // "Typical: 21–35 days"
        let status: Status
        var known: Bool { status != .learning }
    }

    // MARK: - Cycle length

    static func cycleLength(_ days: Int?, gentle: Bool = false) -> Frame {
        let lo = 21, hi = gentle ? 45 : 35
        let typical = "Typical: \(lo)–\(hi) days"
        guard let days, days > 0 else {
            return Frame(title: "Cycle length", herValue: "—", typical: typical, status: .learning)
        }
        let status: Status
        if days >= lo && days <= hi {
            status = .inRange
        } else if gentle {
            status = .watch("Common while your cycles are still settling — worth a mention if it keeps up")
        } else {
            status = .watch("A little outside the common range — worth mentioning to a doctor if it continues")
        }
        return Frame(title: "Cycle length", herValue: "\(days) days", typical: typical, status: status)
    }

    // MARK: - Period length

    static func periodLength(_ days: Int?, gentle: Bool = false) -> Frame {
        let typical = "Typical: 2–7 days"
        guard let days, days > 0 else {
            return Frame(title: "Period length", herValue: "—", typical: typical, status: .learning)
        }
        let status: Status
        if days >= 2 && days <= 7 {
            status = .inRange
        } else if days > 7 {
            status = .watch("Longer than most — worth a chat with a doctor if it's a regular thing")
        } else {
            status = .watch("Shorter than most — usually fine; mention it if it's new for you")
        }
        return Frame(title: "Period length", herValue: "\(days) days", typical: typical, status: status)
    }

    // MARK: - Cycle-to-cycle variation

    static func variation(_ days: Int?, gentle: Bool = false) -> Frame {
        let cap = gentle ? 9 : 7
        let typical = "Typical: up to about \(cap) days"
        guard let days, days >= 0 else {
            return Frame(title: "Cycle-to-cycle change", herValue: "—", typical: typical, status: .learning)
        }
        let status: Status = days <= cap
            ? .inRange
            : .watch("Your cycle length varies quite a bit — often normal, and worth mentioning to a doctor")
        return Frame(title: "Cycle-to-cycle change", herValue: "± \(days) days", typical: typical, status: status)
    }

    // MARK: - Period pain (only when she logs pain)

    static func pain(_ avg: Int?) -> Frame? {
        guard let avg, avg > 0 else { return nil }
        let status: Status = avg <= 6
            ? .inRange
            : .watch("Pain this strong that gets in the way of your day is worth talking to a doctor about — you don't have to just cope")
        return Frame(title: "Period pain", herValue: "\(avg)/10 average", typical: "Mild–moderate cramping is common", status: status)
    }

    /// The reassuring footer under the panel.
    static let footer = "These are common ranges, not rules. If something changes suddenly, or gets in the way of your life, that's always worth a conversation with a doctor or nurse."
}

/// A small curated Q&A the user can tap open inside the guide sheet — answered from
/// HER real numbers, ordered so today's phase comes first, always ending
/// provider-forward. Deterministic (no AI, no free-form input) so it's identical on
/// every device and fully testable.
enum GuideQuestions {

    struct QA: Equatable, Identifiable {
        let id: String
        let question: String
        let answer: String
    }

    static func forToday(phase: CyclePhase, avgCycle: Int?, variation: Int?, gentle: Bool) -> [QA] {
        let cycleText = avgCycle.map { "\($0) days" } ?? "still being learned"
        let varText = variation.map { "\($0) days" } ?? "a few days"

        // (question, answer, phases it's most relevant to)
        let library: [(id: String, q: String, a: String, phases: Set<CyclePhase>)] = [
            ("varies", "Is it normal that my cycle length changes?",
             "Yes — a few days' change between cycles is completely common. Yours vary by about \(varText). Big, sudden swings are worth mentioning to a doctor, but small changes are just your body.",
             [.follicular, .unknown]),
            ("mood-low", "Why does my mood dip before my period?",
             "In the days before your period, estrogen and progesterone drop, and that can pull your mood and energy down with them. It's a hormone shift, not a flaw. If it regularly overwhelms your life, a doctor can help.",
             [.pms, .luteal]),
            ("energy-high", "Why do I feel more energetic some weeks?",
             "After your period, rising estrogen often brings sharper focus and more energy, usually peaking around ovulation. Noticing this helps you plan around your own rhythm.",
             [.follicular, .ovulation]),
            ("ovulation", "How do I know when I'm ovulating?",
             "It's usually around the middle of your cycle. Clear, stretchy discharge, a small rise in temperature the next day, and a positive LH strip are the common signs. Logging these teaches Caelyn your real timing.",
             [.ovulation, .follicular]),
            ("period-pain", "Is it normal for periods to hurt?",
             "Mild to moderate cramping is very common — it's the uterus contracting. Heat and gentle movement help. Pain that stops you doing normal things is not something to just endure; it's worth a doctor's time.",
             [.menstrual]),
            ("tired", "Why am I so tired on my period?",
             "Your hormones are at their lowest and your body is doing real work, so lower energy is expected. Rest is genuinely part of the cycle, not laziness.",
             [.menstrual]),
            ("normal-length", "What counts as a normal cycle?",
             gentle
                ? "In the first years of having periods, anywhere from 21 to 45 days — and some irregularity — is normal. Yours average \(cycleText)."
                : "For most people, 21 to 35 days from one period to the next. Yours average \(cycleText). Outside that range now and then is usually fine.",
             [.unknown]),
            ("see-doctor", "When should I talk to a doctor?",
             "Good reasons to check in: periods that soak through protection hourly, pain that stops your day, cycles suddenly much longer or shorter, bleeding between periods, or no period for a few months (outside pregnancy). None of these mean something is wrong — they're just worth a conversation.",
             [.menstrual, .follicular, .ovulation, .luteal, .pms, .unknown]),
        ]

        // Phase-relevant questions first (stable order within each group).
        let relevant = library.filter { $0.phases.contains(phase) }
        let rest = library.filter { !$0.phases.contains(phase) }
        return (relevant + rest).map { QA(id: $0.id, question: $0.q, answer: $0.a) }
    }
}
