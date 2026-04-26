import SwiftUI

struct OnboardingScaffold<Content: View, Footer: View>: View {
    let title: String
    let subtitle: String?
    let content: () -> Content
    let footer: () -> Footer

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.footer = footer
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: MavieSpacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                            .foregroundStyle(MavieColor.deepPlumText)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(MavieFont.body)
                                .foregroundStyle(MavieColor.deepPlumText.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    content()
                }
                .padding(.horizontal, MavieSpacing.lg)
                .padding(.top, MavieSpacing.lg)
                .padding(.bottom, MavieSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 0) {
                footer()
            }
            .padding(.horizontal, MavieSpacing.lg)
            .padding(.top, MavieSpacing.sm)
            .padding(.bottom, MavieSpacing.lg)
        }
    }
}
