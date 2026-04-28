#if DEBUG
import SwiftUI

/// Design-system gallery used only by Xcode previews. Compiled out of Release
/// builds so it doesn't bloat the shipped binary.
struct ComponentGallery: View {
    @State private var selectedSymptoms: Set<String> = ["Cramps", "Fatigue"]
    @State private var selectedMood: String = "Calm"

    private let symptoms: [(label: String, icon: String)] = [
        ("Cramps", "bolt.heart"),
        ("Bloating", "circle.dotted"),
        ("Acne", "drop"),
        ("Cravings", "fork.knife"),
        ("Fatigue", "moon.zzz"),
        ("Headache", "brain.head.profile")
    ]

    private let moods = ["Calm", "Tired", "Moody", "Energetic", "Anxious", "Sensitive"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                header
                ringSection
                quickActionsSection
                cardsSection
                buttonsSection
                symptomsSection
                moodsSection
                statsSection
                insightsSection
            }
            .padding(CaelynSpacing.lg)
        }
        .background(CaelynColor.backgroundCream.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.xxs) {
            HStack {
                Text("Caelyn")
                    .font(CaelynFont.largeTitle)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Spacer()
                PrivacyChip()
            }
            Text("Components gallery (preview-only)")
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
        .padding(.top, CaelynSpacing.lg)
    }

    private var ringSection: some View {
        VStack(spacing: CaelynSpacing.md) {
            SectionHeader(title: "Cycle ring")
            CaelynCard {
                VStack(spacing: CaelynSpacing.md) {
                    CycleRingView(cycleDay: 18, cycleLength: 29, periodLength: 5)
                    legend
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: CaelynSpacing.md) {
            legendItem(color: CaelynColor.softRose, label: "Period")
            legendItem(color: CaelynColor.sage, label: "Ovulation")
            legendItem(color: CaelynColor.lavender, label: "PMS")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(CaelynFont.caption)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "Quick actions")
            CaelynCard {
                HStack(spacing: CaelynSpacing.xxs) {
                    QuickActionButton(title: "Log Period", icon: "drop.fill", background: CaelynColor.blush) {}
                    QuickActionButton(title: "Symptoms", icon: "sparkles", background: CaelynColor.lavender) {}
                    QuickActionButton(title: "Mood", icon: "face.smiling", background: CaelynColor.sage) {}
                    QuickActionButton(title: "Note", icon: "square.and.pencil", background: CaelynColor.warmSand) {}
                }
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "Cards")
            CaelynCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default card (cardWhite, card shadow)")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Use as the default container for grouped content.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                }
            }
            CaelynCard(radius: CaelynRadius.cardLarge, background: CaelynColor.lavender, shadow: .subtle) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lavender card")
                        .font(CaelynFont.headline)
                        .foregroundStyle(CaelynColor.deepPlumText)
                    Text("Larger radius, subtle shadow — for emphasis cards.")
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.7))
                }
            }
        }
    }

    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "Buttons")
            VStack(spacing: CaelynSpacing.sm) {
                CaelynButton(title: "Continue", variant: .primary, icon: "arrow.right") {}
                CaelynButton(title: "Skip for now", variant: .secondary) {}
                CaelynButton(title: "Maybe later", variant: .tertiary) {}
                CaelynButton(title: "Disabled", variant: .primary) {}
                    .disabled(true)
            }
        }
    }

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "Symptom chips", subtitle: "Tap to toggle")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: CaelynSpacing.xs), count: 3),
                spacing: CaelynSpacing.xs
            ) {
                ForEach(symptoms, id: \.label) { item in
                    SymptomChip(
                        label: item.label,
                        icon: item.icon,
                        isSelected: selectedSymptoms.contains(item.label)
                    ) {
                        toggle(item.label)
                    }
                }
            }
        }
    }

    private var moodsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "Mood chips")
            CaelynCard {
                VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                    HStack(spacing: CaelynSpacing.xs) {
                        ForEach(moods.prefix(3), id: \.self) { mood in
                            MoodChip(label: mood, isSelected: mood == selectedMood) {
                                selectedMood = mood
                            }
                        }
                    }
                    HStack(spacing: CaelynSpacing.xs) {
                        ForEach(moods.suffix(3), id: \.self) { mood in
                            MoodChip(label: mood, isSelected: mood == selectedMood) {
                                selectedMood = mood
                            }
                        }
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "Stat cards")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: CaelynSpacing.sm) {
                StatCard(value: "29", label: "Avg cycle", unit: "days")
                StatCard(value: "5", label: "Avg period", unit: "days")
                StatCard(value: "±3", label: "Variation", unit: "days", accent: CaelynColor.alertRose)
                StatCard(value: "Cramps", label: "Most common")
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.md) {
            SectionHeader(title: "Insight cards")
            VStack(spacing: CaelynSpacing.sm) {
                InsightCard(
                    title: "Pattern",
                    message: "You often log cramps 1 day before your period."
                )
                InsightCard(
                    title: "Cycle",
                    message: "Your last 3 cycles averaged 29 days.",
                    icon: "calendar",
                    accent: CaelynColor.successSage
                )
                InsightCard(
                    title: "Heads up",
                    message: "Heavy flow usually appears on day 2.",
                    icon: "drop.fill",
                    accent: CaelynColor.alertRose
                )
            }
        }
        .padding(.bottom, CaelynSpacing.xl)
    }

    private func toggle(_ symptom: String) {
        if selectedSymptoms.contains(symptom) {
            selectedSymptoms.remove(symptom)
        } else {
            selectedSymptoms.insert(symptom)
        }
    }
}

#Preview {
    ComponentGallery()
        .modelContainer(Persistence.preview)
}
#endif
