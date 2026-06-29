import SwiftUI

// MARK: - Welcome

struct WelcomeStep: View {
    let vm: OnboardingViewModel

    @State private var logoAppear = false
    @State private var textAppear = false
    @State private var buttonAppear = false

    // Floating decorative icons: (systemName, xOffset, yOffset, delay, size, color)
    private let floaters: [(String, CGFloat, CGFloat, Double, CGFloat, Color)] = [
        ("sparkle",     -100,  -130, 0.05, 16, Color(hex: 0xF9A8C4)),
        ("heart.fill",   105,  -110, 0.15, 13, Color(hex: 0xFB7185)),
        ("star.fill",   -115,   -35, 0.25, 15, Color(hex: 0xFBD38D)),
        ("leaf.fill",    108,   -20, 0.35, 17, Color(hex: 0x86EFAC)),
        ("sparkle",      -80,   115, 0.45, 13, Color(hex: 0xC4B5FD)),
        ("moon.fill",     92,    95, 0.55, 18, Color(hex: 0xA78BFA)),
        ("circle.fill", -130,    50, 0.65,  9, Color(hex: 0xFDA4AF)),
        ("star.fill",    118,  -155, 0.75, 11, Color(hex: 0xFCD34D)),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero illustration
            ZStack {
                // Background glow orbs
                PulsingGlow(color: CaelynColor.softRose.opacity(0.5), size: 220, delay: 0)
                PulsingGlow(color: CaelynColor.lavender.opacity(0.4), size: 180, delay: 0.6)
                    .offset(x: 30, y: 20)

                // Floating icons
                ForEach(Array(floaters.enumerated()), id: \.offset) { _, item in
                    FloatingIcon(
                        systemName: item.0,
                        color: item.5.opacity(0.82),
                        size: item.4,
                        delay: item.3
                    )
                    .offset(x: item.1, y: item.2)
                }

                // Main logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xF472B6),
                                    Color(hex: 0xA855F7),
                                    Color(hex: 0x6F3D74)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 148, height: 148)
                        .shadow(
                            color: Color(hex: 0x6F3D74).opacity(0.45),
                            radius: 28, x: 0, y: 10
                        )

                    Image(systemName: "sparkles")
                        .font(.system(size: 62, weight: .light))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .scaleEffect(logoAppear ? 1.0 : 0.55)
                .opacity(logoAppear ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.75, dampingFraction: 0.62).delay(0.05)) {
                        logoAppear = true
                    }
                }
            }
            .frame(height: 300)

            Spacer().frame(height: 36)

            // Text
            VStack(spacing: 10) {
                Text("Made just for you 🌸")
                    .font(CaelynFont.subheadline.weight(.semibold))
                    .foregroundStyle(CaelynColor.primaryPlum.opacity(0.85))
                    .tracking(0.3)

                Text("Meet Caelyn")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)

                Text("Your personal cycle companion — understand your body, track how you feel, and love every day a little more.")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CaelynSpacing.sm)
            }
            .opacity(textAppear ? 1 : 0)
            .offset(y: textAppear ? 0 : 18)
            .onAppear {
                withAnimation(.easeOut(duration: 0.55).delay(0.35)) {
                    textAppear = true
                }
            }

            Spacer()

            // CTA
            VStack(spacing: CaelynSpacing.sm) {
                CaelynButton(title: "Let's begin ✨", variant: .primary) { vm.next() }
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Your data stays private, always.")
                        .font(CaelynFont.footnote)
                }
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
            }
            .opacity(buttonAppear ? 1 : 0)
            .offset(y: buttonAppear ? 0 : 12)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45).delay(0.6)) {
                    buttonAppear = true
                }
            }
        }
        .padding(.horizontal, CaelynSpacing.lg)
        .padding(.bottom, CaelynSpacing.lg)
    }
}

// MARK: - Feature Highlights

