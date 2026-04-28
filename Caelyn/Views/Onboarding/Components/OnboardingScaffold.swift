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
                VStack(alignment: .leading, spacing: CaelynSpacing.lg) {
                    VStack(alignment: .leading, spacing: 8) {
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
