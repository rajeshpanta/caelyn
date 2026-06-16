import XCTest

/// App Store screenshot capture.
///
/// Run with:
///   xcodebuild test -scheme Caelyn -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max,OS=latest' \
///     -only-testing CaelynUITests/ScreenshotTests \
///     -resultBundlePath screenshots.xcresult
///
/// Screenshots land in the .xcresult bundle. Extract with:
///   xcrun xcresulttool export --type directory --path screenshots.xcresult --output-path ./screenshots
final class ScreenshotTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--screenshot-mode"]
        app.launch()

        // Wait for either onboarding or the main tab bar.
        let homeTab = app.tabBars.buttons["Home"]
        let onboarding = app.staticTexts["Meet Caelyn"]
        guard homeTab.waitForExistence(timeout: 8) || onboarding.waitForExistence(timeout: 8) else {
            XCTFail("App failed to launch to a known state")
            return
        }

        // Skip onboarding if shown.
        if onboarding.exists {
            skipOnboarding()
        }
    }

    // MARK: - Screenshot 1: Home (phase ring + upcoming)

    func test01_Home() {
        tap(tab: "Home")
        snapshot("01_Home")
    }

    // MARK: - Screenshot 2: Daily log (symptom chips)

    func test02_DailyLog() {
        tap(tab: "Log")
        snapshot("02_DailyLog")
    }

    // MARK: - Screenshot 3: Calendar

    func test03_Calendar() {
        tap(tab: "Calendar")
        snapshot("03_Calendar")
    }

    // MARK: - Screenshot 4: Insights charts

    func test04_Insights() {
        tap(tab: "Insights")
        snapshot("04_Insights")
    }

    // MARK: - Screenshot 5: Pro paywall

    func test05_Paywall() {
        tap(tab: "Home")
        // Tap the pro badge / paywall trigger on home screen.
        let paywallButton = app.buttons["Unlock Pro"]
        if paywallButton.waitForExistence(timeout: 3) {
            paywallButton.tap()
        } else {
            // Fall back: open paywall from Settings.
            tap(tab: "Settings")
            let upgradeCell = app.staticTexts["Upgrade to Pro"]
            if upgradeCell.waitForExistence(timeout: 3) { upgradeCell.tap() }
        }
        snapshot("05_Paywall")
    }

    // MARK: - Helpers

    private func tap(tab name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 4) { tab.tap() }
    }

    private func snapshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func skipOnboarding() {
        // Advance through onboarding by tapping Continue / Get Started
        for _ in 0..<10 {
            let cont = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Continue' OR label CONTAINS 'Get Started' OR label CONTAINS 'Start'")).firstMatch
            if cont.waitForExistence(timeout: 2) { cont.tap() } else { break }
        }
    }
}
