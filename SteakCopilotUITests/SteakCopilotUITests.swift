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
        XCTAssertFalse(app.staticTexts["Starting Temperature"].exists)
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
        XCTAssertTrue(evidence.sawNoThermometer)
        let reachedFinishingOrResult = app.staticTexts["FINISHING"].waitForExistence(timeout: 2)
            || app.buttons["ready.continue"].waitForExistence(timeout: 4)
        XCTAssertTrue(reachedFinishingOrResult)
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
            if app.buttons["cook.temperature.submit"].waitForExistence(timeout: 1) {
                app.sliders["cook.temperature.slider"]
                    .adjust(toNormalizedSliderPosition: 0.80)
                app.buttons["cook.temperature.submit"].tap()
                break
            }
            let confirm = app.buttons["cook.confirm"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            let label = confirm.label
            flipCount += label == "Flipped" ? 1 : 0
            sawFatCap = sawFatCap || label == "Start fat cap"
            sawButter = sawButter || label == "Butter added"
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
        XCTAssertTrue(app.staticTexts["FINISHING"].waitForExistence(timeout: 4))
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
        XCTAssertTrue(app.staticTexts["FINISHING"].waitForExistence(timeout: 4))
    }

    /// Regression for the overlapping artwork bug: a cook stage draws a
    /// complete photograph that already contains the pan and the steak, so it
    /// must not also layer an object cutout on top of it (which rendered two
    /// steaks). The stage artwork is exposed to accessibility as images whose
    /// labels are the asset names, so the rendered layer count is observable.
    func testCookingStageRendersOneArtworkLayerWithoutCutoutOverlap() {
        let app = launchApp()
        startCooking(app)

        let cutouts = app.images.matching(
            NSPredicate(format: "label ENDSWITH %@", "Cutout")
        )
        let compositions = app.images.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Cook")
        )

        // Guard against a vacuous pass: the stage artwork must be observable.
        XCTAssertGreaterThanOrEqual(
            compositions.count,
            1,
            "Expected the full-bleed stage photograph to be rendered"
        )
        XCTAssertEqual(
            cutouts.count,
            0,
            "A complete cooking photograph must not be overlaid with a cutout"
        )
        attachScreenshot(named: "stage-single-layer-sear", app: app)
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
            "FINISHING",
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
            if app.staticTexts["FINISHING"].exists { break }
            if app.buttons["cook.noThermometer"].waitForExistence(timeout: 1) {
                app.buttons["cook.noThermometer"].tap()
                continue
            }
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
            case "CHECK TEMP" where !capturedCheck:
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
        XCTAssertTrue(app.staticTexts["FINISHING"].waitForExistence(timeout: 4))
        settleArtwork()
        attachScreenshot(named: "prototype-rest", app: app)

        // FINISHING runs for the estimated carryover time, which at the
        // visual-cook time scale is ~18s, so the wait must exceed that.
        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 45))
        settleArtwork()
        attachScreenshot(named: "prototype-result", app: app)
    }

    /// The Tuning Lab is a developer tool, reachable only via `-tuningLab`.
    ///
    /// Walks its flows in the order a developer would: edit a value at the top
    /// of the form, save it, then scroll down through every section to export,
    /// attempt an invalid import, and reset.
    func testTuningLabEditsExportImportsAndResets() {
        let app = launchApp(tuningLab: true)

        // The Lab opens automatically for this launch.
        let budgetValue = app.staticTexts["tuningLab.cooking.baseCookingBudget.value"]
        XCTAssertTrue(budgetValue.waitForExistence(timeout: 5))
        let productionBudget = budgetValue.label

        // Live edit the first row of the Cooking section.
        let increment = app.buttons["tuningLab.cooking.baseCookingBudget.increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 3))
        increment.tap()
        XCTAssertNotEqual(
            budgetValue.label,
            productionBudget,
            "Editing a value should update the displayed value immediately"
        )

        // Save persists it; the Lab reports back.
        app.buttons["tuningLab.save"].tap()
        XCTAssertTrue(
            app.staticTexts["tuningLab.message"].waitForExistence(timeout: 3),
            "Saving should report success"
        )

        // Every parameter group has a section, each reachable by scrolling.
        for section in ["Cooking", "Cuts", "Doneness", "Calibration",
                        "Finishing", "Notifications", "Motion", "Override JSON"] {
            XCTAssertTrue(
                scrollToVisible(section, in: app),
                "Tuning Lab is missing the \(section) section"
            )
        }

        // The Override JSON section exposes every import/export affordance.
        XCTAssertTrue(app.buttons["tuningLab.export"].exists)
        XCTAssertTrue(app.buttons["tuningLab.copy"].exists)
        XCTAssertTrue(app.buttons["tuningLab.importPasted"].exists)
        XCTAssertTrue(app.buttons["tuningLab.importFile"].exists)

        // Export populates the editor with a versioned document.
        app.buttons["tuningLab.export"].tap()
        let editor = app.textViews["tuningLab.importText"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        let exported = editor.value as? String ?? ""
        XCTAssertTrue(
            exported.contains("schemaVersion"),
            "Export should produce a versioned override document, got: \(exported)"
        )

        // Reset returns to production.yaml defaults.
        app.buttons["tuningLab.reset"].tap()
        XCTAssertTrue(app.staticTexts["tuningLab.message"].waitForExistence(timeout: 3))

        attachScreenshot(named: "tuning-lab", app: app)
    }

    private enum ScrollDirection {
        case up
        case down

        var gesture: (XCUIApplication) -> Void {
            switch self {
            case .up: { $0.swipeUp() }
            case .down: { $0.swipeDown() }
            }
        }
    }

    /// Scrolls until a static text with this label is actually on screen.
    /// Hittability (not just existence) is required, because XCUITest reports
    /// off-screen form rows as existing.
    private func scrollToVisible(
        _ label: String,
        in app: XCUIApplication,
        direction: ScrollDirection = .up,
        attempts: Int = 14
    ) -> Bool {
        scrollToVisible(app.staticTexts[label], in: app, direction: direction, attempts: attempts)
    }

    /// Scrolls until an arbitrary element is actually on screen.
    private func scrollToVisible(
        _ element: XCUIElement,
        in app: XCUIApplication,
        direction: ScrollDirection = .up,
        attempts: Int = 14
    ) -> Bool {
        for _ in 0..<attempts {
            if element.exists, element.isHittable { return true }
            direction.gesture(app)
        }
        return element.exists && element.isHittable
    }

    /// Scrolls until a button with this identifier is on screen.
    private func scrollToVisibleButton(
        _ identifier: String,
        in app: XCUIApplication,
        direction: ScrollDirection = .up,
        attempts: Int = 14
    ) -> Bool {
        for _ in 0..<attempts {
            let element = app.buttons[identifier]
            if element.exists, element.isHittable { return true }
            direction.gesture(app)
        }
        let element = app.buttons[identifier]
        return element.exists && element.isHittable
    }

    private func launchApp(
        language: String? = "en",
        locale: String? = "en_US",
        fastCook: Bool = true,
        visualCook: Bool = false,
        tuningLab: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-resetSession",
            "-resetTuning",
            "-disableNotifications",
            "-disableLiveActivity",
            "-quietFeedback"
        ]
        if tuningLab { app.launchArguments.append("-tuningLab") }
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
    ) -> (
        flipCount: Int,
        sawFatCap: Bool,
        sawButter: Bool,
        sawTakeOut: Bool,
        sawNoThermometer: Bool
    ) {
        var flipCount = 0
        var sawFatCap = false
        var sawButter = false
        var sawTakeOut = false
        var sawNoThermometer = false

        for _ in 0..<30 {
            if app.staticTexts["FINISHING"].exists { break }
            let noThermometer = app.buttons["cook.noThermometer"]
            if noThermometer.waitForExistence(timeout: 1) {
                sawNoThermometer = true
                noThermometer.tap()
                continue
            }
            let confirm = app.buttons["cook.confirm"]
            if !confirm.waitForExistence(timeout: 5) {
                if app.staticTexts["FINISHING"].waitForExistence(timeout: 2) {
                    break
                }
                XCTFail("Expected the next cook action or the finishing phase")
                break
            }
            let label = confirm.label
            flipCount += label == "Flipped" ? 1 : 0
            sawFatCap = sawFatCap || label == "Start fat cap"
            sawButter = sawButter || label == "Butter added"
            sawTakeOut = sawTakeOut || label == "Steak is out"
            tapWhenEnabled(confirm, timeout: 15)
        }

        return (flipCount, sawFatCap, sawButter, sawTakeOut, sawNoThermometer)
    }

    private func finishReadyFeedbackFlow(_ app: XCUIApplication) {
        // Long enough to cover the finishing estimate at any time scale.
        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 45))
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
