import SwiftUI

struct HomeComingUp: View {
    let events: [(icon: String, label: String, accent: String)]

    var body: some View {
        MavieCard {
            VStack(alignment: .leading, spacing: MavieSpacing.md) {
                Text("Coming up")
                    .font(MavieFont.headline)
                    .foregroundStyle(MavieColor.deepPlumText)

                if events.isEmpty {
                    HStack(spacing: MavieSpacing.sm) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.4))
                        Text("Nothing on the horizon — Mavie will let you know.")
                            .font(MavieFont.body)
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                    }
                } else {
                    VStack(alignment: .leading, spacing: MavieSpacing.sm) {
                        ForEach(events.indices, id: \.self) { idx in
                            eventRow(events[idx])
                            if idx < events.count - 1 {
                                Rectangle()
                                    .fill(MavieColor.deepPlumText.opacity(0.06))
                                    .frame(height: 1)
                                    .padding(.leading, 36)
                            }
                        }
                    }
                }
            }
        }
    }

    private func eventRow(_ event: (icon: String, label: String, accent: String)) -> some View {
        HStack(spacing: MavieSpacing.sm) {
            ZStack {
                Circle()
                    .fill(accentBackground(for: event.accent))
                    .frame(width: 28, height: 28)
                Image(systemName: event.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor(for: event.accent))
            }
            Text(event.label)
                .font(MavieFont.body)
                .foregroundStyle(MavieColor.deepPlumText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func accentBackground(for accent: String) -> Color {
        switch accent {
        case "rose":     return MavieColor.blush
        case "lavender": return MavieColor.lavender
        case "sage":     return MavieColor.sage
        default:         return MavieColor.lavender
        }
    }

    private func accentColor(for accent: String) -> Color {
        switch accent {
        case "rose":     return MavieColor.alertRose
        case "lavender": return MavieColor.primaryPlum
        case "sage":     return MavieColor.successSage
        default:         return MavieColor.primaryPlum
        }
    }
}
