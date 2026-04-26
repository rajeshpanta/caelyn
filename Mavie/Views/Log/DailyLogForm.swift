import SwiftUI
import SwiftData

struct DailyLogForm: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleEntry.date, order: .reverse) private var allEntries: [CycleEntry]

    @State private var noteDraft: String = ""
    @State private var showAdvanced: Bool = false
    @State private var medicationDraft: String = ""
    @State private var basalTempDraft: String = ""
    @FocusState private var noteFocused: Bool
    @FocusState private var medicationFocused: Bool
    @FocusState private var basalFocused: Bool

    private var entry: CycleEntry? {
        let target = Calendar.current.startOfDay(for: date)
        return allEntries.first { Calendar.current.isDate($0.date, inSameDayAs: target) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.lg) {
            flowSection
            painSection
            symptomsSection
            moodSection
            noteSection
            advancedSection
        }
        .onAppear {
            noteDraft = entry?.note ?? ""
            medicationDraft = entry?.medication ?? ""
            basalTempDraft = entry?.basalTemperature.map { String(format: "%.1f", $0) } ?? ""
        }
        .onChange(of: noteFocused) { _, focused in
            if !focused { commitNote() }
        }
        .onChange(of: medicationFocused) { _, focused in
            if !focused { commitMedication() }
        }
        .onChange(of: basalFocused) { _, focused in
            if !focused { commitBasalTemp() }
        }
    }

    // MARK: - Flow

    private var flowSection: some View {
        SectionContainer(title: "Flow") {
            HStack(spacing: 6) {
                flowPill(nil, label: "None")
                flowPill(.spotting, label: "Spotting")
                flowPill(.light, label: "Light")
                flowPill(.medium, label: "Medium")
                flowPill(.heavy, label: "Heavy")
            }
        }
    }

    private func flowPill(_ flow: FlowLevel?, label: String) -> some View {
        let isSelected = entry?.flow == flow
        return Button {
            withEntry { $0.flow = flow }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? flowColor(flow) : flowColor(flow).opacity(0.35))
                        .frame(width: 28, height: 28)
                    if flow == nil {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                    }
                }
                Text(label)
                    .font(MavieFont.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(MavieColor.deepPlumText.opacity(isSelected ? 1.0 : 0.65))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, MavieSpacing.sm)
            .background(
                isSelected ? flowColor(flow).opacity(0.18) : MavieColor.cardWhite.opacity(0.5),
                in: RoundedRectangle(cornerRadius: MavieRadius.chip, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MavieRadius.chip, style: .continuous)
                    .stroke(
                        isSelected ? flowColor(flow).opacity(0.5) : MavieColor.deepPlumText.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func flowColor(_ flow: FlowLevel?) -> Color {
        switch flow {
        case .none:     return MavieColor.deepPlumText
        case .spotting: return MavieColor.softRose.opacity(0.7)
        case .light:    return MavieColor.softRose
        case .medium:   return MavieColor.alertRose.opacity(0.85)
        case .heavy:    return MavieColor.alertRose
        }
    }

    // MARK: - Pain

    private var painSection: some View {
        SectionContainer(title: "Pain") {
            VStack(alignment: .leading, spacing: MavieSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(entry?.pain ?? 0)")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(MavieColor.primaryPlum)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: entry?.pain)
                    Text("/ 10")
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                    Spacer()
                    Text(painLabel(entry?.pain ?? 0))
                        .font(MavieFont.caption.weight(.medium))
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                }

                Slider(
                    value: Binding(
                        get: { Double(entry?.pain ?? 0) },
                        set: { newValue in withEntry { $0.pain = Int(newValue.rounded()) } }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(MavieColor.primaryPlum)

                Text("Pain locations")
                    .font(MavieFont.caption.weight(.semibold))
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                    .tracking(0.3)
                    .padding(.top, 4)

                FlexibleChipRow(items: PainType.allCases) { painType in
                    painChip(for: painType)
                }
            }
        }
    }

    private func painChip(for painType: PainType) -> some View {
        let isSelected = entry?.painTypes.contains(painType) ?? false
        return Button {
            togglePainType(painType)
        } label: {
            Text(painType.displayName)
                .font(MavieFont.callout.weight(.medium))
                .padding(.horizontal, MavieSpacing.sm)
                .padding(.vertical, MavieSpacing.xs)
                .foregroundStyle(isSelected ? .white : MavieColor.deepPlumText)
                .background(isSelected ? MavieColor.primaryPlum : MavieColor.lavender.opacity(0.5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func painLabel(_ pain: Int) -> String {
        switch pain {
        case 0:     return "None"
        case 1...3: return "Mild"
        case 4...6: return "Moderate"
        case 7...8: return "Strong"
        default:    return "Severe"
        }
    }

    // MARK: - Symptoms

    private var symptomsSection: some View {
        let visibleSymptoms: [Symptom] = [
            .bloating, .acne, .cravings, .fatigue,
            .nausea, .dizziness, .sleepChanges, .tenderBreasts
        ]
        return SectionContainer(title: "Symptoms") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: MavieSpacing.xs), count: 4),
                spacing: MavieSpacing.xs
            ) {
                ForEach(visibleSymptoms) { symptom in
                    SymptomChip(
                        label: symptom.displayName,
                        icon: symptom.icon,
                        isSelected: entry?.symptoms.contains(symptom) ?? false
                    ) {
                        toggleSymptom(symptom)
                    }
                }
            }
        }
    }

    // MARK: - Mood

    private var moodSection: some View {
        let visibleMoods: [Mood] = [
            .calm, .happy, .focused, .sensitive,
            .anxious, .sad, .irritable, .lowEnergy
        ]
        return SectionContainer(title: "Mood") {
            FlexibleChipRow(items: visibleMoods) { mood in
                MoodChip(
                    label: mood.displayName,
                    isSelected: entry?.mood == mood
                ) {
                    setMood(mood)
                }
            }
        }
    }

    // MARK: - Note

    private var noteSection: some View {
        SectionContainer(title: "Note") {
            ZStack(alignment: .topLeading) {
                if noteDraft.isEmpty {
                    Text("Add a private note…")
                        .font(MavieFont.body)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.35))
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $noteDraft)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .focused($noteFocused)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    showAdvanced.toggle()
                }
            } label: {
                HStack {
                    Text(showAdvanced ? "Hide tracking options" : "More tracking options")
                        .font(MavieFont.body.weight(.medium))
                        .foregroundStyle(MavieColor.primaryPlum)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
                .padding(.horizontal, MavieSpacing.md)
                .padding(.vertical, MavieSpacing.sm)
                .background(MavieColor.lavender.opacity(0.6), in: Capsule())
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(spacing: MavieSpacing.sm) {
                    medicationField
                    basalTempField
                    advancedToggleRow(
                        title: "Ovulation test",
                        icon: "testtube.2",
                        isOn: Binding(
                            get: { entry?.ovulationTest ?? false },
                            set: { newValue in withEntry { $0.ovulationTest = newValue ? true : nil } }
                        )
                    )
                    advancedToggleRow(
                        title: "Pregnancy test",
                        icon: "cross.case",
                        isOn: Binding(
                            get: { entry?.pregnancyTest ?? false },
                            set: { newValue in withEntry { $0.pregnancyTest = newValue ? true : nil } }
                        )
                    )
                    advancedToggleRow(
                        title: "Sexual activity",
                        icon: "heart",
                        isOn: Binding(
                            get: { entry?.sexualActivity ?? false },
                            set: { newValue in withEntry { $0.sexualActivity = newValue ? true : nil } }
                        )
                    )
                    cervicalMucusField
                }
                .padding(.top, MavieSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var medicationField: some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: MavieSpacing.sm) {
                Image(systemName: "pills")
                    .foregroundStyle(MavieColor.primaryPlum)
                    .frame(width: 24)
                TextField("Medication", text: $medicationDraft)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                    .focused($medicationFocused)
                    .submitLabel(.done)
                    .onSubmit { commitMedication() }
            }
        }
    }

    private var basalTempField: some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: MavieSpacing.sm) {
                Image(systemName: "thermometer.medium")
                    .foregroundStyle(MavieColor.primaryPlum)
                    .frame(width: 24)
                TextField("Basal temperature (°F)", text: $basalTempDraft)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                    .keyboardType(.decimalPad)
                    .focused($basalFocused)
            }
        }
    }

    private var cervicalMucusField: some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: MavieSpacing.sm) {
                Image(systemName: "drop.degreesign")
                    .foregroundStyle(MavieColor.primaryPlum)
                    .frame(width: 24)
                Text("Cervical mucus")
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                Spacer()
                Menu {
                    Button("Clear") { withEntry { $0.cervicalMucus = nil } }
                    Divider()
                    ForEach(CervicalMucus.allCases) { mucus in
                        Button(mucus.displayName) { withEntry { $0.cervicalMucus = mucus } }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(entry?.cervicalMucus?.displayName ?? "Choose")
                            .font(MavieFont.callout.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(MavieColor.primaryPlum)
                }
            }
        }
    }

    private func advancedToggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: MavieSpacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(MavieColor.primaryPlum)
                    .frame(width: 24)
                Text(title)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(MavieColor.primaryPlum)
            }
        }
    }

    // MARK: - Mutations

    private func withEntry(_ mutate: (CycleEntry) -> Void) {
        let target = entry ?? CycleEntry(date: date)
        if entry == nil { modelContext.insert(target) }
        mutate(target)
        target.updatedAt = .now
        try? modelContext.save()
    }

    private func toggleSymptom(_ symptom: Symptom) {
        withEntry { entry in
            if let idx = entry.symptoms.firstIndex(of: symptom) {
                entry.symptoms.remove(at: idx)
            } else {
                entry.symptoms.append(symptom)
            }
        }
    }

    private func togglePainType(_ painType: PainType) {
        withEntry { entry in
            if let idx = entry.painTypes.firstIndex(of: painType) {
                entry.painTypes.remove(at: idx)
            } else {
                entry.painTypes.append(painType)
            }
        }
    }

    private func setMood(_ mood: Mood) {
        withEntry { entry in
            entry.mood = entry.mood == mood ? nil : mood
        }
    }

    private func commitNote() {
        withEntry { $0.note = noteDraft.isEmpty ? nil : noteDraft }
    }

    private func commitMedication() {
        withEntry { $0.medication = medicationDraft.isEmpty ? nil : medicationDraft }
    }

    private func commitBasalTemp() {
        let trimmed = basalTempDraft.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            withEntry { $0.basalTemperature = nil }
        } else if let value = Double(trimmed) {
            withEntry { $0.basalTemperature = value }
        }
    }
}

