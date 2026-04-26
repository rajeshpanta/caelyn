import SwiftUI

struct ToggleCard: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        MavieCard(padding: MavieSpacing.md) {
            HStack(spacing: MavieSpacing.md) {
                ZStack {
                    Circle()
                        .fill(isOn ? MavieColor.primaryPlum.opacity(0.12) : MavieColor.lavender)
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(MavieColor.primaryPlum)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MavieFont.headline)
                        .foregroundStyle(MavieColor.deepPlumText)
                    Text(subtitle)
                        .font(MavieFont.subheadline)
                        .foregroundStyle(MavieColor.deepPlumText.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(MavieColor.primaryPlum)
            }
        }
    }
}
