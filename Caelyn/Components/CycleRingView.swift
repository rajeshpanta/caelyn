import SwiftUI

struct CycleRingView: View {
    let cycleDay: Int
    let cycleLength: Int
    let periodLength: Int
    var thickness: CGFloat = 14
    var size: CGFloat = 220

    @State private var hasAppeared = false
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ovulationDay: Int { max(1, cycleLength - 14) }
    private var pmsStart: Int { max(1, cycleLength - 4) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(CaelynColor.warmSand.opacity(0.5), style: StrokeStyle(lineWidth: thickness))

            phaseArc(startDay: 0, endDay: periodLength, color: CaelynColor.softRose)
            phaseArc(startDay: ovulationDay - 1, endDay: ovulationDay + 1, color: CaelynColor.sage)
            phaseArc(startDay: pmsStart, endDay: cycleLength, color: CaelynColor.lavender)

            currentDayIndicator

            VStack(spacing: 2) {
                Text("Day")
                    .font(CaelynFont.subheadline)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                Text("\(cycleDay)")
                    .font(CaelynFont.numberLarge)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Text("of \(cycleLength)")
                    .font(CaelynFont.footnote)
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(hasAppeared || reduceMotion ? 1.0 : 0.88)
        .opacity(hasAppeared || reduceMotion ? 1.0 : 0)
        .onAppear {
            guard !reduceMotion else { hasAppeared = true; return }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.05)) {
                hasAppeared = true
            }
        }
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
        // Cycle day is 1-indexed but the phase arcs are 0-indexed (the period arc
        // starts at fraction 0). Use cycleDay-1 so Day 1 sits at the ring origin
        // instead of one day ahead of the arc it belongs to (plat-6).
        let safeLen = max(1, cycleLength)
        let fraction = Double(max(0, cycleDay - 1)) / Double(safeLen)
        let angleRad = (fraction * 2 * .pi) - .pi / 2
        let radius = (size - thickness) / 2
        let x = size / 2 + cos(angleRad) * radius
        let y = size / 2 + sin(angleRad) * radius
        let dotSize = thickness + 4
        return ZStack {
            // A soft "heartbeat" halo — quietly says "this is you, right now".
            Circle()
                .fill(CaelynColor.primaryPlum.opacity(0.35))
                .frame(width: dotSize, height: dotSize)
                .scaleEffect(pulse ? 2.1 : 1.0)
                .opacity(pulse ? 0 : 0.5)
            Circle()
                .fill(CaelynColor.primaryPlum)
                .frame(width: dotSize, height: dotSize)
                .overlay(Circle().stroke(CaelynColor.cardWhite, lineWidth: 3))
        }
        .position(x: x, y: y)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.lg) {
        CycleRingView(cycleDay: 4, cycleLength: 29, periodLength: 5)
        HStack(spacing: CaelynSpacing.md) {
            CycleRingView(cycleDay: 14, cycleLength: 29, periodLength: 5, thickness: 10, size: 140)
            CycleRingView(cycleDay: 26, cycleLength: 29, periodLength: 5, thickness: 10, size: 140)
        }
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
