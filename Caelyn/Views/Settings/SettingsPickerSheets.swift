import SwiftUI

struct ThemePickerSheet: View {
    @Binding var selection: AppTheme
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    Text("Pick how Caelyn looks. We currently support Light only — Dark mode is on the roadmap.")
                        .font(CaelynFont.body)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                        .padding(.horizontal, CaelynSpacing.lg)
                        .padding(.top, CaelynSpacing.md)

                    VStack(spacing: 0) {
                        ForEach(AppTheme.allCases) { theme in
                            themeRow(theme)
                            if theme != AppTheme.allCases.last {
                                Rectangle()
                                    .fill(CaelynColor.deepPlumText.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .background(CaelynColor.cardWhite, in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
                    .padding(.horizontal, CaelynSpacing.lg)
                }
                .padding(.bottom, CaelynSpacing.lg)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
        }
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        Button {
            selection = theme
        } label: {
            HStack(spacing: CaelynSpacing.sm) {
                Image(systemName: themeIcon(theme))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(CaelynColor.primaryPlum)
                    .frame(width: 32)
                Text(theme.displayName)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                Spacer()
                if selection == theme {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
            .padding(CaelynSpacing.md)
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
                VStack(alignment: .leading, spacing: CaelynSpacing.md) {
                    VStack(spacing: 0) {
                        ForEach(options, id: \.0) { value, label in
                            Button {
                                selection = value
                            } label: {
                                HStack {
                                    Text(label)
                                        .font(CaelynFont.body)
                                        .foregroundStyle(CaelynColor.deepPlumText)
                                    Spacer()
                                    if selection == value {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(CaelynColor.primaryPlum)
                                    }
                                }
                                .padding(CaelynSpacing.md)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if value != options.last?.0 {
                                Rectangle()
                                    .fill(CaelynColor.deepPlumText.opacity(0.06))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .background(CaelynColor.cardWhite, in: RoundedRectangle(cornerRadius: CaelynRadius.card, style: .continuous))
                    .padding(.horizontal, CaelynSpacing.lg)
                }
                .padding(.top, CaelynSpacing.md)
                .padding(.bottom, CaelynSpacing.lg)
            }
            .background(CaelynColor.backgroundCream.ignoresSafeArea())
            .navigationTitle("Start of week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundStyle(CaelynColor.primaryPlum)
                }
            }
        }
    }
}
