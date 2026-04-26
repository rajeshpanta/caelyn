import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var profiles: [UserProfile]
    @Query private var entries: [CycleEntry]
    @Environment(\.modelContext) private var modelContext

    @State private var showingFirstDayPicker = false
    @State private var showingResetOnboardingConfirm = false
    @State private var showingDeleteFirst = false
    @State private var showingDeleteSecond = false
    @State private var showingExportSheet = false
    @State private var showingReminders = false
    @State private var showingHealthKit = false
    @State private var showingPaywall = false
    @State private var purchase = PurchaseService.shared

    @State private var lockToggleError: String?

    private var profile: UserProfile? { profiles.first }
    private let appVersion = "0.1.0"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    proSection
                    privacySection
                    healthSection
                    dataSection
                    appSection
                    aboutSection
                    diagnosticsSection
                }
                .padding(.horizontal, MavieSpacing.lg)
                .padding(.top, MavieSpacing.md)
                .padding(.bottom, MavieSpacing.xl)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationDestination(isPresented: $showingReminders) {
                RemindersView()
            }
            .navigationDestination(isPresented: $showingHealthKit) {
                HealthKitConnectView()
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showingFirstDayPicker) {
            if let profile {
                FirstDayOfWeekPickerSheet(
                    selection: firstDayBinding(profile: profile),
                    isPresented: $showingFirstDayPicker
                )
                .presentationDetents([.medium])
            }
        }
        .confirmationDialog(
            "Reset onboarding?",
            isPresented: $showingResetOnboardingConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { resetOnboarding() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes your profile and re-runs onboarding. Logged entries are preserved.")
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $showingDeleteFirst,
            titleVisibility: .visible
        ) {
            Button("Continue", role: .destructive) {
                // Delay so SwiftUI fully dismisses this dialog before
                // attempting to present the second one. Without the gap,
                // the second confirmation occasionally fails to appear on
                // some iOS builds.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    showingDeleteSecond = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every cycle entry, your profile, and any settings. This cannot be undone.")
        }
        .confirmationDialog(
            "Are you absolutely sure?",
            isPresented: $showingDeleteSecond,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive) { deleteAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Last chance — there's no recovery after this.")
        }
        .alert("Couldn't enable lock", isPresented: Binding(
            get: { lockToggleError != nil },
            set: { if !$0 { lockToggleError = nil } }
        )) {
            Button("OK") { lockToggleError = nil }
        } message: {
            Text(lockToggleError ?? "")
        }
    }

    // MARK: - Mavie Pro section

    @ViewBuilder
    private var proSection: some View {
        if purchase.isPro {
            MavieCard(padding: MavieSpacing.md) {
                HStack(spacing: MavieSpacing.sm) {
                    ZStack {
                        Circle().fill(MavieColor.successSage.opacity(0.18)).frame(width: 36, height: 36)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(MavieColor.successSage)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mavie Pro · Subscribed")
                            .font(MavieFont.body.weight(.medium))
                            .foregroundStyle(MavieColor.deepPlumText)
                        Text("Manage your subscription in iOS Settings.")
                            .font(MavieFont.caption)
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                }
            }
        } else {
            Button { showingPaywall = true } label: {
                HStack(alignment: .top, spacing: MavieSpacing.md) {
                    ZStack {
                        Circle().fill(MavieColor.lavender).frame(width: 44, height: 44)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(MavieColor.primaryPlum)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock Mavie Pro")
                            .font(MavieFont.headline)
                            .foregroundStyle(MavieColor.deepPlumText)
                        Text("Advanced insights, PDF reports, themes, and yearly summary.")
                            .font(MavieFont.subheadline)
                            .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MavieColor.primaryPlum.opacity(0.55))
                        .padding(.top, 14)
                }
                .padding(MavieSpacing.md)
                .background(
                    LinearGradient(
                        colors: [MavieColor.cardWhite, MavieColor.lavender.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous)
                        .stroke(MavieColor.primaryPlum.opacity(0.18), lineWidth: 1)
                )
                .mavieShadow(.subtle)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Privacy section

    private var privacySection: some View {
        SettingsSectionCard(title: "Privacy") {
            if let profile {
                SettingsToggleRow(
                    icon: lockIcon,
                    iconColor: MavieColor.primaryPlum,
                    title: lockTitle,
                    subtitle: lockSubtitle,
                    isOn: lockBinding(profile: profile),
                    disabled: !BiometricService.canAuthenticate
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "eye.slash",
                    iconColor: MavieColor.primaryPlum,
                    title: "Hide app preview",
                    subtitle: "Mask Mavie in the iOS task switcher.",
                    isOn: hidePreviewBinding(profile: profile)
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "bell.badge.slash",
                    iconColor: MavieColor.primaryPlum,
                    title: "Private notifications",
                    subtitle: "Reminders show \"Mavie reminder\" instead of details.",
                    isOn: privateNotificationsBinding(profile: profile)
                )
            }
        }
    }

    // MARK: - Health section

    private var healthSection: some View {
        SettingsSectionCard(title: "Health") {
            SettingsRow(
                icon: "heart.text.square",
                iconColor: MavieColor.alertRose,
                title: "Apple Health",
                detail: profile?.healthKitConnected == true ? "Connected" : nil,
                action: { showingHealthKit = true }
            )
        }
    }

    // MARK: - Data section

    private var dataSection: some View {
        SettingsSectionCard(title: "Data") {
            SettingsRow(
                icon: "square.and.arrow.up",
                iconColor: MavieColor.primaryPlum,
                title: "Export data",
                detail: nil,
                action: { showingExportSheet = true }
            )
            SettingsDivider()
            SettingsRow(
                icon: "trash",
                iconColor: MavieColor.alertRose,
                title: "Delete all data",
                detail: nil,
                action: { showingDeleteFirst = true },
                isDestructive: true
            )
        }
    }

    // MARK: - App section

    private var appSection: some View {
        SettingsSectionCard(title: "App") {
            SettingsRow(
                icon: "calendar",
                iconColor: MavieColor.primaryPlum,
                title: "First day of week",
                detail: firstDayLabel,
                action: { showingFirstDayPicker = true }
            )
            SettingsDivider()
            SettingsRow(
                icon: "bell",
                iconColor: MavieColor.primaryPlum,
                title: "Reminders",
                detail: remindersDetail,
                action: { showingReminders = true }
            )
        }
    }

    private var remindersDetail: String {
        guard let profile else { return "Off" }
        let count = [profile.remindPeriodStart, profile.remindDailyCheckIn, profile.remindMedication, profile.remindOvulation]
            .filter { $0 }.count
        return count == 0 ? "Off" : "\(count) on"
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSectionCard(title: "About") {
            HStack(spacing: MavieSpacing.sm) {
                ZStack {
                    Circle().fill(MavieColor.lavender).frame(width: 32, height: 32)
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mavie · Period Tracker")
                        .font(MavieFont.body)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text("Version \(appVersion)")
                        .font(MavieFont.caption)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(MavieSpacing.md)
        }
    }

    // MARK: - Diagnostics (dev-only while we build)

    private var diagnosticsSection: some View {
        SettingsSectionCard(title: "Diagnostics", subtitle: "Dev-only while we're building") {
            DataStatusCard()
                .padding(MavieSpacing.md)
            SettingsDivider()
            SettingsRow(
                icon: "arrow.uturn.backward.circle",
                iconColor: MavieColor.alertRose,
                title: "Reset onboarding",
                detail: nil,
                action: { showingResetOnboardingConfirm = true },
                isDestructive: true
            )
        }
    }

    // MARK: - Bindings

    private func lockBinding(profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: { profile.lockEnabled },
            set: { newValue in
                if newValue && !BiometricService.canAuthenticate {
                    lockToggleError = "This device has no passcode or biometrics set up. Add one in iOS Settings, then try again."
                    return
                }
                profile.lockEnabled = newValue
                try? modelContext.save()
            }
        )
    }

    // MARK: - Lock copy

    private var lockIcon: String {
        let kind = BiometricService.availableKind()
        return kind == .none ? "lock" : kind.icon
    }

    private var lockTitle: String {
        let kind = BiometricService.availableKind()
        return kind == .none ? "App lock" : "\(kind.displayName) lock"
    }

    private var lockSubtitle: String {
        if !BiometricService.canAuthenticate {
            return "Add a passcode in iOS Settings to enable lock."
        }
        let kind = BiometricService.availableKind()
        if kind == .none {
            return "Mavie locks when backgrounded — unlock with your passcode."
        }
        return "Mavie locks when backgrounded — \(kind.displayName) or passcode unlocks."
    }

    private func hidePreviewBinding(profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: { profile.hidePreview },
            set: { profile.hidePreview = $0; try? modelContext.save() }
        )
    }

    private func privateNotificationsBinding(profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: { profile.privateNotifications },
            set: { profile.privateNotifications = $0; try? modelContext.save() }
        )
    }

    private func firstDayBinding(profile: UserProfile) -> Binding<Int> {
        Binding(
            get: { profile.firstDayOfWeek },
            set: { profile.firstDayOfWeek = $0; try? modelContext.save() }
        )
    }

    // MARK: - Computed labels

    private var firstDayLabel: String {
        switch profile?.firstDayOfWeek ?? 1 {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 7: return "Saturday"
        default: return "Sunday"
        }
    }

    // MARK: - Destructive actions

    private func resetOnboarding() {
        for profile in profiles { modelContext.delete(profile) }
        try? modelContext.save()
    }

    private func deleteAllData() {
        for entry in entries { modelContext.delete(entry) }
        for profile in profiles { modelContext.delete(profile) }
        try? modelContext.save()
    }
}

#Preview {
    SettingsView()
        .modelContainer(Persistence.preview)
}
