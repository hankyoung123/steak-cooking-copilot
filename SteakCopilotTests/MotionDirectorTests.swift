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

// MARK: - Stage motion response mapping

@MainActor
final class StageMotionResponseTests: XCTestCase {
    func testReduceMotionDisablesAllStageMotion() {
        let visuals: [MotionVisual] = [
            .heroFlip, .compactFlip, .pull, .attention(seconds: 3), .ready, .none
        ]
        for visual in visuals {
            XCTAssertEqual(
                StageMotionResponse(visual: visual, reduceMotion: true),
                .none
            )
        }
    }

    func testFlipAndPullMapToDistinctStageMotion() {
        XCTAssertEqual(
            StageMotionResponse(visual: .heroFlip, reduceMotion: false),
            .heroFlip
        )
        XCTAssertEqual(
            StageMotionResponse(visual: .compactFlip, reduceMotion: false),
            .compactFlip
        )
        XCTAssertEqual(
            StageMotionResponse(visual: .pull, reduceMotion: false),
            .pull
        )
        XCTAssertEqual(
            StageMotionResponse(visual: .addButter, reduceMotion: false),
            .none
        )
    }
}

// MARK: - Live Activity end semantics

final class LiveActivityEndStateTests: XCTestCase {
    func testFinishedEndStateCelebrates() {
        let state = SteakActivityAttributes.ContentState.endState(for: .finished)

        XCTAssertEqual(state.phaseTitle, String(localized: "READY"))
        XCTAssertEqual(state.actionTitle, String(localized: "TIME TO EAT"))
    }

    func testCancelledEndStateNeverDisplaysReadyOrTimeToEat() {
        let finished = SteakActivityAttributes.ContentState.endState(for: .finished)
        let cancelled = SteakActivityAttributes.ContentState.endState(for: .cancelled)

        XCTAssertNotEqual(cancelled.phaseTitle, finished.phaseTitle)
        XCTAssertNotEqual(cancelled.actionTitle, finished.actionTitle)
        XCTAssertNotEqual(cancelled.phaseTitle, String(localized: "READY"))
        XCTAssertNotEqual(cancelled.actionTitle, String(localized: "TIME TO EAT"))
        XCTAssertEqual(cancelled.phaseTitle, String(localized: "SESSION ENDED"))
        XCTAssertEqual(cancelled.actionTitle, String(localized: "CANCELLED"))
    }

    func testActivityAttributesCarryStableSessionIdentity() {
        let sessionID = UUID()
        let attributes = SteakActivityAttributes(sessionID: sessionID)

        XCTAssertEqual(attributes.sessionID, sessionID)
    }
}
