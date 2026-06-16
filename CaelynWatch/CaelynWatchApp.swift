import SwiftUI
import WatchConnectivity

@main
struct CaelynWatchApp: App {
    @StateObject private var model = WatchDataModel()

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(model)
                .onAppear { model.activate() }
        }
    }
}
