import XCTest
@testable import SteakCopilot

/// The session progress rail.
///
/// The rail is a second view of the same walk the `05 / 07` counter shows, and
/// it used to be mapped per `CookingPhase`. That mapping stepped **backwards**
/// at the one moment the route legitimately returns to the searing loop: the
/// no-thermometer fallback goes BASTE → `.sear` after the baste window, and
/// `.baste` was a fixed `0.62` while `.sear` was a fraction of the cooking
/// budget — `0.12 + 0.48 × (159.25 + 31.36) / 245 = 0.493` for the default
/// ribeye 3cm Medium Rare.
///
/// These tests pin the three properties that replaced it: monotonicity along the
/// route, agreement with the counter, and monotonicity through a real controller
/// walk that actually performs the BASTE → SEAR re-entry.
@MainActor
final class SessionProgressRailTests: XCTestCase {
    private let engine = CookingEngine()
    private let start = Date(timeIntervalSince1970: 700_000)

    private let ribeye = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
    private let strip = SteakConfiguration(cut: .strip, thicknessCM: 3, doneness: .mediumRare)

    // MARK: - Helpers

    private func profile(_ configuration: SteakConfiguration) -> CookingProfile {
        engine.profile(for: configuration, calibration: .neutral)
    }

    private func rail(
        phase: CookingPhase,
        milestone: CookingJourneyStep?,
        journey: CookingJourney,
        elapsed: TimeInterval,
        budget: TimeInterval
    ) -> Double {
        SessionProgressRail.progress(
            phase: phase,
            milestone: milestone,
            journey: journey,
            estimatedProgress: min(max(elapsed / budget, 0), 1)
        )
    }

    /// The same inputs the session view passes, read off a live controller.
    private func rail(_ controller: CookingSessionController) -> Double {
        SessionProgressRail.progress(
            phase: controller.session.phase,
            milestone: controller.session.journeyMilestone,
            journey: controller.journey,
            estimatedProgress: controller.guidance.estimatedProgress
        )
    }

    private func segment(
        of step: CookingJourneyStep,
        in journey: CookingJourney
    ) -> ClosedRange<Double> {
        let position = Double(journey.position(of: step) ?? 1)
        let steps = Double(journey.totalSteps)
        let span = SessionProgressRail.cookCeiling - SessionProgressRail.cookFloor
        let lower = SessionProgressRail.cookFloor + span * (position - 1) / steps
        let upper = SessionProgressRail.cookFloor + span * position / steps
        return lower...upper
    }

    // MARK: - The regression

    /// The exact defect: returning to the searing loop after BASTE must not move
    /// the rail back.
    func testTheBasteToSearReEntryDoesNotStepTheRailBack() {
        let configuration = ribeye
        let cutProfile = profile(configuration)
        let journey = CookingJourney(configuration: configuration)
        let budget = cutProfile.estimatedCookingBudget
        let basteEnd = cutProfile.lateStageDateOffset + cutProfile.basteDuration

        let atBasteEnd = rail(
            phase: .baste,
            milestone: .baste,
            journey: journey,
            elapsed: basteEnd,
            budget: budget
        )
        // The mistake was tapping FLIP here, which returns the phase to `.sear`.
        let afterReEntry = rail(
            phase: .sear,
            milestone: .baste,
            journey: journey,
            elapsed: basteEnd,
            budget: budget
        )

        XCTAssertGreaterThanOrEqual(
            afterReEntry,
            atBasteEnd,
            "BASTE → SEAR must not move the rail backwards"
        )
        // The old phase mapping would have produced 0.62 -> 0.493 here.
        XCTAssertEqual(
            afterReEntry,
            atBasteEnd,
            accuracy: 0.001,
            "The rail should hold while the loop runs its last flips"
        )
    }

    /// The re-entry is a real part of the production route, not a hypothetical:
    /// drive the controller and prove the walk performs it.
    func testAControllerWalkNeverMovesTheRailBackwards() {
        let fixture = makeController()
        let controller = fixture.controller
        var samples: [(phase: CookingPhase, rail: Double)] = [(controller.session.phase, rail(controller))]
        var sawReEntry = false
        var wasBasting = false

        for _ in 0..<20 {
            let due = try! XCTUnwrap(controller.session.nextActionAt)
            controller.refresh(at: due)
            samples.append((controller.session.phase, rail(controller)))

            if controller.session.phase == .baste { wasBasting = true }
            if wasBasting, controller.session.phase == .sear { sawReEntry = true }

            let action = controller.guidance.currentAction
            controller.confirmCurrentAction(at: due)
            samples.append((controller.session.phase, rail(controller)))
            if action == .takeOut { break }
        }

        for (previous, next) in zip(samples, samples.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                next.rail,
                previous.rail - 0.0001,
                """
                The rail moved backwards: \(previous.phase) \(previous.rail) \
                → \(next.phase) \(next.rail)
                """
            )
        }

