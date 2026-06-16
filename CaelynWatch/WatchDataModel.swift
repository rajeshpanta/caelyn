import Foundation
import WatchConnectivity
import Combine

final class WatchDataModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var snapshot: WidgetSnapshot? = WidgetDataStore.read()
    @Published var pendingLogSent = false

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        // Always try to pull latest from App Group
        snapshot = WidgetDataStore.read()
    }

    // MARK: - Send quick log to iPhone

    func sendQuickLog(flow: String?, pain: Int?, mood: String?) {
        var info: [String: Any] = ["date": Date().timeIntervalSince1970]
        if let f = flow  { info["flow"]  = f }
        if let p = pain  { info["pain"]  = p }
        if let m = mood  { info["mood"]  = m }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(info, replyHandler: nil)
        } else {
            WCSession.default.transferUserInfo(info)
        }
        pendingLogSent = true
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.snapshot = WidgetDataStore.read() }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let data = applicationContext["snapshot"] as? Data,
           let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            DispatchQueue.main.async { self.snapshot = snap }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let data = message["snapshot"] as? Data,
           let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            DispatchQueue.main.async { self.snapshot = snap }
        }
    }

#if !os(watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
#endif
}
