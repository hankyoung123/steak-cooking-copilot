import XCTest
@testable import SteakCopilot

/// The in-pan time model.
///
/// Two properties are pinned here. First, the Medium-Rare baseline is the
/// empirical, linear one — 2.0cm ≈ 120s and +60s per additional 0.5cm — and it
/// describes the *ideal* heat exposure with no operating margin baked in.
/// Second, lateness is absorbed by the interaction layer: a late action
/// compresses what follows it instead of pushing TAKE IT OUT later, and a flip
/// that would land on top of the pull boundary is not scheduled at all.
@MainActor
final class PanTimingModelTests: XCTestCase {
    private let engine = CookingEngine(tuning: .production)
    private let tuning = AppTuning.production
    private let start = Date(timeIntervalSince1970: 500_000)

    // MARK: - Helpers

    private func budget(
        _ thicknessCM: Double,
        cut: SteakCut = .strip,
        doneness: Doneness = .mediumRare
    ) -> TimeInterval {
        engine.profile(
            for: SteakConfiguration(
                cut: cut,
                thicknessCM: thicknessCM,
                doneness: doneness
            ),
            calibration: .neutral
        ).estimatedCookingBudget
    }

    private func profile(
        cut: SteakCut = .ribeye,
        thicknessCM: Double = 3
    ) -> CookingProfile {
        engine.profile(
            for: SteakConfiguration(
                cut: cut,
                thicknessCM: thicknessCM,
                doneness: .mediumRare
            ),
            calibration: .neutral
        )
    }

