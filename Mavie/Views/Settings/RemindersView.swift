import SwiftUI
import SwiftData
import UserNotifications

struct RemindersView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                RemindersForm(profile: profile)
            } else {
                Text("Set up your profile to manage reminders.")
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                    .padding(MavieSpacing.lg)
            }
        }
        .background(MavieColor.backgroundCream.ignoresSafeArea())
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RemindersForm: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var isRequestingPermission = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                if authStatus == .denied {
                    deniedBanner
                }

                introCopy
                howRemindersWorkCard

                VStack(spacing: 0) {
                    ToggleCard(
                        title: "Daily check-in",
                        subtitle: "A silent nudge that appears in Notification Center — no banner, no sound.",
                        icon: "checkmark.circle",
                        isOn: bind(\.remindDailyCheckIn)
                    )
                    if profile.remindDailyCheckIn {
                        timePickerRow(
                            label: "Check-in time",
                            hour: bindHour(\.dailyCheckInHour, \.dailyCheckInMinute),
                            note: nil
                        )
                    }
                }
                VStack(spacing: 0) {
                    ToggleCard(
                        title: "Medication",
                        subtitle: "A time-sensitive reminder for daily medications. Breaks through Focus modes.",
                        icon: "pills",
                        isOn: bind(\.remindMedication)
                    )
                    if profile.remindMedication {
                        timePickerRow(
                            label: "Medication time",
                            hour: bindHour(\.medicationHour, \.medicationMinute),
                            note: nil
                        )
                    }
                }

                inAppOnlyExplainer

                privateToggleSection
            }
            .padding(MavieSpacing.lg)
        }
        .task { await refreshAuthStatus() }
    }

    // MARK: - Sections

    private var introCopy: some View {
        Text("Mavie waits to be asked. Cycle and ovulation events live as cards inside the app — they never appear on your lock screen.")
            .font(MavieFont.subheadline)
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Soft explainer card surfacing the "Reveal on Face ID" architecture so
    /// testers/users understand what makes Mavie's reminder system different.
    private var howRemindersWorkCard: some View {
        MavieCard(padding: MavieSpacing.md, background: MavieColor.lavender.opacity(0.55)) {
            VStack(alignment: .leading, spacing: MavieSpacing.xs) {
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MavieColor.primaryPlum)
                    Text("How Mavie's reminders work")
                        .font(MavieFont.caption.weight(.semibold))
                        .foregroundStyle(MavieColor.primaryPlum)
                        .tracking(0.4)
                }
                Text("Notifications read \"Mavie reminder\" on the lock screen — anyone glancing at your phone sees nothing. When you tap, Face ID opens the relevant card inside the app.")
                    .font(MavieFont.subheadline)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var inAppOnlyExplainer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 11, weight: .medium))
                Text("In-app only")
                    .font(MavieFont.caption.weight(.semibold))
                    .tracking(0.4)
            }
            .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
            Text("Period and ovulation heads-up cards always appear on Home — they don't fire as notifications. Your cycle data never leaves Mavie.")
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var deniedBanner: some View {
        MavieCard(padding: MavieSpacing.md, background: MavieColor.alertRose.opacity(0.12)) {
            VStack(alignment: .leading, spacing: MavieSpacing.xs) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.slash")
                        .foregroundStyle(MavieColor.alertRose)
                    Text("Notifications are off")
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                }
                Text("Mavie can't send reminders until you allow notifications in iOS Settings.")
                    .font(MavieFont.subheadline)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open iOS Settings") { openSystemSettings() }
                    .font(MavieFont.body.weight(.semibold))
                    .foregroundStyle(MavieColor.alertRose)
                    .padding(.top, 4)
            }
        }
    }

    private var privateToggleSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            Text("Privacy".uppercased())
                .font(MavieFont.caption.weight(.semibold))
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                .tracking(0.6)
            ToggleCard(
                title: "Private notification text",
                subtitle: "Reminders show \"Mavie reminder\" instead of cycle details on the lock screen.",
                icon: "bell.badge.slash",
                isOn: bind(\.privateNotifications)
            )
        }
    }

    // MARK: - Time picker

    private func timePickerRow(label: String, hour: Binding<Date>, note: String?) -> some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: MavieSpacing.sm) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MavieColor.primaryPlum)
                    .frame(width: 24)
                Text(label)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                Spacer(minLength: 0)
                DatePicker("", selection: hour, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(MavieColor.primaryPlum)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Bindings + side effects

    private func bind(_ keyPath: ReferenceWritableKeyPath<UserProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
                try? modelContext.save()
                Haptics.selection()
                Task { await handleToggle(turningOn: newValue) }
            }
        )
    }

    /// Two Int columns (hour + minute) presented as a single Date binding for the
    /// system DatePicker. Date's other components are ignored.
    private func bindHour(
        _ hourPath: ReferenceWritableKeyPath<UserProfile, Int>,
        _ minutePath: ReferenceWritableKeyPath<UserProfile, Int>
    ) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = profile[keyPath: hourPath]
                components.minute = profile[keyPath: minutePath]
                return Calendar.current.date(from: components) ?? .now
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                profile[keyPath: hourPath] = components.hour ?? 0
                profile[keyPath: minutePath] = components.minute ?? 0
                try? modelContext.save()
                Task { await NotificationService.syncFromLiveStore() }
            }
        )
    }

    private func handleToggle(turningOn: Bool) async {
        if turningOn && authStatus == .notDetermined && !isRequestingPermission {
            isRequestingPermission = true
            _ = await NotificationService.requestAuthorization()
            await refreshAuthStatus()
            isRequestingPermission = false
        }
        await NotificationService.syncFromLiveStore()
    }

    private func refreshAuthStatus() async {
        authStatus = await NotificationService.authorizationStatus()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        RemindersView()
            .modelContainer(Persistence.preview)
    }
}
