import SwiftUI

/// Lays its children out in a row normally, and in a column at accessibility
/// text sizes.
///
/// **Why this exists.** Several pickers in the Log are a fixed HStack of N equal
/// pills whose labels are `lineLimit(1)` — "None / Spotting / Light / Medium /
/// Heavy". A single line that cannot wrap has an intrinsic *minimum* width equal
/// to the full label, so at large accessibility sizes five of them demand far
/// more width than the screen has. The row forces its parent VStack wider than
/// the display, `.frame(maxWidth: .infinity)` centres that overflow, and the
/// screen's content gets clipped off *both* edges — headings included. Stacking
/// them vertically removes the horizontal demand entirely.
///
/// `AnyLayout` swaps the container without changing view identity, so selection
/// state and animations survive the switch.
struct AdaptiveRow<Content: View>: View {
    var spacing: CGFloat = CaelynSpacing.xs
    /// Horizontal alignment used when stacked vertically.
    var verticalAlignment: HorizontalAlignment = .leading
    @ViewBuilder var content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: verticalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout { content() }
    }
}
