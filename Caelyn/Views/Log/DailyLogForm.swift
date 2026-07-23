import SwiftUI
import SwiftData

struct DailyLogForm: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleEntry.date, order: .reverse) private var allEntries: [CycleEntry]
    @Query private var profiles: [UserProfile]

    @State private var noteDraft: String = ""
    @State private var showAdvanced: Bool = false
    @State private var medicationDraft: String = ""
    @State private var basalTempDraft: String = ""
    @State private var showAddSymptom = false
    @State private var newSymptomDraft = ""
    @FocusState private var noteFocused: Bool
    @FocusState private var medicationFocused: Bool
    @FocusState private var basalFocused: Bool
    @FocusState private var newSymptomFocused: Bool

    private var profile: UserProfile? { profiles.first }

    private var entry: CycleEntry? {
        let target = Calendar.current.startOfDay(for: date)
        return allEntries.first { Calendar.current.isDate($0.date, inSameDayAs: target) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
            flowSection
            painSection
            symptomsSection
            moodSection
            energySection
            temperatureSection
            ovulationTestSection
            noteSection
            advancedSection
        }
        .onAppear {
            noteDraft = entry?.note ?? ""
            medicationDraft = entry?.medication ?? ""
            basalTempDraft = entry?.basalTemperature.map { String(format: "%.2f", $0) } ?? ""
        }
        .onDisappear {
            commitNote()
            commitMedication()
            commitBasalTemp()
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
            Haptics.selection()
            // Don't create an entry just to set flow to nil (e.g. tapping "None"
            // on a day with no log) — that would be a phantom entry (stz-011).
            let newValue: FlowLevel? = (entry?.flow == flow) ? nil : flow
            guard newValue != nil || entry != nil else { return }
            withEntry { $0.flow = newValue }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? flowColor(flow) : flowColor(flow).opacity(0.35))
                        .frame(width: CaelynIconSize.sm, height: CaelynIconSize.sm)
                    if flow == nil {
                        Image(systemName: "minus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    }
                }
                Text(label)
                    .font(CaelynFont.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(isSelected ? 1.0 : 0.65))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CaelynSpacing.sm)
            .background(
                isSelected ? flowColor(flow).opacity(0.18) : CaelynColor.cardWhite.opacity(0.5),
                in: RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
                    .stroke(
                        isSelected ? flowColor(flow).opacity(0.5) : CaelynColor.deepPlumText.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) flow")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func flowColor(_ flow: FlowLevel?) -> Color {
        switch flow {
        case .none:     return CaelynColor.deepPlumText
        case .spotting: return CaelynColor.softRose.opacity(0.7)
        case .light:    return CaelynColor.softRose
        case .medium:   return CaelynColor.alertRose.opacity(0.85)
        case .heavy:    return CaelynColor.alertRose
        }
    }

    // MARK: - Pain

    private var painSection: some View {
        SectionContainer(title: "Pain") {
            VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(entry?.pain ?? 0)")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: entry?.pain)
                    Text("/ 10")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    Spacer()
                    if let pain = entry?.pain, pain > 0 {
                        Button {
                            Haptics.selection()
                            withEntry { $0.pain = nil }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                    Text(entry?.pain.map { painLabel($0) } ?? "")
                        .font(CaelynFont.caption.weight(.medium))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                }

                Slider(
                    value: Binding(
                        get: { Double(entry?.pain ?? 0) },
                        set: { newValue in
                            let rounded = Int(newValue.rounded())
                            if rounded > 0 || entry != nil {
                                withEntry { $0.pain = rounded == 0 ? nil : rounded }
                            }
                        }
                    ),
                    in: 0...10,
                    step: 1
                )
                .tint(CaelynColor.primaryPlum)
                .accessibilityLabel("Pain level")
                .accessibilityValue("\(entry?.pain ?? 0) out of 10, \(painLabel(entry?.pain ?? 0))")

                Text("Where does it hurt?")
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
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
                .font(CaelynFont.callout.weight(.medium))
                .padding(.horizontal, CaelynSpacing.sm)
                .padding(.vertical, CaelynSpacing.xs)
                .foregroundStyle(isSelected ? .white : CaelynColor.deepPlumText)
                .background(isSelected ? CaelynColor.primaryPlum : CaelynColor.lavender.opacity(0.5))
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

    private var visibleSymptoms: [Symptom] {
        var base: [Symptom] = [.cramps, .bloating, .headache, .backPain, .acne, .cravings, .fatigue, .nausea, .dizziness, .sleepChanges, .tenderBreasts]
        if profile?.perimenoEnabled == true {
            base += Symptom.perimenoSymptoms.filter { !base.contains($0) }
        }
        if profile?.endoEnabled == true {
            base += Symptom.endoSymptoms.filter { !base.contains($0) }
        }
        if profile?.pcosEnabled == true {
            base += Symptom.pcosSymptoms.filter { !base.contains($0) }
        }
        if profile?.pregnancyEnabled == true {
            base += Symptom.pregnancySymptoms.filter { !base.contains($0) }
        }
        if profile?.postpartumEnabled == true {
            base += Symptom.postpartumSymptoms.filter { !base.contains($0) }
        }
        return base
    }

    private var symptomsSection: some View {
        let customNames = profile?.customSymptoms ?? []
        let builtInSelected = entry?.symptoms ?? []
        let customSelected = entry?.loggedCustomSymptoms ?? []
        return SectionContainer(title: "Symptoms") {
            VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                // Built-in chips
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: CaelynSpacing.xs), count: 4),
                    spacing: CaelynSpacing.xs
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

                // Custom symptom chips + add button
                FlowLayout(spacing: CaelynSpacing.xs) {
                    ForEach(customNames, id: \.self) { name in
                        SymptomChip(
                            label: name,
                            icon: "tag.fill",
                            isSelected: entry?.loggedCustomSymptoms.contains(name) ?? false
                        ) {
                            toggleCustomSymptom(name)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                removeCustomSymptom(name)
                            } label: {
                                Label("Remove symptom", systemImage: "trash")
                            }
                        }
                    }

                    if customNames.count < 5 {
                        Button {
                            showAddSymptom = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(CaelynFont.caption.weight(.semibold))
                                .foregroundStyle(CaelynColor.primaryPlum)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(CaelynColor.lavender.opacity(0.5), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add custom symptom")
                    } else {
                        Text("5 max")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                    }
                }

                // Severity picker for all selected (built-in + custom)
                if !builtInSelected.isEmpty || !customSelected.isEmpty {
                    severitySection(builtIn: builtInSelected, custom: customSelected)
                }
            }
        }
        .sheet(isPresented: $showAddSymptom) {
            addCustomSymptomSheet
        }
    }

    // MARK: - Severity

    private func severitySection(builtIn: [Symptom], custom: [String]) -> some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
            Text("How severe?")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                .tracking(0.3)
                .padding(.top, 4)

            ForEach(builtIn) { symptom in
                severityRow(name: symptom.displayName, key: symptom.rawValue)
            }
            ForEach(custom, id: \.self) { name in
                severityRow(name: name, key: "custom:\(name)")
            }
        }
    }

    private func severityRow(name: String, key: String) -> some View {
        let currentLevel = entry?.symptomSeverity[key] ?? 2
        return HStack(spacing: 6) {
            Text(name)
                .font(CaelynFont.callout)
                .foregroundStyle(CaelynColor.deepPlumText)
                .frame(minWidth: 80, alignment: .leading)
                .lineLimit(1)
            Spacer(minLength: 4)
            ForEach([1, 2, 3], id: \.self) { level in
                let labels = ["Mild", "Mod", "Severe"]
                let label = labels[level - 1]
                let isActive = currentLevel == level
                Button {
                    Haptics.selection()
                    withEntry {
                        if $0.symptomSeverity[key] == level {
                            $0.symptomSeverity.removeValue(forKey: key)
                        } else {
                            $0.symptomSeverity[key] = level
                        }
                    }
                } label: {
                    Text(label)
                        .font(CaelynFont.caption.weight(isActive ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundStyle(isActive ? Color.white : CaelynColor.deepPlumText.opacity(0.7))
                        .background(
                            isActive ? severityColor(level) : CaelynColor.lavender.opacity(0.45),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label) severity for \(name)")
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
    }

    private func severityColor(_ level: Int) -> Color {
        switch level {
        case 1:  return CaelynColor.successSage
        case 2:  return CaelynColor.primaryPlum.opacity(0.75)
        default: return CaelynColor.alertRose
        }
    }

    // MARK: - Add Custom Symptom Sheet

    private var addCustomSymptomSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                Text("Name your symptom")
                    .font(CaelynFont.callout)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))

                TextField("e.g. Insomnia, Joint pain", text: $newSymptomDraft)
                    .focused($newSymptomFocused)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit { commitAddSymptom() }

                Spacer()
            }
            .padding(CaelynSpacing.lg)
            .onAppear { newSymptomFocused = true }
            .navigationTitle("Add Symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newSymptomDraft = ""
                        showAddSymptom = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { commitAddSymptom() }
                        .disabled(addSymptomDisabled)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
    }

    private var addSymptomDisabled: Bool {
        let trimmed = newSymptomDraft.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return true }
        let existing = profile?.customSymptoms ?? []
        return existing.contains(trimmed) || existing.count >= 5
    }

    private func commitAddSymptom() {
        let name = newSymptomDraft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              !(profile?.customSymptoms.contains(name) ?? false),
              (profile?.customSymptoms.count ?? 0) < 5 else { return }
        profile?.customSymptoms.append(name)
        modelContext.saveOrLog()
        newSymptomDraft = ""
        showAddSymptom = false
    }

    // MARK: - Mood

    private var moodSection: some View {
        let visibleMoods: [Mood] = [
            .calm, .happy, .energetic, .focused,
            .sensitive, .anxious, .tired, .moody,
            .sad, .irritable, .lowEnergy
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

    // MARK: - Energy

    private var energySection: some View {
        SectionContainer(title: "Energy") {
            HStack(spacing: CaelynSpacing.xs) {
                ForEach(EnergyLevel.allCases) { level in
                    energyPill(level)
                }
            }
        }
    }

    private func energyPill(_ level: EnergyLevel) -> some View {
        let isSelected = entry?.energyLevel == level
        return Button {
            Haptics.selection()
            let newValue: EnergyLevel? = (entry?.energyLevel == level) ? nil : level
            guard newValue != nil || entry != nil else { return }   // no phantom entry (stz-011)
            withEntry { $0.energyLevel = newValue }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: level.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? energyColor(level) : CaelynColor.deepPlumText.opacity(0.4))
                Text(level.displayName)
                    .font(CaelynFont.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(isSelected ? 0.9 : 0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, CaelynSpacing.sm)
            .background(
                isSelected ? energyColor(level).opacity(0.15) : CaelynColor.cardWhite.opacity(0.5),
                in: RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
                    .stroke(
                        isSelected ? energyColor(level).opacity(0.4) : CaelynColor.deepPlumText.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(level.displayName) energy")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func energyColor(_ level: EnergyLevel) -> Color {
        switch level {
        case .drained:   return CaelynColor.deepPlumText
        case .low:       return CaelynColor.alertRose
        case .moderate:  return CaelynColor.warmSand
        case .high:      return CaelynColor.successSage
        case .energized: return CaelynColor.primaryPlum
        }
    }

    // MARK: - Temperature

    private var temperatureSection: some View {
        SectionContainer(title: "Temperature", subtitle: "Measure before getting up for accuracy") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: CaelynSpacing.sm) {
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .frame(width: 24)
                    TextField("°C (e.g. 36.5)", text: $basalTempDraft)
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .keyboardType(.decimalPad)
                        .focused($basalFocused)
                        .accessibilityLabel("Basal body temperature in degrees Celsius")
                    if let temp = entry?.basalTemperature {
                        Text(String(format: "%.2f°C", temp))
                            .font(CaelynFont.callout.monospacedDigit())
                            .foregroundStyle(CaelynColor.primaryPlum)
                    }
                }
                if !basalTempDraft.isEmpty, Double(basalTempDraft) == nil || {
                    let v = Double(basalTempDraft) ?? 0; return v < 35.0 || v > 42.0
                }() {
                    Text("Enter a value between 35.0 and 42.0°C")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.alertRose.opacity(0.8))
                }
            }
        }
    }

    // MARK: - Ovulation Test

    private var ovulationTestSection: some View {
        SectionContainer(title: "Ovulation Test") {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                HStack(spacing: CaelynSpacing.xs) {
                    // Clear button
                    if entry?.ovulationTestResult != nil {
                        Button {
                            Haptics.selection()
                            withEntry { $0.ovulationTestResult = nil }
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: CaelynSpacing.xs) {
                    ForEach(OvulationTestResult.allCases) { result in
                        ovTestChip(result)
                    }
                }
                if let result = entry?.ovulationTestResult, result != .negative {
                    let hint: String = {
                        switch result {
                        case .rising:  return "LH is rising — you may ovulate in the next 2–3 days."
                        case .lhSurge: return "Surge detected — you're likely ovulating soon. Most fertile now."
                        case .positive: return "Peak fertility — great time if you're trying to conceive."
                        default: return ""
                        }
                    }()
                    Label(hint, systemImage: "info.circle")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.successSage)
                }
            }
        }
    }

    private func ovTestChip(_ result: OvulationTestResult) -> some View {
        let isSelected = entry?.ovulationTestResult == result
        let accentColor: Color = {
            switch result {
            case .negative: return CaelynColor.deepPlumText.opacity(0.6)
            case .rising:   return CaelynColor.warmSand.opacity(0.8)
            case .lhSurge:  return CaelynColor.primaryPlum
            case .positive: return CaelynColor.successSage
            }
        }()
        return Button {
            Haptics.selection()
            let newValue: OvulationTestResult? = (entry?.ovulationTestResult == result) ? nil : result
            guard newValue != nil || entry != nil else { return }   // no phantom entry (stz-011)
            withEntry { $0.ovulationTestResult = newValue }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: result.icon)
                    .font(.system(size: 13, weight: .medium))
                Text(result.displayName)
                    .font(CaelynFont.callout.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? .white : accentColor)
            .padding(.horizontal, CaelynSpacing.sm)
            .padding(.vertical, CaelynSpacing.xs)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? accentColor : accentColor.opacity(0.12),
                in: RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CaelynRadius.chip, style: .continuous)
                    .stroke(isSelected ? accentColor.opacity(0.0) : accentColor.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.displayName) ovulation test")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Note

    private var noteSection: some View {
        SectionContainer(title: "Note") {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                ZStack(alignment: .topLeading) {
                    if noteDraft.isEmpty {
                        Text("What's on your mind? Just for you 🔒")
                            .font(CaelynFont.body)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $noteDraft)
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80)
                        .focused($noteFocused)
                }
                .padding(.horizontal, 4)

                // Optional gentle reminder on this note — a date, or cycle-relative
                // ("before my next period"), which only a period app can do.
                if entry?.note?.isEmpty == false {
                    noteReminderControl
                }
            }
        }
    }

    private var currentReminderRule: NoteReminderRule? {
        entry?.noteReminderRule.flatMap(NoteReminderRule.init(rawValue:))
    }

    private var noteReminderControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "bell")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(CaelynColor.primaryPlum)
                Text("Remind me about this")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Spacer(minLength: 0)
                Menu {
                    Button("Off") { setReminder(nil) }
                    ForEach(NoteReminderRule.allCases) { rule in
                        Button(rule.label) { setReminder(rule) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(currentReminderRule?.label ?? "Off")
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .font(CaelynFont.subheadline.weight(.medium))
                    .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
            if currentReminderRule == .date {
                DatePicker("When", selection: reminderDateBinding, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .font(CaelynFont.subheadline)
                    .tint(CaelynColor.primaryPlum)
            }
            if let rule = currentReminderRule {
                Text(rule.picked)
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: { entry?.noteReminderAt ?? Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now },
            set: { newValue in
                withEntry { $0.noteReminderAt = newValue; $0.noteReminderDone = false }
                resyncReminders(requestPermission: false)
            }
        )
    }

    private func setReminder(_ rule: NoteReminderRule?) {
        withEntry { e in
            e.noteReminderRule = rule?.rawValue
            e.noteReminderDone = false
            switch rule {
            case .none:
                e.noteReminderAt = nil
            case .beforePeriod, .atPeriod:
                break   // cycle rules resolve their concrete date on sync
            case .date:
                if (e.noteReminderAt ?? .distantPast) <= .now {
                    e.noteReminderAt = Calendar.current.date(byAdding: .day, value: 1, to: .now)
                }
            }
        }
        resyncReminders(requestPermission: rule != nil)
    }

    private func resyncReminders(requestPermission: Bool) {
        Task {
            if requestPermission { _ = await NotificationService.requestAuthorization() }
            await NotificationService.syncFromLiveStore()
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
                    Text(showAdvanced ? "Hide extra options" : "More to track · meds, fluid, tests")
                        .font(CaelynFont.body.weight(.medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                .padding(.horizontal, CaelynSpacing.md)
                .padding(.vertical, CaelynSpacing.sm)
                .background(CaelynColor.lavender.opacity(0.6), in: Capsule())
            }
            .buttonStyle(.plain)

            if showAdvanced {
                VStack(spacing: CaelynSpacing.sm) {
                    medicationField
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
                .padding(.top, CaelynSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var medicationField: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.sm) {
                Image(systemName: "pills")
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .frame(width: 24)
                TextField("What are you taking today?", text: $medicationDraft)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .focused($medicationFocused)
                    .submitLabel(.done)
                    .onSubmit { commitMedication() }
            }
        }
    }

    private var cervicalMucusField: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.sm) {
                Image(systemName: "drop.degreesign")
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cervical fluid")
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Helps track fertile days")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                }
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
                            .font(CaelynFont.callout.weight(.medium))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
        }
    }

    private func advancedToggleRow(title: String, icon: String, isOn: Binding<Bool>) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .frame(width: 24)
                Text(title)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(CaelynColor.primaryPlum)
            }
        }
    }

    // MARK: - Mutations

    private func withEntry(_ mutate: (CycleEntry) -> Void) {
        let target = entry ?? CycleEntry(date: date)
        if entry == nil { modelContext.insert(target) }
        mutate(target)
        target.updatedAt = .now
        modelContext.saveOrLog()

        // Prompt for review after meaningful engagement.
        let entryCount = allEntries.count
        Task { @MainActor in RatingService.considerRequestingReview(loggedEntryCount: entryCount) }

        // Fire-and-forget HealthKit sync. Service no-ops if not connected.
        let snapshotEntries = allEntries
        let captured = target
        Task { await HealthKitSync.syncIfConnected(captured, in: snapshotEntries, modelContext: modelContext) }
    }

    private func toggleSymptom(_ symptom: Symptom) {
        withEntry { entry in
            if let idx = entry.symptoms.firstIndex(of: symptom) {
                entry.symptoms.remove(at: idx)
                entry.symptomSeverity.removeValue(forKey: symptom.rawValue)
            } else {
                entry.symptoms.append(symptom)
                entry.symptomSeverity[symptom.rawValue] = 2  // default: moderate
            }
        }
    }

    private func toggleCustomSymptom(_ name: String) {
        Haptics.selection()
        withEntry { entry in
            if let idx = entry.loggedCustomSymptoms.firstIndex(of: name) {
                entry.loggedCustomSymptoms.remove(at: idx)
                entry.symptomSeverity.removeValue(forKey: "custom:\(name)")
            } else {
                entry.loggedCustomSymptoms.append(name)
                entry.symptomSeverity["custom:\(name)"] = 2  // default: moderate
            }
        }
    }

    private func removeCustomSymptom(_ name: String) {
        // Deselect from this day's log only if there's already an entry with that symptom.
        if let e = entry, e.loggedCustomSymptoms.contains(name) {
            withEntry { e in
                e.loggedCustomSymptoms.removeAll { $0 == name }
                e.symptomSeverity.removeValue(forKey: "custom:\(name)")
            }
        }
        // Remove from the user's custom list regardless.
        profile?.customSymptoms.removeAll { $0 == name }
        modelContext.saveOrLog()
    }

    private func togglePainType(_ painType: PainType) {
        Haptics.selection()
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
        let value = noteDraft.isEmpty ? nil : noteDraft
        guard value != nil || entry != nil else { return }   // don't create an empty entry (stz-011)
        guard entry?.note != value else { return }           // skip no-op rewrite
        withEntry { $0.note = value }
    }

    private func commitMedication() {
        let value = medicationDraft.isEmpty ? nil : medicationDraft
        guard value != nil || entry != nil else { return }   // don't create an empty entry (stz-011)
        guard entry?.medication != value else { return }     // skip no-op rewrite
        withEntry { $0.medication = value }
    }

    private func commitBasalTemp() {
        let trimmed = basalTempDraft.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            // Nothing to clear and no entry → don't create a phantom one (stz-011).
            guard entry?.basalTemperature != nil else { return }
            withEntry { $0.basalTemperature = nil }
        } else if let value = Double(trimmed), value >= 35.0, value <= 42.0 {
            // Skip the write when unchanged so merely revisiting a day never
            // rewrites (and never re-rounds) the stored temperature (stz-012).
            guard entry?.basalTemperature != value else { return }
            withEntry { $0.basalTemperature = value }
        } else {
            // Out of realistic range — reset the field to the last saved value
            // at full precision so a 2-decimal reading isn't truncated (stz-012).
            basalTempDraft = entry?.basalTemperature.map { String(format: "%.2f", $0) } ?? ""
        }
    }
}

// MARK: - SectionContainer

private struct SectionContainer<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    .tracking(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                }
            }
            CaelynCard(padding: CaelynSpacing.md) {
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
        FlowLayout(spacing: CaelynSpacing.xs) {
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
            .padding(CaelynSpacing.lg)
    }
    .background(CaelynColor.backgroundCream)
    .modelContainer(Persistence.preview)
}
