import WidgetKit
import SwiftUI

@main
struct CaelynWidgetBundle: WidgetBundle {
    var body: some Widget {
        CaelynCycleWidget()
    }
}

// MARK: - Widget configuration

struct CaelynCycleWidget: Widget {
    let kind = "CaelynCycleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaelynWidgetProvider()) { entry in
            CaelynWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(widgetHex: entry.snapshot.phaseTintHex)
                }
        }
        .configurationDisplayName("Caelyn")
        .description("Your cycle at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

// MARK: - Hex → Color helper (widget-local, no access to CaelynColor)

extension Color {
    init(widgetHex hex: Int, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >>  8) & 0xFF) / 255.0,
            blue:  Double( hex        & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// Convenient constants matching CaelynColor so widget views stay on-brand.
extension Color {
    static let widgetPlum     = Color(widgetHex: 0x6F3D74)
    static let widgetDeepText = Color(widgetHex: 0x2F1B32)
    static let widgetRose     = Color(widgetHex: 0xEFA7B2)
    static let widgetSage     = Color(widgetHex: 0x6E9B7B)
}
