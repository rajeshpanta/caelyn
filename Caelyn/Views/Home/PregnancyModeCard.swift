import SwiftUI

struct PregnancyModeCard: View {
    let dueDate: Date

    private var cal: Calendar { Calendar.current }

    private var today: Date { cal.startOfDay(for: .now) }

    private var conceptionDate: Date {
        cal.date(byAdding: .day, value: -280, to: dueDate) ?? dueDate
    }

    private var weeksPregnant: Int {
        let days = cal.dateComponents([.day], from: conceptionDate, to: today).day ?? 0
        return max(0, min(42, days / 7))
    }

    private var daysRemaining: Int {
        max(0, cal.dateComponents([.day], from: today, to: dueDate).day ?? 0)
    }

    /// True once the due date has passed — the card stops counting down and
    /// nudges the user to switch to Postpartum mode instead of freezing at
    /// "Week 42 · 0 days left" (stz-013).
    private var isPastDue: Bool { today > cal.startOfDay(for: dueDate) }

    private var trimester: Int {
        switch weeksPregnant {
        case 0..<13: return 1
        case 13..<27: return 2
        default: return 3
        }
    }

    private var trimesterColor: Color {
        switch trimester {
        case 1: return CaelynColor.successSage
        case 2: return CaelynColor.primaryPlum
        default: return CaelynColor.softRose
        }
    }

    private var milestone: String {
        if isPastDue { return "Your due date has passed — switch to Postpartum in Settings" }
        switch weeksPregnant {
        case 0..<4:   return "Implantation week"
        case 4..<8:   return "Heart forming"
        case 8..<12:  return "All organs developing"
        case 12..<16: return "Baby moving"
        case 16..<20: return "Halfway there!"
        case 20..<24: return "Viability milestone"
        case 24..<28: return "Lungs developing"
        case 28..<32: return "Brain development"
        case 32..<36: return "Final growth push"
        case 36..<40: return "Almost term!"
        default: return "Due any day now"
        }
    }

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(trimesterColor)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Pregnancy")
                            .font(CaelynFont.caption.weight(.semibold))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        Text(isPastDue ? "Past your due date" : "Week \(weeksPregnant) · Trimester \(trimester)")
                            .font(CaelynFont.headline)
                            .foregroundStyle(CaelynColor.deepPlumText)
                    }
                    Spacer()
                    if isPastDue {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(trimesterColor)
                    } else {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(daysRemaining)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(trimesterColor)
                            Text("days left")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                        }
                    }
                }

                Divider()

                Label(milestone, systemImage: "sparkles")
                    .font(CaelynFont.callout)
                    .foregroundStyle(trimesterColor)

                Text("Due \(dueDate, format: .dateTime.month(.wide).day().year())")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isPastDue
            ? "Pregnancy: past your due date. \(milestone)."
            : "Pregnancy: week \(weeksPregnant), trimester \(trimester). \(milestone). \(daysRemaining) days until due date.")
    }
}

struct PostpartumModeCard: View {
    let birthDate: Date

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: .now) }

    /// Recovery-tracking window (~6 months). Past this, the card stops counting
    /// up open-endedly (no "Week 230 postpartum") and nudges to turn the mode off.
    private static let windowWeeks = 26

    private var weeksPostpartum: Int {
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: birthDate), to: today).day ?? 0
        return max(0, days / 7)
    }

    private var isPastWindow: Bool { weeksPostpartum > Self.windowWeeks }

    private var weekLabel: String {
        isPastWindow ? "\(Self.windowWeeks)+ weeks postpartum" : "Week \(weeksPostpartum) postpartum"
    }

    private var milestone: String {
        if isPastWindow { return "Recovery window complete — turn off Postpartum in Settings any time" }
        switch weeksPostpartum {
        case 0..<1: return "First week — rest and recover"
        case 1..<2: return "Milk supply establishing"
        case 2..<6: return "Uterus shrinking back"
        case 6..<12: return "6-week checkup window"
        default: return "Body continuing to heal"
        }
    }

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    Image(systemName: "figure.and.child.holdinghands")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(CaelynColor.warmSand)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Postpartum")
                            .font(CaelynFont.caption.weight(.semibold))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        Text(weekLabel)
                            .font(CaelynFont.headline)
                            .foregroundStyle(CaelynColor.deepPlumText)
                    }
                    Spacer()
                }
                Divider()
                Label(milestone, systemImage: "heart.circle")
                    .font(CaelynFont.callout)
                    .foregroundStyle(CaelynColor.primaryPlum)
                Text("Born \(birthDate, format: .dateTime.month(.wide).day().year())")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Postpartum: \(weekLabel). \(milestone).")
    }
}
