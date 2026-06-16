import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject private var model: WatchDataModel
    @State private var showQuickLog = false

    private var snap: WidgetSnapshot { model.snapshot ?? .placeholder() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    phaseRing
                    statsRow
                    upcomingRow
                    logButton
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .navigationTitle("Caelyn")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showQuickLog) {
            WatchQuickLogView()
                .environmentObject(model)
        }
    }

    // MARK: - Phase ring

    private var phaseRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(phaseColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: ringProgress)
            VStack(spacing: 2) {
                Text("Day \(snap.cycleDay)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(snap.phaseName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: 110, height: 110)
        .padding(.top, 4)
    }

    private var ringProgress: CGFloat {
        guard snap.cycleLength > 0 else { return 0 }
        return min(CGFloat(snap.cycleDay) / CGFloat(snap.cycleLength), 1.0)
    }

    private var phaseColor: Color {
        switch snap.phaseRaw {
        case "menstrual":  return Color(red: 0.91, green: 0.38, blue: 0.47)
        case "follicular": return Color(red: 0.57, green: 0.78, blue: 0.65)
        case "ovulation":  return Color(red: 0.41, green: 0.75, blue: 0.58)
        case "luteal":     return Color(red: 0.71, green: 0.60, blue: 0.85)
        case "pms":        return Color(red: 0.80, green: 0.65, blue: 0.90)
        default:           return Color.gray
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 8) {
            statPill(
                icon: "drop.fill",
                label: periodLabel,
                tint: Color(red: 0.91, green: 0.38, blue: 0.47)
            )
            statPill(
                icon: "leaf.fill",
                label: fertileLabel,
                tint: Color(red: 0.41, green: 0.75, blue: 0.58)
            )
        }
    }

    private var periodLabel: String {
        switch snap.daysUntilPeriod {
        case -1: return "No pred"
        case 0:  return "Period"
        case let d where d < 0: return "Period"
        default: return "In \(snap.daysUntilPeriod)d"
        }
    }

    private var fertileLabel: String {
        if snap.upcomingLine1.lowercased().contains("ovulat") { return "Ovulating" }
        if snap.upcomingLine1.lowercased().contains("fertil") { return "Fertile" }
        return "—"
    }

    private func statPill(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.1), in: Capsule())
    }

    // MARK: - Upcoming

    @ViewBuilder
    private var upcomingRow: some View {
        if !snap.upcomingLine1.isEmpty {
            Text(snap.upcomingLine1)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // MARK: - Log button

    private var logButton: some View {
        Button {
            showQuickLog = true
        } label: {
            Label("Log Today", systemImage: "plus.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.50, green: 0.30, blue: 0.65))
    }
}