struct FeatureHighlightsStep: View {
    let vm: OnboardingViewModel
    @State private var currentPage = 0

    private let features: [FeatureHighlight] = [
        FeatureHighlight(
            icon: "waveform.path.ecg.rectangle.fill",
            title: "Your cycle,\ndecoded 🌸",
            description: "See exactly where you are — period, ovulation, PMS — every single day. No more guessing.",
            accentColor: Color(hex: 0xFB7185),
            backgroundStart: Color(hex: 0xFFF1F2),
            backgroundEnd: Color(hex: 0xFCE7F3)
        ),
        FeatureHighlight(
            icon: "heart.text.clipboard.fill",
            title: "Feel it,\nlog it 💭",
            description: "Moods, symptoms, energy, pain — track it all and spot the patterns your body is whispering.",
            accentColor: Color(hex: 0xA855F7),
            backgroundStart: Color(hex: 0xFAF5FF),
            backgroundEnd: Color(hex: 0xEDE9FE)
        ),
        FeatureHighlight(
            icon: "calendar.badge.checkmark",
            title: "Stay one\nstep ahead ✨",
            description: "Caelyn predicts your next period, PMS window, and fertile days — up to 3 months out.",
            accentColor: Color(hex: 0x6E9B7B),
            backgroundStart: Color(hex: 0xF0FDF4),
            backgroundEnd: Color(hex: 0xDCFCE7)
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(features.enumerated()), id: \.offset) { i, feature in
                    FeatureSlideView(feature: feature)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: .infinity)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentPage)

            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<features.count, id: \.self) { i in
                    Capsule()
                        .fill(currentPage == i
                              ? CaelynColor.primaryPlum
                              : CaelynColor.deepPlumText.opacity(0.18))
                        .frame(width: currentPage == i ? 28 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding(.bottom, CaelynSpacing.md)

            // Action button
            CaelynButton(
                title: currentPage < features.count - 1 ? "Next" : "Set up my cycle →",
                variant: .primary
            ) {
                if currentPage < features.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentPage += 1
                    }
                    Haptics.selection()
                } else {
                    vm.next()
                }
            }
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.bottom, CaelynSpacing.lg)
        }
    }
}

private struct FeatureHighlight {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
    let backgroundStart: Color
    let backgroundEnd: Color
}

private struct FeatureSlideView: View {
    let feature: FeatureHighlight
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                PulsingGlow(color: feature.accentColor.opacity(0.28), size: 220, delay: 0)
                PulsingGlow(color: feature.accentColor.opacity(0.15), size: 280, delay: 0.5)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [feature.backgroundStart, feature.backgroundEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 170, height: 170)
                    .shadow(color: feature.accentColor.opacity(0.3), radius: 24, x: 0, y: 8)

                Image(systemName: feature.icon)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [feature.accentColor, CaelynColor.primaryPlum],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolEffect(.pulse, options: .repeating)
            }
            .scaleEffect(appear ? 1 : 0.72)
            .opacity(appear ? 1 : 0)

            Spacer().frame(height: 48)

            VStack(spacing: 14) {
                Text(feature.title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)

                Text(feature.description)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CaelynSpacing.lg)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 20)
            }

            Spacer()
        }
        .onAppear {
            appear = false
            withAnimation(.spring(response: 0.65, dampingFraction: 0.75).delay(0.1)) {
                appear = true
            }
        }
        .onDisappear { appear = false }
    }
}

// MARK: - Privacy

struct PrivacyStep: View {
    let vm: OnboardingViewModel

    private let promises: [(String, String, String, Color)] = [
        ("iphone",                "Stays on your device",       "Your cycle data never touches our servers.",       Color(hex: 0x6F3D74)),
        (BiometricService.availableKind() == .none ? "lock.fill" : BiometricService.availableKind().icon, "\(BiometricService.availableKind() == .none ? "App" : BiometricService.availableKind().displayName) protection", "Lock the app — your body, your business.", Color(hex: 0xA855F7)),
        ("hand.raised.slash.fill","Zero ads, zero selling",     "No trackers. No selling. Ever.",                   Color(hex: 0xFB7185)),
        ("square.and.arrow.up",   "Your data, your choice",     "Export as CSV, or delete everything in seconds.",  Color(hex: 0x6E9B7B)),
    ]

