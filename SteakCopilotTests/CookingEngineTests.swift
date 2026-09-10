import XCTest
@testable import SteakCopilot

final class CookingEngineTests: XCTestCase {
    /// Production parameters generated from Config/production.yaml.
    private let tuning = AppTuning.production

    private let engine = CookingEngine()

    func testDonenessOffersFiveOrderedLevels() {
        XCTAssertEqual(
            Doneness.allCases,
            [.rare, .mediumRare, .medium, .mediumWell, .wellDone]
        )
    }

    func testDonenessTemperaturesAndCookingBudgetsIncreaseMonotonically() {
        let levels = Doneness.allCases

        for level in levels {
            XCTAssertGreaterThan(
                tuning.doneness[level].targetTemperatureC,
                tuning.doneness[level].pullTemperatureC
            )
        }

        for (lower, higher) in zip(levels, levels.dropFirst()) {
            XCTAssertGreaterThan(
                tuning.doneness[higher].targetTemperatureC,
                tuning.doneness[lower].targetTemperatureC
            )
            XCTAssertGreaterThan(
                tuning.doneness[higher].pullTemperatureC,
                tuning.doneness[lower].pullTemperatureC
            )
            XCTAssertGreaterThan(
                tuning.doneness[higher].cookingBudgetFactor,
                tuning.doneness[lower].cookingBudgetFactor
            )
        }
    }

    func testStandardSteakUsesThirtySecondFlipCycle() {
        let configuration = SteakConfiguration(
            cut: .ribeye,
            thicknessCM: 3,
            doneness: .mediumRare
        )

        XCTAssertEqual(engine.flipInterval(for: configuration), 30, accuracy: 0.001)
    }

    func testFlipGuidanceUsesAbsoluteNextActionDate() {
        let start = Date(timeIntervalSince1970: 10_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(30)
        )
        session.startedAt = start

        let before = engine.guidance(for: session, at: start.addingTimeInterval(24.9))
        let attention = engine.guidance(for: session, at: start.addingTimeInterval(25))
        let now = engine.guidance(for: session, at: start.addingTimeInterval(30))

        XCTAssertEqual(before.remainingTime, 5.1, accuracy: 0.001)
        XCTAssertNil(before.event)
        XCTAssertEqual(attention.event, .flipApproaching(seconds: 5))
        XCTAssertEqual(now.currentAction, .flip)
        XCTAssertEqual(now.event, .flipNow(style: .hero))
    }

    func testTenderloinLateSearSkipsFatCap() {
        let start = Date(timeIntervalSince1970: 20_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(300)
        )
        session.configuration = .init(
            cut: .tenderloin,
            thicknessCM: 3,
            doneness: .medium
        )
        session.startedAt = start

        let guidance = engine.guidance(
            for: session,
            at: start.addingTimeInterval(300)
        )

        XCTAssertFalse(tuning.cuts[session.configuration.cut].needsFatCap)
        XCTAssertEqual(guidance.currentAction, .addButter)
    }

    func testStripLateSearRequestsFatCap() {
        let start = Date(timeIntervalSince1970: 30_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(400)
        )
        session.configuration = .init(
            cut: .strip,
            thicknessCM: 4,
            doneness: .mediumRare
        )
        session.startedAt = start

        let guidance = engine.guidance(
            for: session,
            at: start.addingTimeInterval(400)
        )

        XCTAssertTrue(tuning.cuts[session.configuration.cut].needsFatCap)
        XCTAssertEqual(guidance.currentAction, .standFatCap)
    }

    func testManualTemperatureAtPullThresholdImmediatelyRequestsTakeOut() {
        let start = Date(timeIntervalSince1970: 40_000)
        var session = CookingSession.fixture(
            phase: .checkTemperature,
            phaseStartedAt: start,
            nextActionAt: nil
        )
        session.lastManualTemperatureC = tuning.doneness[.mediumRare].pullTemperatureC
        session.lastManualTemperatureAt = start

        let guidance = engine.guidance(for: session, at: start)

        XCTAssertEqual(guidance.pullRecommendation, .takeOut)
        XCTAssertEqual(guidance.currentAction, .takeOut)
        XCTAssertEqual(guidance.event, .pullNow)
    }

    func testNoThermometerNeverCreatesTemperatureReading() {
        let start = Date(timeIntervalSince1970: 50_000)
        let session = CookingSession.fixture(
            phase: .finishing,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(210)
        )

        let guidance = engine.guidance(
            for: session,
            at: start.addingTimeInterval(60)
        )

        XCTAssertNil(guidance.lastManualTemperatureC)
        XCTAssertGreaterThan(guidance.finishingEstimate.upperBound, guidance.finishingEstimate.lowerBound)
        XCTAssertNotEqual(guidance.finishingEstimate.upperBound, 240)
    }

    func testTargetAndPullTemperaturesAreSeparate() {
        XCTAssertGreaterThan(
            tuning.doneness[.mediumRare].targetTemperatureC,
            tuning.doneness[.mediumRare].pullTemperatureC
        )
    }

