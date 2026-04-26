import SwiftUI

struct HomeQuickActions: View {
    let onLogPeriod: () -> Void
    let onAddSymptoms: () -> Void
    let onMoodCheckIn: () -> Void
    let onAddNote: () -> Void

    var body: some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: 0) {
                QuickActionButton(
                    title: "Log Period",
                    icon: "drop.fill",
                    background: MavieColor.blush,
                    action: onLogPeriod
                )
                QuickActionButton(
                    title: "Symptoms",
                    icon: "sparkles",
                    background: MavieColor.lavender,
                    action: onAddSymptoms
                )
                QuickActionButton(
                    title: "Mood",
                    icon: "face.smiling",
                    background: MavieColor.sage,
                    action: onMoodCheckIn
                )
                QuickActionButton(
                    title: "Note",
                    icon: "square.and.pencil",
                    background: MavieColor.warmSand,
                    action: onAddNote
                )
            }
        }
    }
}
