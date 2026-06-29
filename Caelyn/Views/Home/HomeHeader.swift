import SwiftUI

struct HomeHeader: View {
    let greeting: String
    let cycleDay: Int
    let phase: CyclePhase

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(greeting) \(greetingEmoji) ")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(CaelynColor.deepPlumText)

                // Hide the "Day N · phase" subline until there's a real cycle to
                // describe — otherwise a brand-new user sees a fake "Day 1 · cycle"
                // under "Welcome to Caelyn" (stz-010).
                if phase != .unknown {
                    HStack(spacing: 0) {
                        Text("Day \(cycleDay)")
                            .font(CaelynFont.subheadline.weight(.semibold))
                            .foregroundStyle(phase.accentColor)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cycleDay)

                        Text(" · \(phase.displayName.lowercased())")
                            .font(CaelynFont.subheadline)
                            .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                    }
                }
            }
            Spacer(minLength: 0)
            PrivacyChip()
        }
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