    func testThickerSteakProducesLargerEstimatedCookingBudget() {
        let thin = engine.profile(
            for: .init(cut: .strip, thicknessCM: 2, doneness: .mediumRare),
            calibration: .neutral
        )
        let thick = engine.profile(
            for: .init(cut: .strip, thicknessCM: 4, doneness: .mediumRare),
            calibration: .neutral
        )

        XCTAssertGreaterThan(thick.estimatedCookingBudget, thin.estimatedCookingBudget)
    }

    // MARK: - Manual temperature authority

    func testManualTemperatureBelowPullKeepsCooking() {
        let start = Date(timeIntervalSince1970: 60_000)
        var session = CookingSession.fixture(
            phase: .checkTemperature,
            phaseStartedAt: start,
            nextActionAt: nil
        )
        session.lastManualTemperatureC = tuning.doneness[.mediumRare].pullTemperatureC - 1
        session.lastManualTemperatureAt = start

        let guidance = engine.guidance(for: session, at: start)

        XCTAssertEqual(guidance.pullRecommendation, .keepCooking)
        XCTAssertEqual(guidance.currentAction, .checkTemperature)
        XCTAssertEqual(guidance.event, .checkTemperature)
    }

    func testManualTemperatureAbovePullRequestsTakeOut() {
        let start = Date(timeIntervalSince1970: 61_000)
        var session = CookingSession.fixture(
            phase: .checkTemperature,
            phaseStartedAt: start,
            nextActionAt: nil
        )
        session.lastManualTemperatureC = tuning.doneness[.mediumRare].pullTemperatureC + 0.5
        session.lastManualTemperatureAt = start

        let guidance = engine.guidance(for: session, at: start)

        XCTAssertEqual(guidance.pullRecommendation, .takeOut)
        XCTAssertEqual(guidance.currentAction, .takeOut)
        XCTAssertEqual(guidance.event, .pullNow)
    }

    func testManualTemperatureBelowPullNeverTakesOutBeforeBoundary() {
        let start = Date(timeIntervalSince1970: 62_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(500)
        )
        session.startedAt = start
        session.lastManualTemperatureC = tuning.doneness[.mediumRare].pullTemperatureC - 3
        session.lastManualTemperatureAt = start.addingTimeInterval(100)

        let guidance = engine.guidance(for: session, at: start.addingTimeInterval(101))

        XCTAssertEqual(guidance.pullRecommendation, .keepCooking)
        XCTAssertNotEqual(guidance.currentAction, .takeOut)
    }

    // MARK: - No-thermometer fallback