    var body: some View {
        OnboardingScaffold(
            icon: "lock.shield.fill",
            iconColor: CaelynColor.primaryPlum,
            title: "Private by design 🔒",
            subtitle: "Caelyn is built around one simple promise: your body data is yours."
        ) {
            VStack(spacing: CaelynSpacing.sm) {
                ForEach(Array(promises.enumerated()), id: \.offset) { i, item in
                    privacyRow(icon: item.0, title: item.1, body: item.2, color: item.3, delay: Double(i) * 0.07)
                }

                Text("Caelyn is a personal tracker, not a medical device. Predictions are estimates. For health concerns, please talk to a healthcare professional.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, CaelynSpacing.xs)
            }
        } footer: {
            CaelynButton(title: "I understand, continue", variant: .primary) { vm.next() }
        }
    }

    private func privacyRow(icon: String, title: String, body: String, color: Color, delay: Double) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(color)
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
        .staggeredAppear(delay: 0.3 + delay)
    }
}

// MARK: - Last Period

struct LastPeriodStep: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            icon: "drop.fill",
            iconColor: CaelynColor.softRose,
            title: "When did your last period start?",
            subtitle: "Pick the first day of flow — Caelyn uses this to map your cycle."
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
                    .opacity(vm.notSureLastPeriod ? 0.35 : 1.0)
                    .labelsHidden()
                }
                .staggeredAppear(delay: 0.28)

                ToggleCard(
                    title: "I'm not sure right now",
                    subtitle: "That's okay! Caelyn will learn from your first logged period. 🌸",
                    icon: "questionmark.circle",
                    isOn: $vm.notSureLastPeriod
                )
                .staggeredAppear(delay: 0.42)
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }
}

// MARK: - Cycle Length

struct CycleLengthStep: View {
    @Bindable var vm: OnboardingViewModel
    private let options = Array(18...45)