// MARK: - SectionContainer

private struct SectionContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            Text(title.uppercased())
                .font(MavieFont.caption.weight(.semibold))
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                .tracking(0.6)
            MavieCard(padding: MavieSpacing.md) {
                content()
            }
        }
    }
}

// MARK: - FlexibleChipRow (wraps to multiple lines)

private struct FlexibleChipRow<Item: Identifiable, ChipView: View>: View {
    let items: [Item]
    let chip: (Item) -> ChipView

    var body: some View {
        FlowLayout(spacing: MavieSpacing.xs) {
            ForEach(items) { item in
                chip(item)
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let result = arrange(subviews: subviews, in: width)
        return CGSize(width: result.width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, in: bounds.width)
        for (subview, offset) in zip(subviews, result.offsets) {
            subview.place(at: CGPoint(x: bounds.minX + offset.x, y: bounds.minY + offset.y), proposal: .unspecified)
        }
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> (offsets: [CGPoint], width: CGFloat, height: CGFloat) {
        var offsets: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            offsets.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxWidth = max(maxWidth, x - spacing)
        }
        return (offsets, maxWidth, y + rowHeight)
    }
}

#Preview {
    ScrollView {
        DailyLogForm(date: .now)
            .padding(MavieSpacing.lg)
    }
    .background(MavieColor.backgroundCream)
    .modelContainer(Persistence.preview)
}
