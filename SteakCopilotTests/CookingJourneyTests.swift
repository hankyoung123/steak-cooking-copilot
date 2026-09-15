import XCTest
@testable import SteakCopilot

/// The in-pan cooking journey and the flow counter that displays it.
///
/// The counter used to be a switch on `currentAction` with a hardcoded `/ 07`,
/// which is wrong in three separate ways: every cut was shown seven steps even
/// though fat cap is optional, a repeated flip re-counted the same milestone, and
/// returning to the searing loop (a low reading, or the no-thermometer fallback)
/// walked the number backwards. These tests pin the route, the monotonicity and
/// the hand-off to the chrome.
@MainActor
final class CookingJourneyTests: XCTestCase {

    // MARK: - Route

    private func route(_ cut: SteakCut) -> CookingJourney {
        CookingJourney(
            configuration: SteakConfiguration(cut: cut),
            tuning: .production
        )
    }

    /// Strip stands the fat cap up, so its route is seven steps.
    func testStripRouteIncludesTheFatCapMilestone() {
        let journey = route(.strip)

        XCTAssertEqual(
            journey.steps.map(\.rawValue),
            ["sear", "flip", "fatCap", "addButter", "baste", "checkTemperature", "takeOut"]
        )
        XCTAssertEqual(journey.totalSteps, 7)
        XCTAssertEqual(journey.position(of: .sear), 1)
        XCTAssertEqual(journey.position(of: .flip), 2)
        XCTAssertEqual(journey.position(of: .fatCap), 3)
        XCTAssertEqual(journey.position(of: .addButter), 4)
        XCTAssertEqual(journey.position(of: .baste), 5)
        XCTAssertEqual(journey.position(of: .checkTemperature), 6)
        XCTAssertEqual(journey.position(of: .takeOut), 7)
    }

    /// Cuts that need no fat cap get a shorter route, and — the part that matters
    /// — a *contiguous* one. The old label produced 02 → 04 by leaving an empty
    /// slot where the fat cap would have been.
    func testCutsWithoutAFatCapGetAContiguousSixStepRoute() {
        for cut in [SteakCut.ribeye, .tenderloin] {
            let journey = route(cut)

            XCTAssertEqual(
                journey.steps.map(\.rawValue),
                ["sear", "flip", "addButter", "baste", "checkTemperature", "takeOut"],
                "\(cut.rawValue) must not reserve a fat-cap slot"
            )
            XCTAssertEqual(journey.totalSteps, 6)
            XCTAssertFalse(journey.contains(.fatCap))

            let positions = journey.steps.compactMap(journey.position(of:))
            XCTAssertEqual(
                positions,
                Array(1...journey.totalSteps),
                "\(cut.rawValue) positions must run 1...total with no gap"
            )
        }
    }

    /// The fat cap is the only optional step, so it is the only thing that makes
    /// the two routes differ.
    func testFatCapIsTheOnlyDifferenceBetweenTheRoutes() {
        let strip = route(.strip).steps
        let ribeye = route(.ribeye).steps

        XCTAssertEqual(strip.filter { $0 != .fatCap }, ribeye)
    }

    /// TAKE OUT ends the in-pan journey: nothing is counted after it.
    func testTakeOutIsTheFinalCookStep() {
        for cut in SteakCut.allCases {
            XCTAssertEqual(route(cut).finalStep, .takeOut)
        }
    }

    // MARK: - Milestone derivation

    private func facts(
        cut: SteakCut = .ribeye,
        flips: Int = 0,
        phase: CookingPhase = .sear,
        butter: Bool = false,
        reading: Bool = false,
        pulled: Bool = false,
        action: CookingAction = .wait
    ) -> CookingJourneyFacts {
        CookingJourneyFacts(
            needsFatCap: cut.spec(in: .production).needsFatCap,
            flipCount: flips,
            phase: phase,
            butterAddedAt: butter ? Date(timeIntervalSince1970: 1) : nil,
            lastManualTemperatureAt: reading ? Date(timeIntervalSince1970: 2) : nil,
            pulledAt: pulled ? Date(timeIntervalSince1970: 3) : nil,
            pendingAction: action
        )
    }

    /// Frequent flipping is one milestone. The count is only consulted for "has
    /// flipped at all", so flipping twenty times cannot inflate the route.
    func testRepeatedFlipsStayOnTheSameMilestone() {
        let journey = route(.ribeye)

        let first = journey.candidate(for: facts(flips: 1, action: .wait))
        XCTAssertEqual(first, .flip)

        for flips in [2, 5, 20] {
            XCTAssertEqual(
                journey.candidate(for: facts(flips: flips, action: .wait)),
                .flip,
                "Flip \(flips) must not advance the milestone"
            )
        }

        // And the counter itself does not move either.
        XCTAssertEqual(
            journey.progress(for: .sear, milestone: .flip)?.currentStep,
            journey.progress(for: .sear, milestone: first)?.currentStep
        )
    }

