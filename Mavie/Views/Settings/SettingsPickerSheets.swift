import SwiftUI

struct ThemePickerSheet: View {
    @Binding var selection: AppTheme
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.md) {
                    Text("Pick how Mavie looks. We currently support Light only — Dark mode is on the roadmap.")
                        .font(MavieFont.body)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                        .padding(.horizontal, MavieSpacing.lg)
                        .padding(.top, MavieSpacing.md)

                    VStack(spacing: 0) {
                        ForEach(AppTheme.allCases) { theme in
                            themeRow(theme)
                            if theme != AppTheme.allCases.last {
                                Rectangle()
                                    .fill(MavieColor.deepPlumText.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .background(MavieColor.cardWhite, in: RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous))
                    .padding(.horizontal, MavieSpacing.lg)
                }
                .padding(.bottom, MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(MavieColor.primaryPlum)
                }
            }
        }
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        Button {
            selection = theme
        } label: {
            HStack(spacing: MavieSpacing.sm) {
                Image(systemName: themeIcon(theme))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MavieColor.primaryPlum)
                    .frame(width: 32)
                Text(theme.displayName)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                Spacer()
                if selection == theme {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
            }
            .padding(MavieSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func themeIcon(_ theme: AppTheme) -> String {
        switch theme {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon.stars"
        }
    }
}

struct FirstDayOfWeekPickerSheet: View {
    @Binding var selection: Int  // 1 = Sunday, 2 = Monday
    @Binding var isPresented: Bool

    private let options: [(Int, String)] = [
        (1, "Sunday"),
        (2, "Monday"),
        (7, "Saturday")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(options, id: \.0) { value, label in
                            Button {
                                selection = value
                            } label: {
                                HStack {
                                    Text(label)
                                        .font(MavieFont.body)
                                        .foregroundStyle(MavieColor.deepPlumText)
                                    Spacer()
                                    if selection == value {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(MavieColor.primaryPlum)
                                    }
                                }
                                .padding(MavieSpacing.md)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if value != options.last?.0 {
                                Rectangle()
                                    .fill(MavieColor.deepPlumText.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .background(MavieColor.cardWhite, in: RoundedRectangle(cornerRadius: MavieRadius.card, style: .continuous))
                    .padding(.horizontal, MavieSpacing.lg)
                }
                .padding(.top, MavieSpacing.md)
                .padding(.bottom, MavieSpacing.lg)
            }
            .background(MavieColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Start of week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(MavieColor.primaryPlum)
                }
            }
        }
    }
}
