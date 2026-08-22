import XCTest
@testable import SteakCopilot

final class CookingEngineTests: XCTestCase {
    private let engine = CookingEngine()

    func testThickerSteakProducesLongerCookingProfile() {
        let thin = engine.profile(
            for: .init(cut: .strip, thicknessCM: 2.0, doneness: .mediumRare),
            calibration: .neutral
        )
        let thick = engine.profile(
            for: .init(cut: .strip, thicknessCM: 4.0, doneness: .mediumRare),
            calibration: .neutral
        )

        XCTAssertGreaterThan(thick.totalCookingDuration, thin.totalCookingDuration)
    }

    func testHigherDonenessProducesLongerProfileAndHigherPullTemperature() {
        let rare = engine.profile(
            for: .init(cut: .ribeye, thicknessCM: 3.0, doneness: .rare),
            calibration: .neutral
        )
        let medium = engine.profile(
            for: .init(cut: .ribeye, thicknessCM: 3.0, doneness: .medium),
            calibration: .neutral
        )

        XCTAssertGreaterThan(medium.totalCookingDuration, rare.totalCookingDuration)
        XCTAssertGreaterThan(medium.pullTemperatureC, rare.pullTemperatureC)
    }

    func testRemainingTimeIsDerivedFromAbsoluteDate() {
        let start = Date(timeIntervalSince1970: 10_000)
        let session = CookingSession.fixture(
            phase: .searFirst,
            phaseStartedAt: start,
            phaseDuration: 60
        )

        let guidance = engine.guidance(for: session, at: start.addingTimeInterval(17))

        XCTAssertEqual(guidance.remainingTime, 43, accuracy: 0.001)
    }

    func testFlipAttentionEventStartsAtFiveSeconds() {
        let start = Date(timeIntervalSince1970: 10_000)
        let session = CookingSession.fixture(
            phase: .searFirst,
            phaseStartedAt: start,
            phaseDuration: 60
        )

        let before = engine.guidance(for: session, at: start.addingTimeInterval(54.9))
        let attention = engine.guidance(for: session, at: start.addingTimeInterval(55))
        let now = engine.guidance(for: session, at: start.addingTimeInterval(60))

        XCTAssertNil(before.event)
        XCTAssertEqual(attention.event, .flipApproaching(seconds: 5))
        XCTAssertEqual(now.event, .flipNow(style: .hero))
    }

    func testLaterFlipUsesCompactStyle() {
        let start = Date(timeIntervalSince1970: 20_000)
        var session = CookingSession.fixture(
            phase: .searSecond,
            phaseStartedAt: start,
            phaseDuration: 45
        )
        session.flipCount = 1

        let guidance = engine.guidance(for: session, at: start.addingTimeInterval(45))

        XCTAssertEqual(guidance.event, .flipNow(style: .compact))
    }
}
