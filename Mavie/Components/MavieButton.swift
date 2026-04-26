import SwiftUI

enum MavieButtonVariant {
    case primary
    case secondary
    case tertiary
}

struct MavieButton: View {
    let title: String
    var variant: MavieButtonVariant = .primary
    var icon: String? = nil
    var fullWidth: Bool = true
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: MavieSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(MavieFont.body.weight(.semibold))
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, MavieSpacing.lg)
            .padding(.vertical, MavieSpacing.md)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: MavieRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.button, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .opacity(isEnabled ? 1.0 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(MaviePressStyle())
    }

    private var foreground: Color {
        switch variant {
        case .primary: return .white
        case .secondary, .tertiary: return MavieColor.primaryPlum
        }
    }

    private var background: Color {
        switch variant {
        case .primary: return MavieColor.primaryPlum
        case .secondary, .tertiary: return .clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: return MavieColor.primaryPlum.opacity(0.4)
        default: return .clear
        }
    }

    private var borderWidth: CGFloat {
        variant == .secondary ? 1.5 : 0
    }
}

private struct MaviePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: MavieSpacing.sm) {
        MavieButton(title: "Continue", variant: .primary) {}
        MavieButton(title: "Continue", variant: .primary, icon: "arrow.right") {}
        MavieButton(title: "Skip for now", variant: .secondary) {}
        MavieButton(title: "Maybe later", variant: .tertiary) {}
        MavieButton(title: "Disabled primary", variant: .primary) {}
            .disabled(true)
        MavieButton(title: "Disabled secondary", variant: .secondary) {}
            .disabled(true)
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
