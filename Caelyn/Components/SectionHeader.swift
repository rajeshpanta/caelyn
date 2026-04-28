import SwiftUI

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingTitle: String = "See all"
    var trailingAction: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CaelynFont.title3.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText)
                if let subtitle {
                    Text(subtitle)
                        .font(CaelynFont.subheadline)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.6))
                }
            }
            Spacer()
            if let trailingAction {
                Button(trailingTitle, action: trailingAction)
                    .font(CaelynFont.subheadline.weight(.medium))
                    .foregroundStyle(CaelynColor.primaryPlum)
            }
        }
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.lg) {
        SectionHeader(title: "Today")
        SectionHeader(title: "Coming up", subtitle: "Next 7 days")
        SectionHeader(title: "Insights", trailingAction: {})
        SectionHeader(title: "Calendar", subtitle: "April 2026", trailingTitle: "Edit", trailingAction: {})
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