    var body: some View {
        OnboardingScaffold(
            icon: "arrow.circlepath",
            iconColor: CaelynColor.primaryPlum,
            title: "How long is your usual cycle?",
            subtitle: "Count from the first day of one period to the first day of the next. Most cycles are 25–35 days."
        ) {
            VStack(spacing: CaelynSpacing.lg) {
                bigNumber
                    .staggeredAppear(delay: 0.28)

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
                .staggeredAppear(delay: 0.36)

                ToggleCard(
                    title: "Not sure — use the average",
                    subtitle: "We'll start with 28 days and refine it as you log. 💕",
                    icon: "questionmark.circle",
                    isOn: $vm.notSureCycleLength
                )
                .staggeredAppear(delay: 0.44)
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }

    private var bigNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(vm.cycleLength)")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [CaelynColor.primaryPlum, CaelynColor.softRose],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.cycleLength)
            Text("days")
                .font(.system(.title2, design: .rounded).weight(.medium))
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .opacity(vm.notSureCycleLength ? 0.38 : 1.0)
        .animation(.easeOut, value: vm.notSureCycleLength)
    }

    private func numberPill(_ value: Int) -> some View {
        let selected = vm.cycleLength == value && !vm.notSureCycleLength
        return Button {
            vm.cycleLength = value
            vm.notSureCycleLength = false
            Haptics.selection()
        } label: {
            Text("\(value)")
                .font(CaelynFont.headline)
                .frame(width: 52, height: 52)
                .foregroundStyle(selected ? .white : CaelynColor.deepPlumText)
                .background(
                    selected
                        ? AnyShapeStyle(LinearGradient(colors: [CaelynColor.primaryPlum, CaelynColor.softRose.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(CaelynColor.cardWhite)
                )
                .clipShape(Circle())
                .overlay(Circle().stroke(CaelynColor.deepPlumText.opacity(selected ? 0 : 0.07), lineWidth: 1))
                .shadow(color: selected ? CaelynColor.primaryPlum.opacity(0.35) : .clear, radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(value) day cycle")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - Period Length

struct PeriodLengthStep: View {
    @Bindable var vm: OnboardingViewModel
    private let options = Array(1...12)

    var body: some View {
        OnboardingScaffold(
            icon: "drop.fill",
            iconColor: CaelynColor.alertRose,
            title: "How long does your period usually last?",
            subtitle: "An average is totally fine — Caelyn refines it as you log more cycles."
        ) {
            VStack(spacing: CaelynSpacing.lg) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(vm.periodLength)")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CaelynColor.alertRose, CaelynColor.softRose],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: vm.periodLength)
                    Text(vm.periodLength == 1 ? "day" : "days")
                        .font(.system(.title2, design: .rounded).weight(.medium))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .opacity(vm.notSurePeriodLength ? 0.38 : 1.0)
                .animation(.easeOut, value: vm.notSurePeriodLength)
                .staggeredAppear(delay: 0.28)

                HStack(spacing: CaelynSpacing.xs) {
                    ForEach(options, id: \.self) { value in
                        let selected = vm.periodLength == value && !vm.notSurePeriodLength
                        Button {
                            vm.periodLength = value
                            vm.notSurePeriodLength = false
                            Haptics.selection()
                        } label: {
                            Text("\(value)")
                                .font(CaelynFont.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(selected ? .white : CaelynColor.deepPlumText)
                                .background(
                                    selected
                                        ? AnyShapeStyle(LinearGradient(colors: [CaelynColor.alertRose, CaelynColor.softRose.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        : AnyShapeStyle(CaelynColor.cardWhite)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CaelynRadius.button, style: .continuous)
                                        .stroke(CaelynColor.deepPlumText.opacity(selected ? 0 : 0.07), lineWidth: 1)
                                )
                                .shadow(color: selected ? CaelynColor.alertRose.opacity(0.35) : .clear, radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(value == 1 ? "1 day" : "\(value) days")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .staggeredAppear(delay: 0.36)

                ToggleCard(
                    title: "Not sure — use 5 days",
                    subtitle: "That's the most common period length. Caelyn will learn yours! 💕",
                    icon: "questionmark.circle",
                    isOn: $vm.notSurePeriodLength
                )
                .staggeredAppear(delay: 0.44)
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) { vm.next() }
        }
    }
}

// MARK: - Goals

struct GoalsStep: View {
    let vm: OnboardingViewModel

    private let allGoals: [(TrackingGoal, String, String)] = [
        (.period,        "drop.fill",      "Period tracking"),
        (.symptoms,      "sparkles",       "Symptoms"),
        (.mood,          "face.smiling",   "Mood & energy"),
        (.pms,           "cloud.bolt.fill","PMS tracking"),
        (.ovulation,     "sun.max.fill",   "Ovulation"),
        (.fertileWindow, "leaf.fill",      "Fertile window"),
        (.reminders,     "bell.fill",      "Reminders"),
        (.doctorNotes,   "stethoscope",    "Doctor notes"),
    ]

    var body: some View {
        OnboardingScaffold(
            icon: "heart.circle.fill",
            iconColor: CaelynColor.softRose,
            title: "What matters to you?",
            subtitle: "Pick everything you'd like to track. You can always change this later."
        ) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: CaelynSpacing.sm),
                    GridItem(.flexible(), spacing: CaelynSpacing.sm)
                ],
                spacing: CaelynSpacing.sm
            ) {
                ForEach(Array(allGoals.enumerated()), id: \.offset) { i, goalData in
                    let (goal, icon, label) = goalData
                    GoalCard(
                        title: label,
                        icon: icon,
                        isSelected: vm.trackingGoals.contains(goal)
                    ) {
                        vm.toggleGoal(goal)
                        Haptics.selection()
                    }
                    .staggeredAppear(delay: 0.32 + Double(i) * 0.055)
                }
            }
        } footer: {
            CaelynButton(title: "Looks good!", variant: .primary) { vm.next() }
                .disabled(vm.trackingGoals.isEmpty)
        }
    }
}

// MARK: - Reminders

struct RemindersStep: View {
    let vm: OnboardingViewModel

    private var anyReminderEnabled: Bool {
        vm.remindDailyCheckIn || vm.remindMedication ||
        vm.remindPeriodStart  || vm.remindOvulation
    }

    var body: some View {
        OnboardingScaffold(
            icon: "bell.fill",
            iconColor: Color(hex: 0xFBBF24),
            title: "Gentle reminders 🔔",
            subtitle: "Caelyn only nudges you when you ask. Totally opt-in, always quiet when off."
        ) {
            VStack(spacing: CaelynSpacing.sm) {
                ToggleCard(
                    title: "Daily check-in",
                    subtitle: "A soft prompt to log how you're feeling each day.",
                    icon: "checkmark.circle.fill",
                    isOn: Binding(
                        get: { vm.remindDailyCheckIn },
                        set: { vm.updateReminder(daily: $0) }
                    )
                )
                .staggeredAppear(delay: 0.30)
                ToggleCard(
                    title: "Medication reminder",
                    subtitle: "Time to take your pill or any other medication you track.",
                    icon: "pills.fill",
                    isOn: Binding(
                        get: { vm.remindMedication },
                        set: { vm.updateReminder(medication: $0) }
                    )
                )
                .staggeredAppear(delay: 0.38)
                ToggleCard(
                    title: "Period start",
                    subtitle: "A heads-up a couple of days before your period is predicted.",
                    icon: "drop.fill",
                    isOn: Binding(
                        get: { vm.remindPeriodStart },
                        set: { vm.updateReminder(period: $0) }
                    )
                )
                .staggeredAppear(delay: 0.46)
                ToggleCard(
                    title: "Ovulation",
                    subtitle: "A nudge around your estimated fertile window.",
                    icon: "sparkles",
                    isOn: Binding(
                        get: { vm.remindOvulation },
                        set: { vm.updateReminder(ovulation: $0) }
                    )
                )
                .staggeredAppear(delay: 0.54)
                ToggleCard(
                    title: "No reminders for now",
                    subtitle: "Caelyn stays completely quiet — you come to it when you're ready.",
                    icon: "bell.slash.fill",
                    isOn: Binding(
                        get: { vm.noReminders },
                        set: { vm.setNoReminders($0) }
                    )
                )
                .staggeredAppear(delay: 0.62)
            }
        } footer: {
            CaelynButton(title: "Continue", variant: .primary) {
                if anyReminderEnabled {
                    Task { await NotificationService.requestAuthorization() }
                }
                vm.next()
            }
        }
    }
}

// MARK: - Lock

struct LockStep: View {
    @Bindable var vm: OnboardingViewModel

    @State private var appear = false

    var body: some View {
        OnboardingScaffold(
            icon: "lock.shield.fill",
            iconColor: CaelynColor.primaryPlum,
            title: "Keep Caelyn private 🔐",
            subtitle: "Add \(BiometricService.availableKind() == .none ? "a passcode" : BiometricService.availableKind().displayName) so only you can open the app. You can change this anytime in Settings."
        ) {
            VStack(spacing: CaelynSpacing.lg) {
                ZStack {
                    PulsingGlow(color: CaelynColor.lavender.opacity(0.6), size: 180, delay: 0)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [CaelynColor.lavender, CaelynColor.blush],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                        .shadow(color: CaelynColor.primaryPlum.opacity(0.2), radius: 20, x: 0, y: 8)

                    let biometricIcon = BiometricService.availableKind() == .none ? "lock.fill" : BiometricService.availableKind().icon
                    Image(systemName: vm.enableLock ? biometricIcon : "lock.open.fill")
                        .font(.system(size: 60, weight: .light))
                        .foregroundStyle(CaelynColor.primaryPlum)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(maxWidth: .infinity)
                .scaleEffect(appear ? 1 : 0.8)
                .opacity(appear ? 1 : 0)
                .onAppear {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                        appear = true
                    }
                }

                let biometricName = BiometricService.availableKind() == .none ? "Lock" : BiometricService.availableKind().displayName
                Text(vm.enableLock ? "\(biometricName) is on 🔒" : "\(biometricName) is off")
                    .font(CaelynFont.headline)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentTransition(.identity)
            }
        } footer: {
            VStack(spacing: CaelynSpacing.xs) {
                let biometricName = BiometricService.availableKind() == .none ? "Lock" : BiometricService.availableKind().displayName
                CaelynButton(
                    title: vm.enableLock ? "Continue" : "Enable \(biometricName)",
                    variant: .primary
                ) {
                    if vm.enableLock { vm.next() }
                    else { vm.enableLock = true }
                }
                CaelynButton(
                    title: vm.enableLock ? "Turn off \(biometricName)" : "Skip for now",
                    variant: .tertiary
                ) {
                    if vm.enableLock { vm.enableLock = false }
                    else { vm.next() }
                }
            }
        }
    }
}

// MARK: - Done

struct DoneStep: View {
    let vm: OnboardingViewModel
    let onComplete: () -> Void

    @State private var logoAppear = false
    @State private var textAppear = false
    @State private var confettiAppear = false

    // Confetti: (symbol, x, y, size, color, delay)
    private let confetti: [(String, CGFloat, CGFloat, CGFloat, Color, Double)] = [
        ("sparkle",    -115,  -95,  16, Color(hex: 0xFB7185), 0.05),
        ("heart.fill",  110,  -80,  14, Color(hex: 0xF472B6), 0.12),
        ("star.fill",  -80,  -145,  15, Color(hex: 0xFCD34D), 0.19),
        ("sparkle",    115,  -145,  13, Color(hex: 0xC4B5FD), 0.26),
        ("circle.fill",-130,  -55,   9, Color(hex: 0xFDA4AF), 0.33),
        ("star.fill",   130,  -30,  12, Color(hex: 0xA78BFA), 0.40),
        ("heart.fill", -90,  -180,  11, Color(hex: 0xFB7185), 0.47),
        ("sparkle",     85,  -175,  15, Color(hex: 0xFCD34D), 0.54),
        ("leaf.fill",  -145,  -120, 13, Color(hex: 0x86EFAC), 0.61),
        ("circle.fill", 145,  -100,  8, Color(hex: 0xFDA4AF), 0.68),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Celebration illustration
            ZStack {
                // Confetti
                ForEach(Array(confetti.enumerated()), id: \.offset) { _, c in
                    ConfettiParticle(
                        symbol: c.0,
                        color: c.4.opacity(0.85),
                        size: c.3,
                        offsetX: c.1,
                        offsetY: c.2,
                        delay: c.5
                    )
                    .opacity(confettiAppear ? 1 : 0)
                }

                // Main circle
                ZStack {
                    PulsingGlow(color: CaelynColor.softRose.opacity(0.5), size: 180, delay: 0)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: 0xF472B6),
                                    Color(hex: 0xA855F7),
                                    Color(hex: 0x6F3D74)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 150, height: 150)
                        .shadow(color: CaelynColor.primaryPlum.opacity(0.4), radius: 24, x: 0, y: 10)

                    Image(systemName: "checkmark")
                        .font(.system(size: 62, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(logoAppear ? 1.0 : 0.4)
                .opacity(logoAppear ? 1 : 0)
            }
            .frame(height: 310)
            .onAppear {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.58)) {
                    logoAppear = true
                }
                confettiAppear = true
                withAnimation(.easeOut(duration: 0.55).delay(0.35)) {
                    textAppear = true
                }
            }

            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                Text("You're all set! 🎉")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(CaelynColor.deepPlumText)

                Text("Caelyn is ready to grow with you. Your first log is waiting — let's do this, gorgeous!")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CaelynSpacing.lg)
            }
            .opacity(textAppear ? 1 : 0)
            .offset(y: textAppear ? 0 : 20)

            Spacer()

            CaelynButton(title: "Open Caelyn 💕", variant: .primary) { onComplete() }
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.bottom, CaelynSpacing.lg)
                .opacity(textAppear ? 1 : 0)
        }
    }
}

// MARK: - Apple Health

struct HealthStep: View {
    let vm: OnboardingViewModel

    @State private var isConnecting = false
    @State private var connected = false
    @State private var denied = false

    var body: some View {
        OnboardingScaffold(
            icon: "heart.text.square.fill",
            iconColor: CaelynColor.alertRose,
            title: "Sync with Apple Health?",
            subtitle: "Import your existing period logs and symptoms — or skip and start fresh. You can always change this in Settings."
        ) {
            VStack(spacing: CaelynSpacing.sm) {
                healthRow(icon: "drop.fill",  title: "Menstrual flow",
                          body: "Reads and writes period data to Health.")
                    .staggeredAppear(delay: 0.30)
                healthRow(icon: "sparkles",   title: "Symptoms",
                          body: "Shares symptoms you log with Apple Health.")
                    .staggeredAppear(delay: 0.38)

                if connected {
                    CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.successSage.opacity(0.12)) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CaelynColor.successSage)
                            Text("Apple Health connected")
                                .font(CaelynFont.subheadline.weight(.medium))
                                .foregroundStyle(CaelynColor.deepPlumText)
                        }
                    }
                } else if denied {
                    CaelynCard(padding: CaelynSpacing.md, background: CaelynColor.alertRose.opacity(0.10)) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(CaelynColor.alertRose)
                            Text("Enable access in iOS Settings → Health anytime.")
                                .font(CaelynFont.caption)
                                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        } footer: {
            VStack(spacing: CaelynSpacing.xs) {
                if !connected && !denied {
                    CaelynButton(
                        title: isConnecting ? "Connecting…" : "Connect Apple Health",
                        variant: .primary,
                        icon: "heart.text.square"
                    ) {
                        Task { await connect() }
                    }
                    .disabled(isConnecting)
                }
                CaelynButton(title: connected ? "Continue" : "Skip for now", variant: connected ? .primary : .tertiary) {
                    vm.next()
                }
            }
        }
        .onAppear {
            // Auto-skip if HealthKit isn't available (e.g. iPad). Respect the nav
            // direction so the Back button from a later step skips BACKWARD past
            // this step instead of bouncing the user forward — the old code always
            // called next(), trapping iPad users (plat-8).
            guard !HealthKitService.isAvailable else { return }
            if vm.navigationDirection == .backward { vm.back() } else { vm.next() }
        }
    }

    private func healthRow(icon: String, title: String, body: String) -> some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: CaelynSpacing.sm) {
                ZStack {
                    Circle().fill(CaelynColor.alertRose.opacity(0.12)).frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CaelynColor.alertRose)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(CaelynFont.body).foregroundStyle(CaelynColor.deepPlumText)
                    Text(body).font(CaelynFont.subheadline).foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await HealthKitService.requestAuthorization()
            let granted = HealthKitService.canWriteMenstrualFlow()
            if granted {
                vm.healthKitConnected = true
                connected = true
            } else {
                denied = true
            }
        } catch {
            denied = true
        }
    }
}
