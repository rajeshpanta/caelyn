import SwiftUI

struct HomeMoodCheckIn: View {
    let selectedMood: Mood?
    let onSelect: (Mood) -> Void

    private let moods: [Mood] = [.calm, .happy, .energetic, .tired, .sensitive, .moody, .anxious, .focused]

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
        MavieCard {
            VStack(alignment: .leading, spacing: MavieSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("How are you feeling today?")
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text(subtitle)
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MavieSpacing.xs) {
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
    }
}
