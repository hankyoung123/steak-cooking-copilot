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

        // Drive into the searing loop so the new status readout and the flip
        // countdown are exercised in Chinese as well as English.
        app.buttons["prep.dry"].tap()
        app.buttons["prep.salt"].tap()
        tapWhenEnabled(app.buttons["prep.continue"], timeout: 3)
        XCTAssertTrue(app.buttons["heat.ready"].waitForExistence(timeout: 3))
        app.buttons["heat.ready"].tap()
        waitForLabelPrefix(
            "煎制",
            on: app.staticTexts["session.phase.title"],
            timeout: 3
        )

        let telemetry = layoutElement("session.telemetry", in: app)
        XCTAssertTrue(telemetry.waitForExistence(timeout: 3))
        XCTAssertTrue(
            telemetry.label.contains("估算"),
            "status readout should be labelled in Chinese, got \(telemetry.label)"
        )
        XCTAssertTrue(telemetry.label.contains("建议"), telemetry.label)

        let instruction = layoutElement("session.instruction", in: app)
        XCTAssertTrue(instruction.exists)
        XCTAssertTrue(
            instruction.label.contains("剩余翻面"),
            "flip countdown should be in Chinese, got \(instruction.label)"
        )
        attachScreenshot(named: "searing-zh-Hans", app: app)
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

    /// The app no longer offers a probe reading, so this is simply the cook flow.
    func testCaseARibeyeCompletesTheEstimatedFlow() {
        let app = launchApp()
        startCooking(app)

        let evidence = advanceToFinishing(app)

        XCTAssertGreaterThanOrEqual(evidence.flipCount, 2)
        XCTAssertTrue(evidence.sawButter)
        XCTAssertTrue(evidence.sawTakeOut)
        let reachedFinishingOrResult = app.staticTexts["FINISHING"].waitForExistence(timeout: 2)
            || app.buttons["ready.continue"].waitForExistence(timeout: 4)
        XCTAssertTrue(reachedFinishingOrResult)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+\\.[0-9]°C")).firstMatch.exists)
        attachScreenshot(named: "case-a-estimated-finish", app: app)

        finishReadyFeedbackFlow(app)
    }

    func testCaseBStripUsesFatCapAndTakesOut() {
        // The "watch it happen" scale, not `-fastCook`: a 4cm strip has a 1.2s
        // fat-cap window at the fast scale, which is the same order as one
        // XCUITest query-plus-tap, so which actions the walk managed to witness
        // depended on how loaded the host was.
        let app = launchApp(fastCook: false, visualCook: true)
        app.buttons["home.nextCut"].tap()
        app.buttons["home.settings"].tap()
        app.sliders["setup.thickness"].adjust(toNormalizedSliderPosition: 0.67)
        app.buttons["settings.save"].tap()
        startCooking(app)

        var flipCount = 0
        var sawFatCap = false
        var sawButter = false
        var sawTakeOut = false

        // Confirms until the steak is out. TAKE OUT ends the in-pan journey, so
        // the loop stops on the FINISHING phase rather than on a step count.
        for _ in 0..<30 {
            if app.staticTexts["FINISHING"].exists { break }

            // The fat cap is read from the flow counter rather than from the
            // button label. The counter advances when the app *records* the
            // milestone, so it cannot go stale between the query and the tap the
            // way a label can at the late-stage transition. Strip's route is
            // 01 sear · 02 flip · 03 fat cap · 04 butter · 05 baste · 06 take out.
            let step = app.staticTexts["session.step"]
            if step.exists, step.label.hasPrefix("03 / ") {
                sawFatCap = true
            }

            let confirm = app.buttons["cook.confirm"]
            XCTAssertTrue(confirm.waitForExistence(timeout: 5))
            let label = confirm.label
            flipCount += label == "Flipped" ? 1 : 0
            sawButter = sawButter || label == "Butter added"
            sawTakeOut = sawTakeOut || label == "Steak is out"
            tapWhenEnabled(confirm, timeout: 15)
        }

        XCTAssertGreaterThanOrEqual(flipCount, 2)
        XCTAssertTrue(sawFatCap, "Strip must stand the fat cap up")
        XCTAssertTrue(sawButter)
        XCTAssertTrue(sawTakeOut, "The journey must end with TAKE OUT")
        XCTAssertTrue(
            app.staticTexts["FINISHING"].waitForExistence(timeout: 4),
            "Taking the steak out should hand over to the rest"
        )
    }

    func testCaseCTenderloinMediumSkipsFatCap() {
        let app = launchApp()
        app.buttons["home.nextCut"].tap()
        app.buttons["home.nextCut"].tap()
        app.buttons["home.settings"].tap()
        app.buttons["setup.doneness.medium"].tap()
        app.buttons["settings.save"].tap()
        startCooking(app)

        let evidence = advanceToFinishing(app)

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
    /// Regression: one flip is enough to have seared both faces, so the stage
    /// must switch to the seared composition and must not fall back to the raw
    /// one for the rest of the searing loop.
    ///
    /// Runs at the real time scale, because the interesting window (the first
    /// searing wait and the loop that follows it) is one flip interval long —
    /// 30s here, against 2.4s under `-visualCook`, which is too short to stand
    /// on either side of the transition.
    ///
    /// The stage artwork is exposed to accessibility as images whose labels are
    /// the asset names, so the composition is observable from the outside.
    func testStageShowsTheSearedCompositionAfterTheFirstFlip() {
        let app = launchApp(fastCook: false, visualCook: false)
        startCooking(app)

        // Before the first flip the visible face is raw.
        let raw = stageImage(prefix: "CookSearBackground", in: app)
        XCTAssertTrue(
            raw.waitForExistence(timeout: 8),
            "Expected the raw steak first, saw: \(stageImageLabels(in: app))"
        )
        XCTAssertFalse(
            stageImage(prefix: "CookSearedBackground", in: app).exists,
            "Nothing is seared on both faces before the first flip"
        )
        settleArtwork(after: 0.4)
        attachScreenshot(named: "stage-raw-before-first-flip", app: app)

        // Flip once.
        let confirm = app.buttons["cook.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 40))
        tapWhenEnabled(confirm, timeout: 20)

        // After it, the seared composition is the only correct one…
        XCTAssertTrue(
            stageImage(prefix: "CookSearedBackground", in: app)
                .waitForExistence(timeout: 10),
            "After the first flip the stage must show the seared steak, saw: "
                + stageImageLabels(in: app)
        )
        settleArtwork(after: 0.4)
        attachScreenshot(named: "stage-seared-after-first-flip", app: app)

        // …and the raw compositions must be gone for the rest of the loop.
        XCTAssertFalse(
            stageImage(prefix: "CookSearBackground", in: app).exists,
            "The stage went back to the raw steak after the first flip"
        )
        XCTAssertFalse(
            stageImage(prefix: "CookFlipBackground", in: app).exists,
            "The tongs photo shows the raw face and only fits the first flip"
        )
    }

    /// Stage artwork by asset name. The images carry the asset name as their
    /// accessibility *label*, so they are matched by label, not by identifier.
    private func stageImage(
        prefix: String,
        in app: XCUIApplication
    ) -> XCUIElement {
        app.images.matching(
            NSPredicate(format: "label BEGINSWITH %@", prefix)
        ).firstMatch
    }

    private func stageImageLabels(in app: XCUIApplication) -> String {
        app.images.allElementsBoundByIndex
            .map(\.label)
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

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
            let confirm = app.buttons["cook.confirm"]
            if !confirm.waitForExistence(timeout: 5) {
                // The cook can reach the rest between the check above and this
                // wait, which takes the confirm button away. That is the natural
                // end of the walk, not a failure.
                if app.staticTexts["FINISHING"].exists { break }
                XCTFail("Expected the next cook action or the finishing phase")
                break
            }

            switch confirm.label {
            case "Flipped" where !capturedFlip:
                settleArtwork()
                attachScreenshot(named: "prototype-flip", app: app)
                capturedFlip = true
            case "Butter added" where !capturedBaste:
                settleArtwork()
                attachScreenshot(named: "prototype-baste", app: app)
                capturedBaste = true
            // With no probe reading, the "check" photograph belongs to the
            // take-out prompt: it is the last cook action before the rest.
            case "Steak is out" where !capturedCheck:
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
                        "Finishing", "Thermal", "Notifications", "Motion",
                        "Override JSON"] {
            XCTAssertTrue(
                scrollToVisible(section, in: app),
                "Tuning Lab is missing the \(section) section"
            )
        }

        // The Override JSON section exposes every import/export affordance.
        // The form renders lazily, so each control has to be scrolled to before
        // it exists in the tree.
        for identifier in ["tuningLab.export", "tuningLab.copy",
                           "tuningLab.importPasted", "tuningLab.importFile"] {
            XCTAssertTrue(
                scrollToVisibleButton(identifier, in: app),
                "Tuning Lab is missing \(identifier)"
            )
        }

        // Export populates the editor with a versioned document.
        scrollToVisibleButton("tuningLab.export", in: app)
        app.buttons["tuningLab.export"].tap()
        let editor = app.textViews["tuningLab.importText"]
        XCTAssertTrue(
            scrollToVisible(editor, in: app) || editor.waitForExistence(timeout: 3)
        )
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

            let confirm = app.buttons["cook.confirm"]
            if confirm.waitForExistence(timeout: 4) {
                tapWhenEnabled(confirm, timeout: 20)
                continue
            }

            XCTFail("Expected the next cook action or the finishing phase")
            break
        }

        XCTAssertGreaterThanOrEqual(
            Set(samples.map(\.phaseTitle)).count,
            4,
            "The walk should have sampled several distinct cooking phases, "
                + "saw \(Set(samples.map(\.phaseTitle)).sorted())"
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
        // The instruction band gains and loses its supporting line — prep and
        // heat have one, and so does the searing loop now that it carries the
        // flip count — so the band's top edge is what has to hold, not the height
        // of the text inside it.
        assertStable(samples, "session.instruction", tolerance, height: false) { $0.instruction }
        assertStable(samples, "session.primaryAction", tolerance) { $0.primaryAction }

        // The progress rail is present in every phase except FINISHING (where
        // carryover heat has no measurable progress), and the telemetry is
        // swapped out for the reading entry and then the finishing card. Both
        // must hold one frame in every phase that shows them.
        assertStable(samples, "session.progress (while shown)", tolerance) { $0.progress }
        assertStable(samples, "session.telemetry (while shown)", tolerance) { $0.telemetry }

        // The flow counter is a strip route, so it runs 01 / 06 … 06 / 06 and is
        // never allowed to walk backwards — the timing estimate sends the session
        // back into the searing loop after BASTE.
        let counted = samples.compactMap(\.step)
        XCTAssertFalse(counted.isEmpty, "The flow counter was never displayed")
        XCTAssertEqual(
            counted,
            counted.sorted(),
            "The flow counter must be monotonic, saw \(counted)"
        )
        for sample in samples {
            guard let label = sample.stepLabel else { continue }
            XCTAssertEqual(
                sample.stepLabel?.hasSuffix("/ 06"),
                true,
                "Strip is a six-step route but showed \(label) in \(sample.phaseTitle)"
            )
        }
        XCTAssertNil(
            samples.first { $0.phaseTitle == "FINISHING" }?.stepLabel,
            "FINISHING is a rest, not the next cook step, so it must show no counter"
        )
        XCTAssertEqual(
            counted.max(),
            6,
            "The walk should have reached the final cook step, saw \(counted)"
        )

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

    // MARK: - App settings

    /// The gear opens app-wide settings, not the per-cook sheet it used to
    /// duplicate.
    func testGearOpensAppSettingsRatherThanTheCutSheet() {
        let app = launchApp()

        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.buttons["setup.doneness.mediumRare"].exists,
            "the gear must not open this cook's doneness and thickness"
        )

        // The bottom entry point still edits this cook.
        app.buttons["appSettings.close"].tap()
        XCTAssertTrue(app.buttons["home.settings"].waitForExistence(timeout: 3))
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.buttons["setup.doneness.mediumRare"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["appSettings.close"].exists)
    }

    func testHidingACutTakesItOffTheHomeScreen() {
        let app = launchApp()

        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        layoutElement("appSettings.cut.strip", in: app).tap()
        attachScreenshot(named: "app-settings-cuts", app: app)
        app.buttons["appSettings.close"].tap()

        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.buttons["setup.cut.strip"].exists,
            "a hidden cut must not be in the carousel at all"
        )
        XCTAssertTrue(app.buttons["setup.cut.ribeye"].exists)
        XCTAssertTrue(app.buttons["setup.cut.tenderloin"].exists)

        // Its neighbour is still reachable, and it is not the hidden one.
        app.buttons["home.nextCut"].tap()
        XCTAssertTrue(app.buttons["setup.cut.tenderloin"].waitForExistence(timeout: 3))

        // And it comes back.
        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        layoutElement("appSettings.cut.strip", in: app).tap()
        app.buttons["appSettings.close"].tap()
        XCTAssertTrue(app.buttons["setup.cut.strip"].waitForExistence(timeout: 3))
    }

    /// The screen can never end up with nothing to show.
    func testTheLastVisibleCutCannotBeHidden() {
        let app = launchApp()

        let titleBefore = layoutFrame("home.title", in: app)

        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        layoutElement("appSettings.cut.strip", in: app).tap()
        layoutElement("appSettings.cut.tenderloin", in: app).tap()

        let last = layoutElement("appSettings.cut.ribeye", in: app)
        XCTAssertFalse(last.isEnabled, "the last visible cut must not be hideable")
        XCTAssertTrue(
            app.staticTexts["Keep at least one cut on the home screen."].exists,
            "the reason has to be visible, not a control that silently does nothing"
        )
        attachScreenshot(named: "app-settings-last-cut", app: app)

        app.buttons["appSettings.close"].tap()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["setup.cut.ribeye"].exists)
        XCTAssertFalse(
            app.buttons["home.nextCut"].exists,
            "with one cut there is nothing to navigate, so the arrows are gone"
        )

        // The navigation row keeps its height even when it is empty, so dropping
        // to a single cut does not shift the title, the parameters or the CTA.
        let titleAfter = layoutFrame("home.title", in: app)
        XCTAssertEqual(
            titleAfter.minY,
            titleBefore.minY,
            accuracy: 2,
            "an empty navigation row must still reserve its height"
        )
        XCTAssertEqual(titleAfter.height, titleBefore.height, accuracy: 2)

        attachScreenshot(named: "home-single-cut", app: app)
    }

    /// Every app-wide group is on the settings screen.
    func testSettingsCoversEveryAppWideGroup() {
        let app = launchApp()

        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))

        for section in ["CUTS ON HOME", "REMINDERS", "SOUND & HAPTICS",
                        "LEARNED ADJUSTMENTS", "ABOUT"] {
            XCTAssertTrue(
                scrollToVisible(section, in: app),
                "Settings is missing the \(section) section"
            )
        }

        XCTAssertTrue(layoutElement("appSettings.reminders", in: app).exists)
        XCTAssertTrue(layoutElement("appSettings.sound", in: app).exists)
        XCTAssertTrue(layoutElement("appSettings.haptics", in: app).exists)
        XCTAssertTrue(
            layoutElement("appSettings.version", in: app).exists,
            "About should show a version"
        )
        XCTAssertTrue(
            scrollToVisible(
                layoutElement("appSettings.adjustments.empty", in: app),
                in: app
            ),
            "with no feedback yet there is nothing learned to show"
        )
        attachScreenshot(named: "app-settings-full", app: app)
    }

    /// The switches are preferences, not session state: they have to survive a
    /// relaunch.
    func testFeedbackSwitchSurvivesARelaunch() {
        let app = launchApp()

        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        layoutElement("appSettings.sound", in: app).tap()
        app.buttons["appSettings.close"].tap()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 3))

        // Relaunch without the reset argument, so the stored value is read back.
        app.terminate()
        app.launchArguments = app.launchArguments.filter { $0 != "-resetPreferences" }
        app.launch()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 5))

        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        XCTAssertEqual(
            layoutElement("appSettings.sound", in: app).value as? String,
            "0",
            "the sound switch should still be off"
        )
        XCTAssertEqual(
            layoutElement("appSettings.haptics", in: app).value as? String,
            "1",
            "and the other switch should be untouched"
        )
    }

    /// The gap this whole screen was built for: what the app has learned is now
    /// visible, and can be undone.
    func testLearnedAdjustmentIsShownAndCanBeReset() {
        let app = launchApp()

        // Skip to the result screen, then answer the feedback badly so there is
        // something to learn.
        app.buttons["setup.primary"].tap()
        for _ in 0..<4 { confirmSkip(in: app) }
        XCTAssertTrue(app.buttons["ready.continue"].waitForExistence(timeout: 5))
        app.buttons["ready.continue"].tap()
        XCTAssertTrue(app.buttons["eat.feedback"].waitForExistence(timeout: 3))
        app.buttons["eat.feedback"].tap()

        let save = app.buttons["feedback.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        let tooDone = layoutElement("feedback.doneness.2", in: app)
        XCTAssertTrue(scrollToVisible(tooDone, in: app))
        tooDone.tap()
        app.buttons["feedback.save"].tap()
        XCTAssertTrue(app.buttons["setup.primary"].waitForExistence(timeout: 5))

        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            scrollToVisibleButton("appSettings.resetAdjustments", in: app),
            "an overshot cook should have taught the app something"
        )
        XCTAssertFalse(
            layoutElement("appSettings.adjustments.empty", in: app).exists,
            "the empty state should have given way to the list"
        )
        // Guard the assertion the tap depends on: a row left under the sticky
        // Save bar is still reported as hittable, and tapping it would press the
        // bar instead — which dismisses the sheet.
        let reset = app.buttons["appSettings.resetAdjustments"]
        XCTAssertTrue(reset.isHittable, "the reset action must be reachable")
        attachScreenshot(named: "app-settings-adjustments", app: app)
        reset.tap()
        attachScreenshot(named: "app-settings-reset-tapped", app: app)
        XCTAssertTrue(app.buttons["Reset"].waitForExistence(timeout: 3))
        app.buttons["Reset"].tap()
        app.buttons["appSettings.close"].tap()

        // Reopen: the list is empty again.
        XCTAssertTrue(app.buttons["home.topSettings"].waitForExistence(timeout: 3))
        app.buttons["home.topSettings"].tap()
        XCTAssertTrue(app.buttons["appSettings.close"].waitForExistence(timeout: 3))
        XCTAssertTrue(
            scrollToVisible(
                layoutElement("appSettings.adjustments.empty", in: app),
                in: app
            ),
            "resetting should forget everything it had learned"
        )
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
        /// The flow counter as displayed, e.g. "03 / 06"; `nil` when the chrome
        /// hides it because the in-pan journey is over.
        let stepLabel: String?
        let topControls: CGRect
        let hero: CGRect
        let scene: CGRect
        let instruction: CGRect
        let progress: CGRect?
        let telemetry: CGRect?
        let primaryAction: CGRect

        var phaseLabel: String { phaseTitle }

        /// The leading number of the counter.
        var step: Int? {
            stepLabel
                .flatMap { $0.split(separator: "/").first }
                .flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
    }

    private func captureSessionSkeleton(in app: XCUIApplication) -> SessionSkeletonSample {
        SessionSkeletonSample(
            phaseTitle: app.staticTexts["session.phase.title"].label,
            stepLabel: app.staticTexts["session.step"].exists
                ? app.staticTexts["session.step"].label
                : nil,
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
    ///
    /// `height` is for a band whose *content* gains or loses a line. The band
    /// itself is a fixed slot, and its content is top aligned, so the thing that
    /// must hold still is the top edge; the combined element's box simply reports
    /// how many lines are showing.
    private func assertStable<S: LayoutSample>(
        _ samples: [S],
        _ name: String,
        _ tolerance: CGFloat,
        horizontal: Bool = true,
        height: Bool = true,
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
            if height {
                XCTAssertEqual(
                    rect.height,
                    first.1.height,
                    accuracy: tolerance,
                    "\(name) changed height in \(phase)"
                )
            }
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
            // Learned adjustments outlive a session by design, so without this a
            // run would inherit whatever an earlier run taught the app.
            "-resetCalibrations",
            // App preferences persist by design, so every test starts from the
            // default (all cuts visible) rather than from whatever a previous
            // run left behind.
            "-resetPreferences",
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

    /// Confirms whatever the app asks for until the steak is resting.
    ///
    /// There is no reading entry point, so nothing has to be chosen along the
    /// way; the cook runs on the timing estimate.
    private func advanceToFinishing(
        _ app: XCUIApplication
    ) -> (
        flipCount: Int,
        sawFatCap: Bool,
        sawButter: Bool,
        sawTakeOut: Bool
    ) {
        var flipCount = 0
        var sawFatCap = false
        var sawButter = false
        var sawTakeOut = false

        for _ in 0..<30 {
            if app.staticTexts["FINISHING"].exists { break }
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

        return (flipCount, sawFatCap, sawButter, sawTakeOut)
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
