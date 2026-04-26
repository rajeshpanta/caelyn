import SwiftUI

struct MoodChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(MavieFont.callout.weight(.medium))
                .padding(.horizontal, MavieSpacing.md)
                .padding(.vertical, MavieSpacing.xs + 2)
                .foregroundStyle(isSelected ? .white : MavieColor.deepPlumText)
                .background(isSelected ? MavieColor.primaryPlum : MavieColor.blush)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let moods = ["Calm", "Tired", "Moody", "Energetic", "Anxious", "Sensitive"]
    VStack(spacing: MavieSpacing.sm) {
        FlexibleHStack(items: moods, selected: "Calm")
    }
    .padding()
    .background(MavieColor.backgroundCream)
}

private struct FlexibleHStack: View {
    let items: [String]
    let selected: String
    var body: some View {
        HStack(spacing: MavieSpacing.xs) {
            ForEach(items.prefix(3), id: \.self) { mood in
                MoodChip(label: mood, isSelected: mood == selected) {}
            }
        }
        HStack(spacing: MavieSpacing.xs) {
            ForEach(items.suffix(3), id: \.self) { mood in
                MoodChip(label: mood, isSelected: false) {}
            }
        }
    }
}
