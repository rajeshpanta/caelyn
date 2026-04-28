import SwiftUI

struct SettingsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CaelynSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(CaelynFont.caption.weight(.semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                    .tracking(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.45))
                }
            }
            CaelynCard(padding: 0) {
                VStack(spacing: 0) {
                    content()
                }
            }
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String?
    let action: () -> Void
    var isDestructive: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: CaelynSpacing.sm) {
                iconBadge
                Text(title)
                    .font(CaelynFont.body)
                    .foregroundStyle(isDestructive ? CaelynColor.alertRose : CaelynColor.deepPlumText)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(CaelynFont.callout)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.5))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(CaelynColor.deepPlumText.opacity(0.3))
            }
            .padding(CaelynSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconBadge: some View {
        ZStack {
            Circle().fill(iconColor.opacity(0.15)).frame(width: CaelynIconSize.md, height: CaelynIconSize.md)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
        }
    }
}

struct SettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: CaelynSpacing.sm) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: CaelynIconSize.md, height: CaelynIconSize.md)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CaelynFont.body)
                    .foregroundStyle(CaelynColor.deepPlumText)
                if let subtitle {
                    Text(subtitle)
                        .font(CaelynFont.caption)
                        .foregroundStyle(CaelynColor.deepPlumText.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(CaelynColor.primaryPlum)
                .disabled(disabled)
        }
        .padding(CaelynSpacing.md)
        .opacity(disabled ? 0.6 : 1.0)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(CaelynColor.deepPlumText.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, CaelynSpacing.md + 32 + CaelynSpacing.sm)
    }
}
