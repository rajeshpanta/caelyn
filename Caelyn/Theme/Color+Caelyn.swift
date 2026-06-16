import SwiftUI

// MARK: - Hex init

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8)  & 0xFF) / 255,
            blue:  CGFloat(hex         & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Adaptive palette

enum CaelynColor {
    // Backgrounds
    static let backgroundCream = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0x16091A)
            : UIColor(hex: 0xFFF8F3)
    })

    static let cardWhite = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0x241329)
            : UIColor(hex: 0xFFFFFF)
    })

    // Text
    static let deepPlumText = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0xEDE0F3)
            : UIColor(hex: 0x2F1B32)
    })

    // Accents
    static let primaryPlum = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0xBB82C3)
            : UIColor(hex: 0x6F3D74)
    })

    static let softRose = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0xC87B8E)
            : UIColor(hex: 0xEFA7B2)
    })

    static let blush = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0x3A1C28)
            : UIColor(hex: 0xFBE4E7)
    })

    static let lavender = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0x281B40)
            : UIColor(hex: 0xEEE7FF)
    })

    static let sage = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0x1B2E1E)
            : UIColor(hex: 0xDCEBDD)
    })

    static let warmSand = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0x2C1E12)
            : UIColor(hex: 0xF4E2D1)
    })

    // Status
    static let alertRose = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0xE9808F)
            : UIColor(hex: 0xD96A7A)
    })

    static let successSage = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: 0x80B98E)
            : UIColor(hex: 0x6E9B7B)
    })
}
