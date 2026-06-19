import XCTest

/// App Store screenshot capture for Caelyn.
///
/// **iPhone 6.9" (required):**
///   xcodebuild test -scheme Caelyn \
///     -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=18.4' \
///     -only-testing CaelynUITests/ScreenshotTests \
///     -resultBundlePath screenshots_iphone.xcresult
///
/// **iPad Pro 13-inch / 12.9" (required):**
///   xcodebuild test -scheme Caelyn \
///     -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4),OS=18.4' \
///     -only-testing CaelynUITests/ScreenshotTests \
///     -resultBundlePath screenshots_ipad.xcresult
///
/// **Extract screenshots:**
///   xcrun xcresulttool export object --legacy --type directory \
///     --path screenshots_ipad.xcresult \
///     --output-path ./screenshots/ipad
final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()

        // On iPhone, tabs live in a bottom TabView (tabBars).
        // On iPad iOS 18, tabs render as top pill buttons (regular buttons).
        // Waiting for app.buttons["Home"] covers both cases.
        XCTAssertTrue(
            app.buttons["Home"].waitForExistence(timeout: 15),
            "Home tab should appear with screenshot seed data"
        )
    }

    // MARK: - 1: Home — Day 14, ovulation phase

    func test01_Home() throws {
        tap(tab: "Home")
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
        scroll.swipeUp()
        scroll.swipeUp()
        sleep(1)
        snapshot("05_Insights_Charts")
    }

    // MARK: - 6: Paywall — upsell card

    func test06_Paywall() throws {
        // Relaunch without the Pro override so Settings shows the upgrade button
        app.terminate()
        app.launchArguments = ["--screenshot-paywall"]
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 15))
        sleep(1)
        tap(tab: "Settings")
        sleep(1)
        let upgradeBtn = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Unlock Caelyn Pro'")
        ).firstMatch
        if upgradeBtn.waitForExistence(timeout: 3) {
            upgradeBtn.tap()
            sleep(2)
            snapshot("06_Paywall")
        } else {
            snapshot("06_Settings_Fallback")
        }
    }

    // MARK: - Helpers

    private func tap(tab name: String) {
        let btn = app.buttons[name]
        if btn.waitForExistence(timeout: 5) { btn.tap() }
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
