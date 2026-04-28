import XCTest

final class CaelynUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()
        let onboardingHero = app.staticTexts["Meet Caelyn"]
        let mainHomeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(
            onboardingHero.waitForExistence(timeout: 5) || mainHomeTab.waitForExistence(timeout: 5),
            "Expected either onboarding welcome (first launch) or main tab bar (already onboarded) to appear."
        )
    }
}
