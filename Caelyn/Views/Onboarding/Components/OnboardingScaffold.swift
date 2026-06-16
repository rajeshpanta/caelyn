import SwiftUI

struct OnboardingScaffold<Content: View, Footer: View>: View {
    var icon: String? = nil
    var iconColor: Color = CaelynColor.primaryPlum
    let title: String
    let subtitle: String?
    let content: () -> Content
    let footer: () -> Footer

    @State private var headerAppear = false

    init(
        icon: String? = nil,
        iconColor: Color = CaelynColor.primaryPlum,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    // Header: optional icon + title + subtitle
                    VStack(alignment: .leading, spacing: 12) {
                        if let icon {
                            ZStack {
                                Circle()
                                    .fill(iconColor.opacity(0.12))
                                    .frame(width: 60, height: 60)
                                Image(systemName: icon)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(iconColor)
                            }
                            .scaleEffect(headerAppear ? 1 : 0.65)
                            .opacity(headerAppear ? 1 : 0)
                            .onAppear {
                                withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.05)) {
                                    headerAppear = true
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                                .foregroundStyle(CaelynColor.deepPlumText)
                                .fixedSize(horizontal: false, vertical: true)
                            if let subtitle {
                                Text(subtitle)
                                    .font(CaelynFont.body)
                                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.65))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    content()
                }
                .padding(.horizontal, CaelynSpacing.lg)
                .padding(.top, CaelynSpacing.lg)
                .padding(.bottom, CaelynSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 0) {
                footer()
            }
            .padding(.horizontal, CaelynSpacing.lg)
            .padding(.top, CaelynSpacing.sm)
            .padding(.bottom, CaelynSpacing.lg)
        }
    }
}
