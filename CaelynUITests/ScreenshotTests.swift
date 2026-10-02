import XCTest
import StoreKitTest

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

    // MARK: - 6b: Paywall scrolled to the priced tiers

    /// App Store Connect's IAP review screenshot has to show the actual purchase
    /// options. `test06_Paywall` stops at the top of the sheet, where the
    /// free-vs-Pro table fills the screen and no price is visible, so this scrolls
    /// down to the tier cards before capturing. Prices come from the local
    /// `Caelyn.storekit` config wired into the scheme's `test` action.
    func test06b_PaywallPricing() throws {
        // Load the StoreKit config in-process rather than trusting the scheme —
        // see the note on CaelynUITests' resources in project.yml.
        let storeKit = try SKTestSession(configurationFileNamed: "Caelyn")
        storeKit.disableDialogs = true
        storeKit.clearTransactions()

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
        XCTAssertTrue(upgradeBtn.waitForExistence(timeout: 5), "Settings should offer the paywall")
        upgradeBtn.tap()
        sleep(2)

        // The tier cards sit just below the fold; one swipe brings all three plus
        // the CTA into frame.
        app.swipeUp()
        sleep(1)

        let perYear = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'per year'")
        ).firstMatch
        XCTAssertTrue(
            perYear.waitForExistence(timeout: 5),
            "Priced tier cards should be on screen — if this fails the products did not load"
        )
        snapshot("06b_PaywallPricing")
    }


    // MARK: - App Store set
    //
    // These eight captures are the raw material for the published store frames.
    // `screenshots/store-v2/_build/` crops and composes them, so the names here
    // and the names in those scripts have to stay in step. Both idioms run the
    // same tests: the iPhone frames and the iPad frames differ only in how the
    // composers crop, not in what is photographed.
    //
    //   xcodebuild test -project Caelyn.xcodeproj -scheme Caelyn \
    //     -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    //     -only-testing:CaelynUITests/ScreenshotTests/testStore1_Home ...
    //
    // Pin the status bar first so every frame reads 9:41 with a full battery:
    //   xcrun simctl status_bar <udid> override --time "9:41" \
    //     --cellularBars 4 --wifiBars 3 --batteryState charged --batteryLevel 100

    /// Home on an ovulation day — the billboard frame.
    func testStore1_Home() throws {
        tap(tab: "Home")
        sleep(2)
        snapshot("S1_Home")
    }

    /// The phase guide, which carries the typical-range table ("is this normal?")
    /// above the fold and the common questions below it. Both are captured
    /// because the phone frame uses the first and the iPad frame the second.
    func testStore2_PhaseGuide() throws {
        tap(tab: "Home")
        sleep(2)
        let badge = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Ovulation window' OR label CONTAINS 'phase'")
        ).firstMatch
        if badge.waitForExistence(timeout: 6) { badge.tap(); sleep(2) }
        snapshot("S2_PhaseGuide")
        app.swipeUp()
        sleep(1)
        snapshot("S2b_PhaseGuideQuestions")
    }

    /// The privacy page — the claim the whole product rests on.
    func testStore3_Privacy() throws {
        tap(tab: "Settings")
        sleep(2)
        let row = scrollUntil("Your privacy")
        if row.exists { row.tap(); sleep(2) }
        snapshot("S3_Privacy")
    }

    /// Insights: four big numbers, then the learned-about-you rows.
    func testStore4_Insights() throws {
        tap(tab: "Insights")
        sleep(2)
        snapshot("S4_Insights")
    }

    /// A month with a complete cycle in it. The current month has barely started,
    /// so the calendar frame has to step back one month to show colour.
    func testStore5_Calendar() throws {
        tap(tab: "Calendar")
        sleep(2)
        goToPreviousMonth()
        snapshot("S5_Calendar")
    }

    /// A day that was actually logged — medium flow, pain 5/10, cramps and
    /// fatigue. Matching on a bare "2," used to select the grid's trailing cell
    /// from the *next* month, which is empty; "20" is mid-period in the seed.
    func testStore6_LoggedDay() throws {
        tap(tab: "Calendar")
        sleep(2)
        goToPreviousMonth()
        let day = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '20'")).firstMatch
        if day.waitForExistence(timeout: 5) { day.tap() }
        sleep(2)
        snapshot("S6_LoggedDay")
        app.swipeUp()
        sleep(1)
        snapshot("S6b_LoggedDaySymptoms")
    }

    /// The import sheet, which names the apps Caelyn can read from. Most installs
    /// in this category are switchers, so this is the frame that speaks to them.
    func testStore7_BringHistory() throws {
        tap(tab: "Settings")
        sleep(2)
        let row = scrollUntil("Bring your history")
        if row.exists { row.tap(); sleep(2) }
        snapshot("S7_BringHistory")
    }

    /// Export — the reason to still be logging in month six.
    func testStore8_Export() throws {
        tap(tab: "Settings")
        sleep(2)
        let row = scrollUntil("Export data")
        if row.exists { row.tap(); sleep(2) }
        snapshot("S8_Export")
    }

    // MARK: - Helpers

    private func tap(tab name: String) {
        // iPad's sidebar-adaptable TabView publishes each tab twice — once in the
        // sidebar, once in the collapsed tab bar — so an exact-label query is
        // ambiguous there and `tap()` throws "Multiple matching elements found".
        // firstMatch resolves to the visible one on both idioms.
        let btn = app.buttons.matching(NSPredicate(format: "label == %@", name)).firstMatch
        if btn.waitForExistence(timeout: 5) { btn.tap() }
    }

    /// Scrolls the first scroll view until a button whose label contains `label`
    /// is on screen and hittable. Settings is long enough on both idioms that the
    /// import and export rows start below the fold.
    private func scrollUntil(_ label: String, swipes: Int = 10) -> XCUIElement {
        let el = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", label)).firstMatch
        for _ in 0..<swipes {
            if el.exists && el.isHittable { return el }
            app.scrollViews.firstMatch.swipeUp()
        }
        return el
    }

    private func goToPreviousMonth() {
        let prev = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Previous' OR label CONTAINS 'chevron.left'")
        ).firstMatch
        if prev.exists { prev.tap(); sleep(2) }
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
