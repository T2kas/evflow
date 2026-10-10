import XCTest

/// Tapping a station pin on the map must open its sheet ("Važiuojam" button).
final class MapTapUITests: XCTestCase {
    func testTappingPinOpensStationSheet() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(8) // feed + map style load
        // the pin right above the car at the demo start location (VILNIUS TECH)
        let pin = app.coordinate(withNormalizedOffset: CGVector(dx: 0.429, dy: 0.462))
        pin.tap()
        let sheet = app.buttons["Važiuojam"]
        let opened = sheet.waitForExistence(timeout: 4)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.lifetime = .keepAlways; add(shot)
        XCTAssertTrue(opened, "station sheet did not open after tapping the pin")
    }
}

extension MapTapUITests {
    /// pin on the map → station sheet → "Važiuojam" must show the map-app picker
    func testVaziuojamFromMapShowsPicker() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.429, dy: 0.462)).tap()
        let go = app.buttons["Važiuojam"]
        XCTAssertTrue(go.waitForExistence(timeout: 5), "station sheet")
        go.tap()
        let picker = app.staticTexts["Kuo važiuosi?"]
        let shown = picker.waitForExistence(timeout: 3)
        let a = XCTAttachment(screenshot: app.screenshot()); a.lifetime = .keepAlways; add(a)
        XCTAssertTrue(shown, "map-app picker did not appear")
    }
}

extension MapTapUITests {
    /// map pin → Važiuojam → picker → EVFlow → our route → Važiuojam → picker again
    func testRouteScreenVaziuojamShowsPicker() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(8)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.429, dy: 0.462)).tap()
        XCTAssertTrue(app.buttons["Važiuojam"].waitForExistence(timeout: 5))
        app.buttons["Važiuojam"].tap()
        XCTAssertTrue(app.staticTexts["Kuo važiuosi?"].waitForExistence(timeout: 3))
        app.staticTexts["EVFlow"].tap()
        XCTAssertTrue(app.buttons["Ne"].waitForExistence(timeout: 8), "route screen")
        sleep(3)
        app.buttons["Važiuojam"].firstMatch.tap()
        let shown = app.staticTexts["Kuo važiuosi?"].waitForExistence(timeout: 3)
        let a = XCTAttachment(screenshot: app.screenshot()); a.lifetime = .keepAlways; add(a)
        XCTAssertTrue(shown, "picker on the route screen")
    }
}

extension MapTapUITests {
    /// drag the home sheet down → compact (search + peek of the chips), drag up → back to normal
    func testHomeSheetCompactSize() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(8)
        let search = app.textFields["Kur krausime?"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        let before = search.frame.minY
        let grab = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
        grab.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        sleep(1)
        let compact = XCTAttachment(screenshot: app.screenshot()); compact.name = "compact"; compact.lifetime = .keepAlways; add(compact)
        XCTAssertGreaterThan(search.frame.minY, before + 120, "sheet did not shrink")
        XCTAssertTrue(search.isHittable)
        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.88))
        low.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7)))
        sleep(1)
        XCTAssertEqual(search.frame.minY, before, accuracy: 4, "back to normal size")
    }
}
