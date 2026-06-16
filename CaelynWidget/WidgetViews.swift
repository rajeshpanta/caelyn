import SwiftUI
import WidgetKit

// ─────────────────────────────────────────────────────────────────────────────
// All five widget view implementations in one file.
// Color helpers are defined in CaelynWidgetBundle.swift.
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - Shared upgrade prompt

private struct UpgradePromptView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.widgetPlum)
            Text("Caelyn Pro")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.widgetDeepText)
            Text("Upgrade for richer widgets")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(Color.widgetDeepText.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Phase badge (shared between Small + Large)

private struct PhaseBadge: View {
    let icon: String
    let name: String
    let accentHex: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(name.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.5)
                .lineLimit(1)
        }
        .foregroundStyle(Color(widgetHex: accentHex))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.65), in: Capsule())
    }
}

// MARK: - systemSmall (FREE)

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhaseBadge(
                icon: snapshot.phaseIcon,
                name: snapshot.phaseName,
                accentHex: snapshot.phaseAccentHex
            )
            Spacer(minLength: 8)
            Text("\(snapshot.cycleDay)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(Color(widgetHex: snapshot.phaseAccentHex))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Cycle Day")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.widgetDeepText.opacity(0.5))
            Spacer(minLength: 6)
            countdownLine
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var countdownLine: some View {
        Group {
            if snapshot.daysUntilPeriod > 0 {
                Label("Period in \(snapshot.daysUntilPeriod)d", systemImage: "drop.fill")
            } else if snapshot.daysUntilPeriod == 0 {
                Label("Period may start today", systemImage: "drop.fill")
            } else {
                Text("Open Caelyn to log")
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(Color.widgetDeepText.opacity(0.45))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

// MARK: - systemMedium (PRO)

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if !snapshot.isPro {
            UpgradePromptView()
        } else {
            HStack(alignment: .top, spacing: 14) {
                leftColumn
                    .frame(maxWidth: 100, alignment: .leading)
                Rectangle()
                    .fill(Color.widgetDeepText.opacity(0.08))
                    .frame(width: 1)
                rightColumn
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhaseBadge(
                icon: snapshot.phaseIcon,
                name: snapshot.phaseName,
                accentHex: snapshot.phaseAccentHex
            )
            Spacer(minLength: 4)
            Text("\(snapshot.cycleDay)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Color(widgetHex: snapshot.phaseAccentHex))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("Day \(snapshot.cycleDay) of \(snapshot.cycleLength)")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color.widgetDeepText.opacity(0.45))
                .lineLimit(1)
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !snapshot.periodWindowText.isEmpty {
                eventRow(icon: "drop.fill",
                         text: snapshot.periodWindowText,
                         color: Color.widgetRose)
            }
            if !snapshot.upcomingLine1.isEmpty {
                eventRow(icon: "sun.max.fill",
                         text: snapshot.upcomingLine1,
                         color: Color(widgetHex: snapshot.phaseAccentHex))
            }
            if !snapshot.upcomingLine2.isEmpty {
                eventRow(icon: "cloud.fill",
                         text: snapshot.upcomingLine2,
                         color: Color.widgetPlum.opacity(0.75))
            }
            Spacer(minLength: 0)
        }
    }

    private func eventRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 12, alignment: .center)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.widgetDeepText.opacity(0.7))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - systemLarge (PRO · also renders in Standby)

struct LargeWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if !snapshot.isPro {
            proUpgradeFullView
        } else {
            proContent
        }
    }

    private var proContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhaseBadge(
                icon: snapshot.phaseIcon,
                name: snapshot.phaseName,
                accentHex: snapshot.phaseAccentHex
            )
            Spacer(minLength: 14)

            // Big cycle day number
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.cycleDay)")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(widgetHex: snapshot.phaseAccentHex))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("Cycle Day · \(snapshot.cycleLength)-day cycle")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.widgetDeepText.opacity(0.5))
            }

            Spacer(minLength: 18)

            Rectangle()
                .fill(Color.widgetDeepText.opacity(0.08))
                .frame(height: 1)

            Spacer(minLength: 14)

            // Upcoming events
            VStack(alignment: .leading, spacing: 11) {
                if !snapshot.periodWindowText.isEmpty {
                    bigEventRow(icon: "drop.fill",
                                text: "Period: \(snapshot.periodWindowText)",
                                color: Color.widgetRose)
                }
                if !snapshot.upcomingLine1.isEmpty {
                    bigEventRow(icon: "sun.max.fill",
                                text: snapshot.upcomingLine1,
                                color: Color.widgetSage)
                }
                if !snapshot.upcomingLine2.isEmpty {
                    bigEventRow(icon: "cloud.fill",
                                text: snapshot.upcomingLine2,
                                color: Color.widgetPlum.opacity(0.8))
                }
                if !snapshot.upcomingLine3.isEmpty {
                    bigEventRow(icon: "calendar",
                                text: snapshot.upcomingLine3,
                                color: Color.widgetDeepText.opacity(0.55))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func bigEventRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.widgetDeepText.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var proUpgradeFullView: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.widgetPlum)
            Text("Caelyn Pro")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.widgetDeepText)
            Text("Upgrade for full widget views with your cycle timeline, coming-up events, and predictions.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.widgetDeepText.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - accessoryCircular (PRO · lock screen)

struct AccessoryCircularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if snapshot.isPro {
                VStack(spacing: 0) {
                    Text("\(snapshot.cycleDay)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("DAY")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .opacity(0.65)
                }
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
            }
        }
    }
}

// MARK: - accessoryRectangular (PRO · lock screen)

struct AccessoryRectangularView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if !snapshot.isPro {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                Text("Upgrade to Pro")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: snapshot.phaseIcon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(snapshot.phaseName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                }
                periodLine
            }
        }
    }

    private var periodLine: some View {
        Group {
            if snapshot.daysUntilPeriod > 0 {
                Text("Period in \(snapshot.daysUntilPeriod) day\(snapshot.daysUntilPeriod == 1 ? "" : "s")")
            } else if snapshot.daysUntilPeriod == 0 {
                Text("Period may start today")
            } else {
                Text("Day \(snapshot.cycleDay) of \(snapshot.cycleLength)")
            }
        }
        .font(.system(size: 11, weight: .regular, design: .rounded))
        .opacity(0.65)
        .lineLimit(1)
    }
}
