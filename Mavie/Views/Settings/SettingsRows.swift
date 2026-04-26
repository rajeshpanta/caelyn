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
        VStack(alignment: .leading, spacing: MavieSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(MavieFont.caption.weight(.semibold))
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                    .tracking(0.6)
                if let subtitle {
                    Text(subtitle)
                        .font(MavieFont.caption)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.45))
                }
            }
            MavieCard(padding: 0) {
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
            HStack(spacing: MavieSpacing.sm) {
                iconBadge
                Text(title)
                    .font(MavieFont.body)
                    .foregroundStyle(isDestructive ? MavieColor.alertRose : MavieColor.deepPlumText)
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(MavieFont.callout)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.5))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MavieColor.deepPlumText.opacity(0.3))
            }
            .padding(MavieSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconBadge: some View {
        ZStack {
            Circle().fill(iconColor.opacity(0.15)).frame(width: 32, height: 32)
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
        HStack(spacing: MavieSpacing.sm) {
            ZStack {
                Circle().fill(iconColor.opacity(0.15)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MavieFont.body)
                    .foregroundStyle(MavieColor.deepPlumText)
                if let subtitle {
                    Text(subtitle)
                        .font(MavieFont.caption)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(MavieColor.primaryPlum)
                .disabled(disabled)
        }
        .padding(MavieSpacing.md)
        .opacity(disabled ? 0.6 : 1.0)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(MavieColor.deepPlumText.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, MavieSpacing.md + 32 + MavieSpacing.sm)
    }
}
