import XCTest
@testable import SteakCopilot

@MainActor
final class CookingSessionControllerTests: XCTestCase {
    func testConfirmingFlipStaysInSearAndSchedulesNextAbsoluteFlip() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 10_000))
        let controller = fixture.controller
        let start = fixture.start

        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)

        let firstFlipAt = try! XCTUnwrap(controller.session.nextActionAt)
        controller.refresh(at: firstFlipAt)
        controller.confirmCurrentAction(at: firstFlipAt)

        XCTAssertEqual(controller.session.phase, .sear)
        XCTAssertEqual(controller.session.flipCount, 1)
        XCTAssertEqual(
            controller.session.nextActionAt,
            firstFlipAt.addingTimeInterval(controller.currentProfile.flipInterval)
        )
    }

    func testBackgroundRecoveryUsesAbsoluteNextActionDate() {
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 20_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(60)
        )
        session.startedAt = start
        store.save(session: session)

        let controller = CookingSessionController(store: store, now: start)
        controller.refresh(at: start.addingTimeInterval(42))

        XCTAssertEqual(controller.guidance.remainingTime, 18, accuracy: 0.001)
    }

    func testTimerCompletionDoesNotConfirmFlipForUser() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 30_000))
        let controller = fixture.controller
        let start = fixture.start
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
        let due = try! XCTUnwrap(controller.session.nextActionAt)

        controller.refresh(at: due.addingTimeInterval(5))

        XCTAssertEqual(controller.session.phase, .sear)
        XCTAssertEqual(controller.session.flipCount, 0)
        XCTAssertEqual(controller.guidance.currentAction, .flip)
    }

    func testLowManualTemperatureReturnsToSearCycle() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 40_000))
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)

        controller.recordManualTemperature(49, at: now.addingTimeInterval(200))

        XCTAssertEqual(controller.session.phase, .sear)
        XCTAssertEqual(controller.guidance.pullRecommendation, .keepCooking)
        XCTAssertEqual(controller.session.lastManualTemperatureC, 49)
        XCTAssertNotNil(controller.session.nextActionAt)
    }

    func testPullTemperatureEntersFinishingOnlyAfterTakeOutConfirmation() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 50_000))
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)
        controller.recordManualTemperature(
            controller.currentProfile.pullTemperatureC,
            at: now.addingTimeInterval(120)
        )

        XCTAssertEqual(controller.guidance.currentAction, .takeOut)
        XCTAssertEqual(controller.session.phase, .checkTemperature)

        controller.confirmCurrentAction(at: now.addingTimeInterval(121))

        XCTAssertEqual(controller.session.phase, .finishing)
        XCTAssertNotNil(controller.session.pulledAt)
        XCTAssertNotNil(controller.session.nextActionAt)
    }

    private func makeController(at start: Date) -> (controller: CookingSessionController, start: Date) {
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return (
            CookingSessionController(
                store: CookingStore(defaults: defaults),
                notificationService: NotificationService(isEnabled: false),
                liveActivityService: LiveActivityService(isEnabled: false),
                now: start
            ),
            start
        )
    }
}
