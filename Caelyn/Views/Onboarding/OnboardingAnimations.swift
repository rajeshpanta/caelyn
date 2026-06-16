import SwiftUI

// MARK: - Floating decorative icon

struct FloatingIcon: View {
    let systemName: String
    let color: Color
    let size: CGFloat
    let delay: Double

    @State private var offsetY: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.7

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
            .offset(y: offsetY)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(delay)) {
                    opacity = 1
                    scale = 1
                }
                withAnimation(
                    .easeInOut(duration: 2.6 + delay * 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    offsetY = -13
                }
            }
    }
}

// MARK: - Soft pulsing glow

struct PulsingGlow: View {
    let color: Color
    let size: CGFloat
    let delay: Double

    @State private var scale: CGFloat = 0.9

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: size * 0.28)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.8)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    scale = 1.12
                }
            }
    }
}

// MARK: - Confetti particle

struct ConfettiParticle: View {
    let symbol: String
    let color: Color
    let size: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let delay: Double

    @State private var appear = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .foregroundStyle(color)
            .offset(x: offsetX, y: offsetY)
            .scaleEffect(appear ? 1 : 0.1)
            .opacity(appear ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(delay)) {
                    appear = true
                }
            }
    }
}

// MARK: - Feature slide illustration

struct FeatureSlideIllustration: View {
    let systemName: String
    let accentColor: Color

    @State private var pulse = false
    @State private var appear = false

    var body: some View {
        ZStack {
            PulsingGlow(color: accentColor.opacity(0.22), size: 200, delay: 0)
            PulsingGlow(color: accentColor.opacity(0.14), size: 260, delay: 0.4)

            Circle()
                .fill(accentColor.opacity(0.12))
                .frame(width: 160, height: 160)

            Image(systemName: systemName)
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, CaelynColor.primaryPlum],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating)
                .scaleEffect(appear ? 1 : 0.7)
                .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
        .onDisappear { appear = false }
    }
}
