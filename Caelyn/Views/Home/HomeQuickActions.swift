import SwiftUI

struct HomeQuickActions: View {
    let onLogPeriod: () -> Void
    let onAddSymptoms: () -> Void
    let onMoodCheckIn: () -> Void
    let onAddNote: () -> Void

    var body: some View {
        CaelynCard(padding: CaelynSpacing.md) {
            HStack(spacing: 0) {
                QuickActionButton(
                    title: "Log Period",
                    icon: "drop.fill",
                    background: CaelynColor.blush,
                    action: onLogPeriod
                )
                QuickActionButton(
                    title: "Symptoms",
                    icon: "sparkles",
                    background: CaelynColor.lavender,
                    action: onAddSymptoms
                )
                QuickActionButton(
                    title: "Mood",
                    icon: "face.smiling",
                    background: CaelynColor.sage,
                    action: onMoodCheckIn
                )
                QuickActionButton(
                    title: "Note",
                    icon: "square.and.pencil",
                    background: CaelynColor.warmSand,
                    action: onAddNote
                )
            }
        }
    }
}
