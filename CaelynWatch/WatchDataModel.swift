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

    /// Seeds a realistic cycle state for App Store screenshot capture, driven by
    /// the `--screenshot-mode` launch argument (the watch counterpart of the
    /// iPhone's `ScreenshotSeeder`). Day 14 / ovulation, matching the phone
    /// captures so both tell one story. Only the anchors are set — `recomputed(for:)`
    /// in WatchHomeView derives every displayed value from them, so the capture
    /// exercises the real code path rather than hand-written strings.
    ///
    /// Unreachable in normal use: launch arguments can't be passed to an installed
    /// app, and WCSession is never activated in this mode so a paired phone can't
    /// overwrite the seeded state mid-capture.
    func loadScreenshotSnapshot() {
        let cal = Calendar.current
        var snap = WidgetSnapshot.placeholder()
        snap.anchorPeriodStart = cal.date(byAdding: .day, value: -13, to: cal.startOfDay(for: Date()))
        snap.cycleLength = 28
        snap.periodLength = 5
        snap.isPro = true
        snapshot = snap
    }

    // MARK: - Send quick log to iPhone

    func sendQuickLog(flow: String?, pain: Int?, mood: String?) {
        var info: [String: Any] = ["date": Date().timeIntervalSince1970]
        if let f = flow  { info["flow"]  = f }
        if let p = pain  { info["pain"]  = p }
        if let m = mood  { info["mood"]  = m }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(info, replyHandler: { _ in }) { _ in
                WCSession.default.transferUserInfo(info)
            }
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
