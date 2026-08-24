import XCTest

/// Drives the paced tour that the App Store preview video records.
///
/// The preview must be a **plain screen capture** — App Review rejected the
/// earlier one under 2.3.4 because the footage was composited into a device
/// frame on a marketing background. Nothing here draws or decorates: the
/// recording is whatever the simulator screen shows, and the only craft is in
/// the pacing, so a viewer's eye can land before the next thing moves.
///
/// Run it with the screen recorder already rolling:
///
///   xcrun simctl io <udid> recordVideo --codec h264 --mask ignored out.mov &
///   xcodebuild test-without-building -scheme Caelyn \
///     -destination 'platform=iOS Simulator,id=<udid>' \
///     -only-testing CaelynUITests/PreviewTourTests
///
/// The leading launch and the trailing teardown are trimmed in post; the tour
/// itself runs about 26 seconds, inside Apple's 15–30s window.
final class PreviewTourTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testPreviewTour() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()

        XCTAssertTrue(
            app.buttons["Home"].waitForExistence(timeout: 30),
            "Home tab should appear with screenshot seed data"
        )
        // Let the launch animation finish before the tour starts. Everything
        // before the first beat gets trimmed anyway.
        pause(2.5)

        // 1 — Home. The cycle ring: today's day and phase, the reason someone
        // opens the app at all. This is the poster frame.
        tab("Home", in: app)
        pause(4.5)
        scroll(app, .up, by: 1)
        pause(3)
        scroll(app, .down, by: 1)
        pause(1.5)

        // 2 — Log. Show it being used, not just displayed: a symptom, its
        // severity and a mood are tapped on camera.
        tab("Log", in: app)
        pause(2)
        tapIfPresent(app.buttons["Cramps"], in: app)
        pause(1.2)
        tapIfPresent(app.buttons["Energetic"], in: app)
        pause(1.5)
        scroll(app, .up, by: 1)
        pause(2)

        // 3 — Calendar. The whole cycle at a glance.
        tab("Calendar", in: app)
        pause(3.5)
        scroll(app, .up, by: 1)
        pause(2)

        // 4 — Insights, ending on "What Caelyn learned about you" — the payoff
        // is the last thing the viewer sees.
        tab("Insights", in: app)
        pause(3)
        scroll(app, .up, by: 1)
        pause(2.5)
        scroll(app, .up, by: 1)
        pause(4)
    }

    // MARK: - Helpers

    private enum Direction { case up, down }

    private func tab(_ name: String, in app: XCUIApplication) {
        let button = app.tabBars.buttons[name].exists
            ? app.tabBars.buttons[name]
            : app.buttons[name]
        if button.waitForExistence(timeout: 5) { button.tap() }
    }

    /// A slow drag rather than `swipeUp()`. A flick blurs the screen for most of
    /// the frames it occupies, which is exactly what a preview should not show.
    private func scroll(_ app: XCUIApplication, _ direction: Direction, by count: Int) {
        let scrollView = app.scrollViews.firstMatch
        let target: XCUIElement = scrollView.exists ? scrollView : app
        for _ in 0..<count {
            switch direction {
            case .up:   target.swipeUp(velocity: XCUIGestureVelocity(rawValue: 320))
            case .down: target.swipeDown(velocity: XCUIGestureVelocity(rawValue: 320))
            }
        }
    }

    private func tapIfPresent(_ element: XCUIElement, in app: XCUIApplication) {
        guard element.waitForExistence(timeout: 2), element.isHittable else { return }
        element.tap()
    }

    private func pause(_ seconds: Double) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
