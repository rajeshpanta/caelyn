import SwiftUI
import SwiftData

@main
struct MavieApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Persistence.live)
    }
}
