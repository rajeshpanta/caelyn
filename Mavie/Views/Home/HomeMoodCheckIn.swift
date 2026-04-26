import SwiftUI

struct HomeMoodCheckIn: View {
    let selectedMood: Mood?
    let onSelect: (Mood) -> Void

    private let moods: [Mood] = [.calm, .happy, .energetic, .tired, .sensitive, .moody, .anxious, .focused]

    var body: some View {
        MavieCard {
            VStack(alignment: .leading, spacing: MavieSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("How are you feeling today?")
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text(selectedMood == nil
                         ? "Tap a mood to log a quick check-in."
                         : "You logged feeling \(selectedMood!.displayName.lowercased()) today.")
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
