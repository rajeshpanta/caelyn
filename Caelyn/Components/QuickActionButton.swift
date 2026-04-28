import SwiftUI

struct QuickActionButton: View {
    let title: String
    let icon: String
    var tint: Color = CaelynColor.primaryPlum
    var background: Color = CaelynColor.lavender
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
                    .font(CaelynFont.caption.weight(.medium))
                    .foregroundStyle(CaelynColor.deepPlumText)
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
    HStack(spacing: CaelynSpacing.xs) {
        QuickActionButton(title: "Log Period", icon: "drop.fill", background: CaelynColor.blush) {}
        QuickActionButton(title: "Add Symptoms", icon: "sparkles", background: CaelynColor.lavender) {}
        QuickActionButton(title: "Mood Check-in", icon: "face.smiling", background: CaelynColor.sage) {}
        QuickActionButton(title: "Add Note", icon: "square.and.pencil", background: CaelynColor.warmSand) {}
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
