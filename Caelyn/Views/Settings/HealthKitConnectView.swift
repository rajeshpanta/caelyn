import SwiftUI
import SwiftData

struct HealthKitConnectView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                HealthKitConnectForm(profile: profile)
            } else {
                Text("Set up your profile to connect Apple Health.")
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                    .padding(CaelynSpacing.lg)
            }
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
        .navigationTitle("Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HealthKitConnectForm: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]

    @State private var isAuthorizing = false
    @State private var isBackfilling = false
    @State private var isImporting = false
    @State private var statusBanner: StatusBanner?

    enum StatusBanner: Equatable {
        case success(String)
        case error(String)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                heroCard
                if let banner = statusBanner {
                    statusView(banner)
                }
                if profile.healthKitConnected {
                    syncTogglesSection
                    actionSection
                    disconnectSection
                } else {
                    connectSection
                }
                privacyCopy
            }
            .padding(CaelynSpacing.lg)
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        CaelynCard {
            HStack(alignment: .top, spacing: CaelynSpacing.md) {
                ZStack {
                    Circle().fill(CaelynColor.alertRose.opacity(0.15)).frame(width: CaelynIconSize.xxl, height: CaelynIconSize.xxl)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(CaelynColor.alertRose)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.healthKitConnected ? "Connected to Apple Health" : "Sync with Apple Health")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("You choose whether Caelyn imports flow or writes new flow and symptoms. iOS lets you change access anytime.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Connect (disconnected state)

    private var connectSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            // Apple's HealthKit HIG: "Avoid adding custom screens that replicate
            // the standard permission screen's behavior or content." Apple's sheet
            // lists every data type with its own toggle — duplicating that list here
            // is the thing the guideline names.
            // App Review 5.1.1(iv): Apple rejected this screen for labelling the
            // button with the grant action. The explanatory copy above is allowed;
            // the control that opens the system sheet must read neutrally.
            CaelynButton(
                title: HealthKitService.isAvailable ? "Continue" : "Unavailable on this device",
                variant: .primary
            ) {
                Task { await connect() }
            }
            .disabled(isAuthorizing || !HealthKitService.isAvailable)
            if !HealthKitService.isAvailable {
                Text("Apple Health sync isn't available on this device. Your Caelyn logs still work normally and stay on this device.")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Connected state — toggles

    private var syncTogglesSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionTitle("Sync preferences")
            VStack(spacing: CaelynSpacing.xs) {
                ToggleCard(
                    title: "Write flow to Health",
                    subtitle: "Send Caelyn's flow logs to Apple Health.",
                    icon: "drop.fill",
                    isOn: bind(\.hkWriteFlow)
                )
                ToggleCard(
                    title: "Read flow from Health",
                    subtitle: "Pull flow logs from Apple Health into Caelyn.",
                    icon: "drop",
                    isOn: bind(\.hkReadFlow)
                )
                ToggleCard(
                    title: "Write symptoms to Health",
                    subtitle: "Send Caelyn's symptom logs to Apple Health.",
                    icon: "sparkles",
                    isOn: bind(\.hkWriteSymptoms)
                )
                ToggleCard(
                    title: "Read symptoms from Health",
                    subtitle: "Bring in symptoms and pain logged in other apps.",
                    icon: "sparkles.rectangle.stack",
                    isOn: bind(\.hkReadSymptoms)
                )
                ToggleCard(
                    title: "Read fertility signals",
                    subtitle: "Temperature, cervical mucus, ovulation and pregnancy tests.",
                    icon: "thermometer.medium",
                    isOn: bind(\.hkReadFertility)
                )
            }
        }
    }

    // MARK: - Connected state — actions

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionTitle("One-time sync")
            CaelynButton(
                title: isBackfilling ? "Backfilling…" : "Backfill Caelyn data to Health",
                variant: .secondary,
                icon: "arrow.up.heart"
            ) {
                Task { await runBackfill() }
            }
            .disabled(isBackfilling || !(profile.hkWriteFlow || profile.hkWriteSymptoms))

            CaelynButton(
                title: isImporting ? "Importing…" : "Bring my history from Health",
                variant: .secondary,
                icon: "arrow.down.heart"
            ) {
                Task { await runImport() }
            }
            .disabled(isImporting || !anyReadEnabled)
        }
    }

    // MARK: - Disconnect

    private var disconnectSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            sectionTitle("Disconnect")
            CaelynCard {
                VStack(alignment: .leading, spacing: CaelynSpacing.xs) {
                    Text("Disconnect Caelyn from Apple Health")
                        .font(CaelynFont.body.weight(.medium))
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Caelyn will stop reading and writing. Data already in Apple Health stays there. Manage iOS-level access in iOS Settings → Apple Health.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Disconnect") { disconnect() }
                        .font(CaelynFont.body.weight(.semibold))
                        .foregroundStyle(CaelynColor.alertRose)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var privacyCopy: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("All sync happens on this device.")
                .font(CaelynFont.footnote)
        }
        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
        .padding(.top, CaelynSpacing.sm)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(CaelynFont.caption.weight(.semibold))
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            .tracking(0.6)
    }

    private func statusView(_ banner: StatusBanner) -> some View {
        let isError: Bool
        let message: String
        switch banner {
        case .success(let m): isError = false; message = m
        case .error(let m):   isError = true; message = m
        }
        return CaelynCard(padding: CaelynSpacing.md, background: (isError ? CaelynColor.alertRose : CaelynColor.successSage).opacity(0.12)) {
            HStack(spacing: 8) {
                Image(systemName: isError ? "exclamationmark.circle" : "checkmark.circle")
                    .foregroundStyle(isError ? CaelynColor.alertRose : CaelynColor.successSage)
                Text(message)
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Bindings + actions

    private func bind(_ keyPath: ReferenceWritableKeyPath<UserProfile, Bool>) -> Binding<Bool> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { newValue in
                profile[keyPath: keyPath] = newValue
                modelContext.saveOrLog()
            }
        )
    }

    private func connect() async {
        isAuthorizing = true
        defer { isAuthorizing = false }
        do {
            try await HealthKitService.requestAuthorization()
            // Apple's sheet is the consent record. HealthKit never reports read
            // authorization, and the sheet lets people enable writes selectively,
            // so a write probe cannot distinguish "declined" from "granted read
            // only". Never infer a denial from it — individual writes no-op
            // harmlessly — and never tell people to go turn something on.
            let canWrite = HealthKitService.canWriteMenstrualFlow()
            profile.healthKitConnected = true
            profile.hkWriteFlow = canWrite
            profile.hkWriteSymptoms = canWrite
            profile.hkReadFlow = true
            profile.hkReadSymptoms = true
            profile.hkReadFertility = true
            modelContext.saveOrLog()
            statusBanner = .success("Your choices are saved. Caelyn uses only what you allowed, and you can change that any time in iOS Settings → Privacy & Security → Health.")
        } catch {
            statusBanner = .error("Couldn't connect — \(error.localizedDescription)")
        }
    }

    private func disconnect() {
        profile.healthKitConnected = false
        profile.hkReadFlow = false
        profile.hkWriteFlow = false
        profile.hkReadSymptoms = false
        profile.hkWriteSymptoms = false
        profile.hkReadFertility = false
        // Forget which values came from Health, so a later reconnect treats
        // everything in her log as hers and can only add to it.
        HealthSyncService.forgetSyncState()
        modelContext.saveOrLog()
        statusBanner = .success("Disconnected.")
    }

    private func runBackfill() async {
        isBackfilling = true
        defer { isBackfilling = false }
        do {
            var flowCount = 0
            var symptomCount = 0
            if profile.hkWriteFlow {
                flowCount = try await HealthKitService.backfillFlowToHealth(entries: entries)
            }
            if profile.hkWriteSymptoms {
                symptomCount = try await HealthKitService.backfillSymptomsToHealth(entries: entries)
            }
            statusBanner = .success("Backfilled \(flowCount) flow days and \(symptomCount) symptoms.")
        } catch {
            statusBanner = .error("Couldn't backfill — \(error.localizedDescription)")
        }
    }

    private var anyReadEnabled: Bool {
        profile.hkReadFlow || profile.hkReadSymptoms || profile.hkReadFertility
    }

    private func runImport() async {
        isImporting = true
        defer { isImporting = false }
        let summary = await HealthSyncService.run(mode: .fullImport, profile: profile, context: modelContext)
        statusBanner = .success(HealthSyncCopy.importResult(summary))
    }
}

#Preview {
    NavigationStack {
        HealthKitConnectView()
            .modelContainer(Persistence.preview)
    }
}
