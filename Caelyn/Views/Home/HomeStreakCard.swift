import SwiftUI

struct HomeStreakCard: View {
    let streak: Int
    let recentDays: [(date: Date, logged: Bool)]

    private var streakLabel: String {
        switch streak {
        case 0:  return "Log today to start a streak"
        case 1:  return "First log — keep going!"
        case 3:  return "3-day streak"
        case 7:  return "One week — great consistency"
        case 14: return "Two weeks — amazing!"
        default: return "\(streak)-day streak"
        }
    }

    private var streakIcon: String {
        switch streak {
        case 0:    return "circle.dotted"
        case 1..<3: return "flame"
        default:   return "flame.fill"
        }
    }

    private var iconColor: Color {
        streak == 0 ? CaelynColor.deepPlumText.opacity(0.3) : CaelynColor.alertRose
    }

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(streak == 0 ? CaelynColor.lavender.opacity(0.4) : CaelynColor.blush)
                            .frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                        Image(systemName: streakIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if streak > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(streak)")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CaelynColor.primaryPlum)
                                    .contentTransition(.numericText())
                                Text(streak == 1 ? "day logged" : "days logged")
                                    .font(CaelynFont.subheadline)
                                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                            }
                        }
                        Text(streakLabel)
                            .font(streak == 0 ? CaelynFont.body : CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(streak == 0 ? 0.55 : 0.5))
                    }
                    Spacer(minLength: 0)
                }

                dotGrid
            }
        }
    }

    private var dotGrid: some View {
        HStack(spacing: 5) {
            ForEach(recentDays.reversed(), id: \.date) { day in
                VStack(spacing: 3) {
                    Circle()
                        .fill(day.logged ? CaelynColor.primaryPlum : CaelynColor.deepPlumText.opacity(0.1))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Calendar.current.isDateInToday(day.date)
                                ? Circle().stroke(CaelynColor.primaryPlum, lineWidth: 1.5)
                                : nil
                        )
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HomeStreakCard(streak: 0, recentDays: (0..<14).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: .now)!, false)
        })
        HomeStreakCard(streak: 5, recentDays: (0..<14).map { i in
            (Calendar.current.date(byAdding: .day, value: -i, to: .now)!, i < 5)
        })
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
