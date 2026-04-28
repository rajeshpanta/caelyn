import SwiftUI

// MARK: - Welcome

struct WelcomeStep: View {
    let vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            heroIllustration
                .padding(.bottom, CaelynSpacing.xl)

            VStack(spacing: CaelynSpacing.sm) {
                Text("Meet Caelyn")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text("A private, beautiful way to track your cycle, symptoms, moods, and reminders.")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CaelynSpacing.md)
            }

            Spacer()

            VStack(spacing: CaelynSpacing.sm) {
                CaelynButton(title: "Get started", variant: .primary) { vm.next() }
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Your data stays in your control.")
                        .font(CaelynFont.footnote)
                }
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            }
        }
        .padding(.horizontal, CaelynSpacing.lg)
        .padding(.bottom, CaelynSpacing.lg)
    }

    private var heroIllustration: some View {
        ZStack {
            Circle().fill(CaelynColor.lavender).frame(width: 220, height: 220).offset(x: -56, y: -28)
            Circle().fill(CaelynColor.softRose.opacity(0.85)).frame(width: 180, height: 180).offset(x: 60, y: 16)
            Circle().fill(CaelynColor.sage.opacity(0.7)).frame(width: 130, height: 130).offset(x: -16, y: 80)
            Text("C")
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.primaryPlum.opacity(0.85))
        }
        .frame(height: 280)
    }
}

// MARK: - Privacy