    /// A flip being *due* does not move the counter before the user confirms it,
    /// and confirming it moves it exactly once.
    func testSearedFirstSideCountsAsSearUntilTheFirstFlip() {
        let journey = route(.ribeye)

        XCTAssertEqual(journey.candidate(for: facts(flips: 0, action: .wait)), .sear)
        XCTAssertEqual(journey.candidate(for: facts(flips: 0, action: .flip)), .sear)
        XCTAssertEqual(journey.candidate(for: facts(flips: 1, action: .flip)), .flip)
    }

    /// Being asked to probe the steak is the CHECK TEMP step: by the time the
    /// prompt appears the baste timer has already run out.
    func testCheckTemperaturePromptIsItsOwnStep() {
        let journey = route(.ribeye)

        XCTAssertEqual(
            journey.candidate(for: facts(flips: 3, phase: .baste, butter: true, action: .checkTemperature)),
            .checkTemperature
        )
        XCTAssertEqual(
            journey.progress(for: .baste, milestone: .checkTemperature)?.label,
            "05 / 06"
        )
    }

    /// The final step is reachable: it is displayed while the app is asking for
    /// the steak to come out, before the rest begins.
    func testTakeOutPromptShowsTheFinalStep() {
        let strip = route(.strip)
        let milestone = strip.candidate(
            for: facts(cut: .strip, flips: 4, phase: .checkTemperature, butter: true, action: .takeOut)
        )
        XCTAssertEqual(milestone, .takeOut)
        XCTAssertEqual(
            strip.progress(for: .checkTemperature, milestone: milestone)?.label,
            "07 / 07"
        )

        let ribeye = route(.ribeye)
        XCTAssertEqual(
            ribeye.progress(for: .checkTemperature, milestone: .takeOut)?.label,
            "06 / 06"
        )
    }

    func testButterAndLaterStagesAdvanceTheMilestone() {
        let journey = route(.ribeye)

        XCTAssertEqual(
            journey.candidate(for: facts(flips: 3, action: .addButter)),
            .addButter
        )
        XCTAssertEqual(
            journey.candidate(for: facts(flips: 3, phase: .baste, butter: true)),
            .baste
        )
        XCTAssertEqual(
            journey.candidate(for: facts(flips: 3, phase: .checkTemperature, butter: true)),
            .checkTemperature
        )
        XCTAssertEqual(
            journey.candidate(for: facts(flips: 3, reading: true, pulled: true)),
            .takeOut
        )
    }

    /// Butter is sticky: once it is in the pan the milestone cannot fall back to
    /// the searing loop even when the engine sends the session there.
    func testFactDerivedMilestoneDoesNotFallBackOnceButterIsIn() {
        let journey = route(.ribeye)

        let inBaste = journey.candidate(
            for: facts(flips: 4, phase: .baste, butter: true, action: .baste)
        )
        let backInSear = journey.candidate(
            for: facts(flips: 5, phase: .sear, butter: true, action: .flip)
        )

        XCTAssertEqual(inBaste, .baste)
        XCTAssertEqual(backInSear, .baste, "Searing again must not undo the butter step")
    }

    /// The monotonic guard is what actually protects the counter, so it is tested
    /// independently of the facts that feed it.
    func testAdvanceIsMonotonic() {
        let journey = route(.strip)

        var milestone: CookingJourneyStep? = nil
        for step in [CookingJourneyStep.sear, .flip, .fatCap, .addButter, .baste, .checkTemperature, .takeOut] {
            milestone = journey.advanced(from: milestone, with: step)
            XCTAssertEqual(milestone, step)
        }

        // Every attempt to walk back down the route is ignored.
        for older in [CookingJourneyStep.sear, .flip, .fatCap, .baste] {
            milestone = journey.advanced(from: milestone, with: older)
            XCTAssertEqual(milestone, .takeOut, "The mark must never move backwards")
        }
    }

    /// A milestone recorded for a route that no longer applies (a fat cap on a
    /// cut that has none) resolves to the nearest step on the real route rather
    /// than producing a gap.
    func testMilestoneFromAnotherRouteIsClampedOntoThisOne() {
        let ribeye = route(.ribeye)

        XCTAssertEqual(ribeye.clamped(.fatCap), .flip)
        XCTAssertEqual(ribeye.position(of: ribeye.clamped(.fatCap)), 2)
    }

    // MARK: - The displayed counter

