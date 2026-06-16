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
                        .fill(
                            LinearGradient(
                                colors: [background, background.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: tint.opacity(0.18), radius: 6, x: 0, y: 3)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(title)
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(QuickActionStyle())
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

private struct QuickActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: CaelynSpacing.xs) {
        QuickActionButton(title: "Log Period", icon: "drop.fill", background: CaelynColor.blush) {}
        QuickActionButton(title: "Symptoms", icon: "sparkles", background: CaelynColor.lavender) {}
        QuickActionButton(title: "Mood", icon: "face.smiling", background: CaelynColor.sage) {}
        QuickActionButton(title: "Note", icon: "square.and.pencil", background: CaelynColor.warmSand) {}
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
