import SwiftUI

struct PrivacyChip: View {
    var text: String = "Private on device"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(CaelynFont.footnote.weight(.medium))
        }
        .foregroundStyle(CaelynColor.primaryPlum)
        .padding(.horizontal, CaelynSpacing.sm)
        .padding(.vertical, 6)
        .background(CaelynColor.lavender, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

#Preview {
    VStack(spacing: CaelynSpacing.sm) {
        PrivacyChip()
        PrivacyChip(text: "Stored on your device")
        PrivacyChip(text: "Face ID locked")
    }
    .padding()
    .background(CaelynColor.backgroundCream)
}
