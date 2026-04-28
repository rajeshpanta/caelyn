import SwiftUI

enum CaelynButtonVariant {
    case primary
    case secondary
    case tertiary
}

struct CaelynButton: View {
    let title: String
    var variant: CaelynButtonVariant = .primary
    var icon: String? = nil
    var fullWidth: Bool = true
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: CaelynSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(CaelynFont.body.weight(.semibold))
            }
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.vertical, CaelynSpacing.md)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .opacity(isEnabled ? 1.0 : 0.4)
            .contentShape(Rectangle())
        }
        .buttonStyle(CaelynPressStyle())
    }

    private var foreground: Color {
        switch variant {
        case .primary: return .white
        case .secondary, .tertiary: return CaelynColor.primaryPlum
        }
    }

    private var background: Color {
        switch variant {
        case .primary: return CaelynColor.primaryPlum
        case .secondary, .tertiary: return .clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary: return CaelynColor.primaryPlum.opacity(0.4)
        default: return .clear
        }
    }

    private var borderWidth: CGFloat {
        variant == .secondary ? 1.5 : 0
    }
}

private struct CaelynPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.sm) {
        CaelynButton(title: "Continue", variant: .primary) {}
        CaelynButton(title: "Continue", variant: .primary, icon: "arrow.right") {}
        CaelynButton(title: "Skip for now", variant: .secondary) {}
        CaelynButton(title: "Maybe later", variant: .tertiary) {}
        CaelynButton(title: "Disabled primary", variant: .primary) {}
            .disabled(true)
        CaelynButton(title: "Disabled secondary", variant: .secondary) {}
            .disabled(true)
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
