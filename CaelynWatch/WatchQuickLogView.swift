import SwiftUI

struct WatchQuickLogView: View {
    @EnvironmentObject private var model: WatchDataModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFlow: String? = nil
    @State private var pain: Int = 0
    @State private var selectedMood: String? = nil
    @State private var saved = false

    private let flows: [(String, String)] = [
        ("None", ""),
        ("Spotting", "spotting"),
        ("Light", "light"),
        ("Medium", "medium"),
        ("Heavy", "heavy")
    ]
    private let moods: [(String, String)] = [
        ("😊", "happy"),
        ("😌", "calm"),
        ("😰", "anxious"),
        ("😢", "sad"),
        ("😤", "irritable")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if saved {
                    savedConfirmation
                } else {
                    flowPicker
                    moodPicker
                    painSlider
                    saveButton
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .navigationTitle("Quick Log")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Flow

    private var flowPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FLOW")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(flows, id: \.0) { label, key in
                        flowChip(label: label, key: key)
                    }
                }
            }
        }
    }

    private func flowChip(label: String, key: String) -> some View {
        let isSelected = selectedFlow == key
        return Button {
            selectedFlow = isSelected ? nil : key
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color(red: 0.91, green: 0.38, blue: 0.47) : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mood

    private var moodPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MOOD")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            HStack(spacing: 6) {
                ForEach(moods, id: \.0) { emoji, key in
                    moodChip(emoji: emoji, key: key)
                }
            }
        }
    }

    private func moodChip(emoji: String, key: String) -> some View {
        let isSelected = selectedMood == key
        return Button {
            selectedMood = isSelected ? nil : key
        } label: {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08), in: Circle())
                .overlay(
                    Circle().stroke(isSelected ? Color.white.opacity(0.6) : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pain

    private var painSlider: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PAIN")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("\(pain)/10")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Slider(value: Binding(get: { Double(pain) }, set: { pain = Int($0.rounded()) }), in: 0...10, step: 1)
                .tint(Color(red: 0.50, green: 0.30, blue: 0.65))
        }
    }

    // MARK: - Save

    private var saveButton: some View {
        let hasContent = selectedFlow != nil || pain > 0 || selectedMood != nil
        return Button {
            model.sendQuickLog(
                flow: selectedFlow.flatMap { $0.isEmpty ? nil : $0 },
                pain: pain > 0 ? pain : nil,
                mood: selectedMood
            )
            withAnimation { saved = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        } label: {
            Text("Save")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.50, green: 0.30, blue: 0.65))
        .disabled(!hasContent)
    }

    // MARK: - Saved confirmation

    private var savedConfirmation: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color(red: 0.41, green: 0.75, blue: 0.58))
            Text("Logged!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
            Text("Syncing to iPhone…")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
