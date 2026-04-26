import SwiftUI

struct DayDetailSheet: View {
    let date: Date
    @Binding var isPresented: Bool

    private var titleLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    private var relativeLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date)  { return "Tomorrow" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now), to: cal.startOfDay(for: date)).day ?? 0
        if days < 0 { return "\(-days) days ago" }
        return "in \(days) days"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    header
                    DailyLogForm(date: date)
                }
                .padding(.horizontal, MavieSpacing.lg)
                .padding(.top, MavieSpacing.md)
                .padding(.bottom, MavieSpacing.xl)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .font(MavieFont.body.weight(.semibold))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleLabel)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(MavieColor.deepPlumText)
            Text(relativeLabel)
                .font(MavieFont.subheadline)
                .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
        }
    }
}
