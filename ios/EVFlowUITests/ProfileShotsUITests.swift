import XCTest

/// Screenshots of the profile: settings rows and the Arbus prize cards.
final class ProfileShotsUITests: XCTestCase {
    func testProfileScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-demoScreen", "profile"]
        app.launch()
        sleep(6)
        let sv = app.scrollViews.firstMatch
        sv.swipeUp(velocity: .slow)
        sleep(1)
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = "settings"; a.lifetime = .keepAlways; add(a)
        sv.swipeUp(velocity: .slow)
        sv.swipeUp(velocity: .slow)
        sleep(3)
        let b = XCTAttachment(screenshot: app.screenshot()); b.name = "cards"; b.lifetime = .keepAlways; add(b)
        XCTAssertTrue(app.staticTexts["Prizai"].exists)
    }
}
