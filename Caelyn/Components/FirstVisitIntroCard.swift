import SwiftUI

/// A concise, one-time hint for screens whose first action is not obvious.
struct FirstVisitIntroCard: View {
    private static let isScreenshotMode = CommandLine.arguments.contains("--screenshot-mode")

    enum Screen: String, CaseIterable {
        case home, calendar, log, insights

        var storageKey: String { "caelyn.seenIntro.\(rawValue)" }

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .calendar: return "calendar"
            case .log: return "heart.text.square.fill"
            case .insights: return "chart.bar.fill"
            }
        }

        var title: String {
            switch self {
            case .home: return "Your daily snapshot"
            case .calendar: return "Using the calendar"
            case .log: return "Logging is flexible"
            case .insights: return "Patterns take time"
            }
        }

        var body: String {
            switch self {
            case .home:
                return "Home shows today's cycle estimate. Tap the phase card to learn more, or use a quick action to record how you feel."
            case .calendar:
                return "Tap any day to review or add a log. The legend explains logged and predicted dates."
            case .log:
                return "Choose a date, then add as much or as little as you like. Changes save automatically."
            case .insights:
                return "After two complete cycles, Caelyn starts comparing your timing and logs. Patterns become more useful as you keep logging."
            }
        }

        var tint: Color {
            switch self {
            case .home: return CaelynColor.blush
            case .calendar: return CaelynColor.softRose
            case .log: return CaelynColor.lavender
            case .insights: return CaelynColor.sage
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
        if !seen && !Self.isScreenshotMode {
            CaelynCard(padding: CaelynSpacing.md, radius: CaelynRadius.cardLarge) {
                VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                    header
                    Text(screen.body)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: CaelynRadius.cardLarge, style: .continuous)
                    .fill(screen.tint.opacity(0.14))
                    .blur(radius: 10)
                    .offset(y: 4)
            )
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.98)
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                        appeared = true
                    }
                }
            }
            .transition(.opacity)
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private var header: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                HStack {
                    badge
                    Spacer(minLength: 0)
                    dismissButton
                }
                titleText
            }
        } else {
            HStack(spacing: CaelynSpacing.sm) {
                badge
                titleText
                Spacer(minLength: 0)
                dismissButton
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
                .fill(screen.tint.opacity(0.65))
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
                withAnimation(.easeOut(duration: 0.2)) { seen = true }
            }
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss tip")
    }
}

// MARK: - Permanent in-app guide

/// A short reference users can revisit from Settings after the one-time tips
/// have been dismissed. This teaches the daily workflow without replaying the
/// personal questions or permission prompts in onboarding.
struct AppGuideView: View {
    @State private var tipsReset = false

    private struct GuideItem: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let body: String
        let tint: Color
    }

    private let items: [GuideItem] = [
        GuideItem(
            id: 1,
            icon: "house.fill",
            title: "Home · Understand today",
            body: "See your estimated cycle day, phase, and what may be coming next. Tap the large phase card for a plain-language explanation.",
            tint: CaelynColor.softRose
        ),
        GuideItem(
            id: 2,
            icon: "square.and.pencil.circle.fill",
            title: "Log · Record what matters",
            body: "Choose any date and add flow, symptoms, pain, mood, energy, temperature, or a private note. Add only what feels useful; changes save automatically.",
            tint: CaelynColor.lavender
        ),
        GuideItem(
            id: 3,
            icon: "calendar.badge.checkmark",
            title: "Calendar · Review your timeline",
            body: "Tap a day to review or update it. Use the legend to distinguish your actual logs from Caelyn's predicted dates.",
            tint: CaelynColor.blush
        ),
        GuideItem(
            id: 4,
            icon: "chart.bar.fill",
            title: "Insights · Notice patterns",
            body: "Once you have two complete cycles, Caelyn begins showing averages and patterns. More consistent logs make these summaries more meaningful.",
            tint: CaelynColor.sage
        ),
        GuideItem(
            id: 5,
            icon: "gearshape.fill",
            title: "Settings · Stay in control",
            body: "Adjust reminders and privacy, connect Apple Health, export a copy of your data, or permanently delete everything.",
            tint: CaelynColor.lavender
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                hero

                Text("Your daily rhythm")
                    .font(CaelynFont.title2)
                    .foregroundStyle(CaelynColor.deepPlumText)

                VStack(spacing: CaelynSpacing.sm) {
                    ForEach(items) { item in
                        guideRow(item)
                    }
                }

                CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.sage.opacity(0.45)) {
                    HStack(alignment: .top, spacing: CaelynSpacing.sm) {
                        Image(systemName: "heart.text.clipboard.fill")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(CaelynColor.successSage)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Use estimates as a guide")
                                .font(CaelynFont.headline)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("Cycle predictions and patterns can help you prepare, but they are not a diagnosis or birth-control method. Contact a healthcare professional about symptoms or changes that concern you.")
                                .font(CaelynFont.subheadline)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                CaelynButton(
                    title: "Show first-use tips again",
                    variant: .secondary,
                    icon: "arrow.counterclockwise"
                ) {
                    for screen in FirstVisitIntroCard.Screen.allCases {
                        UserDefaults.standard.removeObject(forKey: screen.storageKey)
                    }
                    tipsReset = true
                    Haptics.soft()
                }
            }
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.top, CaelynSpacing.md)
            .padding(.bottom, CaelynSpacing.xl)
            .caelynContentWidth()
            .frame(maxWidth: .infinity)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .navigationTitle("How Caelyn Works")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Tips are ready", isPresented: $tipsReset) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Visit Home, Calendar, Log, and Insights to see each short introduction again.")
        }
    }

    private var hero: some View {
        CaelynCard(padding: CaelynSpacing.lg) {
            VStack(spacing: CaelynSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [CaelynColor.softRose, CaelynColor.lavender],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                .accessibilityHidden(true)

                Text("Small logs become a clearer picture")
                    .font(CaelynFont.title2)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Check today, log what matters, then look back for patterns. Everything is processed privately on this device.")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func guideRow(_ item: GuideItem) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(alignment: .top, spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(item.tint.opacity(0.65))
                        .frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.82))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(item.body)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: CaelynSpacing.md) {
            ForEach(FirstVisitIntroCard.Screen.allCases, id: \.self) { screen in
                FirstVisitIntroCard(screen)
            }
        }
        .padding(CaelynSpacing.lg)
    }
    .background(CaelynColor.backgroundCream)
}
