import XCTest

/// "Planavimas" chip → destination → stops → when → plan → "Važiuojam" opens the route to the first stop.
final class TripPlannerUITests: XCTestCase {
    func testTripPlannerFlow() throws {
        let app = XCUIApplication()
        app.launch()
        sleep(8)
        func shot(_ name: String) { let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a) }

        let chip = app.buttons["Planavimas"].firstMatch
        // the 4th chip starts off-screen: drag the chip row left
        let row = app.buttons["Greitas krovimas"].firstMatch
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).withOffset(CGVector(dx: 0, dy: row.frame.midY - app.frame.midY)))
        sleep(1)
        chip.tap()
        XCTAssertTrue(app.staticTexts["Kur važiuosi?"].waitForExistence(timeout: 4), "step 1")
        shot("1-destination")
        app.buttons["Kaunas"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Kiek sustojimų?"].waitForExistence(timeout: 4), "step 2")
        let next = app.buttons["Toliau"]
        let ready = NSPredicate(format: "isEnabled == true")
        expectation(for: ready, evaluatedWith: next); waitForExpectations(timeout: 10) // route loaded
        app.buttons["2"].firstMatch.tap()
        shot("2-stops")
        next.tap()

        XCTAssertTrue(app.staticTexts["Kada nori sustoti?"].waitForExistence(timeout: 4), "step 3")
        XCTAssertEqual(app.sliders.count, 2, "one slider per stop")
        app.sliders.element(boundBy: 0).adjust(toNormalizedSliderPosition: 0.2)
        shot("3-time")
        app.buttons["Sudaryti planą"].tap()

        XCTAssertTrue(app.staticTexts["Planas paruoštas"].waitForExistence(timeout: 4), "plan")
        shot("4-plan")
        app.buttons["Važiuojam"].tap()
        XCTAssertTrue(app.buttons["Ne"].waitForExistence(timeout: 8), "route preview to the first stop")
        shot("5-route")
    }
}
