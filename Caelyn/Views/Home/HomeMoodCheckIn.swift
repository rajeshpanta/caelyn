import SwiftUI

struct HomeMoodCheckIn: View {
    let selectedMood: Mood?
    let onSelect: (Mood) -> Void

    @Environment(\.highlightedNotificationCategory) private var highlight
    @State private var pulseFlag = false

    private let moods: [Mood] = [.calm, .happy, .energetic, .tired, .sensitive, .moody, .anxious, .focused]

    private var isHighlighted: Bool { highlight == .dailyCheckIn }

    private var subtitle: String {
        guard let selectedMood else {
            return "Tap a mood — there's no wrong answer."
        }
        let mood = selectedMood.displayName.lowercased()
        switch selectedMood {
        // Light, positive moods → simple, warm confirmation.
        case .calm, .happy, .energetic, .focused:
            return "Logged: feeling \(mood) today. ☺︎"
        // Heavier moods → quiet acknowledgement, no advice, no preaching.
        case .tired, .lowEnergy:
            return "Logged: feeling \(mood). Rest is allowed."
        case .sensitive, .sad:
            return "Logged: feeling \(mood). Be kind to yourself today."
        case .anxious:
            return "Logged: feeling anxious. Slow breaths — you're okay."
        case .moody, .irritable:
            return "Logged: feeling \(mood). Some days are like this."
        }
    }

    var body: some View {
        CaelynCard {
            VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("How are you feeling today?")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(subtitle)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CaelynSpacing.xs) {
                        ForEach(moods, id: \.self) { mood in
                            MoodChip(
                                label: mood.displayName,
                                isSelected: selectedMood == mood
                            ) {
                                onSelect(mood)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollClipDisabled()
            }
        }
        .overlay(
            // Soft pulse ring shown for ~2.5s after the user opened the app
            // by tapping the daily-check-in notification — tells them, with
            // zero text, "this is what we reminded you about."
            RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                .stroke(CaelynColor.primaryPlum.opacity(isHighlighted ? 0.55 : 0), lineWidth: 2)
                .scaleEffect(pulseFlag ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatCount(3, autoreverses: true), value: pulseFlag)
                .allowsHitTesting(false)
        )
        .onChange(of: isHighlighted) { _, newValue in
            if newValue { pulseFlag.toggle() }
        }
    }
}
