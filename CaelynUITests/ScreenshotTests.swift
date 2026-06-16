import XCTest

/// App Store screenshot capture for Caelyn.
///
/// **Run command (iPhone 16 Pro Max — 6.9" required by App Store):**
///   xcodebuild test \
///     -scheme Caelyn \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=latest' \
///     -only-testing CaelynUITests/ScreenshotTests \
///     -resultBundlePath screenshots_6_9.xcresult
///
/// **Extract screenshots:**
///   xcrun xcresulttool export --type directory \
///     --path screenshots_6_9.xcresult \
///     --output-path ./screenshots/6.9
///
/// **Also run on iPhone 8 Plus (5.5" — second required size):**
///   Replace destination with: 'platform=iOS Simulator,name=iPhone 8 Plus,OS=15.5'
///
/// Screenshots land as PNG attachments inside the result bundle.
/// All 6 screens are captured in order: Home, Log, Calendar, Insights, Charts, Paywall.
final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // --screenshot-mode triggers ScreenshotSeeder + Pro override in the app
        app.launchArguments = ["--screenshot-mode"]
        app.launch()

        // Wait for main tab bar (seeded data skips onboarding)
        XCTAssertTrue(
            app.tabBars.buttons["Home"].waitForExistence(timeout: 10),
            "Main tab bar should appear immediately with screenshot seed data"
        )
    }

    // MARK: - 1: Home — Day 14, ovulation phase

    func test01_Home() throws {
        tap(tab: "Home")
        // Let the prediction engine settle and ring animate
        sleep(1)
        snapshot("01_Home_Ovulation")
    }

    // MARK: - 2: Daily log — rich entry state

    func test02_DailyLog() throws {
        tap(tab: "Log")
        sleep(1)
        snapshot("02_DailyLog")
    }

    // MARK: - 3: Calendar — colored cycle months

    func test03_Calendar() throws {
        tap(tab: "Calendar")
        sleep(1)
        snapshot("03_Calendar")
    }

    // MARK: - 4: Insights — stats + pattern cards

    func test04_InsightsStats() throws {
        tap(tab: "Insights")
        sleep(1)
        snapshot("04_Insights_Patterns")
    }

    // MARK: - 5: Insights — Pro charts (visible because Pro is overridden)

    func test05_InsightsCharts() throws {
        tap(tab: "Insights")
        sleep(1)

        let scroll = app.scrollViews.firstMatch
        // Scroll down to reach the Pro charts section
        scroll.swipeUp()
        scroll.swipeUp()
        sleep(1)
        snapshot("05_Insights_Charts")
    }

    // MARK: - 6: Paywall — upsell card

    func test06_Paywall() throws {
        tap(tab: "Settings")
        sleep(1)

        // Tap the upgrade row to open paywall
        let upgradeRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pro' OR label CONTAINS 'Upgrade'")).firstMatch
        if upgradeRow.waitForExistence(timeout: 3) {
            upgradeRow.tap()
            sleep(1)
            snapshot("06_Paywall")
            // Dismiss
            let dismiss = app.buttons["Close"]
            if dismiss.waitForExistence(timeout: 2) { dismiss.tap() }
        } else {
            // Fallback: capture Settings with the pro status row visible
            snapshot("06_Settings")
        }
    }

    // MARK: - Helpers

    private func tap(tab name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 5) { tab.tap() }
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