    func testProgressIsZeroBeforeTheJourneyStarts() {
        let journey = route(.strip)

        for phase: CookingPhase in [.setup, .prep, .heat] {
            let progress = journey.progress(for: phase, milestone: nil)
            XCTAssertEqual(progress, CookingProgress(currentStep: 0, totalSteps: 7))
            XCTAssertEqual(progress?.label, "00 / 07")
        }
    }

    /// FINISHING and serving are not cook steps, so they get no counter — the
    /// old label numbered them 06 and 07 on the end of the route.
    func testRestingAndServingShowNoCounter() {
        let journey = route(.ribeye)

        for phase: CookingPhase in [.finishing, .ready, .eat, .feedback] {
            XCTAssertNil(
                journey.progress(for: phase, milestone: .takeOut),
                "\(phase) must not be numbered as a cook step"
            )
        }
    }

    /// The label is a function of the route, never of the phase or the action, so
    /// it always agrees with the journey.
    func testLabelMatchesTheRouteForEveryStep() {
        let cases: [(SteakCut, [String])] = [
            (.strip, ["01 / 07", "02 / 07", "03 / 07", "04 / 07", "05 / 07", "06 / 07", "07 / 07"]),
            (.ribeye, ["01 / 06", "02 / 06", "03 / 06", "04 / 06", "05 / 06", "06 / 06"]),
            (.tenderloin, ["01 / 06", "02 / 06", "03 / 06", "04 / 06", "05 / 06", "06 / 06"])
        ]

        for (cut, expected) in cases {
            let journey = route(cut)
            let labels = journey.steps.map {
                journey.progress(for: .sear, milestone: $0)?.label
            }
            XCTAssertEqual(labels, expected, "\(cut.rawValue) counter must follow its route")
        }
    }
}

/// The journey as the running session actually produces it.
///
/// `CookingJourney` is pure, so these tests exist to prove the controller feeds
/// it real facts and that the counter a user sees only ever moves forward.
@MainActor
final class CookingProgressIntegrationTests: XCTestCase {

