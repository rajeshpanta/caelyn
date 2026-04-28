import SwiftUI

struct HomeComingUp: View {
    let events: [(icon: String, label: String, accent: String)]

    var body: some View {
        CaelynCard {
            VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                Text("Coming up")
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.deepPlumText)

                if events.isEmpty {
                    HStack(spacing: CaelynSpacing.sm) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.4))
                        Text("Nothing on the horizon — Caelyn will let you know.")
                            .font(CaelynFont.body)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    }
                } else {
                    VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                        ForEach(events.indices, id: \.self) { idx in
                            eventRow(events[idx])
                            if idx < events.count - 1 {
                                Rectangle()
                                    .fill(CaelynColor.deepPlumText.opacity(0.06))
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
        HStack(spacing: CaelynSpacing.sm) {
            ZStack {
                Circle()
                    .fill(accentBackground(for: event.accent))
                    .frame(width: CaelynIconSize.sm, height: CaelynIconSize.sm)
                Image(systemName: event.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentColor(for: event.accent))
            }
            Text(event.label)
                .font(CaelynFont.body)
                .foregroundStyle(CaelynColor.deepPlumText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func accentBackground(for accent: String) -> Color {
        switch accent {
        case "rose":     return CaelynColor.blush
        case "lavender": return CaelynColor.lavender
        case "sage":     return CaelynColor.sage
        default:         return CaelynColor.lavender
        }
    }

    private func accentColor(for accent: String) -> Color {
        switch accent {
        case "rose":     return CaelynColor.alertRose
        case "lavender": return CaelynColor.primaryPlum
        case "sage":     return CaelynColor.successSage
        default:         return CaelynColor.primaryPlum
        }
    }
}
