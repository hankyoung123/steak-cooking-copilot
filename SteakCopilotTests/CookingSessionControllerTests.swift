import XCTest
@testable import SteakCopilot

@MainActor
final class CookingSessionControllerTests: XCTestCase {
    func testBackgroundRecoveryUsesCurrentDateRatherThanTickCount() {
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 30_000)
        var session = CookingSession.fixture(
            phase: .searFirst,
            phaseStartedAt: start,
            phaseDuration: 60
        )
        session.configuration = .init(cut: .strip, thicknessCM: 3, doneness: .mediumRare)
        store.save(session: session)

        let controller = CookingSessionController(store: store)
        controller.refresh(at: start.addingTimeInterval(42))

        XCTAssertEqual(controller.guidance.remainingTime, 18, accuracy: 0.001)
    }

    func testTimerCompletionDoesNotAdvanceCookPhaseWithoutUserAction() {
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 40_000)
        store.save(session: CookingSession.fixture(
            phase: .searFirst,
            phaseStartedAt: start,
            phaseDuration: 10
        ))

        let controller = CookingSessionController(store: store)
        controller.refresh(at: start.addingTimeInterval(15))

        XCTAssertEqual(controller.session.phase, .searFirst)
        XCTAssertEqual(controller.guidance.event, .flipNow(style: .hero))
    }

    func testCompleteCookFlowKeepsActionsInsideCookThenReachesReady() {
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = CookingSessionController(
            store: CookingStore(defaults: defaults),
            timeScale: 0.01,
            now: Date(timeIntervalSince1970: 50_000)
        )
        var now = Date(timeIntervalSince1970: 50_000)

        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)

        let cookPhases: [CookingPhase] = [
            .searFirst, .searSecond, .fatCap, .butter, .baste, .checkTemperature, .pull
        ]
        for expected in cookPhases {
            XCTAssertEqual(controller.session.phase, expected)
            XCTAssertEqual(controller.flowStage, .cook)
            now = controller.session.phaseStartedAt.addingTimeInterval(controller.session.phaseDuration + 0.1)
            controller.refresh(at: now)
            controller.confirmCurrentAction(at: now)
        }

        XCTAssertEqual(controller.session.phase, .resting)
        XCTAssertEqual(controller.flowStage, .finish)

        now = controller.session.phaseStartedAt.addingTimeInterval(controller.session.phaseDuration + 0.1)
        controller.refresh(at: now)
        XCTAssertEqual(controller.session.phase, .ready)
        XCTAssertEqual(controller.flowStage, .eat)
    }
}
