import XCTest

/// Drives the app through each main tab with demo data loaded (see
/// ItemStore's screenshotModeLaunchArgument) and captures a full-screen
/// screenshot per tab, for use as App Store Connect listing images.
///
/// This is not a correctness test in the usual sense - every assertion
/// here exists only to fail loudly if a screen never loaded, so a broken
/// screenshot run shows up as a red X in CI instead of silently producing
/// a blank or half-rendered image that nobody notices until it's already
/// live on the App Store listing.
///
/// Run via .github/workflows/screenshots.yml, which extracts the
/// captured images out of the resulting .xcresult bundle.
final class ScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments += ["UI_TESTING_SCREENSHOTS"]
        app.launch()

        capture(app, tabLabel: "Dashboard", name: "01-Dashboard")
        capture(app, tabLabel: "Items", name: "02-Items")
        capture(app, tabLabel: "Timeline", name: "03-Timeline")
    }

    private func capture(_ app: XCUIApplication, tabLabel: String, name: String) {
        let tabButton = app.tabBars.buttons[tabLabel]
        XCTAssertTrue(tabButton.waitForExistence(timeout: 15), "\(tabLabel) tab never appeared")
        tabButton.tap()

        // Give the tab a beat to finish laying out / animating in before
        // capturing - a screenshot taken mid-transition is worse than a
        // half-second of slack here.
        Thread.sleep(forTimeInterval: 0.75)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
