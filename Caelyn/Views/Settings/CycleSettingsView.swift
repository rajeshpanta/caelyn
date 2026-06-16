import SwiftUI
import SwiftData

struct CycleSettingsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var purchase = PurchaseService.shared
    @State private var showingPaywall = false

    private let cycleLengthRange = Array(18...45)
    private let periodLengthRange = Array(1...12)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    cycleLengthSection
                    periodLengthSection
                    lastPeriodSection
                    irregularModeSection

                    if purchase.isPro {
                        perimenoModeSection
                        conditionModeSection
                        ttcSection
                        pregnancySection
                        postpartumSection
                    } else {
                        proLockedSection(
                            title: "Specialist modes",
                            description: "Perimenopause, Endometriosis, PCOS, TTC, Pregnancy, and Postpartum modes are part of Caelyn Pro.",
                            icon: "heart.circle.fill"
                        )
                    }

                    disclaimer
                }
                .sheet(isPresented: $showingPaywall) {
                    PaywallView()
                }
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.top, CaelynSpacing.md)
                .padding(.bottom, CaelynSpacing.xl)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Cycle settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(CaelynFont.body.weight(.semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
        }
    }

    // MARK: - Cycle length

    private var cycleLengthSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("CYCLE LENGTH")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(spacing: CaelynSpacing.md) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(profile.averageCycleLength)")
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .foregroundStyle(CaelynColor.primaryPlum)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: profile.averageCycleLength)
                        Text("days")
                            .font(.system(.title2, design: .rounded).weight(.medium))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        Spacer(minLength: 0)
                        Text("From first day of one period to the next")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CaelynSpacing.xs) {
                            ForEach(cycleLengthRange, id: \.self) { value in
                                cyclePill(value, selected: profile.averageCycleLength == value) {
                                    profile.averageCycleLength = value
                                    modelContext.saveOrLog()
                                    Haptics.selection()
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                }
            }
        }
    }

    // MARK: - Period length

    private var periodLengthSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("PERIOD LENGTH")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(spacing: CaelynSpacing.md) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(profile.averagePeriodLength)")
                            .font(.system(size: 52, weight: .semibold, design: .rounded))
                            .foregroundStyle(CaelynColor.primaryPlum)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: profile.averagePeriodLength)
                        Text(profile.averagePeriodLength == 1 ? "day" : "days")
                            .font(.system(.title2, design: .rounded).weight(.medium))
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        Spacer(minLength: 0)
                        Text("How long your period usually lasts")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }

                    HStack(spacing: CaelynSpacing.xs) {
                        ForEach(periodLengthRange, id: \.self) { value in
                            periodPill(value, selected: profile.averagePeriodLength == value) {
                                profile.averagePeriodLength = value
                                modelContext.saveOrLog()
                                Haptics.selection()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Last period start

    private var lastPeriodSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("LAST PERIOD START")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.sm) {
                DatePicker(
                    "Last period start",
                    selection: Binding(
                        get: { profile.lastPeriodStart ?? Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .now },
                        set: { profile.lastPeriodStart = $0; modelContext.saveOrLog() }
                    ),
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(CaelynColor.primaryPlum)
                .labelsHidden()
            }
        }
    }

    // MARK: - Irregular Mode

    private var irregularModeSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("CYCLE MODE")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    Toggle(isOn: $profile.irregularModeEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Irregular cycle mode")
                                .font(CaelynFont.body)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("Softens predictions and surfaces insights for cycles that vary significantly in length.")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(CaelynColor.primaryPlum)
                    .onChange(of: profile.irregularModeEnabled) { _, _ in
                        modelContext.saveOrLog()
                    }

                    if profile.irregularModeEnabled {
                        Divider()
                        Text("Predictions still run — they're shown with lower confidence styling to remind you they're approximate.")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Perimenopause Mode

    private var perimenoModeSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("PERIMENOPAUSE")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    Toggle(isOn: $profile.perimenoEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Perimenopause mode")
                                .font(CaelynFont.body)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("Adds hot flash, night sweats, brain fog, and other perimenopause symptoms to your log. Cycle predictions shown with wider uncertainty.")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(CaelynColor.primaryPlum)
                    .onChange(of: profile.perimenoEnabled) { _, _ in
                        modelContext.saveOrLog()
                    }
                }
            }
        }
    }

    // MARK: - Condition Tracking

    private var conditionModeSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("CONDITIONS")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    conditionToggle(
                        title: "Endometriosis",
                        subtitle: "Adds pelvic pressure, painful sex, and endo-specific symptoms to your log.",
                        isOn: $profile.endoEnabled
                    )
                    Divider()
                    conditionToggle(
                        title: "PCOS",
                        subtitle: "Adds hair loss, irregular bleeding, weight changes, and PCOS-specific symptoms.",
                        isOn: $profile.pcosEnabled
                    )
                }
            }
        }
    }

    private var ttcSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("TTC MODE")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                Toggle(isOn: $profile.ttcEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trying to Conceive")
                            .font(CaelynFont.body)
                            .foregroundStyle(CaelynColor.deepPlumText)
                        Text("Shows a daily fertility score on your home screen using your BBT, LH strips, and cervical mucus data.")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(CaelynColor.primaryPlum)
                .onChange(of: profile.ttcEnabled) { _, _ in
                    modelContext.saveOrLog()
                }
            }
        }
    }

    private func conditionToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text(subtitle)
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(CaelynColor.primaryPlum)
        .onChange(of: isOn.wrappedValue) { _, _ in
            modelContext.saveOrLog()
        }
    }

    // MARK: - Pregnancy Mode

    private var pregnancySection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("PREGNANCY")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    Toggle(isOn: $profile.pregnancyEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pregnancy mode")
                                .font(CaelynFont.body)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("Track your pregnancy week, trimester, and milestones. Shows a pregnancy card on your home screen.")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(CaelynColor.primaryPlum)
                    .onChange(of: profile.pregnancyEnabled) { _, _ in modelContext.saveOrLog() }

                    if profile.pregnancyEnabled {
                        Divider()
                        DatePicker(
                            "Due date",
                            selection: Binding(
                                get: { profile.pregnancyDueDate ?? Calendar.current.date(byAdding: .day, value: 280, to: .now) ?? .now },
                                set: { profile.pregnancyDueDate = $0; modelContext.saveOrLog() }
                            ),
                            displayedComponents: .date
                        )
                        .tint(CaelynColor.primaryPlum)
                    }
                }
            }
        }
    }

    // MARK: - Postpartum Mode

    private var postpartumSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            Text("POSTPARTUM")
                .font(CaelynFont.caption.weight(.semibold))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                .tracking(0.6)

            CaelynCard(padding: CaelynSpacing.md) {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    Toggle(isOn: $profile.postpartumEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Postpartum mode")
                                .font(CaelynFont.body)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("Shows your postpartum week and recovery milestones. Adds breast engorgement, mood, and postpartum fatigue to your log.")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(CaelynColor.primaryPlum)
                    .onChange(of: profile.postpartumEnabled) { _, _ in modelContext.saveOrLog() }

                    if profile.postpartumEnabled {
                        Divider()
                        DatePicker(
                            "Birth date",
                            selection: Binding(
                                get: { profile.postpartumBirthDate ?? .now },
                                set: { profile.postpartumBirthDate = $0; modelContext.saveOrLog() }
                            ),
                            in: ...Date.now,
                            displayedComponents: .date
                        )
                        .tint(CaelynColor.primaryPlum)
                    }
                }
            }
        }
    }

    private func proLockedSection(title: String, description: String, icon: String) -> some View {
        Button { showingPaywall = true } label: {
            CaelynCard(padding: CaelynSpacing.md) {
                HStack(spacing: CaelynSpacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.6))
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(CaelynFont.headline)
                                .foregroundStyle(CaelynColor.deepPlumText)
                            Text("PRO")
                                .font(CaelynFont.caption.weight(.bold))
                                .tracking(0.4)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .foregroundStyle(.white)
                                .background(CaelynColor.primaryPlum, in: Capsule())
                        }
                        Text(description)
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.25))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var disclaimer: some View {
        Text("These values are starting points. Caelyn refines them automatically as you log more cycles.")
            .font(CaelynFont.caption)
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, CaelynSpacing.xs)
    }

    // MARK: - Pill helpers

    private func cyclePill(_ value: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(value)")
                .font(CaelynFont.headline)
                .frame(width: 44, height: 44)
                .foregroundStyle(selected ? .white : CaelynColor.deepPlumText)
                .background(selected ? CaelynColor.primaryPlum : CaelynColor.cardWhite)
                .clipShape(Circle())
                .overlay(Circle().stroke(CaelynColor.deepPlumText.opacity(selected ? 0 : 0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) day cycle")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func periodPill(_ value: Int, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(value)")
                .font(CaelynFont.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(selected ? .white : CaelynColor.deepPlumText)
                .background(selected ? CaelynColor.primaryPlum : CaelynColor.cardWhite)
                .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous)
                        .stroke(CaelynColor.deepPlumText.opacity(selected ? 0 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == 1 ? "1 day period" : "\(value) day period")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    CycleSettingsView(profile: UserProfile())
        .modelContainer(Persistence.preview)
}
