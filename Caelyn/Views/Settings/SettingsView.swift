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
    /// Set when the user taps "Continue" on the first delete dialog. We defer
    /// presenting the second dialog until SwiftUI has fully dismissed the first
    /// (observed via `.onChange(of: showingDeleteFirst)`), instead of racing
    /// it with a fixed sleep.
    @State private var pendingShowDeleteSecond = false
    @State private var showingExportSheet = false
    @State private var showingReminders = false
    @State private var showingHealthKit = false
    @State private var showingPaywall = false
    @State private var purchase = PurchaseService.shared

    @State private var lockToggleError: String?

    private var profile: UserProfile? { profiles.first }

    /// Read the app's marketing version + build number from the generated
    /// Info.plist so this label can never drift from `project.yml`'s
    /// `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`.
    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    proSection
                    privacySection
                    healthSection
                    dataSection
                    appSection
                    aboutSection
                    #if DEBUG
                    diagnosticsSection
                    #endif
                }
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.top, CaelynSpacing.md)
                .padding(.bottom, CaelynSpacing.xl)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
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
            // Queue the second dialog — actually presenting it is deferred to
            // when SwiftUI marks `showingDeleteFirst` as false, so the two
            // dialogs never race.
            Button("Continue", role: .destructive) { pendingShowDeleteSecond = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every cycle entry, your profile, and any settings. This cannot be undone.")
        }
        .onChange(of: showingDeleteFirst) { _, isShowing in
            // First dialog has fully dismissed and the user opted to continue
            // — safe to present the second confirmation now.
            if !isShowing && pendingShowDeleteSecond {
                pendingShowDeleteSecond = false
                showingDeleteSecond = true
            }
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

    // MARK: - Caelyn Pro section

    @ViewBuilder
    private var proSection: some View {
        if purchase.isPro {
            CaelynCard(padding: CaelynSpacing.md) {
                HStack(spacing: CaelynSpacing.sm) {
                    ZStack {
                        Circle().fill(CaelynColor.successSage.opacity(0.18)).frame(width: CaelynIconSize.lg, height: CaelynIconSize.lg)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(CaelynColor.successSage)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Caelyn Pro · Subscribed")
                            .font(CaelynFont.body.weight(.medium))
                            .foregroundStyle(CaelynColor.deepPlumText)
                        Text("Manage your subscription in iOS Settings.")
                            .font(CaelynFont.caption)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                }
            }
        } else {
            Button { showingPaywall = true } label: {
                HStack(alignment: .top, spacing: CaelynSpacing.md) {
                    ZStack {
                        Circle().fill(CaelynColor.lavender).frame(width: CaelynIconSize.xl, height: CaelynIconSize.xl)
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(CaelynColor.primaryPlum)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unlock Caelyn Pro")
                            .font(CaelynFont.headline)
                            .foregroundStyle(CaelynColor.deepPlumText)
                        Text("Advanced insights, PDF reports, themes, and yearly summary.")
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum.opacity(0.55))
                        .padding(.top, 14)
                }
                .padding(CaelynSpacing.md)
                .background(
                    LinearGradient(
                        colors: [CaelynColor.cardWhite, CaelynColor.lavender.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous)
                        .stroke(CaelynColor.primaryPlum.opacity(0.18), lineWidth: 1)
                )
                .caelynShadow(.subtle)
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
                    iconColor: CaelynColor.primaryPlum,
                    title: lockTitle,
                    subtitle: lockSubtitle,
                    isOn: lockBinding(profile: profile),
                    disabled: !BiometricService.canAuthenticate
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "eye.slash",
                    iconColor: CaelynColor.primaryPlum,
                    title: "Hide app preview",
                    subtitle: "Mask Caelyn in the iOS task switcher.",
                    isOn: hidePreviewBinding(profile: profile)
                )
                SettingsDivider()
                SettingsToggleRow(
                    icon: "bell.badge.slash",
                    iconColor: CaelynColor.primaryPlum,
                    title: "Private notifications",
                    subtitle: "Reminders show \"Caelyn reminder\" instead of details.",
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
                iconColor: CaelynColor.alertRose,
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
                iconColor: CaelynColor.primaryPlum,
                title: "Export data",
                detail: nil,
                action: { showingExportSheet = true }
            )
            SettingsDivider()
            SettingsRow(
                icon: "trash",
                iconColor: CaelynColor.alertRose,
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
                iconColor: CaelynColor.primaryPlum,
                title: "First day of week",
                detail: firstDayLabel,
                action: { showingFirstDayPicker = true }
            )
            SettingsDivider()
            SettingsRow(
                icon: "bell",
                iconColor: CaelynColor.primaryPlum,
                title: "Reminders",
                detail: remindersDetail,
                action: { showingReminders = true }
            )
        }
    }

    private var remindersDetail: String {
        guard let profile else { return "Off" }
        // Only the categories that actually fire as OS notifications count.
        // Period and ovulation events live as in-app cards and don't push.
        let count = [profile.remindDailyCheckIn, profile.remindMedication]
            .filter { $0 }.count
        return count == 0 ? "Off" : "\(count) on"
    }

    // MARK: - About

    private var aboutSection: some View {
        SettingsSectionCard(title: "About") {
            HStack(spacing: CaelynSpacing.sm) {
                ZStack {
                    Circle().fill(CaelynColor.lavender).frame(width: CaelynIconSize.md, height: CaelynIconSize.md)
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Caelyn: Period & Cycle Tracker")
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Version \(appVersion)")
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(CaelynSpacing.md)

            Rectangle()
                .fill(CaelynColor.deepPlumText.opacity(0.07))
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "stethoscope")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    Text("Health disclaimer")
                        .font(CaelynFont.caption.weight(.semibold))
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        .tracking(0.4)
                }
                Text("Caelyn is a personal cycle tracker, not a medical device. Predictions and patterns are estimates based on your logs and shouldn't be used to diagnose, treat, or prevent any condition. For medical concerns, please consult a healthcare provider.")
                    .font(CaelynFont.caption)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(CaelynSpacing.md)
        }
    }

    // MARK: - Diagnostics (dev-only while we build)

    private var diagnosticsSection: some View {
        SettingsSectionCard(title: "Diagnostics", subtitle: "Dev-only while we're building") {
            DataStatusCard()
                .padding(CaelynSpacing.md)
            SettingsDivider()
            SettingsRow(
                icon: "arrow.uturn.backward.circle",
                iconColor: CaelynColor.alertRose,
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
                modelContext.saveOrLog()
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
            return "Caelyn locks when backgrounded — unlock with your passcode."
        }
        return "Caelyn locks when backgrounded — \(kind.displayName) or passcode unlocks."
    }

    private func hidePreviewBinding(profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: { profile.hidePreview },
            set: { profile.hidePreview = $0; modelContext.saveOrLog() }
        )
    }

    private func privateNotificationsBinding(profile: UserProfile) -> Binding<Bool> {
        Binding(
            get: { profile.privateNotifications },
            set: { profile.privateNotifications = $0; modelContext.saveOrLog() }
        )
    }

    private func firstDayBinding(profile: UserProfile) -> Binding<Int> {
        Binding(
            get: { profile.firstDayOfWeek },
            set: { profile.firstDayOfWeek = $0; modelContext.saveOrLog() }
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
        modelContext.saveOrLog()
    }

    private func deleteAllData() {
        for entry in entries { modelContext.delete(entry) }
        for profile in profiles { modelContext.delete(profile) }
        modelContext.saveOrLog()
        // Pending local notifications would still fire and reference data
        // that no longer exists — cancel them as part of the wipe.
        NotificationService.cancelAll()
        Haptics.warning()
    }
}

#Preview {
    SettingsView()
        .modelContainer(Persistence.preview)
}