    private func searSession(
        startingAt start: Date,
        configuration: SteakConfiguration = .init(),
        nextActionAt: Date,
        thermometerUnavailable: Bool = false,
        thermometerUnavailableAt: Date? = nil
    ) -> CookingSession {
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: nextActionAt
        )
        session.startedAt = start
        session.configuration = configuration
        if thermometerUnavailable {
            session.thermometerUnavailableAt = thermometerUnavailableAt ?? start
        }
        return session
    }

    func testNoThermometerFallbackNeverPromptsCheckTemperatureAndTakesOutAtBoundary() {
        let start = Date(timeIntervalSince1970: 63_000)
        let configuration = SteakConfiguration(
            cut: .ribeye,
            thicknessCM: 3,
            doneness: .mediumRare
        )
        let profile = engine.profile(for: configuration, calibration: .neutral)
        let estimatedPullAt = start.addingTimeInterval(profile.estimatedCookingBudget)
        let session = searSession(
            startingAt: start,
            configuration: configuration,
            nextActionAt: start.addingTimeInterval(90),
            thermometerUnavailable: true
        )

        // Mid-cook: flip guidance only, never CHECK TEMP, never a temperature.
        let mid = engine.guidance(for: session, at: start.addingTimeInterval(75))
        XCTAssertEqual(mid.currentAction, .wait)
        XCTAssertEqual(mid.nextAction, .flip)
        XCTAssertNil(mid.lastManualTemperatureC)

        let atFlip = engine.guidance(for: session, at: start.addingTimeInterval(90))
        XCTAssertEqual(atFlip.currentAction, .flip)
        XCTAssertNotEqual(atFlip.currentAction, .checkTemperature)

        // At the estimated pull boundary: TAKE IT OUT.
        let atBoundary = engine.guidance(for: session, at: estimatedPullAt)
        XCTAssertEqual(atBoundary.pullRecommendation, .takeOut)
        XCTAssertEqual(atBoundary.currentAction, .takeOut)
        XCTAssertNil(atBoundary.lastManualTemperatureC)
    }

    func testNoThermometerFallbackDoesNotMeanPullTemperatureReached() {
        let start = Date(timeIntervalSince1970: 64_000)
        let session = searSession(
            startingAt: start,
            nextActionAt: start.addingTimeInterval(30),
            thermometerUnavailable: true,
            thermometerUnavailableAt: start.addingTimeInterval(5)
        )

        let guidance = engine.guidance(for: session, at: start.addingTimeInterval(5))

        XCTAssertEqual(guidance.pullRecommendation, .keepCooking)
        XCTAssertNotEqual(guidance.currentAction, .takeOut)
        XCTAssertNil(guidance.lastManualTemperatureC)
    }

    func testNoThermometerSelectedAfterPullBoundaryIsTakeOut() {
        let start = Date(timeIntervalSince1970: 65_000)
        let profile = engine.profile(
            for: SteakConfiguration(cut: .strip, thicknessCM: 3, doneness: .mediumRare),
            calibration: .neutral
        )
        let estimatedPullAt = start.addingTimeInterval(profile.estimatedCookingBudget)
        let session = searSession(
            startingAt: start,
            nextActionAt: estimatedPullAt,
            thermometerUnavailable: true,
            thermometerUnavailableAt: estimatedPullAt.addingTimeInterval(20)
        )

        let guidance = engine.guidance(
            for: session,
            at: estimatedPullAt.addingTimeInterval(20)
        )

        XCTAssertEqual(guidance.pullRecommendation, .takeOut)
        XCTAssertEqual(guidance.currentAction, .takeOut)
    }

    // MARK: - Calibrated late-stage boundary

    func testLighterCrustCalibrationMovesLateStageLaterAndChangesTransition() {
        let start = Date(timeIntervalSince1970: 66_000)
        let configuration = SteakConfiguration(
            cut: .strip,
            thicknessCM: 3,
            doneness: .mediumRare
        )
        let neutral = engine.profile(for: configuration, calibration: .neutral)
        let light = CookingCalibration(cookingTimeAdjustment: 0, searBias: 8)
        let dark = CookingCalibration(cookingTimeAdjustment: 0, searBias: -8)

        let neutralLate = start.addingTimeInterval(neutral.lateStageDateOffset)
        let lightLate = start.addingTimeInterval(
            engine.profile(for: configuration, calibration: light).lateStageDateOffset
        )
        let darkLate = start.addingTimeInterval(
            engine.profile(for: configuration, calibration: dark).lateStageDateOffset
        )

        // “Crust too light” → later boundary; “too dark” → earlier boundary.
        XCTAssertLessThan(darkLate, neutralLate)
        XCTAssertLessThan(neutralLate, lightLate)

        // At the neutral boundary the lighter-calibrated session is still
        // flipping, while the darker-calibrated one already enters the
        // late stage. This proves the transition TIME changed, not just a
        // stored number.
        let lightSession = searSession(
            startingAt: start,
            configuration: configuration,
            nextActionAt: neutralLate
        )
        let lightGuidance = engine.guidance(
            for: lightSession,
            at: neutralLate,
            calibration: light
        )
        XCTAssertEqual(lightGuidance.currentAction, .flip)

        let darkSession = searSession(
            startingAt: start,
            configuration: configuration,
            nextActionAt: darkLate
        )
        let darkGuidance = engine.guidance(
            for: darkSession,
            at: darkLate,
            calibration: dark
        )
        XCTAssertEqual(darkGuidance.currentAction, .standFatCap)
    }

    // MARK: - Finishing

    func testFinishingGuidanceCarriesOnlyTheManualReading() {
        let start = Date(timeIntervalSince1970: 67_000)
        var session = CookingSession.fixture(
            phase: .finishing,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(240)
        )
        session.lastManualTemperatureC = 52
        session.lastManualTemperatureAt = start

        let guidance = engine.guidance(for: session, at: start.addingTimeInterval(30))

        XCTAssertEqual(guidance.lastManualTemperatureC, 52)
        XCTAssertGreaterThan(
            guidance.finishingEstimate.upperBound,
            guidance.finishingEstimate.lowerBound
        )
        // No synthesized “current” temperature exists in the model: the
        // only measured value is the manual reading, and target/pull are
        // static configuration values.
        XCTAssertEqual(guidance.targetTemperatureC, tuning.doneness[.mediumRare].targetTemperatureC)
        XCTAssertEqual(guidance.pullTemperatureC, tuning.doneness[.mediumRare].pullTemperatureC)
        XCTAssertNotEqual(guidance.lastManualTemperatureC, 54)
    }

    func testFinishingEstimateIsARangeWithoutThermometer() {
        let start = Date(timeIntervalSince1970: 68_000)
        let session = CookingSession.fixture(
            phase: .finishing,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(200)
        )

        let guidance = engine.guidance(for: session, at: start)

        XCTAssertNil(guidance.lastManualTemperatureC)
        XCTAssertGreaterThan(
            guidance.finishingEstimate.upperBound,
            guidance.finishingEstimate.lowerBound
        )
    }

    func testEstimatedPullDateIsAbsoluteAndStable() {
        let start = Date(timeIntervalSince1970: 69_000)
        let session = searSession(
            startingAt: start,
            nextActionAt: start.addingTimeInterval(60),
            thermometerUnavailable: true
        )
        let profile = engine.profile(
            for: session.configuration,
            calibration: .neutral
        )

        XCTAssertEqual(
            engine.estimatedPullDate(for: session, profile: profile),
            start.addingTimeInterval(profile.estimatedCookingBudget)
        )
    }
}
