import SwiftUI

// MARK: - Welcome

struct WelcomeStep: View {
    let vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            heroIllustration
                .padding(.bottom, MavieSpacing.xl)

            VStack(spacing: MavieSpacing.sm) {
                Text("Meet Mavie")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(MavieColor.deepPlumText)
                Text("A private, beautiful way to track your cycle, symptoms, moods, and reminders.")
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MavieSpacing.md)
            }

            Spacer()

            VStack(spacing: MavieSpacing.sm) {
                MavieButton(title: "Get started", variant: .primary) { vm.next() }
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Your data stays in your control.")
                        .font(MavieFont.footnote)
                }
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
            }
        }
        .padding(.horizontal, MavieSpacing.lg)
        .padding(.bottom, MavieSpacing.lg)
    }

    private var heroIllustration: some View {
        ZStack {
            Circle().fill(MavieColor.lavender).frame(width: 220, height: 220).offset(x: -56, y: -28)
            Circle().fill(MavieColor.softRose.opacity(0.85)).frame(width: 180, height: 180).offset(x: 60, y: 16)
            Circle().fill(MavieColor.sage.opacity(0.7)).frame(width: 130, height: 130).offset(x: -16, y: 80)
            Text("M")
                .font(.system(size: 96, weight: .semibold, design: .rounded))
                .foregroundStyle(MavieColor.primaryPlum.opacity(0.85))
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
            subtitle: "Mavie is built around four promises."
        ) {
            VStack(spacing: MavieSpacing.sm) {
                privacyRow(icon: "iphone", title: "Stored on your device", body: "Your data lives locally — never on our servers.")
                privacyRow(icon: "faceid", title: "Face ID lock available", body: "Optional, but built in for when you want it.")
                privacyRow(icon: "hand.raised.slash.fill", title: "No ads or selling data", body: "Mavie has no third-party trackers.")
                privacyRow(icon: "square.and.arrow.up", title: "Export or delete anytime", body: "It's your data. Take it with you, or wipe it.")

                Text("Mavie is a personal cycle tracker, not a medical device. Predictions are estimates based on your logs. For medical concerns, please consult a healthcare provider.")
                    .font(MavieFont.caption)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, MavieSpacing.xs)
            }
        } footer: {
            MavieButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }

    private func privacyRow(icon: String, title: String, body: String) -> some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: MavieSpacing.md) {
                ZStack {
                    Circle().fill(MavieColor.lavender).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text(body)
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
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
            VStack(spacing: MavieSpacing.md) {
                MavieCard(padding: MavieSpacing.sm) {
                    DatePicker(
                        "Last period start",
                        selection: $vm.lastPeriodStart,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(MavieColor.primaryPlum)
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
            MavieButton(title: "Continue", variant: .primary) { vm.next() }
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
            VStack(spacing: MavieSpacing.lg) {
                bigNumber

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: MavieSpacing.xs) {
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
            MavieButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }

    private var bigNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(vm.cycleLength)")
                .font(.system(size: 84, weight: .semibold, design: .rounded))
                .foregroundStyle(MavieColor.primaryPlum)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.cycleLength)
            Text("days")
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
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
                .font(MavieFont.headline)
                .frame(width: 52, height: 52)
                .foregroundStyle(selected ? .white : MavieColor.deepPlumText)
                .background(selected ? MavieColor.primaryPlum : MavieColor.cardWhite)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(MavieColor.deepPlumText.opacity(selected ? 0 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Period Length

struct PeriodLengthStep: View {
    @Bindable var vm: OnboardingViewModel
    private let options = Array(2...9)

    var body: some View {
        OnboardingScaffold(
            title: "How many days does your period usually last?",
            subtitle: "An average is fine — Mavie will refine it as you log."
        ) {
            VStack(spacing: MavieSpacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(vm.periodLength)")
                        .font(.system(size: 84, weight: .semibold, design: .rounded))
                        .foregroundStyle(MavieColor.primaryPlum)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.periodLength)
                    Text(vm.periodLength == 1 ? "day" : "days")
                        .font(.system(.title2, design: .rounded).weight(.medium))
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                }
                .frame(maxWidth: .infinity)
                .opacity(vm.notSurePeriodLength ? 0.45 : 1.0)

                HStack(spacing: MavieSpacing.xs) {
                    ForEach(options, id: \.self) { value in
                        Button {
                            vm.periodLength = value
                            vm.notSurePeriodLength = false
                        } label: {
                            Text("\(value)")
                                .font(MavieFont.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(vm.periodLength == value ? .white : MavieColor.deepPlumText)
                                .background(vm.periodLength == value ? MavieColor.primaryPlum : MavieColor.cardWhite)
                                .clipShape(RoundedRectangle(cornerRadius: MavieRadius.button, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: MavieRadius.button, style: .continuous)
                                        .stroke(MavieColor.deepPlumText.opacity(vm.periodLength == value ? 0 : 0.06), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
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
            MavieButton(title: "Continue", variant: .primary) { vm.next() }
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
                columns: [GridItem(.flexible(), spacing: MavieSpacing.sm), GridItem(.flexible(), spacing: MavieSpacing.sm)],
                spacing: MavieSpacing.sm
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
            MavieButton(title: "Continue", variant: .primary) { vm.next() }
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
            subtitle: "Mavie will only nudge you about what you've turned on."
        ) {
            VStack(spacing: MavieSpacing.sm) {
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
                    subtitle: "Mavie stays quiet until you open it.",
                    icon: "bell.slash",
                    isOn: Binding(
                        get: { vm.noReminders },
                        set: { vm.setNoReminders($0) }
                    )
                )
            }
        } footer: {
            MavieButton(title: "Continue", variant: .primary) { vm.next() }
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
            title: "Keep Mavie private",
            subtitle: "Use Face ID to unlock the app. You can change this anytime in Settings."
        ) {
            VStack(spacing: MavieSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(MavieColor.lavender)
                        .frame(width: 160, height: 160)
                    Image(systemName: vm.enableLock ? "faceid" : "lock.open.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(MavieColor.primaryPlum)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, MavieSpacing.md)

                Text(vm.enableLock ? "Face ID enabled" : "Face ID off")
                    .font(MavieFont.headline)
                    .foregroundStyle(MavieColor.deepPlumText)
                    .frame(maxWidth: .infinity)
            }
        } footer: {
            VStack(spacing: MavieSpacing.xs) {
                MavieButton(
                    title: vm.enableLock ? "Continue" : "Enable Face ID",
                    variant: .primary
                ) {
                    if vm.enableLock {
                        vm.next()
                    } else {
                        vm.enableLock = true
                    }
                }
                MavieButton(title: vm.enableLock ? "Turn off Face ID" : "Maybe later", variant: .tertiary) {
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
                    .fill(MavieColor.sage.opacity(0.7))
                    .frame(width: 220, height: 220)
                Circle()
                    .fill(MavieColor.lavender)
                    .frame(width: 130, height: 130)
                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(MavieColor.primaryPlum)
            }
            .padding(.bottom, MavieSpacing.xl)

            VStack(spacing: MavieSpacing.sm) {
                Text("You're all set")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(MavieColor.deepPlumText)
                Text("Mavie will start learning your patterns from your first log.")
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MavieSpacing.md)
            }

            Spacer()

            MavieButton(title: "Open Mavie", variant: .primary) { onComplete() }
        }
        .padding(.horizontal, MavieSpacing.lg)
        .padding(.bottom, MavieSpacing.lg)
    }
}