        XCTAssertTrue(
            sawReEntry,
            "The walk never re-entered the searing loop, so the regression is untested"
        )
        XCTAssertGreaterThanOrEqual(
            samples.last!.rail,
            SessionProgressRail.finishingProgress,
            "The rail must end the cook at the resting position"
        )
    }

    // MARK: - Monotonicity and agreement with the counter

    /// The property that makes the rail monotone along *any* real walk: it is
    /// non-decreasing in both of its monotone inputs. The milestone only
    /// advances (the journey's high-water mark) and `estimatedProgress` only
    /// advances, so the composite cannot step back — including across the
    /// BASTE → SEAR re-entry, where the phase moves back but the milestone
    /// does not.
    func testTheRailIsNonDecreasingInBothOfItsInputs() {
        let fractions = stride(from: 0.0, through: 1.0, by: 0.1).map { $0 }

        for configuration in [ribeye, strip] {
            let budget = profile(configuration).estimatedCookingBudget
            let journey = CookingJourney(configuration: configuration)

            // A later milestone can only move the rail forward…
            for phase: CookingPhase in [.sear, .fatCap, .baste] {
                for fraction in fractions {
                    var previous = 0.0
                    for step in journey.steps {
                        let value = rail(
                            phase: phase,
                            milestone: step,
                            journey: journey,
                            elapsed: fraction * budget,
                            budget: budget
                        )
                        XCTAssertGreaterThanOrEqual(
                            value,
                            previous - 0.0001,
                            """
                            \(configuration.cut.rawValue) \(phase) at \
                            \(fraction): \(step) moved the rail back to \(value)
                            """
                        )
                        previous = value
                    }
                }
            }

            // …and so can more elapsed time, at a fixed step.
            for phase: CookingPhase in [.sear, .fatCap, .baste] {
                for step in journey.steps {
                    var previous = 0.0
                    for fraction in fractions {
                        let value = rail(
                            phase: phase,
                            milestone: step,
                            journey: journey,
                            elapsed: fraction * budget,
                            budget: budget
                        )
                        XCTAssertGreaterThanOrEqual(
                            value,
                            previous - 0.0001,
                            """
                            \(configuration.cut.rawValue) \(phase) \(step) at \
                            \(fraction) went backwards to \(value)
                            """
                        )
                        previous = value
                    }
                }
            }
        }
    }

    /// The rail and the `05 / 07` counter can never disagree: the bar sits inside
    /// the segment of the step the counter is displaying.
    func testTheRailStaysInsideTheCurrentStepsSegment() {
        let journey = CookingJourney(configuration: strip)

        for step in journey.steps {
            let bounds = segment(of: step, in: journey)
            for elapsedFraction in [0.0, 0.25, 0.5, 0.75, 1.0, 1.5] {
                let value = rail(
                    phase: .sear,
                    milestone: step,
                    journey: journey,
                    elapsed: elapsedFraction * 240,
                    budget: 240
                )
                XCTAssertGreaterThanOrEqual(value, bounds.lowerBound - 0.0001, "\(step)")
                XCTAssertLessThanOrEqual(value, bounds.upperBound + 0.0001, "\(step)")
            }
        }
    }

    /// Before the pan is on the heat the rail is behind the whole route, and
    /// resting is behind neither.
    func testTheRailIsOrderedAcrossTheNonCookPhases() {
        let journey = CookingJourney(configuration: ribeye)

        XCTAssertLessThan(SessionProgressRail.setupProgress, SessionProgressRail.prepProgress)
        XCTAssertLessThan(SessionProgressRail.prepProgress, SessionProgressRail.heatProgress)
        XCTAssertLessThan(SessionProgressRail.heatProgress, SessionProgressRail.cookFloor)
        XCTAssertLessThan(SessionProgressRail.cookCeiling, SessionProgressRail.finishingProgress)
        XCTAssertLessThan(SessionProgressRail.finishingProgress, SessionProgressRail.doneProgress)

        for phase: CookingPhase in [.finishing] {
            let resting = rail(
                phase: phase,
                milestone: journey.finalStep,
                journey: journey,
                elapsed: 240,
                budget: 240
            )
            XCTAssertEqual(resting, SessionProgressRail.finishingProgress, accuracy: 0.0001)
        }
        for phase: CookingPhase in [.ready, .eat, .feedback] {
            let done = rail(
                phase: phase,
                milestone: journey.finalStep,
                journey: journey,
                elapsed: 240,
                budget: 240
            )
            XCTAssertEqual(done, SessionProgressRail.doneProgress, accuracy: 0.0001)
        }
    }

    // MARK: - Fixture

    private func makeController() -> (controller: CookingSessionController, start: Date) {
        let suite = "SessionProgressRailTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let controller = CookingSessionController(
            store: CookingStore(defaults: defaults),
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            now: start
        )
        controller.updateConfiguration(ribeye)
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
        return (controller, start)
    }
}
