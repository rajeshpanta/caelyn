import SwiftUI

struct CycleRingView: View {
    let cycleDay: Int
    let cycleLength: Int
    let periodLength: Int
    var thickness: CGFloat = 14
    var size: CGFloat = 220

    private var ovulationDay: Int { max(1, cycleLength - 14) }
    private var pmsStart: Int { max(1, cycleLength - 4) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(MavieColor.warmSand.opacity(0.5), style: StrokeStyle(lineWidth: thickness))

            phaseArc(startDay: 0, endDay: periodLength, color: MavieColor.softRose)
            phaseArc(startDay: ovulationDay - 1, endDay: ovulationDay + 1, color: MavieColor.sage)
            phaseArc(startDay: pmsStart, endDay: cycleLength, color: MavieColor.lavender)

            currentDayIndicator

            VStack(spacing: 2) {
                Text("Day")
                    .font(MavieFont.subheadline)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                Text("\(cycleDay)")
                    .font(MavieFont.numberLarge)
                    .foregroundStyle(MavieColor.deepPlumText)
                Text("of \(cycleLength)")
                    .font(MavieFont.footnote)
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cycle day \(cycleDay) of \(cycleLength)")
    }

    private func phaseArc(startDay: Int, endDay: Int, color: Color) -> some View {
        let total = Double(cycleLength)
        let from = max(0, Double(startDay) / total)
        let to = min(1, Double(endDay) / total)
        return Circle()
            .trim(from: from, to: to)
            .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }

    private var currentDayIndicator: some View {
        let fraction = Double(cycleDay) / Double(cycleLength)
        let angleRad = (fraction * 2 * .pi) - .pi / 2
        let radius = (size - thickness) / 2
        let x = size / 2 + cos(angleRad) * radius
        let y = size / 2 + sin(angleRad) * radius
        return Circle()
            .fill(MavieColor.primaryPlum)
            .frame(width: thickness + 4, height: thickness + 4)
            .overlay(Circle().stroke(MavieColor.cardWhite, lineWidth: 3))
            .position(x: x, y: y)
    }
}

#Preview {
    VStack(spacing: MavieSpacing.lg) {
        CycleRingView(cycleDay: 4, cycleLength: 29, periodLength: 5)
        HStack(spacing: MavieSpacing.md) {
            CycleRingView(cycleDay: 14, cycleLength: 29, periodLength: 5, thickness: 10, size: 140)
            CycleRingView(cycleDay: 26, cycleLength: 29, periodLength: 5, thickness: 10, size: 140)
        }
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
