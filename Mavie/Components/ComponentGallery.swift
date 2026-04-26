import SwiftUI

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
            VStack(alignment: .leading, spacing: MavieSpacing.lg) {
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
            .padding(MavieSpacing.lg)
        }
        .background(MavieColor.backgroundCream.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.xxs) {
            HStack {
                Text("Mavie")
                    .font(MavieFont.largeTitle)
                    .foregroundStyle(MavieColor.deepPlumText)
                Spacer()
                PrivacyChip()
            }
            Text("Components · Phase 2")
                .font(MavieFont.subheadline)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
        .padding(.top, MavieSpacing.lg)
    }

    private var ringSection: some View {
        VStack(spacing: MavieSpacing.md) {
            SectionHeader(title: "Cycle ring")
            MavieCard {
                VStack(spacing: MavieSpacing.md) {
                    CycleRingView(cycleDay: 18, cycleLength: 29, periodLength: 5)
                    legend
                }
            }
        }
    }

    private var legend: some View {
        HStack(spacing: MavieSpacing.md) {
            legendItem(color: MavieColor.softRose, label: "Period")
            legendItem(color: MavieColor.sage, label: "Ovulation")
            legendItem(color: MavieColor.lavender, label: "PMS")
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(MavieFont.caption)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Quick actions")
            MavieCard {
                HStack(spacing: MavieSpacing.xxs) {
                    QuickActionButton(title: "Log Period", icon: "drop.fill", background: MavieColor.blush) {}
                    QuickActionButton(title: "Symptoms", icon: "sparkles", background: MavieColor.lavender) {}
                    QuickActionButton(title: "Mood", icon: "face.smiling", background: MavieColor.sage) {}
                    QuickActionButton(title: "Note", icon: "square.and.pencil", background: MavieColor.warmSand) {}
                }
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Cards")
            MavieCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default card (cardWhite, card shadow)")
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text("Use as the default container for grouped content.")
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                }
            }
            MavieCard(radius: MavieRadius.cardLarge, background: MavieColor.lavender, shadow: .subtle) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lavender card")
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text("Larger radius, subtle shadow — for emphasis cards.")
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.7))
                }
            }
        }
    }

    private var buttonsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Buttons")
            VStack(spacing: MavieSpacing.sm) {
                MavieButton(title: "Continue", variant: .primary, icon: "arrow.right") {}
                MavieButton(title: "Skip for now", variant: .secondary) {}
                MavieButton(title: "Maybe later", variant: .tertiary) {}
                MavieButton(title: "Disabled", variant: .primary) {}
                    .disabled(true)
            }
        }
    }

    private var symptomsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Symptom chips", subtitle: "Tap to toggle")
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: MavieSpacing.xs), count: 3),
                spacing: MavieSpacing.xs
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
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Mood chips")
            MavieCard {
                VStack(alignment: .leading, spacing: MavieSpacing.sm) {
                    HStack(spacing: MavieSpacing.xs) {
                        ForEach(moods.prefix(3), id: \.self) { mood in
                            MoodChip(label: mood, isSelected: mood == selectedMood) {
                                selectedMood = mood
                            }
                        }
                    }
                    HStack(spacing: MavieSpacing.xs) {
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
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Stat cards")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MavieSpacing.sm) {
                StatCard(value: "29", label: "Avg cycle", unit: "days")
                StatCard(value: "5", label: "Avg period", unit: "days")
                StatCard(value: "±3", label: "Variation", unit: "days", accent: MavieColor.alertRose)
                StatCard(value: "Cramps", label: "Most common")
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: MavieSpacing.md) {
            SectionHeader(title: "Insight cards")
            VStack(spacing: MavieSpacing.sm) {
                InsightCard(
                    title: "Pattern",
                    message: "You often log cramps 1 day before your period."
                )
                InsightCard(
                    title: "Cycle",
                    message: "Your last 3 cycles averaged 29 days.",
                    icon: "calendar",
                    accent: MavieColor.successSage
                )
                InsightCard(
                    title: "Heads up",
                    message: "Heavy flow usually appears on day 2.",
                    icon: "drop.fill",
                    accent: MavieColor.alertRose
                )
            }
        }
        .padding(.bottom, MavieSpacing.xl)
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
}
