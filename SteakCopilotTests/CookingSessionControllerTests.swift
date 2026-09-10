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

    func testStartOverClearsNotificationsEndsLiveActivityAndMotion() async {
        let notifications = NotificationServiceSpy()
        let liveActivity = LiveActivityServiceSpy()
        let motion = MotionDirector(
            haptics: HapticService(isEnabled: false),
            sounds: SoundService(isEnabled: false)
        )
        motion.handle(.flipNow(style: .hero))
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 60_000)
        let controller = CookingSessionController(
            store: CookingStore(defaults: defaults),
            motionDirector: motion,
            notificationService: notifications,
            liveActivityService: liveActivity,
            now: start
        )
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
        let oldSessionID = controller.session.id

        await controller.startOver(at: start.addingTimeInterval(5))

        XCTAssertEqual(notifications.clearCount, 1)
        XCTAssertEqual(liveActivity.endedSessionIDs, [oldSessionID])
        XCTAssertEqual(liveActivity.endedReasons, [.cancelled])
        XCTAssertEqual(motion.cue.visual, .none)
        XCTAssertNotEqual(controller.session.id, oldSessionID)
        XCTAssertEqual(controller.session.phase, .setup)
    }

    func testFinishingBoundaryDispatchesEngineReadyEvent() async {
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 70_000)
        let readyAt = start.addingTimeInterval(180)
        let store = CookingStore(defaults: defaults)
        store.save(
            session: CookingSession.fixture(
                phase: .finishing,
                phaseStartedAt: start,
                nextActionAt: readyAt
            )
        )
        let motion = MotionDirector(
            haptics: HapticService(isEnabled: false),
            sounds: SoundService(isEnabled: false)
        )
        let liveActivity = LiveActivityServiceSpy()
        let controller = CookingSessionController(
            store: store,
            motionDirector: motion,
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: liveActivity,
            now: start
        )

        controller.refresh(at: readyAt)

        XCTAssertEqual(controller.session.phase, .ready)
        XCTAssertEqual(motion.cue.visual, .ready)

        for _ in 0..<100 where liveActivity.endedReasons.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(liveActivity.endedReasons, [.finished])
    }

    func testSkippingEveryActiveStageAdvancesAndReturnsToFreshSetup() async {
        let fixture = makeController(at: Date(timeIntervalSince1970: 80_000))
        let controller = fixture.controller
        var now = fixture.start
        controller.finishSetup(at: now)
        let originalSessionID = controller.session.id

        XCTAssertEqual(controller.session.phase, .prep)

        now.addTimeInterval(1)
        await controller.skipCurrentStage(at: now)
        XCTAssertEqual(controller.session.phase, .heat)

        now.addTimeInterval(1)
        await controller.skipCurrentStage(at: now)
        XCTAssertEqual(controller.session.phase, .sear)

        now.addTimeInterval(1)
        await controller.skipCurrentStage(at: now)
        XCTAssertEqual(controller.session.phase, .finishing)
        XCTAssertEqual(controller.session.pulledAt, now)

        now.addTimeInterval(1)
        await controller.skipCurrentStage(at: now)
        XCTAssertEqual(controller.session.phase, .ready)
        XCTAssertEqual(controller.session.finishedAt, now)

        now.addTimeInterval(1)
        await controller.skipCurrentStage(at: now)
        XCTAssertEqual(controller.session.phase, .eat)

        now.addTimeInterval(1)
        await controller.skipCurrentStage(at: now)
        XCTAssertEqual(controller.session.phase, .feedback)

        now.addTimeInterval(1)
        await controller.skipCurrentStage(at: now)
        XCTAssertEqual(controller.session.phase, .setup)
        XCTAssertNotEqual(controller.session.id, originalSessionID)
    }

    // MARK: - No-thermometer fallback

    func testContinueWithoutThermometerCreatesNoTemperatureAndKeepsCooking() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 90_000))
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)

        controller.continueWithoutThermometer(at: now.addingTimeInterval(60))

        XCTAssertNotNil(controller.session.thermometerUnavailableAt)
        XCTAssertNil(controller.session.lastManualTemperatureC)
        XCTAssertNil(controller.guidance.lastManualTemperatureC)
        XCTAssertEqual(controller.guidance.currentAction, .wait)
        XCTAssertNotEqual(controller.guidance.currentAction, .takeOut)
        XCTAssertNotEqual(controller.guidance.currentAction, .checkTemperature)
        XCTAssertEqual(controller.session.phase, .sear)
    }

    func testNoThermometerFallbackContinuesFlipCycleUntilEstimatedPullBoundary() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 100_000))
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)
        controller.continueWithoutThermometer(at: now.addingTimeInterval(60))

        // Confirm a few flips; each must schedule an absolute boundary no
        // later than min(now + flipInterval, estimatedPullAt), and CHECK
        // TEMP must never reappear.
        var date = try! XCTUnwrap(controller.session.nextActionAt)
        for index in 0..<4 {
            controller.refresh(at: date)
            XCTAssertEqual(controller.guidance.currentAction, .flip)
            XCTAssertNotEqual(controller.guidance.currentAction, .checkTemperature)
            let profile = controller.currentProfile
            let estimatedPullAt = try! XCTUnwrap(controller.session.startedAt)
                .addingTimeInterval(profile.estimatedCookingBudget)
            controller.confirmCurrentAction(at: date)
            XCTAssertEqual(controller.session.phase, .sear)
            XCTAssertEqual(controller.session.flipCount, index + 1)
            let next = try! XCTUnwrap(controller.session.nextActionAt)
            XCTAssertLessThanOrEqual(
                next,
                min(date.addingTimeInterval(profile.flipInterval), estimatedPullAt)
                    .addingTimeInterval(0.001)
            )
            date = next
        }

        // Past the estimated pull boundary the next action must be TAKE IT OUT.
        let estimatedPullAt = try! XCTUnwrap(controller.session.startedAt)
            .addingTimeInterval(controller.currentProfile.estimatedCookingBudget)
        controller.refresh(at: estimatedPullAt.addingTimeInterval(0.1))
        XCTAssertEqual(controller.guidance.currentAction, .takeOut)
        XCTAssertNil(controller.session.lastManualTemperatureC)
    }

    func testNoThermometerSelectedAfterPullBoundaryIsImmediatelyActionable() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 110_000))
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)
        let estimatedPullAt = try! XCTUnwrap(controller.session.startedAt)
            .addingTimeInterval(controller.currentProfile.estimatedCookingBudget)

        controller.continueWithoutThermometer(at: estimatedPullAt.addingTimeInterval(30))

        XCTAssertEqual(controller.guidance.currentAction, .takeOut)
        XCTAssertNil(controller.session.lastManualTemperatureC)
    }

    func testManualReadingOverridesEstimatedFallback() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 120_000))
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)
        controller.continueWithoutThermometer(at: now.addingTimeInterval(30))

        controller.recordManualTemperature(
            controller.currentProfile.pullTemperatureC - 4,
            at: now.addingTimeInterval(60)
        )

        XCTAssertNil(controller.session.thermometerUnavailableAt)
        XCTAssertEqual(
            controller.session.lastManualTemperatureC,
            controller.currentProfile.pullTemperatureC - 4
        )
        XCTAssertEqual(controller.guidance.pullRecommendation, .keepCooking)
        XCTAssertEqual(controller.session.phase, .sear)
    }

    // MARK: - Calibration-aware sear boundary

    func testLearnedSearBiasMovesTheScheduledLateStageBoundary() {
        let suite = "CookingSessionControllerTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let key = CalibrationKey(
            cut: .strip,
            thicknessBucket: .standard,
            doneness: .mediumRare
        )
        store.save(
            calibration: CookingCalibration(cookingTimeAdjustment: 0, searBias: 16),
            for: key
        )
        let start = Date(timeIntervalSince1970: 130_000)
        let controller = CookingSessionController(
            store: store,
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            now: start
        )
        let configuration = SteakConfiguration(
            cut: .strip,
            thicknessCM: 3,
            doneness: .mediumRare
        )
        controller.updateConfiguration(configuration)
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)

        let neutralLateStage = controller.session.startedAt!
            .addingTimeInterval(
                CookingEngine()
                    .profile(for: configuration, calibration: .neutral)
                    .lateStageDateOffset
            )
        let learnedLateStage = controller.session.startedAt!
            .addingTimeInterval(controller.currentProfile.lateStageDateOffset)

        // Learned “crust too light” bias keeps searing longer.
        XCTAssertGreaterThan(learnedLateStage, neutralLateStage)

        // Confirming a flip must never schedule past the learned boundary.
        let flipAt = controller.session.nextActionAt!
        controller.refresh(at: flipAt)
        controller.confirmCurrentAction(at: flipAt)
        XCTAssertLessThanOrEqual(
            controller.session.nextActionAt!,
            learnedLateStage.addingTimeInterval(0.001)
        )
    }

    // MARK: - Advanced settings estimate

    func testEstimatedCookingBudgetRecomputesForDraftConfiguration() {
        let fixture = makeController(at: Date(timeIntervalSince1970: 140_000))
        let controller = fixture.controller

        let base = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
        let thicker = SteakConfiguration(cut: .ribeye, thicknessCM: 5, doneness: .mediumRare)
        let moreDone = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .wellDone)

        let baseBudget = controller.estimatedCookingBudget(for: base)
        XCTAssertGreaterThan(
            controller.estimatedCookingBudget(for: thicker),
            baseBudget
        )
        XCTAssertGreaterThan(
            controller.estimatedCookingBudget(for: moreDone),
            baseBudget
        )
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

@MainActor
private final class NotificationServiceSpy: CookingNotificationServing {
    private(set) var clearCount = 0

    func requestAuthorization() async -> Bool { true }

    func scheduleNextAction(guidance: CookingGuidance) async {}

    func clearCookingNotifications() {
        clearCount += 1
    }
}

@MainActor
private final class LiveActivityServiceSpy: CookingLiveActivityServing {
    private(set) var endedSessionIDs: [UUID] = []
    private(set) var endedReasons: [CookingLiveActivityEndReason] = []

    func recover(for session: CookingSession, guidance: CookingGuidance) async {}
    func start(for session: CookingSession, guidance: CookingGuidance) async {}
    func update(for session: CookingSession, guidance: CookingGuidance) async {}

    func end(
        for session: CookingSession,
        guidance: CookingGuidance,
        reason: CookingLiveActivityEndReason
    ) async {
        endedSessionIDs.append(session.id)
        endedReasons.append(reason)
    }
}
