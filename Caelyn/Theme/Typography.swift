import SwiftUI

enum CaelynFont {
    static let largeTitle   = Font.system(.largeTitle, design: .rounded).weight(.semibold)
    static let title        = Font.system(.title, design: .rounded).weight(.semibold)
    static let title2       = Font.system(.title2, design: .rounded).weight(.semibold)
    static let title3       = Font.system(.title3, design: .rounded).weight(.medium)
    static let headline     = Font.system(.headline, design: .rounded)
    static let body         = Font.system(.body, design: .rounded)
    static let callout      = Font.system(.callout, design: .rounded)
    static let subheadline  = Font.system(.subheadline, design: .rounded)
    static let footnote     = Font.system(.footnote, design: .rounded)
    static let caption      = Font.system(.caption, design: .rounded)

    static let numberLarge  = Font.system(size: 64, weight: .semibold, design: .rounded)
    static let numberMedium = Font.system(size: 32, weight: .semibold, design: .rounded)
}
