import SwiftUI

struct MoodChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(label)
                .font(CaelynFont.callout.weight(.medium))
                .padding(.horizontal, CaelynSpacing.md)
                .padding(.vertical, CaelynSpacing.xs + 2)
                .foregroundStyle(isSelected ? .white : CaelynColor.deepPlumText)
                .background(isSelected ? CaelynColor.primaryPlum : CaelynColor.blush)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    let moods = ["Calm", "Tired", "Moody", "Energetic", "Anxious", "Sensitive"]
    VStack(spacing: CaelynSpacing.sm) {
        FlexibleHStack(items: moods, selected: "Calm")
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}

private struct FlexibleHStack: View {
    let items: [String]
    let selected: String
    var body: some View {
        HStack(spacing: CaelynSpacing.xs) {
            ForEach(items.prefix(3), id: \.self) { mood in
                MoodChip(label: mood, isSelected: mood == selected) {}
            }
        }
        HStack(spacing: CaelynSpacing.xs) {
            ForEach(items.suffix(3), id: \.self) { mood in
                MoodChip(label: mood, isSelected: false) {}
            }
        }
    }
}
