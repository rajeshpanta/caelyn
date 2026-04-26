import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

enum MavieColor {
    static let backgroundCream = Color(hex: 0xFFF8F3)
    static let cardWhite       = Color(hex: 0xFFFFFF)
    static let primaryPlum     = Color(hex: 0x6F3D74)
    static let deepPlumText    = Color(hex: 0x2F1B32)
    static let softRose        = Color(hex: 0xEFA7B2)
    static let blush           = Color(hex: 0xFBE4E7)
    static let lavender        = Color(hex: 0xEEE7FF)
    static let sage            = Color(hex: 0xDCEBDD)
    static let warmSand        = Color(hex: 0xF4E2D1)
    static let alertRose       = Color(hex: 0xD96A7A)
    static let successSage     = Color(hex: 0x6E9B7B)
}
