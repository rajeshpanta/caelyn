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
        // The last context is replayed here rather than through
        // `didReceiveApplicationContext`, which only fires on a *change* — so a
        // wipe that happened while the watch app was closed would otherwise never
        // be seen, and the stale snapshot would come straight back.
        let received = session.receivedApplicationContext
        DispatchQueue.main.async {
            if received["cleared"] != nil {
                self.snapshot = nil
                WidgetDataStore.clear()
            } else {
                self.snapshot = WidgetDataStore.read()
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        apply(message)
    }

    /// One place to read an incoming payload, so the clear cannot be handled in
    /// one delivery path and forgotten in the other.
    ///
    /// **The clear matters as much as the snapshot.** Before this, the watch could
    /// only ever be *given* data: every path set `snapshot`, none unset it. So a
    /// "Delete all data" on the phone left her cycle day, phase and next predicted
    /// period sitting on her wrist, and the application context is persistent, so
    /// it survived relaunching the watch app. After the duress wipe — whose entire
    /// promise is an app that looks brand new — the watch was still counting.
    private func apply(_ payload: [String: Any]) {
        if payload["cleared"] != nil {
            DispatchQueue.main.async {
                self.snapshot = nil
                self.pendingLogSent = false
                WidgetDataStore.clear()
            }
            return
        }
        if let data = payload["snapshot"] as? Data,
           let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            DispatchQueue.main.async { self.snapshot = snap }
        }
    }

#if !os(watchOS)
    func sessionDidBecomeInactive(_ session: WCSession) { }
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
#endif
}
