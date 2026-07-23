import SwiftUI

struct MoodChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Haptics.selection()
            popAndBloom()
            action()
        } label: {
            Text(label)
                .font(CaelynFont.callout.weight(.medium))
                .padding(.horizontal, CaelynSpacing.md)
                .padding(.vertical, CaelynSpacing.xs + 2)
                .foregroundStyle(isSelected ? CaelynColor.onPrimary : CaelynColor.deepPlumText)
                .background(isSelected ? CaelynColor.primaryPlum : CaelynColor.blush)
                .clipShape(Capsule())
                // The "Caelyn heard you" beat: a spring settle on tap + the fill
                // blooming into plum over ~220ms. Same physics on every log chip.
                .scaleEffect(pressed ? 0.94 : 1.0)
                .animation(.easeOut(duration: 0.22), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) mood")
        .accessibilityHint(isSelected ? "Selected" : "Tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func popAndBloom() {
        guard !reduceMotion else { return }
        pressed = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { pressed = false }
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
