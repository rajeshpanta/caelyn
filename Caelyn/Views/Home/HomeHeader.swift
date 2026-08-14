import SwiftUI

struct HomeHeader: View {
    let greeting: String
    let cycleDay: Int
    let phase: CyclePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
                greetingBlock
                PrivacyChip()
            }
        } else {
            HStack(alignment: .top) {
                greetingBlock
                Spacer(minLength: CaelynSpacing.sm)
                PrivacyChip()
            }
        }
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(greeting) \(greetingEmoji)")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(CaelynColor.deepPlumText)
                .fixedSize(horizontal: false, vertical: true)

            // Hide the "Day N · phase" subline until there's a real cycle to
            // describe — otherwise a brand-new user sees a fake "Day 1 · cycle"
            // under "Welcome to Caelyn" (stz-010).
            if phase != .unknown {
                cycleStatus
            }
        }
    }

    @ViewBuilder
    private var cycleStatus: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                cycleDayText
                phaseText
            }
        } else {
            HStack(spacing: 0) {
                cycleDayText
                Text(" · ")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                phaseText
            }
        }
    }

    private var cycleDayText: some View {
        Text("Day \(cycleDay)")
            .font(CaelynFont.subheadline.weight(.semibold))
            .foregroundStyle(phase.accentColor)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cycleDay)
    }

    private var phaseText: some View {
        Text(dynamicTypeSize.isAccessibilitySize ? phase.displayName : phase.displayName.lowercased())
            .font(CaelynFont.subheadline)
            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
            .fixedSize(horizontal: false, vertical: true)
    }

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "☀️"
        case 12..<17: return "🌸"
        case 17..<22: return "🌙"
        default:      return "✨"
        }
    }
}
