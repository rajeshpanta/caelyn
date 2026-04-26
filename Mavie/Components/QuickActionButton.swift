import SwiftUI

struct QuickActionButton: View {
    let title: String
    let icon: String
    var tint: Color = MavieColor.primaryPlum
    var background: Color = MavieColor.lavender
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(background)
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(MavieFont.caption.weight(.medium))
                    .foregroundStyle(MavieColor.deepPlumText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack(spacing: MavieSpacing.xs) {
        QuickActionButton(title: "Log Period", icon: "drop.fill", background: MavieColor.blush) {}
        QuickActionButton(title: "Add Symptoms", icon: "sparkles", background: MavieColor.lavender) {}
        QuickActionButton(title: "Mood Check-in", icon: "face.smiling", background: MavieColor.sage) {}
        QuickActionButton(title: "Add Note", icon: "square.and.pencil", background: MavieColor.warmSand) {}
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