    private func makeController(at start: Date) -> CookingSessionController {
        let suite = "CookingProgressIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return CookingSessionController(
            store: CookingStore(defaults: defaults),
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            now: start
        )
    }

    private func startCooking(
        _ controller: CookingSessionController,
        cut: SteakCut,
        at start: Date
    ) {
        var configuration = SteakConfiguration(cut: cut, thicknessCM: 4)
        configuration.doneness = .mediumRare
        controller.updateConfiguration(configuration)
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
    }

    /// Walks a real session the way a person does: look at what the app is
    /// asking for, then do it.
    ///
    /// Observing *before* acting matters — a prompt such as ADD BUTTER or TAKE OUT
    /// is a step in its own right, and confirming it in the same breath would hide
    /// that step from the recording. Time only moves on while the app is waiting
    /// for a timer.
    private func walk(
        _ controller: CookingSessionController,
        from start: Date,
        usingThermometer: Bool
    ) -> [Int] {
        var observed: [Int] = []
        var now = start
        let pullTarget = controller.guidance.pullTemperatureC

        func advanceTime() {
            if let due = controller.session.nextActionAt, due > now {
                now = due
            } else {
                now = now.addingTimeInterval(1)
            }
        }

        for _ in 0..<160 {
            controller.refresh(at: now)
            guard let progress = controller.cookingProgress else { break }
            observed.append(progress.currentStep)

            if controller.session.phase == .finishing { break }

            switch controller.guidance.currentAction {
            case .wait, .baste, .waitForFinish:
                advanceTime()

            case .standFatCap:
                // Standing the fat cap is a timer: confirming it before the stand
                // is over is a no-op, so the clock has to move.
                if controller.session.phase == .fatCap {
                    advanceTime()
                } else {
                    controller.confirmCurrentAction(at: now)
                }

            case .flip, .addButter:
                controller.confirmCurrentAction(at: now)

            case .checkTemperature:
                if controller.session.phase == .checkTemperature {
                    if usingThermometer {
                        // A reading at the pull target is what moves the journey
                        // on to its final step.
                        controller.recordManualTemperature(pullTarget, at: now)
                    } else {
                        controller.continueWithoutThermometer(at: now)
                    }
                } else {
                    controller.confirmCurrentAction(at: now)
                }

            case .takeOut:
                controller.confirmCurrentAction(at: now)

            case .eat:
                break
            }
        }

        return observed
    }

    /// Collapses consecutive repeats, so a milestone that is observed many times
    /// (frequent flips, a running timer) counts once.
    private func milestones(_ observed: [Int]) -> [Int] {
        observed.reduce(into: []) { result, step in
            if result.last != step { result.append(step) }
        }
    }

    func testStripSessionCountsOneThroughSeven() {
        let start = Date(timeIntervalSince1970: 500_000)
        let controller = makeController(at: start)
        startCooking(controller, cut: .strip, at: start)

        let observed = walk(controller, from: start, usingThermometer: true)

        XCTAssertEqual(controller.journey.totalSteps, 7)
        XCTAssertEqual(
            observed,
            observed.sorted(),
            "The counter must never go backwards, saw \(observed)"
        )
        XCTAssertEqual(observed.first, 1)
        XCTAssertEqual(observed.last, 7, "Saw \(observed)")
        // The exact route the requirement describes, with repeat observations of
        // one milestone (frequent flips, a running timer) collapsed.
        XCTAssertEqual(
            milestones(observed),
            [1, 2, 3, 4, 5, 6, 7],
            "Strip should walk SEAR → FLIP → FAT CAP → ADD BUTTER → BASTE → "
                + "CHECK TEMP → TAKE OUT, saw \(observed)"
        )
    }

    func testRibeyeSessionNeverCountsPastSix() {
        let start = Date(timeIntervalSince1970: 600_000)
        let controller = makeController(at: start)
        startCooking(controller, cut: .ribeye, at: start)

        let observed = walk(controller, from: start, usingThermometer: true)

        XCTAssertEqual(controller.journey.totalSteps, 6)
        XCTAssertEqual(observed, observed.sorted())
        XCTAssertEqual(observed.first, 1)
        XCTAssertEqual(observed.last, 6, "Saw \(observed)")
        XCTAssertEqual(
            milestones(observed),
            [1, 2, 3, 4, 5, 6],
            "Ribeye should walk SEAR → FLIP → ADD BUTTER → BASTE → CHECK TEMP "
                + "→ TAKE OUT with no fat-cap gap, saw \(observed)"
        )
        XCTAssertLessThanOrEqual(
            observed.max() ?? 0,
            6,
            "A six-step route must never display a seventh step"
        )
    }

    /// The fallback sends the session back into the searing loop after BASTE and
    /// CHECK TEMP. This is the case that used to make the number jump backwards.
    func testNoThermometerFallbackNeverWalksTheCounterBackwards() {
        let start = Date(timeIntervalSince1970: 700_000)
        let controller = makeController(at: start)
        startCooking(controller, cut: .strip, at: start)

        let observed = walk(controller, from: start, usingThermometer: false)

        XCTAssertFalse(observed.isEmpty, "The walk should have observed the counter")
        XCTAssertEqual(
            observed,
            observed.sorted(),
            "The no-thermometer fallback must not walk the counter back, saw \(observed)"
        )
        XCTAssertGreaterThanOrEqual(
            observed.max() ?? 0,
            5,
            "The fallback should still pass through BASTE, saw \(observed)"
        )
    }

    /// The journey only starts when the pan is ready, so PREP and HEAT show
    /// `00 / total` rather than already counting the first sear.
    func testCounterStaysAtZeroUntilThePanIsReady() {
        let start = Date(timeIntervalSince1970: 800_000)
        let controller = makeController(at: start)

        XCTAssertEqual(controller.cookingProgress?.label, "00 / 06")

        controller.finishSetup(at: start)
        XCTAssertEqual(controller.cookingProgress?.label, "00 / 06")

        controller.finishPrep(at: start)
        XCTAssertEqual(controller.cookingProgress?.label, "00 / 06")

        controller.panIsReady(at: start)
        XCTAssertEqual(controller.cookingProgress?.label, "01 / 06")
    }

    /// The counter disappears once the steak is out of the pan: resting is not
    /// the next cook step.
    func testCounterDisappearsOnceTheSteakIsResting() {
        let start = Date(timeIntervalSince1970: 900_000)
        let controller = makeController(at: start)
        startCooking(controller, cut: .ribeye, at: start)
        _ = walk(controller, from: start, usingThermometer: true)
        controller.refresh(at: start)

        XCTAssertEqual(controller.session.phase, .finishing)
        XCTAssertNil(
            controller.cookingProgress,
            "FINISHING must not be numbered as a cook step"
        )
    }

    /// The milestone survives a relaunch, and a relaunch cannot lower it.
    func testMilestoneIsPersistedAndReloads() {
        let suite = "CookingProgressIntegrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000_000)
        let controller = CookingSessionController(
            store: store,
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            now: start
        )
        startCooking(controller, cut: .strip, at: start)
        _ = walk(controller, from: start, usingThermometer: true)
        let reached = controller.session.journeyMilestone

        let reloaded = CookingSessionController(store: store, now: start)
        XCTAssertEqual(reloaded.session.journeyMilestone, reached)
        XCTAssertEqual(
            reloaded.cookingProgress,
            controller.cookingProgress,
            "A relaunch must not change the counter"
        )
    }
}
