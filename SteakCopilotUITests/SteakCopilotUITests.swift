import XCTest

@MainActor
final class SteakCopilotUITests: XCTestCase {
    func testSimplifiedChineseFollowsSystemLanguage() {
        let app = launchApp(language: "zh-Hans", locale: "zh_Hans_CN")

        XCTAssertTrue(app.staticTexts["今日牛排"].exists)
        XCTAssertEqual(app.buttons["setup.primary"].label, "开始烹饪 →")
        // Captured before opening the settings sheet: CJK cut names are the
        // longest copy this screen has to lay out, so the home skeleton is
        // worth an explicit reference image in Chinese.
        attachScreenshot(named: "home-zh-Hans", app: app)
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

    /// Regression for the session layout skeleton.
    ///
    /// The session screen used to reflow on almost every phase change: the hero
    /// switched between a 78pt countdown and a 40pt sentence, the instruction
    /// kept or dropped its detail line, CHECK TEMP inserted a temperature
    /// control into the middle of the column, and FINISHING replaced the
    /// telemetry with a taller card. Every one of those pushed the rows below it.
    ///
    /// This test walks the real cooking sequence (a strip covers the fat-cap
    /// stand, which ribeye and tenderloin skip) and asserts that the shared slots
    /// keep one frame. The artwork band and the progress rail carry no
    /// accessibility content on purpose, so they are measured through geometry
    /// probes that only materialise under `-layoutProbes` — production VoiceOver
    /// never announces a decorative photograph.
    func testSessionSkeletonSlotsDoNotMoveBetweenCookingPhases() {
        let app = launchApp(layoutProbes: true)
        // Strip is the only cut with a fat-cap stand, so this covers
        // SEAR wait → FLIP → FAT CAP → BASTE → CHECK TEMP → FINISHING.
        app.buttons["home.nextCut"].tap()
        startCooking(app)

        var samples: [SessionSkeletonSample] = []
        for _ in 0..<26 {
            // Let the phase transition and the artwork crossfade settle, so a
            // sample is never taken mid-animation.
            settleArtwork(after: 0.3)
            samples.append(captureSessionSkeleton(in: app))

            if app.staticTexts["FINISHING"].exists { break }

            let noThermometer = app.buttons["cook.noThermometer"]
            if noThermometer.exists, noThermometer.isHittable {
                noThermometer.tap()
                continue
            }

            let confirm = app.buttons["cook.confirm"]
            if confirm.waitForExistence(timeout: 4) {
                tapWhenEnabled(confirm, timeout: 20)
                continue
            }

            if app.buttons["cook.temperature.submit"].exists {
                // The reading path is covered by the case tests; this test only
                // needs the phase sequence, and that path has no confirm step.
                break
            }

            XCTFail("Expected the next cook action or the finishing phase")
            break
        }

        XCTAssertGreaterThanOrEqual(
            samples.count,
            6,
            "The walk should have sampled several distinct cooking phases"
        )

        let titles = Set(samples.map(\.phaseTitle))
        XCTAssertTrue(
            titles.contains { $0.hasPrefix("SEAR") },
            "Expected sear samples, saw \(titles.sorted())"
        )
        XCTAssertTrue(
            titles.contains("CHECK"),
            "Expected a CHECK TEMP sample, saw \(titles.sorted())"
        )
        XCTAssertTrue(
            titles.contains("FINISHING"),
            "Expected a FINISHING sample, saw \(titles.sorted())"
        )

        // Coverage guards: the assertions below are only meaningful if the
        // samples really do span both states of the swapped status slot.
        XCTAssertTrue(
            samples.contains { $0.telemetry == nil },
            "No sample without telemetry, so the status-slot swap is untested"
        )
        XCTAssertTrue(
            samples.contains { $0.telemetry != nil },
            "No sample with telemetry, so the status-slot swap is untested"
        )

        let tolerance: CGFloat = 2
        assertStable(samples, "session.topControls", tolerance) { $0.topControls }
        assertStable(samples, "session.scene", tolerance) { $0.scene }
        assertStable(samples, "session.instruction", tolerance) { $0.instruction }
        assertStable(samples, "session.primaryAction", tolerance) { $0.primaryAction }

        // The progress rail is present in every phase except FINISHING (where
        // carryover heat has no measurable progress), and the telemetry is
        // swapped out for the reading entry and then the finishing card. Both
        // must hold one frame in every phase that shows them.
        assertStable(samples, "session.progress (while shown)", tolerance) { $0.progress }
        assertStable(samples, "session.telemetry (while shown)", tolerance) { $0.telemetry }

        // The hero is the one band whose *type size* legitimately changes: a
        // 78pt countdown while a stage timer runs, a 40pt sentence when it has
        // run out. Its container is fixed and its content is centred, so the
        // invariant is the container's centre plus "the text never reaches the
        // scene". Asserting a fixed minY/height here would be asserting that the
        // countdown and the sentence must be the same size, which is not the
        // design.
        assertCentred(samples, "session.hero", tolerance)

        attachScreenshot(named: "layout-skeleton-finishing", app: app)
    }

    /// Regression for the result screen's skeleton (READY → EAT → FEEDBACK).
    ///
    /// The feedback form is much taller than the "how it went" note it replaces.
    /// The upper bands are fixed and the middle band is reserved for the taller
    /// of the two, so the feedback controls must not push the top navigation, the
    /// title, the hero or the summary card.
    func testResultSkeletonSlotsDoNotMoveBetweenReadyEatFeedback() {
        let app = launchApp(layoutProbes: true)
        app.buttons["setup.primary"].tap()

        // Skip PREP → HEAT → SEAR → FINISHING → READY.
        for _ in 0..<4 { confirmSkip(in: app) }
        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 5))