struct PrivacyStep: View {
    let vm: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            title: "Private by design",
            subtitle: "Caelyn is built around four promises."
        ) {
            VStack(spacing: CaelynSpacing.sm) {
                privacyRow(icon: "iphone", title: "Stored on your device", body: "Your data lives locally — never on our servers.")
                privacyRow(icon: "faceid", title: "Face ID lock available", body: "Optional, but built in for when you want it.")
                privacyRow(icon: "hand.raised.slash.fill", title: "No ads or selling data", body: "Caelyn has no third-party trackers.")
                privacyRow(icon: "square.and.arrow.up", title: "Export or delete anytime", body: "It's your data. Take it with you, or wipe it.")

                Text("Caelyn is a personal cycle tracker, not a medical device. Predictions are estimates based on your logs. For medical concerns, please consult a healthcare provider.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, CaelynSpacing.xs)
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }

    private func privacyRow(icon: String, title: String, body: String) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.md) {
                ZStack {
                    Circle().fill(CaelynColor.lavender).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text(body)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Last Period

struct LastPeriodStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            title: "When did your last period start?",
            subtitle: "We use this to estimate your next cycle."
        ) {
            VStack(spacing: CaelynSpacing.md) {
                CaelynCard(padding: CaelynSpacing.sm) {
                    DatePicker(
                        "Last period start",
                        selection: $vm.lastPeriodStart,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(CaelynColor.primaryPlum)
                    .disabled(vm.notSureLastPeriod)
                    .opacity(vm.notSureLastPeriod ? 0.4 : 1.0)
                    .labelsHidden()
                }

                ToggleCard(
                    title: "I'm not sure",
                    subtitle: "We'll learn from your first logged period.",
                    icon: "questionmark.circle",
                    isOn: $vm.notSureLastPeriod
                )
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }
}

// MARK: - Cycle Length

struct CycleLengthStep: View {
    @Bindable var vm: OnboardingViewModel
    private let options = Array(21...40)

    var body: some View {
        OnboardingScaffold(
            title: "How long is your usual cycle?",
            subtitle: "From the first day of one period to the start of the next."
        ) {
            VStack(spacing: CaelynSpacing.lg) {
                bigNumber

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CaelynSpacing.xs) {
                        ForEach(options, id: \.self) { value in
                            numberPill(value)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()

                ToggleCard(
                    title: "I'm not sure",
                    subtitle: "We'll start with 28 days and learn from your logs.",
                    icon: "questionmark.circle",
                    isOn: $vm.notSureCycleLength
                )
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }

    private var bigNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(vm.cycleLength)")
                .font(.system(size: 84, weight: .semibold, design: .rounded))
                .foregroundStyle(CaelynColor.primaryPlum)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.cycleLength)
            Text("days")
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .opacity(vm.notSureCycleLength ? 0.45 : 1.0)
    }

    private func numberPill(_ value: Int) -> some View {
        let selected = vm.cycleLength == value
        return Button {
            vm.cycleLength = value
            vm.notSureCycleLength = false
        } label: {
            Text("\(value)")
                .font(CaelynFont.headline)
                .frame(width: 52, height: 52)
                .foregroundStyle(selected ? .white : CaelynColor.deepPlumText)
                .background(selected ? CaelynColor.primaryPlum : CaelynColor.cardWhite)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(CaelynColor.deepPlumText.opacity(selected ? 0 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) day cycle")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Period Length

struct PeriodLengthStep: View {
    @Bindable var vm: OnboardingViewModel
    private let options = Array(2...9)

    var body: some View {
        OnboardingScaffold(
            title: "How many days does your period usually last?",
            subtitle: "An average is fine — Caelyn will refine it as you log."
        ) {
            VStack(spacing: CaelynSpacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(vm.periodLength)")
                        .font(.system(size: 84, weight: .semibold, design: .rounded))
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.periodLength)
                    Text(vm.periodLength == 1 ? "day" : "days")
                        .font(.system(.title2, design: .rounded).weight(.medium))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .opacity(vm.notSurePeriodLength ? 0.45 : 1.0)

                HStack(spacing: CaelynSpacing.xs) {
                    ForEach(options, id: \.self) { value in
                        Button {
                            vm.periodLength = value
                            vm.notSurePeriodLength = false
                        } label: {
                            Text("\(value)")
                                .font(CaelynFont.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(vm.periodLength == value ? .white : CaelynColor.deepPlumText)
                                .background(vm.periodLength == value ? CaelynColor.primaryPlum : CaelynColor.cardWhite)
                                .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous)
                                        .stroke(CaelynColor.deepPlumText.opacity(vm.periodLength == value ? 0 : 0.06), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(value == 1 ? "1 day period" : "\(value) day period")
                        .accessibilityAddTraits(vm.periodLength == value ? .isSelected : [])
                    }
                }

                ToggleCard(
                    title: "I'm not sure",
                    subtitle: "We'll start with 5 days.",
                    icon: "questionmark.circle",
                    isOn: $vm.notSurePeriodLength
                )
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }
}

// MARK: - Goals

struct GoalsStep: View {
    let vm: OnboardingViewModel

    private let allGoals: [(TrackingGoal, String)] = [
        (.period,        "drop.fill"),
        (.symptoms,      "sparkles"),
        (.mood,          "face.smiling"),
        (.pms,           "cloud.bolt"),
        (.ovulation,     "sun.max"),
        (.fertileWindow, "leaf"),
        (.reminders,     "bell"),
        (.doctorNotes,   "stethoscope")
    ]

    var body: some View {
        OnboardingScaffold(
            title: "What would you like to track?",
            subtitle: "Pick all that fit. You can change this anytime."
        ) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: CaelynSpacing.sm), GridItem(.flexible(), spacing: CaelynSpacing.sm)],
                spacing: CaelynSpacing.sm
            ) {
                ForEach(allGoals, id: \.0) { goal, icon in
                    GoalCard(
                        title: goal.displayName,
                        icon: icon,
                        isSelected: vm.trackingGoals.contains(goal)
                    ) {
                        vm.toggleGoal(goal)
                    }
                }
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
                .disabled(vm.trackingGoals.isEmpty)
        }
    }
}

// MARK: - Reminders

struct RemindersStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            title: "Gentle reminders, only if you want them",
            subtitle: "Caelyn will only nudge you about what you've turned on."
        ) {
            VStack(spacing: CaelynSpacing.sm) {
                ToggleCard(
                    title: "Daily check-in",
                    subtitle: "A silent nudge to log how you feel — no banner, no sound.",
                    icon: "checkmark.circle",
                    isOn: bindingFor(\.remindDailyCheckIn)
                )
                ToggleCard(
                    title: "Medication",
                    subtitle: "Time-sensitive reminder for any meds you track.",
                    icon: "pills",
                    isOn: bindingFor(\.remindMedication)
                )
                ToggleCard(
                    title: "No reminders",
                    subtitle: "Caelyn stays quiet until you open it.",
                    icon: "bell.slash",
                    isOn: Binding(
                        get: { vm.noReminders },
                        set: { vm.setNoReminders($0) }
                    )
                )
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }

    private func bindingFor(_ keyPath: ReferenceWritableKeyPath<OnboardingViewModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { vm[keyPath: keyPath] },
            set: { newValue in
                switch keyPath {
                case \OnboardingViewModel.remindPeriodStart:  vm.updateReminder(period: newValue)
                case \OnboardingViewModel.remindDailyCheckIn: vm.updateReminder(daily: newValue)
                case \OnboardingViewModel.remindMedication:   vm.updateReminder(medication: newValue)
                case \OnboardingViewModel.remindOvulation:    vm.updateReminder(ovulation: newValue)
                default: vm[keyPath: keyPath] = newValue
                }
            }
        )
    }
}

// MARK: - Lock

struct LockStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            title: "Keep Caelyn private",
            subtitle: "Use Face ID to unlock the app. You can change this anytime in Settings."
        ) {
            VStack(spacing: CaelynSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(CaelynColor.lavender)
                        .frame(width: 160, height: 160)
                    Image(systemName: vm.enableLock ? "faceid" : "lock.open.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, CaelynSpacing.md)

                Text(vm.enableLock ? "Face ID enabled" : "Face ID off")
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .frame(maxWidth: .infinity)
            }
        } footer: {
            VStack(spacing: CaelynSpacing.xs) {
                CaelynButton(
                    title: vm.enableLock ? "Continue" : "Enable Face ID",
                    variant: .primary
                ) {
                    if vm.enableLock {
                        vm.next()
                    } else {
                        vm.enableLock = true
                    }
                }
                CaelynButton(title: vm.enableLock ? "Turn off Face ID" : "Maybe later", variant: .tertiary) {
                    if vm.enableLock {
                        vm.enableLock = false
                    } else {
                        vm.next()
                    }
                }
            }
        }
    }
}

// MARK: - Done

struct DoneStep: View {
    let vm: OnboardingViewModel
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(CaelynColor.sage.opacity(0.7))
                    .frame(width: 220, height: 220)
                Circle()
                    .fill(CaelynColor.lavender)
                    .frame(width: 130, height: 130)
                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(CaelynColor.primaryPlum)
            }
            .padding(.bottom, CaelynSpacing.xl)

            VStack(spacing: CaelynSpacing.sm) {
                Text("You're all set")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text("Caelyn will start learning your patterns from your first log.")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CaelynSpacing.md)
            }

            Spacer()

            CaelynButton(title: "Open Caelyn", variant: .primary) { onComplete() }
        }
        .padding(.horizontal, CaelynSpacing.lg)
        .padding(.bottom, CaelynSpacing.lg)
    }
}
