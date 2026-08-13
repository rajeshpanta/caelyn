import SwiftUI
import WatchConnectivity

@main
struct CaelynWatchApp: App {
    @StateObject private var model = WatchDataModel()

    /// Mirrors the iPhone app's `--screenshot-mode`: seeds a demo cycle instead of
    /// activating WCSession, so App Store watch captures show real UI with real
    /// numbers. Inert on a user's watch — launch arguments can't be passed there.
    private static let isScreenshotMode = CommandLine.arguments.contains("--screenshot-mode")
                                       || CommandLine.arguments.contains("--screenshot-log")
    /// Same, but opens the quick-log sheet so that screen can be captured too.
    private static let isLogShotMode = CommandLine.arguments.contains("--screenshot-log")

    var body: some Scene {
        WindowGroup {
            WatchHomeView(presentQuickLogOnAppear: Self.isLogShotMode)
                .environmentObject(model)
                .onAppear {
                    if Self.isScreenshotMode {
                        model.loadScreenshotSnapshot()
                    } else {
                        model.activate()
                    }
                }
        }
    }
}
