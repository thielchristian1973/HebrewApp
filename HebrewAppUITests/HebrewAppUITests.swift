import XCTest

/// A minimal launch smoke test (Documentation/TESTING.md UI matrix starts at "Onboarding →
/// Demo"). Deeper flows are exercised manually per Documentation/PILOT.md's physical device
/// matrix, which XCUITest on Simulator cannot substitute for.
final class HebrewAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesToTodayTab() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Weiterlernen"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testStartingDemoPathNavigatesToFirstStep() throws {
        let app = XCUIApplication()
        app.launch()
        let startButton = app.buttons["Vorstellen starten"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()
        XCTAssertTrue(app.staticTexts["Schritt 1 von 3"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSettingsGearOpensSettingsSheet() throws {
        let app = XCUIApplication()
        app.launch()
        let settingsButton = app.navigationBars.buttons["Einstellungen"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPilotDiagnosticsLinkOpensDeveloperScreen() throws {
        let app = XCUIApplication()
        app.launch()
        let link = app.buttons["Pilot-Diagnose öffnen"]
        XCTAssertTrue(link.waitForExistence(timeout: 10))
        link.tap()
        XCTAssertTrue(app.navigationBars["Pilot-Diagnose"].waitForExistence(timeout: 10))
    }
}
