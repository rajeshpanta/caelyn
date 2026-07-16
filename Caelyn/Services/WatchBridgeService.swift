import Foundation
import WatchConnectivity
import SwiftData

/// Bridges the iPhone app and Apple Watch companion.
/// - Sends the current WidgetSnapshot to Watch whenever it changes.
/// - Receives quick log entries from Watch and saves them as CycleEntry.
@MainActor
final class WatchBridgeService: NSObject, ObservableObject {
    static let shared = WatchBridgeService()

    private override init() { super.init() }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func pushSnapshot(_ snapshot: WidgetSnapshot) {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? WCSession.default.updateApplicationContext(["snapshot": data])
    }
}

extension WatchBridgeService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleIncoming(userInfo)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncoming(message)
        replyHandler(["status": "ok"])
    }

    private nonisolated func handleIncoming(_ info: [String: Any]) {
        guard let timestamp = info["date"] as? TimeInterval else { return }
        let date = Date(timeIntervalSince1970: timestamp)
        let flow  = info["flow"] as? String
        let pain  = info["pain"] as? Int
        let mood  = info["mood"] as? String

        Task { @MainActor in
            let context = Persistence.live.mainContext
            // Single fetch-or-create funnel (by calendar day) — never introduces a
            // same-day duplicate, even if two watch messages arrive back-to-back.
            let entry = CycleStore.entry(for: date, in: context)
            if let f = flow, let level = FlowLevel(rawValue: f) { entry.flow = level }
            if let p = pain { entry.pain = p }
            if let m = mood, let moodVal = Mood(rawValue: m) { entry.mood = moodVal }
            entry.updatedAt = .now
            context.saveOrLog()

            let allEntries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
            let captured = entry
            Task { await HealthKitSync.syncIfConnected(captured, in: allEntries, modelContext: context) }
        }
    }
}
