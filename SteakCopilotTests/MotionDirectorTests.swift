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

    func testHandlingMotionCannotMutateCookingSession() {
        let director = MotionDirector(
            haptics: HapticService(isEnabled: false),
            sounds: SoundService(isEnabled: false)
        )
        let session = CookingSession.fixture(
            phase: .searFirst,
            phaseStartedAt: Date(timeIntervalSince1970: 1),
            phaseDuration: 60
        )

        director.handle(.flipNow(style: .hero))

        XCTAssertEqual(session.phase, .searFirst)
        XCTAssertEqual(session.phaseDuration, 60)
    }
}