    private func searSession(
        cut: SteakCut = .ribeye,
        thicknessCM: Double = 3,
        nextActionAt: Date? = nil,
        butterAddedAt: Date? = nil,
        thermometerUnavailable: Bool = false
    ) -> CookingSession {
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: nextActionAt
        )
        session.startedAt = start
        session.configuration = SteakConfiguration(
            cut: cut,
            thicknessCM: thicknessCM,
            doneness: .mediumRare
        )
        session.butterAddedAt = butterAddedAt
        if thermometerUnavailable {
            session.thermometerUnavailableAt = start
        }
        return session
    }

    // MARK: - The empirical baseline

    func testMediumRareBaselineMatchesTheEmpiricalPanTimes() {
        let baseline: [(thicknessCM: Double, seconds: TimeInterval)] = [
            (2.0, 120),
            (2.5, 180),
            (3.0, 240),
            (3.5, 300)
        ]

        for point in baseline {
            XCTAssertEqual(
                budget(point.thicknessCM),
                point.seconds,
                accuracy: 0.001,
                "\(point.thicknessCM)cm Medium Rare should be \(point.seconds)s"
            )
        }
    }

    func testEveryHalfCentimetreAddsSixtySeconds() {
        let steps: [(Double, Double)] = [
            (2.0, 2.5),
            (2.5, 3.0),
            (3.0, 3.5),
            (3.5, 4.0)
        ]

        for (thin, thick) in steps {
            XCTAssertEqual(
                budget(thick) - budget(thin),
                60,
                accuracy: 0.001,
                "\(thin) → \(thick)cm must add 60s"
            )
        }
    }

    /// The baseline is the *whole* pan time for the reference cut: strip is the
    /// zero point of the cut offsets, so nothing is added for "safety". The
    /// delay a real user needs to pick up tongs, flip and tap confirm is the
    /// interaction layer's problem and is deliberately not compensated here.
    func testTheBaselineIsTheWholePanTimeWithNoOperatingAllowance() {
        XCTAssertEqual(tuning.cuts.strip.cookingBudgetOffset, 0)
        XCTAssertEqual(
            tuning.cooking.exposureTime(thicknessCM: 2.5),
            tuning.cooking.baseCookingBudget,
            accuracy: 0.001
        )
        XCTAssertEqual(budget(2.5), tuning.cooking.baseCookingBudget, accuracy: 0.001)
        XCTAssertEqual(
            budget(3.0),
            tuning.cooking.exposureTime(thicknessCM: 3.0),
            accuracy: 0.001
        )
    }

    /// The floor exists to catch sub-1.8cm slices. It must stay well below the
    /// 2.0cm baseline: at 180s it would have stretched a 120s steak by 50%.
    func testTheBudgetFloorDoesNotClampTheThinBaseline() {
        XCTAssertLessThan(tuning.cooking.minCookingBudget, 120)
        XCTAssertEqual(budget(2.0), 120, accuracy: 0.001)
        XCTAssertEqual(
            budget(1.5),
            tuning.cooking.minCookingBudget,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            budget(1.5),
            tuning.cooking.exposureTime(thicknessCM: 1.5)
        )
    }

    func testDonenessStillScalesTheExposureTime() {
        XCTAssertEqual(budget(2.5, doneness: .mediumRare), 180, accuracy: 0.001)
        XCTAssertEqual(
            budget(2.5, doneness: .rare),
            180 * tuning.doneness.rare.cookingBudgetFactor,
            accuracy: 0.001
        )
        XCTAssertLessThan(budget(2.5, doneness: .rare), budget(2.5))
        XCTAssertGreaterThan(budget(2.5, doneness: .wellDone), budget(2.5))
    }

    /// Thin steaks flip more often, but that is a cadence rule and must not
    /// change the exposure time.
    func testTheFlipCadenceDoesNotChangeTheExposureTime() {
        for thickness in [2.0, 2.5, 3.0, 3.5] {
            let cutProfile = profile(cut: .strip, thicknessCM: thickness)
            XCTAssertGreaterThan(cutProfile.flipInterval, 0)
            XCTAssertGreaterThanOrEqual(
                cutProfile.estimatedCookingBudget,
                cutProfile.flipInterval * tuning.cooking.minBudgetInFlipIntervals
            )
        }
    }

    // MARK: - The late stage is an absolute plan

    /// A baste window is anchored to the plan, so being 8s late to ADD BUTTER
    /// shortens the window by 8s instead of moving TAKE IT OUT 8s later.
    func testLateButterShortensTheBasteByExactlyTheLateness() {
        let ribeye = profile()
        let lateStageAt = start.addingTimeInterval(ribeye.lateStageDateOffset)
        let pullAt = start.addingTimeInterval(ribeye.estimatedCookingBudget)
        let session = searSession(butterAddedAt: lateStageAt, thermometerUnavailable: true)

        let onTime = engine.basteEndDate(for: session, profile: ribeye)
        XCTAssertEqual(
            onTime.timeIntervalSince(lateStageAt),
            ribeye.basteDuration,
            accuracy: 0.001
        )
        XCTAssertLessThanOrEqual(onTime, pullAt)

        // The same session, with the butter going in 8s late: the window ends
        // on the same absolute date and therefore loses exactly 8s.
        let lateButterAt = lateStageAt.addingTimeInterval(8)
        XCTAssertEqual(
            onTime.timeIntervalSince(lateButterAt),
            ribeye.basteDuration - 8,
            accuracy: 0.001
        )
        XCTAssertEqual(
            engine.basteEndDate(for: session, profile: ribeye),
            onTime,
            "The planned end must not depend on when the user taps"
        )
    }

    /// The baste is capped by the pull anchor, so the late stage can never run
    /// past the moment the plan says to pull.
    func testTheBasteEndNeverRunsPastThePullAnchor() {
        // A "crust too light" bias pushes the late stage late enough that a
        // full baste would cross the pull boundary.
        let bias = profile().estimatedCookingBudget * 0.35
        let biased = engine.profile(
            for: SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare),
            calibration: CookingCalibration(cookingTimeAdjustment: 0, searBias: bias)
        )
        let session = searSession(thermometerUnavailable: true)
        let pullAt = start.addingTimeInterval(biased.estimatedCookingBudget)

        XCTAssertGreaterThan(
            start.addingTimeInterval(biased.lateStageDateOffset)
                .addingTimeInterval(biased.basteDuration),
            pullAt,
            "Fixture must make a full baste overshoot the pull"
        )
        XCTAssertEqual(
            engine.basteEndDate(for: session, profile: biased),
            pullAt
        )
    }

    /// With no probe the estimated pull is the deadline. With a probe the pull
    /// follows a reading, so there is no absolute date to compress against and
    /// the windows simply follow the plan.
    func testThePullAnchorOnlyCapsTheWindowsInTheTimingFallback() {
        let ribeye = profile()
        XCTAssertNil(
            engine.fallbackPullDate(
                for: searSession(),
                profile: ribeye
            ),
            "A probe session has no estimated pull deadline"
        )
        XCTAssertNotNil(
            engine.fallbackPullDate(
                for: searSession(thermometerUnavailable: true),
                profile: ribeye
            )
        )
    }

    // MARK: - No flip, then immediately TAKE IT OUT

    func testNoFlipIsScheduledInsideTheGuardWindowBeforeThePull() {
        let ribeye = profile()
        let pullAt = start.addingTimeInterval(ribeye.estimatedCookingBudget)
        let session = searSession(
            nextActionAt: pullAt,
            butterAddedAt: start,
            thermometerUnavailable: true
        )
        let guardSeconds = tuning.cooking.minSecondsAfterFlipBeforePull

        // A flip would land `inside` seconds before the pull: dropped, and the
        // boundary becomes the pull itself.
        let inside = pullAt.addingTimeInterval(
            -ribeye.flipInterval - (guardSeconds - 2)
        )
        let insideFlipAt = inside.addingTimeInterval(ribeye.flipInterval)
        let suppressed = engine.searBoundary(
            for: session,
            profile: ribeye,
            from: inside
        )
        XCTAssertEqual(suppressed.kind, .estimatedPull)
        XCTAssertEqual(suppressed.date, pullAt)
        XCTAssertTrue(
            engine.isFlipPointless(for: session, profile: ribeye, at: insideFlipAt),
            "the flip candidate itself is inside the guard window"
        )

        // Comfortably outside the guard the flip is scheduled as usual.
        let outside = pullAt.addingTimeInterval(
            -ribeye.flipInterval - (guardSeconds + 30)
        )
        let outsideFlipAt = outside.addingTimeInterval(ribeye.flipInterval)
        let scheduled = engine.searBoundary(
            for: session,
            profile: ribeye,
            from: outside
        )
        XCTAssertEqual(scheduled.kind, .flip)
        XCTAssertEqual(scheduled.date, outsideFlipAt)
        XCTAssertFalse(
            engine.isFlipPointless(for: session, profile: ribeye, at: outsideFlipAt)
        )
    }

    /// Inside the guard window the app asks the user to wait for the pull
    /// rather than flip: the announced action and the pending action stay in
    /// agreement, and neither of them is a flip.
    func testThePlanWaitsRatherThanOfferAPointlessFlip() {
        let ribeye = profile()
        let pullAt = start.addingTimeInterval(ribeye.estimatedCookingBudget)
        // An expired flip boundary that sits inside the guard window.
        let expiredFlipAt = pullAt.addingTimeInterval(-3)
        let session = searSession(
            nextActionAt: expiredFlipAt,
            butterAddedAt: start,
            thermometerUnavailable: true
        )

        let guidance = engine.guidance(for: session, at: expiredFlipAt)

        XCTAssertEqual(guidance.currentAction, .wait)
        XCTAssertEqual(guidance.announcedNextAction, .takeOut)
        XCTAssertNotEqual(guidance.currentAction, .flip)
    }

    /// The guard is a fallback-only rule: with a probe the pull depends on a
    /// reading, so a flip near the timing estimate is still scheduled.
    func testTheGuardDoesNotApplyWhenAProbeIsInPlay() {
        let ribeye = profile()
        let pullAt = start.addingTimeInterval(ribeye.estimatedCookingBudget)
        let expiredFlipAt = pullAt.addingTimeInterval(-3)
        let probeSession = searSession(
            nextActionAt: expiredFlipAt,
            butterAddedAt: start
        )

        XCTAssertFalse(
            engine.isFlipPointless(for: probeSession, profile: ribeye, at: expiredFlipAt)
        )
        let boundary = engine.searBoundary(
            for: probeSession,
            profile: ribeye,
            from: expiredFlipAt
        )
        XCTAssertEqual(
            boundary.kind,
            .flip,
            "The timing estimate is not a decision when a probe exists"
        )
        XCTAssertEqual(
            boundary.date,
            expiredFlipAt.addingTimeInterval(ribeye.flipInterval)
        )

        // The same moment in the timing fallback is guarded instead.
        let fallbackSession = searSession(
            nextActionAt: expiredFlipAt,
            butterAddedAt: start,
            thermometerUnavailable: true
        )
        XCTAssertTrue(
            engine.isFlipPointless(
                for: fallbackSession,
                profile: ribeye,
                at: expiredFlipAt
            )
        )
        XCTAssertEqual(
            engine.searBoundary(
                for: fallbackSession,
                profile: ribeye,
                from: expiredFlipAt
            ).kind,
            .estimatedPull
        )
    }

    /// The guard is part of the plan's shape, so it scales with the test time
    /// scales. Unscaled it would be longer than a `-fastCook` steak (8s) and
    /// would suppress every flip, turning the route into SEAR → FAT CAP with no
    /// flipping at all.
    func testTheGuardScalesWithTheTestTimeScale() {
        let configuration = SteakConfiguration(
            cut: .strip,
            thicknessCM: 3,
            doneness: .mediumRare
        )
        let scaled = engine.profile(
            for: configuration,
            calibration: .neutral,
            timeScale: 0.035
        )
        XCTAssertEqual(
            scaled.flipPullGuard,
            tuning.cooking.minSecondsAfterFlipBeforePull * 0.035,
            accuracy: 0.001
        )
        XCTAssertLessThan(scaled.flipPullGuard, scaled.flipInterval)

        let session = searSession(
            cut: .strip,
            nextActionAt: nil,
            thermometerUnavailable: true
        )
        let boundary = engine.searBoundary(
            for: session,
            profile: scaled,
            from: start
        )
        XCTAssertEqual(
            boundary.kind,
            .flip,
            "A fast-cooked steak must still flip on schedule"
        )
        XCTAssertEqual(
            boundary.date,
            start.addingTimeInterval(scaled.flipInterval)
        )
    }

    // MARK: - Lateness never moves the deadline (controller level)

    private func makeController(
        cut: SteakCut = .strip,
        timeScale: Double = 1
    ) -> (controller: CookingSessionController, start: Date) {
        let suite = "PanTimingModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let controller = CookingSessionController(
            store: CookingStore(defaults: defaults),
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            timeScale: timeScale,
            now: start
        )
        controller.updateConfiguration(
            SteakConfiguration(cut: cut, thicknessCM: 3, doneness: .mediumRare)
        )
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
        return (controller, start)
    }

    /// The whole route still flips at the UI-test time scale (`-fastCook`), so
    /// the guard cannot silently delete the searing loop from the walk the UI
    /// tests drive.
    func testTheFastCookScaleStillWalksTheFlipRoute() {
        let fixture = makeController(timeScale: 0.035)
        let controller = fixture.controller
        var actions: [CookingAction] = []

        for _ in 0..<20 {
            let due = try! XCTUnwrap(controller.session.nextActionAt)
            controller.refresh(at: due)
            let action = controller.guidance.currentAction
            actions.append(action)
            controller.confirmCurrentAction(at: due)
            if action == .takeOut { break }
        }

        XCTAssertGreaterThanOrEqual(
            controller.session.flipCount,
            3,
            "A fast-cooked steak must still ask for flips, saw \(actions)"
        )
        XCTAssertEqual(actions.last, .takeOut)
        XCTAssertEqual(controller.session.phase, .finishing)
    }

    /// Every action taken 12s late still leaves the schedule pointing at the
    /// original absolute pull: the lateness is absorbed by the stages that
    /// follow, and the plan never hands the user a boundary past the anchor.
    func testLateActionsCompressLaterStagesAndNeverMoveThePullDeadline() {
        let fixture = makeController()
        let controller = fixture.controller
        let pullAt = try! XCTUnwrap(controller.session.startedAt)
            .addingTimeInterval(controller.currentProfile.estimatedCookingBudget)
        let lateness: TimeInterval = 12

        var performed: [CookingAction] = []
        for _ in 0..<12 {
            let due = try! XCTUnwrap(controller.session.nextActionAt)
            let late = due.addingTimeInterval(lateness)
            controller.refresh(at: late)
            let action = controller.guidance.currentAction
            performed.append(action)
            if action == .takeOut {
                controller.confirmCurrentAction(at: late)
                break
            }
            controller.confirmCurrentAction(at: late)
            let next = try! XCTUnwrap(controller.session.nextActionAt)
            XCTAssertLessThanOrEqual(
                next,
                pullAt.addingTimeInterval(0.001),
                "A late \(action) scheduled past the pull anchor"
            )
        }

        XCTAssertTrue(performed.contains(.flip))
        XCTAssertEqual(performed.last, .takeOut)
        // Every boundary the plan handed out stayed on or before the anchor,
        // and the final tap — the user's own 12s delay — is the only thing that
        // lands after it.
        let pulledAt = try! XCTUnwrap(controller.session.pulledAt)
        XCTAssertGreaterThanOrEqual(pulledAt, pullAt)
        XCTAssertLessThanOrEqual(
            pulledAt.timeIntervalSince(pullAt),
            lateness + 0.001,
            "The cook must not stretch beyond the anchor by more than the user's own delay"
        )
    }

    /// The same walk, on time: the cook ends exactly on the anchored pull.
    func testAnOnTimeCookEndsOnTheAnchoredPull() {
        let fixture = makeController()
        let controller = fixture.controller
        let pullAt = try! XCTUnwrap(controller.session.startedAt)
            .addingTimeInterval(controller.currentProfile.estimatedCookingBudget)

        for _ in 0..<20 {
            let due = try! XCTUnwrap(controller.session.nextActionAt)
            controller.refresh(at: due)
            let action = controller.guidance.currentAction
            controller.confirmCurrentAction(at: due)
            if action == .takeOut { break }
        }

        XCTAssertEqual(controller.session.pulledAt, pullAt)
    }

    /// The butter case from the objective: 8s late to ADD BUTTER leaves an 8s
    /// shorter baste window, and the pull still happens on the anchor.
    func testALateAddButterShrinksTheBasteWindow() {
        let fixture = makeController(cut: .ribeye)
        let controller = fixture.controller
        let lateStageAt = try! XCTUnwrap(controller.session.startedAt)
            .addingTimeInterval(controller.currentProfile.lateStageDateOffset)
        let pullAt = try! XCTUnwrap(controller.session.startedAt)
            .addingTimeInterval(controller.currentProfile.estimatedCookingBudget)
        let basteDuration = controller.currentProfile.basteDuration

        // Walk to the late-stage boundary on time.
        for _ in 0..<20 {
            let due = try! XCTUnwrap(controller.session.nextActionAt)
            if due >= lateStageAt { break }
            controller.refresh(at: due)
            controller.confirmCurrentAction(at: due)
        }

        controller.refresh(at: lateStageAt)
        XCTAssertEqual(controller.guidance.currentAction, .addButter)

        let lateButterAt = lateStageAt.addingTimeInterval(8)
        controller.confirmCurrentAction(at: lateButterAt)

        let basteEnd = try! XCTUnwrap(controller.session.nextActionAt)
        XCTAssertEqual(controller.session.phase, .baste)
        XCTAssertEqual(
            basteEnd.timeIntervalSince(lateButterAt),
            basteDuration - 8,
            accuracy: 0.001
        )
        XCTAssertLessThanOrEqual(basteEnd, pullAt)
    }
}
