import SwiftUI

/// A soft, one-time "here's what this screen is for" card.
///
/// **Why this shape and not a coach-mark tour.** A dark-overlay tour with arrows
/// pointing at tab-bar items needs the tab bar's on-screen geometry, which SwiftUI
/// doesn't expose — so it drifts with Dynamic Type and orientation, and has no
/// meaning at all on iPad, where Caelyn uses a `NavigationSplitView` sidebar
/// instead of a tab bar. It also lands right after an 11-step onboarding, which is
/// exactly when people start tapping "skip".
///
/// This card instead arrives **in context**: the first time she opens a tab, at the
/// top of that tab's own content, in her way not at all. One tap dismisses it
/// forever. It's ordinary layout — no overlays, no measured frames — so it can't
/// break across devices, text sizes, or orientations.
///
/// Home deliberately has no card: onboarding's finish already hands her a
/// prediction and the hero card explains itself, so a card there would be the
/// tour fatigue this design avoids.
struct FirstVisitIntroCard: View {

    enum Screen: String, CaseIterable {
        case calendar, log, insights, settings

        /// One AppStorage flag per screen: seen once, gone for good.
        var storageKey: String { "caelyn.seenIntro.\(rawValue)" }

        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .log:      return "heart.text.square.fill"
            case .insights: return "sparkles"
            case .settings: return "hand.raised.fill"
            }
        }

        var title: String {
            switch self {
            case .calendar: return "Your whole cycle, at a glance"
            case .log:      return "However you're feeling today"
            case .insights: return "The patterns, found for you"
            case .settings: return "All of it, yours to control"
            }
        }

        var body: String {
            switch self {
            // Deliberately does NOT re-explain the colours: the real legend sits
            // directly under the grid (Logged / Tap to log / Predicted / PMS /
            // Ovulation), and a second, differently-worded key would contradict it
            // the moment either one changes.
            case .calendar:
                return "Every day you've logged sits here beside what's coming — your predicted period, PMS window and ovulation. The legend under the grid decodes the colours."
            case .log:
                return "Flow, mood, energy, pain, symptoms, a private note — log as much or as little as you feel like. Even one tap teaches Caelyn something."
            case .insights:
                return "After a couple of cycles, Caelyn starts noticing what your body actually does — which symptoms travel together, when your energy dips, how your cycle really runs."
            case .settings:
                return "Reminders, app lock, Apple Health, and a doctor-ready PDF of your history all live here."
            }
        }

        /// The warm one-liner under the divider — a tip, or the privacy truth.
        var footnote: String {
            switch self {
            case .calendar: return "Tap any day to look back, or fill in one you missed."
            case .log:      return "The more you log, the more your predictions become yours."
            case .insights: return "All of it is worked out on your iPhone. Nothing is sent anywhere."
            case .settings: return "Your data never leaves this device — tap Your privacy to see exactly how."
            }
        }

        /// A **surface tint**, not a foreground colour. These palette entries are
        /// near-black in dark mode (lavender is 0x281B40, sage 0x1B2E1E) because
        /// they're designed to sit behind content — so they're only ever used here
        /// as a fill, never for text or glyphs. Anything that has to stay legible
        /// uses `primaryPlum` / `deepPlumText`, which adapt per theme.
        var tint: Color {
            switch self {
            case .calendar: return CaelynColor.softRose
            case .log:      return CaelynColor.lavender
            case .insights: return CaelynColor.sage
            case .settings: return CaelynColor.primaryPlum
            }
        }
    }

    let screen: Screen

    @AppStorage private var seen: Bool
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(_ screen: Screen) {
        self.screen = screen
        _seen = AppStorage(wrappedValue: false, screen.storageKey)
    }

    var body: some View {
        if !seen {
            card
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.96)
                .onAppear {
                    guard !appeared else { return }
                    if reduceMotion {
                        appeared = true
                    } else {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.15)) {
                            appeared = true
                        }
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var card: some View {
        CaelynCard(padding: CaelynSpacing.md, radius: CaelynRadius.cardLarge) {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                header
                Text(screen.body)
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(CaelynColor.deepPlumText.opacity(0.07))
                    .frame(height: 1)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.caption2)
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.75))
                        .accessibilityHidden(true)
                    Text(screen.footnote)
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                dismissButton
            }
        }
        // A whisper of the screen's accent behind the card, so each tab's intro
        // feels like it belongs to that tab without shouting.
        .background(
            RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
                .fill(screen.tint.opacity(0.14))
                .blur(radius: 12)
                .offset(y: 6)
        )
        .accessibilityElement(children: .contain)
    }

    /// Badge beside the title normally; badge above it at accessibility sizes,
    /// where a 3–4 line title next to a centred circle reads as a stray dot.
    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                badge
                titleText
            }
        } else {
            HStack(spacing: CaelynSpacing.sm) {
                badge
                titleText
            }
        }
    }

    private var titleText: some View {
        Text(screen.title)
            .font(CaelynFont.headline)
            .foregroundStyle(CaelynColor.deepPlumText)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [screen.tint.opacity(0.9), screen.tint.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
            Image(systemName: screen.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.85))
        }
        .accessibilityHidden(true)
    }

    private var dismissButton: some View {
        Button {
            Haptics.soft()
            if reduceMotion {
                seen = true
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) { seen = true }
            }
        } label: {
            Text("Got it")
                .font(CaelynFont.subheadline.weight(.semibold))
                .foregroundStyle(CaelynColor.primaryPlum)
                .padding(.horizontal, CaelynSpacing.md)
                .padding(.vertical, CaelynSpacing.xs)
                .background(
                    Capsule().fill(CaelynColor.primaryPlum.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel("Got it")
        .accessibilityHint("Dismisses this introduction")
    }
}

#Preview {
    ScrollView {
        VStack(spacing: CaelynSpacing.md) {
            ForEach(FirstVisitIntroCard.Screen.allCases, id: \.self) { s in
                FirstVisitIntroCard(s)
            }
        }
        .padding(CaelynSpacing.lg)
    }
    .background(CaelynColor.backgroundCream)
}
