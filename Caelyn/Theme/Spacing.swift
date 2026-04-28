import CoreGraphics

enum CaelynSpacing {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

/// Sizes for circular icon backgrounds (e.g. row leading icons, hero icons).
/// Use `Circle().fill(...).frame(width: CaelynIconSize.md, height: CaelynIconSize.md)`
/// rather than hardcoding numbers so badges stay visually consistent.
enum CaelynIconSize {
    static let sm:  CGFloat = 28  // chip-on-card leading icons
    static let md:  CGFloat = 32  // settings row + small avatars
    static let lg:  CGFloat = 36  // section header / card hero icons
    static let xl:  CGFloat = 44  // CTA card icons
    static let xxl: CGFloat = 56  // top-of-screen hero icons
}
