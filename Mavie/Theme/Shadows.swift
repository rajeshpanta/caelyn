import SwiftUI

struct MavieShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let subtle = MavieShadow(
        color: Color.black.opacity(0.04),
        radius: 8,
        x: 0,
        y: 2
    )

    static let card = MavieShadow(
        color: Color.black.opacity(0.06),
        radius: 16,
        x: 0,
        y: 8
    )
}

extension View {
    func mavieShadow(_ shadow: MavieShadow = .card) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
