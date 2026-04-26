import SwiftUI

struct DayCell: View {
    let state: DayState
    let onTap: () -> Void

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: state.date)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                background
                Circle()
                    .stroke(state.isToday ? MavieColor.primaryPlum : .clear, lineWidth: 1.5)
                    .padding(2)

                VStack(spacing: 2) {
                    Text(dayNumber)
                        .font(MavieFont.callout.weight(state.isToday ? .semibold : .regular))
                        .foregroundStyle(textColor)
                    bottomDot
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .opacity(state.inMonth ? 1.0 : 0.32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
    }

    @ViewBuilder
    private var background: some View {
        switch state.marker {
        case .loggedPeriod:
            Circle()
                .fill(MavieColor.softRose.opacity(0.85))
                .padding(4)
        case .predictedPeriod:
            Circle()
                .fill(MavieColor.softRose.opacity(0.25))
                .overlay(
                    Circle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .foregroundStyle(MavieColor.softRose.opacity(0.7))
                )
                .padding(4)
        case .pms:
            Circle()
                .fill(MavieColor.lavender)
                .padding(4)
        case .ovulation:
            Circle()
                .fill(MavieColor.sage)
                .padding(4)
        case .empty:
            Color.clear
        }
    }

    @ViewBuilder
    private var bottomDot: some View {
        if state.hasNote {
            Circle()
                .fill(MavieColor.deepPlumText.opacity(0.5))
                .frame(width: 3, height: 3)
        } else {
            Color.clear.frame(height: 3)
        }
    }

    private var textColor: Color {
        switch state.marker {
        case .loggedPeriod:    return .white
        case .predictedPeriod, .pms, .ovulation, .empty:
            return MavieColor.deepPlumText
        }
    }

    private var accessibilityDescription: String {
        var parts = [dayNumber]
        if state.isToday { parts.append("today") }
        switch state.marker {
        case .loggedPeriod(let flow): parts.append("logged period \(flow.displayName.lowercased())")
        case .predictedPeriod:        parts.append("predicted period")
        case .pms:                    parts.append("PMS window")
        case .ovulation:              parts.append("ovulation window")
        case .empty:                  break
        }
        if state.hasNote { parts.append("has note") }
        return parts.joined(separator: ", ")
    }
}
