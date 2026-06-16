import SwiftUI
import SwiftData

struct BirthControlView: View {
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        List {
            if let profile {
                enableSection(profile: profile)
                if profile.birthControlEnabled {
                    methodSection(profile: profile)
                    reminderSection(profile: profile)
                    if profile.birthControlMethod != .pill {
                        startDateSection(profile: profile)
                    }
                    infoSection(method: profile.birthControlMethod)
                }
            }
        }
        .navigationTitle("Birth Control")
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
    }

    // MARK: - Sections

    private func enableSection(profile: UserProfile) -> some View {
        Section {
            Toggle("Birth Control Mode", isOn: Binding(
                get: { profile.birthControlEnabled },
                set: { profile.birthControlEnabled = $0; save() }
            ))
            .tint(CaelynColor.primaryPlum)
        } footer: {
            Text("Track your birth control method and get timely reminders.")
        }
    }

    private func methodSection(profile: UserProfile) -> some View {
        Section("Method") {
            Picker("Birth control type", selection: Binding(
                get: { profile.birthControlMethod },
                set: { profile.birthControlMethod = $0; save() }
            )) {
                ForEach(BirthControlMethod.allCases) { method in
                    Label(method.displayName, systemImage: method.icon).tag(method)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private func reminderSection(profile: UserProfile) -> some View {
        Section("Reminder") {
            Toggle("Enable reminder", isOn: Binding(
                get: { profile.birthControlReminderEnabled },
                set: { profile.birthControlReminderEnabled = $0; save() }
            ))
            .tint(CaelynColor.primaryPlum)

            if profile.birthControlReminderEnabled {
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                bySettingHour: profile.birthControlReminderHour,
                                minute: profile.birthControlReminderMinute,
                                second: 0,
                                of: .now
                            ) ?? .now
                        },
                        set: { date in
                            profile.birthControlReminderHour = Calendar.current.component(.hour, from: date)
                            profile.birthControlReminderMinute = Calendar.current.component(.minute, from: date)
                            save()
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    private func startDateSection(profile: UserProfile) -> some View {
        Section {
            DatePicker(
                startDateLabel(method: profile.birthControlMethod),
                selection: Binding(
                    get: { profile.birthControlStartDate ?? .now },
                    set: { profile.birthControlStartDate = $0; save() }
                ),
                in: ...Date.now,
                displayedComponents: .date
            )
        } header: {
            Text("Cycle start")
        } footer: {
            Text(startDateFooter(method: profile.birthControlMethod))
        }
    }

    private func infoSection(method: BirthControlMethod) -> some View {
        Section("How it works") {
            Label(methodDescription(method), systemImage: "info.circle")
                .font(CaelynFont.callout)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.75))
        }
    }

    // MARK: - Helpers

    private func startDateLabel(method: BirthControlMethod) -> String {
        switch method {
        case .patch: return "First patch date"
        case .ring:  return "First insertion date"
        case .pill:  return "Start date"
        }
    }

    private func startDateFooter(method: BirthControlMethod) -> String {
        switch method {
        case .patch: return "Caelyn will calculate your patch change schedule from this date."
        case .ring:  return "Caelyn will remind you to remove (day 21) and reinsert (day 28) based on this date."
        case .pill:  return ""
        }
    }

    private func methodDescription(_ method: BirthControlMethod) -> String {
        switch method {
        case .pill:  return "Daily reminders to take your pill at your chosen time."
        case .patch: return "Patch worn for 7 days × 3 weeks, then 1 week off. Caelyn reminds you on change days."
        case .ring:  return "Ring inserted for 21 days, then removed for 7 days. Caelyn sends insert/remove reminders."
        }
    }

    private func save() {
        modelContext.saveOrLog()
        Task { await NotificationService.syncFromLiveStore() }
    }
}