        var samples: [ResultSkeletonSample] = []
        for _ in 0..<3 {
            settleArtwork(after: 0.4)
            samples.append(captureResultSkeleton(in: app))

            if app.buttons["eat.feedback"].exists {
                app.buttons["eat.feedback"].tap()
            } else if app.buttons["ready.continue"].exists {
                app.buttons["ready.continue"].tap()
            } else {
                break
            }
        }

        XCTAssertEqual(
            samples.count,
            3,
            "Expected a READY, an EAT and a FEEDBACK sample"
        )
        // WELL DONE covers READY and EAT, COOK COMPLETE is FEEDBACK.
        XCTAssertEqual(
            Set(samples.map(\.eyebrow)).count,
            2,
            "The samples should span all three result phases, saw \(samples.map(\.eyebrow))"
        )

        let tolerance: CGFloat = 2
        assertStable(samples, "result.topControls", tolerance) { $0.topControls }
        assertStable(samples, "result.title", tolerance) { $0.title }
        assertStable(samples, "result.hero", tolerance) { $0.hero }
        assertStable(samples, "result.summary", tolerance) { $0.summary }
        assertStable(samples, "result.primaryAction", tolerance) { $0.primaryAction }

        attachScreenshot(named: "layout-result-feedback", app: app)
    }

    // MARK: - Setup screen skeleton

    /// Regression for the setup screen's skeleton.
    ///
    /// The three cuts have different name lengths in both languages, and the
    /// screen used to be a plain `VStack` of intrinsically sized rows, so any
    /// copy change was free to reflow everything below it. The title, the
    /// parameter row, the pre-flight summary and the call to action must all hold
    /// one frame while the selection changes; only the artwork, the cut name, the
    /// neighbour labels and the parameter values may differ.
    func testHomeSkeletonSlotsDoNotMoveBetweenCuts() {
        let app = launchApp()

        var samples: [HomeSkeletonSample] = []
        for index in 0..<3 {
            settleArtwork(after: 0.5)
            samples.append(captureHomeSkeleton(in: app))
            attachScreenshot(named: "home-cut-\(index)", app: app)
            if index < 2 {
                app.buttons["home.nextCut"].tap()
            }
        }

        // Coverage guard: the assertions below are only meaningful if the walk
        // really visited three different cuts.
        XCTAssertEqual(
            Set(samples.map(\.cutTitle)).count,
            3,
            "Expected all three cuts, saw \(samples.map(\.cutTitle))"
        )

        let tolerance: CGFloat = 2
        assertStable(samples, "home.carousel", tolerance) { $0.carousel }
        assertStable(samples, "home.title", tolerance) { $0.title }
        assertStable(samples, "home.plan.doneness", tolerance) { $0.doneness }
        assertStable(samples, "home.plan.thickness", tolerance) { $0.thickness }
        assertStable(samples, "setup.primary", tolerance) { $0.primaryAction }

        // The summary sits inside a fixed-height band, but the row itself is
        // centred and its text width tracks the cut's cooking budget (a two-digit
        // minute count is wider than a one-digit one), so only its vertical
        // placement is asserted.
        assertStable(samples, "home.summary", tolerance, horizontal: false) { $0.summary }
    }

    private struct HomeSkeletonSample: LayoutSample {
        let cutTitle: String
        let carousel: CGRect
        let title: CGRect
        let doneness: CGRect
        let thickness: CGRect
        let summary: CGRect
        let primaryAction: CGRect

        var phaseLabel: String { cutTitle }
    }

    private func captureHomeSkeleton(in app: XCUIApplication) -> HomeSkeletonSample {
        HomeSkeletonSample(
            cutTitle: app.staticTexts["home.title"].label,
            carousel: layoutFrame("home.carousel", in: app),
            title: layoutFrame("home.title", in: app),
            doneness: layoutFrame("home.plan.doneness", in: app),
            thickness: layoutFrame("home.plan.thickness", in: app),
            summary: layoutFrame("home.summary", in: app),
            primaryAction: layoutFrame("setup.primary", in: app)
        )
    }

    // MARK: - Layout skeleton probes

    private struct ResultSkeletonSample: LayoutSample {
        let eyebrow: String
        let topControls: CGRect
        let title: CGRect
        let hero: CGRect
        let summary: CGRect
        let primaryAction: CGRect

        var phaseLabel: String { eyebrow }
    }

    private func captureResultSkeleton(in app: XCUIApplication) -> ResultSkeletonSample {
        ResultSkeletonSample(
            eyebrow: app.staticTexts["session.phase.title"].label,
            topControls: layoutFrame("result.topControls", in: app),
            title: layoutFrame("result.title", in: app),
            hero: layoutFrame("result.hero", in: app),
            summary: layoutFrame("result.summary", in: app),
            primaryAction: layoutFrame("result.primaryAction", in: app)
        )
    }

    private struct SessionSkeletonSample: LayoutSample {
        let phaseTitle: String
        let topControls: CGRect
        let hero: CGRect
        let scene: CGRect
        let instruction: CGRect
        let progress: CGRect?
        let telemetry: CGRect?
        let primaryAction: CGRect

        var phaseLabel: String { phaseTitle }
    }

    private func captureSessionSkeleton(in app: XCUIApplication) -> SessionSkeletonSample {
        SessionSkeletonSample(
            phaseTitle: app.staticTexts["session.phase.title"].label,
            topControls: layoutFrame("session.topControls", in: app),
            hero: layoutFrame("session.hero", in: app),
            scene: layoutFrame("session.scene", in: app),
            instruction: layoutFrame("session.instruction", in: app),
            progress: layoutFrameIfPresent("session.progress", in: app),
            telemetry: layoutFrameIfPresent("session.telemetry", in: app),
            primaryAction: layoutFrame("session.primaryAction", in: app)
        )
    }

    /// Queries by identifier across every element type: the slots are exposed as
    /// containers (`.contain`) or combined elements (`.combine`) depending on
    /// what they hold, and the test must not care which.
    private func layoutElement(
        _ identifier: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func layoutFrame(
        _ identifier: String,
        in app: XCUIApplication
    ) -> CGRect {
        let element = layoutElement(identifier, in: app)
        XCTAssertTrue(
            element.waitForExistence(timeout: 3),
            "Missing layout slot \(identifier)"
        )
        return element.frame
    }

    private func layoutFrameIfPresent(
        _ identifier: String,
        in app: XCUIApplication
    ) -> CGRect? {
        let element = layoutElement(identifier, in: app)
        guard element.exists else { return nil }
        let frame = element.frame
        return frame.isEmpty ? nil : frame
    }

    /// A sampled layout state, so one stability assertion can serve the session,
    /// the result and the setup screens.
    private protocol LayoutSample {
        var phaseLabel: String { get }
    }

    /// Every phase that shows this slot must place it at the same place, with
    /// the same size. The tolerance is deliberately tight: the slots have fixed
    /// heights, so any real drift is tens of points, while accessibility frame
    /// rounding is sub-point. Slots a phase legitimately does not show (the rail
    /// during FINISHING, the telemetry during reading entry) are skipped rather
    /// than asserted to be at zero.
    ///
    /// `horizontal` is for a slot whose width follows its content — a centred row
    /// whose text gets longer really does shift its midpoint, and asserting
    /// otherwise would pin a layout that should be free to breathe. Its vertical
    /// placement is still asserted.
    private func assertStable<S: LayoutSample>(
        _ samples: [S],
        _ name: String,
        _ tolerance: CGFloat,
        horizontal: Bool = true,
        _ frame: (S) -> CGRect?
    ) {
        let present = samples.compactMap { sample in
            frame(sample).map { (sample.phaseLabel, $0) }
        }

        guard let first = present.first else {
            XCTFail("\(name) was never measurable")
            return
        }

        for (phase, rect) in present {
            XCTAssertEqual(
                rect.minY,
                first.1.minY,
                accuracy: tolerance,
                "\(name) moved vertically in \(phase)"
            )
            if horizontal {
                XCTAssertEqual(
                    rect.midX,
                    first.1.midX,
                    accuracy: tolerance,
                    "\(name) moved horizontally in \(phase)"
                )
            }
            XCTAssertEqual(
                rect.height,
                first.1.height,
                accuracy: tolerance,
                "\(name) changed height in \(phase)"
            )
        }
    }

    /// The hero band's centre must not move, and its text must stay inside its
    /// band (never reaching the artwork below it). The band's own bounds are
    /// pinned by the `session.topControls` and `session.scene` assertions above.
    private func assertCentred(
        _ samples: [SessionSkeletonSample],
        _ name: String,
        _ tolerance: CGFloat
    ) {
        guard let first = samples.first else {
            XCTFail("\(name) was never measurable")
            return
        }

        for sample in samples {
            XCTAssertEqual(
                sample.hero.midY,
                first.hero.midY,
                accuracy: tolerance,
                "\(name) centre moved vertically in \(sample.phaseTitle)"
            )
            XCTAssertEqual(
                sample.hero.midX,
                first.hero.midX,
                accuracy: tolerance,
                "\(name) centre moved horizontally in \(sample.phaseTitle)"
            )
            XCTAssertLessThanOrEqual(
                sample.hero.maxY,
                sample.scene.minY + tolerance,
                "\(name) grew past its band into the scene in \(sample.phaseTitle)"
            )
        }
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
        tuningLab: Bool = false,
        layoutProbes: Bool = false
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
        // Geometry anchors for the two decorative slots. Only the layout
        // regression test passes this, so production VoiceOver never announces
        // the stage photograph or the progress rail.
        if layoutProbes { app.launchArguments.append("-layoutProbes") }
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
