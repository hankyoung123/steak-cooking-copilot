import XCTest
@testable import SteakCopilot

@MainActor
final class MotionDirectorTests: XCTestCase {
    func testHeroFlipMapsToActionMotionAndHeavyImpact() {
        let cue = MotionDirector.cue(for: .flipNow(style: .hero))

        XCTAssertEqual(cue.visual, .heroFlip)
        XCTAssertEqual(cue.preset, .action)
        XCTAssertEqual(cue.haptic, .heavyImpact)
    }

    func testLaterFlipMapsToCompactMotion() {
        let cue = MotionDirector.cue(for: .flipNow(style: .compact))

        XCTAssertEqual(cue.visual, .compactFlip)
        XCTAssertEqual(cue.preset, .emphasis)
    }

    func testReadyHasDistinctCompletionFeedback() {
        let cue = MotionDirector.cue(for: .ready)

        XCTAssertEqual(cue.visual, .ready)
        XCTAssertEqual(cue.haptic, .success)
        XCTAssertEqual(cue.sound, .ready)
    }

    func testTakeOutUsesThePullVisualAndUrgentFeedback() {
        let cue = MotionDirector.cue(for: .pullNow)

        XCTAssertEqual(cue.visual, .pull)
        XCTAssertEqual(cue.preset, .action)
        XCTAssertEqual(cue.haptic, .heavyImpact)
        XCTAssertEqual(cue.sound, .pull)
    }

    func testCountdownOnlyTapsForLastThreeSeconds() {
        XCTAssertEqual(
            MotionDirector.cue(for: .flipApproaching(seconds: 5)).haptic,
            .none
        )
        XCTAssertEqual(
            MotionDirector.cue(for: .flipApproaching(seconds: 3)).haptic,
            .lightImpact
        )
    }

}
