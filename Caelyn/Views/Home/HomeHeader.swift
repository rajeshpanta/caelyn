import SwiftUI

struct HomeHeader: View {
    let greeting: String
    let cycleDay: Int
    let phase: CyclePhase

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                HStack(spacing: 6) {
                    Text("Cycle day \(cycleDay)")
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cycleDay)
                    Text("·")
                    Text(phase.displayName.lowercased())
                }
                .font(CaelynFont.subheadline)
                .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
            }
            Spacer(minLength: 0)
            PrivacyChip()
        }
    }
}
