import SwiftUI

struct PrivacyChip: View {
    var text: String = "Private on device"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(MavieFont.footnote.weight(.medium))
        }
        .foregroundStyle(MavieColor.primaryPlum)
        .padding(.horizontal, MavieSpacing.sm)
        .padding(.vertical, 6)
        .background(MavieColor.lavender, in: Capsule())
    }
}

#Preview {
    VStack(spacing: MavieSpacing.sm) {
        PrivacyChip()
        PrivacyChip(text: "Stored on your device")
        PrivacyChip(text: "Face ID locked")
    }
    .padding()
    .background(MavieColor.backgroundCream)
}
