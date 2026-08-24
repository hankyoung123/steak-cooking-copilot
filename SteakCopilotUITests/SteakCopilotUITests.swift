import XCTest

@MainActor
final class SteakCopilotUITests: XCTestCase {
    func testSimplifiedChineseFollowsSystemLanguage() {
        let app = launchApp(language: "zh-Hans", locale: "zh_Hans_CN")

        XCTAssertTrue(app.staticTexts["今日牛排"].exists)
        XCTAssertEqual(app.buttons["setup.primary"].label, "开始烹饪 →")
        app.buttons["home.settings"].tap()
        XCTAssertEqual(
            app.buttons["setup.doneness.mediumWell"].label,
            "七分熟"
        )
        XCTAssertEqual(
            app.buttons["setup.doneness.wellDone"].label,
            "全熟"
        )
        attachScreenshot(named: "setup-zh-Hans", app: app)

        app.buttons["settings.save"].tap()
        app.buttons["setup.primary"].tap()
        XCTAssertTrue(app.buttons["session.exit"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["session.exit"].label, "退出")
        XCTAssertEqual(app.buttons["session.skip"].label, "跳过")
        attachScreenshot(named: "stage-controls-zh-Hans", app: app)
    }

    func testUnsupportedSystemLanguageFallsBackToEnglish() {
        let app = launchApp(language: "fr", locale: "fr_FR")

        XCTAssertTrue(app.staticTexts["TODAY’S CUT"].exists)
        XCTAssertEqual(app.buttons["setup.primary"].label, "Begin Cooking →")
        attachScreenshot(named: "setup-english-fallback", app: app)
    }

    func testFiveDonenessLevelsAreAvailableAndSelectable() {
        let app = launchApp()
        app.buttons["home.settings"].tap()
        let expected = [
            "setup.doneness.rare",
            "setup.doneness.mediumRare",
            "setup.doneness.medium",
            "setup.doneness.mediumWell",
            "setup.doneness.wellDone"
        ]

        for identifier in expected {
            XCTAssertTrue(app.buttons[identifier].exists)
        }

        let wellDone = app.buttons["setup.doneness.wellDone"]
        wellDone.tap()
        XCTAssertTrue(wellDone.isSelected)
        attachScreenshot(named: "setup-five-doneness", app: app)
    }

    func testHomePresentsSettingsAndCookLog() {
        let app = launchApp()
        attachScreenshot(named: "home-v2", app: app)

        app.buttons["home.history"].tap()
        XCTAssertTrue(app.staticTexts["history.title"].waitForExistence(timeout: 3))
        attachScreenshot(named: "cook-log", app: app)
        app.buttons["history.close"].tap()

        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["settings.save"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["setup.doneness.mediumRare"].isSelected)
        attachScreenshot(named: "advanced-settings", app: app)
        app.buttons["settings.save"].tap()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))
    }

    func testCaseARibeyeWithoutThermometerCompletesEstimatedFlow() {
        let app = launchApp()
        startCooking(app)

        let evidence = advanceWithoutThermometer(app)

        XCTAssertGreaterThanOrEqual(evidence.flipCount, 2)
        XCTAssertTrue(evidence.sawButter)
        XCTAssertTrue(evidence.sawTakeOut)
        let reachedRestOrResult = app.staticTexts["REST"].waitForExistence(timeout: 2)
            || app.buttons["ready.continue"].waitForExistence(timeout: 4)
        XCTAssertTrue(reachedRestOrResult)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+\\.[0-9]°C")).firstMatch.exists)
        attachScreenshot(named: "case-a-estimated-finish", app: app)

        finishReadyFeedbackFlow(app)
    }

    func testCaseBStripWithManualTemperatureUsesFatCapAndTakesOut() {
        let app = launchApp()
        app.buttons["home.nextCut"].tap()
        app.buttons["home.settings"].tap()
        app.sliders["setup.thickness"].adjust(toNormalizedSliderPosition: 0.67)
        app.buttons["settings.save"].tap()
        startCooking(app)

        var flipCount = 0
        var sawFatCap = false
        var sawButter = false
        for _ in 0..<30 {
            let confirm = app.buttons["cook.confirm"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            let label = confirm.label
            flipCount += label == "Flipped" ? 1 : 0
            sawFatCap = sawFatCap || label == "Start fat cap"
            sawButter = sawButter || label == "Butter added"

            if app.buttons["cook.temperature.submit"].exists {
                app.sliders["cook.temperature.slider"]
                    .adjust(toNormalizedSliderPosition: 0.80)
                app.buttons["cook.temperature.submit"].tap()
                break
            }
            tapWhenEnabled(confirm, timeout: 15)
        }

        XCTAssertGreaterThanOrEqual(flipCount, 2)
        XCTAssertTrue(sawFatCap)
        XCTAssertTrue(sawButter)

        let takeOut = app.buttons["cook.confirm"]
        XCTAssertTrue(takeOut.waitForExistence(timeout: 4))
        waitForLabel("Steak is out", on: takeOut, timeout: 4)
        XCTAssertEqual(takeOut.label, "Steak is out")
        tapWhenEnabled(takeOut, timeout: 15)
        XCTAssertTrue(app.staticTexts["REST"].waitForExistence(timeout: 4))
    }

    func testCaseCTenderloinMediumSkipsFatCap() {
        let app = launchApp()
        app.buttons["home.nextCut"].tap()
        app.buttons["home.nextCut"].tap()
        app.buttons["home.settings"].tap()
        app.buttons["setup.doneness.medium"].tap()
        app.buttons["settings.save"].tap()
        startCooking(app)

        let evidence = advanceWithoutThermometer(app)

        XCTAssertGreaterThanOrEqual(evidence.flipCount, 2)
        XCTAssertFalse(evidence.sawFatCap)
        XCTAssertTrue(evidence.sawButter)
        XCTAssertTrue(app.staticTexts["REST"].waitForExistence(timeout: 4))
    }

    func testStageControlsSkipEveryStageAndExitToSetup() {
        let app = launchApp()
        app.buttons["setup.primary"].tap()

        XCTAssertTrue(app.buttons["prep.dry"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["session.exit"].exists)
        XCTAssertTrue(app.buttons["session.skip"].exists)
        attachScreenshot(named: "stage-controls-prep", app: app)

        confirmSkip(in: app)
        XCTAssertTrue(app.buttons["heat.ready"].waitForExistence(timeout: 3))
        attachScreenshot(named: "prototype-heat", app: app)

        confirmSkip(in: app)
        waitForLabelPrefix(
            "SEAR",
            on: app.staticTexts["session.phase.title"],
            timeout: 3
        )
        attachScreenshot(named: "stage-controls-cook", app: app)

        confirmSkip(in: app)
        waitForLabel(
            "REST",
            on: app.staticTexts["session.phase.title"],
            timeout: 3
        )
        attachScreenshot(named: "prototype-finish", app: app)

        confirmSkip(in: app)
        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 3))
        attachScreenshot(named: "prototype-ready", app: app)

        confirmSkip(in: app)
        XCTAssertTrue(app.buttons["eat.feedback"].waitForExistence(timeout: 3))
        attachScreenshot(named: "prototype-eat", app: app)

        confirmSkip(in: app)
        XCTAssertTrue(app.buttons["feedback.save"].waitForExistence(timeout: 3))
        attachScreenshot(named: "prototype-feedback", app: app)

        confirmSkip(in: app)
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))

        app.buttons["setup.primary"].tap()
        XCTAssertTrue(app.buttons["session.exit"].waitForExistence(timeout: 3))
        app.buttons["session.exit"].tap()
        XCTAssertTrue(app.buttons["Exit Session"].waitForExistence(timeout: 3))
        app.buttons["Exit Session"].tap()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))
    }

    func testPrototypeVisualStatesUseStageSpecificArtwork() {
        let app = launchApp(fastCook: false, visualCook: true)
        startCooking(app)

        settleArtwork(after: 0.15)
        attachScreenshot(named: "prototype-sear", app: app)

        var capturedFlip = false
        var capturedBaste = false
        var capturedCheck = false

        for _ in 0..<30 {
            if app.staticTexts["REST"].exists { break }
            let confirm = app.buttons["cook.confirm"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))

            switch confirm.label {
            case "Flipped" where !capturedFlip:
                settleArtwork()
                attachScreenshot(named: "prototype-flip", app: app)
                capturedFlip = true
            case "Butter added" where !capturedBaste:
                settleArtwork()
                attachScreenshot(named: "prototype-baste", app: app)
                capturedBaste = true
            case "No thermometer — continue" where !capturedCheck:
                settleArtwork()
                attachScreenshot(named: "prototype-check", app: app)
                capturedCheck = true
            default:
                break
            }

            tapWhenEnabled(confirm, timeout: 15)
        }

        XCTAssertTrue(capturedFlip)
        XCTAssertTrue(capturedBaste)
        XCTAssertTrue(capturedCheck)
        XCTAssertTrue(app.staticTexts["REST"].waitForExistence(timeout: 4))
        settleArtwork()
        attachScreenshot(named: "prototype-rest", app: app)

        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 15))
        settleArtwork()
        attachScreenshot(named: "prototype-result", app: app)
    }

    private func launchApp(
        language: String? = "en",
        locale: String? = "en_US",
        fastCook: Bool = true,
        visualCook: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetSession",
            "-disableNotifications",
            "-disableLiveActivity",
            "-quietFeedback"
        ]
        if fastCook { app.launchArguments.append("-fastCook") }
        if visualCook { app.launchArguments.append("-visualCook") }
        if let language {
            app.launchArguments += ["-AppleLanguages", "(\(language))"]
        }
        if let locale {
            app.launchArguments += ["-AppleLocale", locale]
        }
        app.launch()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 5))
        return app
    }

    private func startCooking(_ app: XCUIApplication) {
        app.buttons["setup.primary"].tap()
        XCTAssertTrue(app.buttons["prep.dry"].waitForExistence(timeout: 3))
        app.buttons["prep.dry"].tap()
        app.buttons["prep.salt"].tap()
        tapWhenEnabled(app.buttons["prep.continue"], timeout: 3)
        XCTAssertTrue(app.buttons["heat.ready"].waitForExistence(timeout: 3))
        app.buttons["heat.ready"].tap()
        waitForLabelPrefix(
            "SEAR",
            on: app.staticTexts["session.phase.title"],
            timeout: 3
        )
    }

    private func advanceWithoutThermometer(
        _ app: XCUIApplication
    ) -> (flipCount: Int, sawFatCap: Bool, sawButter: Bool, sawTakeOut: Bool) {
        var flipCount = 0
        var sawFatCap = false
        var sawButter = false
        var sawTakeOut = false

        for _ in 0..<30 {
            if app.staticTexts["REST"].exists { break }
            let confirm = app.buttons["cook.confirm"]
            if !confirm.waitForExistence(timeout: 5) {
                if app.staticTexts["REST"].waitForExistence(timeout: 2) {
                    break
                }
                XCTFail("Expected the next cook action or the rest phase")
                break
            }
            let label = confirm.label
            flipCount += label == "Flipped" ? 1 : 0
            sawFatCap = sawFatCap || label == "Start fat cap"
            sawButter = sawButter || label == "Butter added"
            sawTakeOut = sawTakeOut || label == "Steak is out"
            tapWhenEnabled(confirm, timeout: 15)
        }

        return (flipCount, sawFatCap, sawButter, sawTakeOut)
    }

    private func finishReadyFeedbackFlow(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 15))
        app.buttons["ready.continue"].tap()
        XCTAssertTrue(app.buttons["eat.feedback"].waitForExistence(timeout: 3))
        app.buttons["eat.feedback"].tap()

        let save = app.buttons["feedback.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        while !save.isHittable { app.swipeUp() }
        save.tap()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))
    }

    private func tapWhenEnabled(
        _ element: XCUIElement,
        timeout: TimeInterval
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))
        let enabled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [enabled], timeout: timeout),
            .completed
        )
        element.tap()
    }

    private func waitForLabel(
        _ label: String,
        on element: XCUIElement,
        timeout: TimeInterval
    ) {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", label),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [matches], timeout: timeout),
            .completed
        )
    }

    private func waitForLabelPrefix(
        _ prefix: String,
        on element: XCUIElement,
        timeout: TimeInterval
    ) {
        let matches = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@", prefix),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [matches], timeout: timeout),
            .completed
        )
    }

    private func confirmSkip(in app: XCUIApplication) {
        let skip = app.buttons["session.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        skip.tap()
        let confirmation = app.buttons["Skip Stage"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.tap()
    }

    private func attachScreenshot(
        named name: String,
        app: XCUIApplication
    ) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func settleArtwork(after delay: TimeInterval = 0.8) {
        let settled = XCTestExpectation(description: "Artwork transition settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: delay + 0.5)
    }
}
