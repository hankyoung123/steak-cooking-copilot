import XCTest
@testable import SteakCopilot

final class CookingEngineTests: XCTestCase {
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
                level.targetTemperatureC,
                level.pullTemperatureC
            )
        }

        for (lower, higher) in zip(levels, levels.dropFirst()) {
            XCTAssertGreaterThan(
                higher.targetTemperatureC,
                lower.targetTemperatureC
            )
            XCTAssertGreaterThan(
                higher.pullTemperatureC,
                lower.pullTemperatureC
            )
            XCTAssertGreaterThan(
                higher.cookingBudgetFactor,
                lower.cookingBudgetFactor
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

        XCTAssertFalse(session.configuration.cut.profile.needsFatCap)
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

        XCTAssertTrue(session.configuration.cut.profile.needsFatCap)
        XCTAssertEqual(guidance.currentAction, .standFatCap)
    }

    func testManualTemperatureAtPullThresholdImmediatelyRequestsTakeOut() {
        let start = Date(timeIntervalSince1970: 40_000)
        var session = CookingSession.fixture(
            phase: .checkTemperature,
            phaseStartedAt: start,
            nextActionAt: nil
        )
        session.lastManualTemperatureC = Doneness.mediumRare.pullTemperatureC
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
            Doneness.mediumRare.targetTemperatureC,
            Doneness.mediumRare.pullTemperatureC
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
}
