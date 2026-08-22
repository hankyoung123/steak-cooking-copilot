import XCTest

@MainActor
final class SteakCopilotUITests: XCTestCase {
    func testCompleteCookingFlow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetSession",
            "-fastCook",
            "-disableNotifications",
            "-disableLiveActivity",
            "-quietFeedback"
        ]
        app.launch()

        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 5))
        attachScreenshot(named: "01-setup", app: app)
        app.buttons["setup.primary"].tap()

        XCTAssertTrue(app.buttons["prep.dry"].waitForExistence(timeout: 3))
        app.buttons["prep.dry"].tap()
        app.buttons["prep.salt"].tap()
        tapWhenEnabled(app.buttons["prep.continue"], timeout: 3)

        XCTAssertTrue(app.buttons["heat.ready"].waitForExistence(timeout: 3))
        app.buttons["heat.ready"].tap()
        XCTAssertTrue(app.staticTexts["COOK"].waitForExistence(timeout: 3))
        attachScreenshot(named: "02-cook", app: app)

        for _ in 0..<7 {
            tapWhenEnabled(app.buttons["cook.confirm"], timeout: 10)
        }

        XCTAssertTrue(app.staticTexts["FINISH"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 12))
        attachScreenshot(named: "03-ready", app: app)
        app.buttons["ready.continue"].tap()

        XCTAssertTrue(app.buttons["eat.feedback"].waitForExistence(timeout: 3))
        app.buttons["eat.feedback"].tap()

        let save = app.buttons["feedback.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        while !save.isHittable {
            app.swipeUp()
        }
        save.tap()

        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))
    }

    private func tapWhenEnabled(_ element: XCUIElement, timeout: TimeInterval) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: timeout), .completed)
        element.tap()
    }

    private func attachScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
