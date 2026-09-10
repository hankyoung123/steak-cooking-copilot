import XCTest
@testable import SteakCopilot

/// Covers the sear-boundary contract: `nextActionAt` and the announced
/// action must always describe the same moment, so a notification or Live
/// Activity can never say FLIP while the app shows TAKE IT OUT.
@MainActor
final class CookingBoundaryTests: XCTestCase {
    private let engine = CookingEngine()
    private let configuration = SteakConfiguration(
        cut: .ribeye,
        thicknessCM: 3,
        doneness: .mediumRare
    )
    private let start = Date(timeIntervalSince1970: 200_000)

    private func searSession(
        nextActionAt: Date?,
        butterAddedAt: Date? = nil,
        thermometerUnavailable: Bool = false,
        configuration: SteakConfiguration? = nil
    ) -> CookingSession {
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: nextActionAt
        )
        session.startedAt = start
        session.configuration = configuration ?? self.configuration
        session.butterAddedAt = butterAddedAt
        if thermometerUnavailable {
            session.thermometerUnavailableAt = start
        }
        return session
    }

    // MARK: - Boundary selection

    func testFlipIsTheEarliestBoundaryDuringNormalSearing() {
        let session = searSession(
            nextActionAt: start.addingTimeInterval(30)
        )
        let profile = engine.profile(for: configuration, calibration: .neutral)

        let boundary = engine.searBoundary(
            for: session,
            profile: profile,
            from: start
        )

        XCTAssertEqual(boundary.kind, .flip)
        XCTAssertEqual(boundary.date, start.addingTimeInterval(30))
        XCTAssertEqual(
            engine.action(for: boundary.kind, configuration: configuration),
            .flip
        )
    }

    func testLateStageEarlierThanFlipSchedulesFatCapOrButter() {
        let profile = engine.profile(for: configuration, calibration: .neutral)
        // A moment whose next flip lands after the calibrated late stage.
        let from = start.addingTimeInterval(profile.lateStageDateOffset - 5)
        let session = searSession(
            nextActionAt: start.addingTimeInterval(profile.lateStageDateOffset)
        )

        let boundary = engine.searBoundary(
            for: session,
            profile: profile,
            from: from
        )

        XCTAssertEqual(boundary.kind, .lateStage)
        XCTAssertEqual(
            boundary.date,
            start.addingTimeInterval(profile.lateStageDateOffset)
        )
        // Ribeye has no fat cap → butter; strip → stand the fat cap.
        XCTAssertEqual(
            engine.action(for: boundary.kind, configuration: configuration),
            .addButter
        )
        let strip = SteakConfiguration(cut: .strip, thicknessCM: 3, doneness: .mediumRare)
        XCTAssertEqual(
            engine.action(for: boundary.kind, configuration: strip),
            .standFatCap
        )
    }

    func testEstimatedPullEarlierThanFlipSchedulesTakeOut() {
        let profile = engine.profile(for: configuration, calibration: .neutral)
        let estimatedPullAt = start.addingTimeInterval(profile.estimatedCookingBudget)
        // Butter already added, so the late-stage candidate no longer applies.
        let from = estimatedPullAt.addingTimeInterval(-5)
        let session = searSession(
            nextActionAt: estimatedPullAt,
            butterAddedAt: start,
            thermometerUnavailable: true
        )

        let boundary = engine.searBoundary(
            for: session,
            profile: profile,
            from: from
        )

        XCTAssertEqual(boundary.kind, .estimatedPull)
        XCTAssertEqual(boundary.date, estimatedPullAt)
        XCTAssertEqual(
            engine.action(for: boundary.kind, configuration: configuration),
            .takeOut
        )
    }

    func testScheduledBoundaryKindMatchesTheScheduledDate() {
        let profile = engine.profile(for: configuration, calibration: .neutral)
        let estimatedPullAt = start.addingTimeInterval(profile.estimatedCookingBudget)
        let lateStageAt = start.addingTimeInterval(profile.lateStageDateOffset)

        let flipScheduled = searSession(nextActionAt: start.addingTimeInterval(30))
        XCTAssertEqual(
            engine.scheduledSearBoundaryKind(for: flipScheduled, profile: profile),
            .flip
        )

        let lateScheduled = searSession(nextActionAt: lateStageAt)
        XCTAssertEqual(
            engine.scheduledSearBoundaryKind(for: lateScheduled, profile: profile),
            .lateStage
        )

        let pullScheduled = searSession(
            nextActionAt: estimatedPullAt,
            butterAddedAt: start,
            thermometerUnavailable: true
        )
        XCTAssertEqual(
            engine.scheduledSearBoundaryKind(for: pullScheduled, profile: profile),
            .estimatedPull
        )
    }

    func testEstimatedPullWinsAnExactTieWithALateStageBoundary() {
        // Craft a calibration whose late-stage date coincides exactly with
        // the estimated pull boundary: pulling must win the tie, never a
        // flip or a butter prompt.
        let base = engine.profile(for: configuration, calibration: .neutral)
        let searBias = base.estimatedCookingBudget * 0.35
        let profile = engine.profile(
            for: configuration,
            calibration: CookingCalibration(
                cookingTimeAdjustment: 0,
                searBias: searBias
            )
        )
        XCTAssertEqual(
            profile.lateStageDateOffset,
            profile.estimatedCookingBudget,
            accuracy: 0.001,
            "Test setup requires a coincidence of both boundaries"
        )

        // Butter not yet added, so both candidates are live at the same date.
        let session = searSession(nextActionAt: nil, thermometerUnavailable: true)
        let boundaryDate = start.addingTimeInterval(profile.estimatedCookingBudget)

        // Start exactly one flip interval earlier so the flip candidate ties
        // with both the late-stage and the pull boundary.
        let boundary = engine.searBoundary(
            for: session,
            profile: profile,
            from: boundaryDate.addingTimeInterval(-profile.flipInterval)
        )

        XCTAssertEqual(boundary.kind, .estimatedPull)
        XCTAssertEqual(boundary.date, boundaryDate)
    }

    // MARK: - Announcement consistency

    func testAnnouncedActionMatchesTheActionPerformedAtTheBoundary() {
        let profile = engine.profile(for: configuration, calibration: .neutral)
        let lateStageAt = start.addingTimeInterval(profile.lateStageDateOffset)
        let estimatedPullAt = start.addingTimeInterval(profile.estimatedCookingBudget)

        let scenarios: [(session: CookingSession, expected: CookingAction)] = [
            (
                searSession(nextActionAt: start.addingTimeInterval(30)),
                .flip
            ),
            (
                searSession(nextActionAt: lateStageAt),
                .addButter
            ),
            (
                searSession(
                    nextActionAt: estimatedPullAt,
                    butterAddedAt: start,
                    thermometerUnavailable: true
                ),
                .takeOut
            )
        ]

        for scenario in scenarios {
            let boundaryDate = try! XCTUnwrap(scenario.session.nextActionAt)
            let before = engine.guidance(
                for: scenario.session,
                at: boundaryDate.addingTimeInterval(-1)
            )
            // What a notification/Live Activity would announce…
            XCTAssertEqual(
                before.announcedNextAction,
                scenario.expected,
                "Announced action must describe the scheduled boundary"
            )
            // …must equal what the app actually presents at that moment.
            let atBoundary = engine.guidance(
                for: scenario.session,
                at: boundaryDate
            )
            XCTAssertEqual(
                atBoundary.currentAction,
                scenario.expected,
                "Action at nextActionAt must match the announced action"
            )
        }
    }

    func testFinishingAndBasteStillAnnounceTheirRealNextAction() {
        // Basting: the scheduled moment is the temperature check.
        var baste = CookingSession.fixture(
            phase: .baste,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(45)
        )
        baste.startedAt = start
        baste.configuration = configuration
        baste.butterAddedAt = start
        let basteGuidance = engine.guidance(for: baste, at: start.addingTimeInterval(10))
        XCTAssertEqual(basteGuidance.currentAction, .baste)
        XCTAssertEqual(basteGuidance.announcedNextAction, .checkTemperature)

        // Finishing: the scheduled moment is READY / time to eat.
        var finishing = CookingSession.fixture(
            phase: .finishing,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(180)
        )
        finishing.startedAt = start
        finishing.configuration = configuration
        finishing.pulledAt = start
        let finishingGuidance = engine.guidance(
            for: finishing,
            at: start.addingTimeInterval(60)
        )
        XCTAssertEqual(finishingGuidance.announcedNextAction, .eat)
    }

    func testFatCapStageAnnouncesButterAtItsBoundary() {
        var session = CookingSession.fixture(
            phase: .fatCap,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(40)
        )
        session.startedAt = start
        session.configuration = SteakConfiguration(
            cut: .strip,
            thicknessCM: 3,
            doneness: .mediumRare
        )
        session.butterAddedAt = nil

        let guidance = engine.guidance(for: session, at: start.addingTimeInterval(10))

        XCTAssertEqual(guidance.currentAction, .standFatCap)
        XCTAssertEqual(guidance.announcedNextAction, .addButter)
    }

    // MARK: - Notification / Live Activity agreement

    func testNotificationAndLiveActivityAnnounceThePullNotAFlip() {
        // Regression: with the no-thermometer fallback the estimated pull
        // boundary can arrive before the next flip. The notification used to
        // say FLIP while the app showed TAKE IT OUT.
        let profile = engine.profile(for: configuration, calibration: .neutral)
        let estimatedPullAt = start.addingTimeInterval(profile.estimatedCookingBudget)
        let session = searSession(
            nextActionAt: estimatedPullAt,
            butterAddedAt: start,
            thermometerUnavailable: true
        )
        let guidance = engine.guidance(
            for: session,
            at: estimatedPullAt.addingTimeInterval(-8)
        )

        XCTAssertEqual(guidance.nextActionAt, estimatedPullAt)
        XCTAssertEqual(guidance.announcedNextAction, .takeOut)

        // Notification copy follows the announced action…
        XCTAssertEqual(
            NotificationService.title(for: guidance.announcedNextAction),
            String(localized: "TAKE IT OUT")
        )
        XCTAssertNotEqual(
            NotificationService.title(for: guidance.announcedNextAction),
            String(localized: "FLIP NOW")
        )

        // …and the Live Activity publishes the identical action.
        let state = LiveActivityService.contentState(
            for: session,
            guidance: guidance
        )
        XCTAssertEqual(state.actionTitle, guidance.announcedNextAction.title)
        XCTAssertEqual(state.actionTitle, CookingAction.takeOut.title)
        XCTAssertEqual(state.actionDate, estimatedPullAt)
    }

    func testLiveActivityAndNotificationShareTheFlipAnnouncement() {
        let session = searSession(nextActionAt: start.addingTimeInterval(30))
        let guidance = engine.guidance(for: session, at: start)

        XCTAssertEqual(guidance.announcedNextAction, .flip)
        XCTAssertEqual(
            NotificationService.title(for: guidance.announcedNextAction),
            String(localized: "FLIP NOW")
        )
        let state = LiveActivityService.contentState(
            for: session,
            guidance: guidance
        )
        XCTAssertEqual(state.actionTitle, CookingAction.flip.title)
        XCTAssertEqual(state.actionDate, start.addingTimeInterval(30))
    }

    // MARK: - Controller agreement

    func testControllerSchedulesTheEngineBoundaryAndAnnouncesItFaithfully() {
        let fixture = makeController()
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)
        controller.continueWithoutThermometer(at: now.addingTimeInterval(20))
        var lastActionDate: Date? = now.addingTimeInterval(20)

        for _ in 0..<40 {
            guard let boundary = controller.session.nextActionAt else { return }
            // What the notification / Live Activity would announce.
            let announced = controller.guidance.announcedNextAction

            // Inside the sear loop the scheduled date is exactly the engine
            // boundary computed from the previous action.
            if controller.session.phase == .sear, let lastActionDate {
                XCTAssertEqual(
                    boundary,
                    engine.searBoundary(
                        for: controller.session,
                        profile: controller.currentProfile,
                        from: lastActionDate
                    ).date,
                    "nextActionAt must come from the engine boundary selection"
                )
            }

            controller.refresh(at: boundary)
            let performed = controller.guidance.currentAction
            lastActionDate = boundary

            XCTAssertEqual(
                performed,
                announced,
                "The action at nextActionAt must match what was announced"
            )
            // No fake temperature is ever produced by the fallback.
            XCTAssertNil(controller.session.lastManualTemperatureC)

            switch performed {
            case .takeOut:
                controller.confirmCurrentAction(at: boundary)
                XCTAssertEqual(controller.session.phase, .finishing)
                XCTAssertNil(controller.session.lastManualTemperatureC)
                return
            case .flip, .standFatCap, .addButter:
                controller.confirmCurrentAction(at: boundary)
            case .checkTemperature:
                XCTAssertNil(controller.session.lastManualTemperatureC)
                controller.continueWithoutThermometer(at: boundary)
            case .wait, .baste, .waitForFinish:
                XCTFail("A sear boundary must not present \(performed) by default")
                return
            default:
                XCTFail("Unexpected boundary action \(performed)")
                return
            }
        }

        XCTFail("No-thermometer fallback never reached TAKE IT OUT")
    }

    func testNoThermometerFallbackNeverCreatesAFakeTemperature() {
        let fixture = makeController()
        let controller = fixture.controller
        let now = fixture.start
        controller.finishSetup(at: now)
        controller.finishPrep(at: now)
        controller.panIsReady(at: now)
        controller.continueWithoutThermometer(at: now.addingTimeInterval(10))

        for step in 0..<20 {
            let date = now.addingTimeInterval(Double(step) * 30)
            controller.refresh(at: date)
            XCTAssertNil(controller.session.lastManualTemperatureC)
            XCTAssertNil(controller.guidance.lastManualTemperatureC)
            XCTAssertNotNil(controller.session.thermometerUnavailableAt)
        }
    }

    private func makeController() -> (controller: CookingSessionController, start: Date) {
        let suite = "CookingBoundaryTests.\(UUID().uuidString)"
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
