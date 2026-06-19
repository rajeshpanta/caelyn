import SwiftUI

struct HomeStreakCard: View {
    let streak: Int
    let recentDays: [(date: Date, logged: Bool)]

    private var streakLabel: String {
        switch streak {
        case 0:       return "Log today to start your streak"
        case 1:       return "First log — great start!"
        case 3:       return "3 days in a row 🔥"
        case 7:       return "One week — you're glowing!"
        case 14:      return "Two weeks — truly amazing! ✨"
        default:      return "\(streak)-day streak 🌸"
        }
    }

    private var streakIcon: String {
        switch streak {
        case 0:      return "circle.dotted"
        case 1..<3:  return "flame"
        default:     return "flame.fill"
        }
    }

    private var isActive: Bool { streak > 0 }

    private var accessibilityDescription: String {
        if streak == 0 { return "Logging streak. Log today to start your streak." }
        return "Logging streak: \(streak) \(streak == 1 ? "day" : "days") in a row. \(streakLabel)"
    }

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.sm) {
                    ZStack {
                        Circle()
                            .fill(
                                isActive
                                    ? LinearGradient(
                                        colors: [CaelynColor.blush, CaelynColor.softRose.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [CaelynColor.lavender.opacity(0.5), CaelynColor.lavender.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                            .shadow(
                                color: isActive ? CaelynColor.alertRose.opacity(0.25) : .clear,
                                radius: 6, x: 0, y: 2
                            )

                        Image(systemName: streakIcon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(
                                isActive
                                    ? LinearGradient(
                                        colors: [CaelynColor.alertRose, Color(hex: 0xFF9A56)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: [CaelynColor.deepPlumText.opacity(0.3), CaelynColor.deepPlumText.opacity(0.3)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        if streak > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(streak)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [CaelynColor.primaryPlum, CaelynColor.softRose],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
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
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var dotGrid: some View {
        HStack(spacing: 5) {
            ForEach(recentDays.reversed(), id: \.date) { day in
                Circle()
                    .fill(
                        day.logged
                            ? LinearGradient(
                                colors: [CaelynColor.primaryPlum, CaelynColor.softRose.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [CaelynColor.deepPlumText.opacity(0.1), CaelynColor.deepPlumText.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 10, height: 10)
                    .overlay(
                        Calendar.current.isDateInToday(day.date)
                            ? Circle().stroke(CaelynColor.primaryPlum, lineWidth: 1.5)
                            : nil
                    )
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
