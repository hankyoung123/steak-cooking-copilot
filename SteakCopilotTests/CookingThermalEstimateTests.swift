import XCTest
@testable import SteakCopilot

/// The estimated centre temperature.
///
/// This value replaced a probe reading on the status band, so the two properties
/// that matter are that it behaves like a heat-transfer estimate rather than a
/// linear ramp, and that it is *only* a display: it must never reach a decision.
@MainActor
final class CookingThermalEstimateTests: XCTestCase {
    private let engine = CookingEngine(tuning: .production)
    private let start = Date(timeIntervalSince1970: 0)

    private func session() -> CookingSession {
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(30)
        )
        session.startedAt = start
        return session
    }

    private func profile() -> CookingProfile {
        engine.profile(for: session().configuration, calibration: .neutral)
    }

    private func estimate(at offset: TimeInterval) -> Double? {
        engine.estimatedCentreTemperatureC(
            for: session(),
            at: start.addingTimeInterval(offset),
            profile: profile()
        )
    }

    // MARK: - Anchoring

    /// The curve starts at the assumed initial centre temperature, so the model
    /// has no discontinuity when the pan goes on.
    func testEstimateStartsAtTheInitialCentreTemperature() {
        XCTAssertEqual(
            try! XCTUnwrap(estimate(at: 0)),
            AppTuning.production.thermal.initialCentreTemperatureC,
            accuracy: 0.001
        )
    }

    /// The whole reason the time constant is solved rather than taken from a
    /// measured diffusivity: the estimate and the schedule have to agree, or the
    /// screen would say "keep cooking" while the app says "take it out".
    func testEstimateReachesTheSuggestedTemperatureExactlyAtTheEstimatedPull() {
        let budget = profile().estimatedCookingBudget

        XCTAssertEqual(
            try! XCTUnwrap(estimate(at: budget)),
            profile().pullTemperatureC,
            accuracy: 0.001
        )
    }

    func testEstimateIsMonotonicAndBoundedByTheSurfaceTemperature() {
        let surface = AppTuning.production.thermal.surfaceTemperatureC
        let budget = profile().estimatedCookingBudget

        var previous = -Double.infinity
        for step in stride(from: 0.0, through: budget * 3, by: budget / 20) {
            let value = try! XCTUnwrap(estimate(at: step))
            XCTAssertGreaterThan(value, previous, "estimate must keep rising at \(step)s")
            XCTAssertLessThanOrEqual(value, surface)
            previous = value
        }
    }

    /// The shape comes from the heat equation's first term, where the
    /// temperature deficit decays exponentially: fast at first, then saturating.
    /// A linear interpolation would land exactly on the midpoint, so this is the
    /// test that distinguishes the two.
    func testEstimateIsConcaveLikeConductionNotLinear() {
        let thermal = AppTuning.production.thermal
        let midpoint = (thermal.initialCentreTemperatureC + profile().pullTemperatureC) / 2
        let halfway = try! XCTUnwrap(estimate(at: profile().estimatedCookingBudget / 2))

        XCTAssertGreaterThan(
            halfway,
            midpoint,
            "half-way through the time the centre should be past half-way in "
                + "temperature, which is what an exponential approach does"
        )
    }

    /// The first half of the time does more than half the work; the second half
    /// does less. That ordering is the convexity of an exponential.
    func testEarlyProgressOutpacesLateProgress() {
        let budget = profile().estimatedCookingBudget
        let initial = AppTuning.production.thermal.initialCentreTemperatureC
        let firstHalf = try! XCTUnwrap(estimate(at: budget / 2)) - initial
        let secondHalf = try! XCTUnwrap(estimate(at: budget)) - initial - firstHalf

        XCTAssertGreaterThan(firstHalf, secondHalf)
    }

    func testNoEstimateBeforeTheCookHasStarted() {
        let fresh = CookingSession.fresh(at: start)
        XCTAssertNil(
            engine.estimatedCentreTemperatureC(
                for: fresh,
                at: start,
                profile: profile()
            ),
            "a session that has not started has nothing to estimate"
        )
    }

    // MARK: - Display only

    /// The estimate must not be able to move anything. Swapping in absurd thermal
    /// parameters leaves the profile, the sear boundary and the whole guidance
    /// identical while the estimate itself changes — which is the isolation this
    /// feature depends on.
    func testEstimateCannotInfluenceAnyDecision() {
        var altered = AppTuning.production
        altered.thermal.surfaceTemperatureC = 900
        altered.thermal.initialCentreTemperatureC = -60
        let alteredEngine = CookingEngine(tuning: altered)

        let session = session()
        let at = start.addingTimeInterval(40)
        let normalProfile = engine.profile(for: session.configuration, calibration: .neutral)
        let alteredProfile = alteredEngine.profile(
            for: session.configuration,
            calibration: .neutral
        )

        XCTAssertEqual(normalProfile, alteredProfile, "the schedule must not move")
        XCTAssertEqual(
            engine.searBoundary(for: session, profile: normalProfile, from: at),
            alteredEngine.searBoundary(for: session, profile: alteredProfile, from: at)
        )
        XCTAssertEqual(
            engine.guidance(for: session, at: at, calibration: .neutral),
            alteredEngine.guidance(for: session, at: at, calibration: .neutral),
            "guidance carries every decision input and must be unchanged"
        )

        XCTAssertNotEqual(
            engine.estimatedCentreTemperatureC(
                for: session,
                at: at,
                profile: normalProfile
            ),
            alteredEngine.estimatedCentreTemperatureC(
                for: session,
                at: at,
                profile: alteredProfile
            ),
            "the estimate should be the only thing that moved"
        )
    }
}

/// The flip countdown shown while searing.
@MainActor
final class CookingFlipCountdownTests: XCTestCase {
    private let engine = CookingEngine(tuning: .production)
    private let start = Date(timeIntervalSince1970: 0)

    private func session() -> CookingSession {
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(30)
        )
        session.startedAt = start
        return session
    }

    private func profile() -> CookingProfile {
        engine.profile(for: session().configuration, calibration: .neutral)
    }

    private func flips(at offset: TimeInterval = 0, _ mutate: (inout CookingSession) -> Void = { _ in }) -> Int? {
        var session = session()
        mutate(&session)
        return engine.remainingSearFlips(
            for: session,
            profile: profile(),
            at: start.addingTimeInterval(offset)
        )
    }

    /// Counted independently of the implementation: flips land on multiples of
    /// the interval, and only those strictly before the late-stage date happen,
    /// because a flip tying with the late stage loses the tie-break.
    func testCountsTheFlipBoundariesBeforeTheLateStage() {
        let profile = profile()
        var expected = 0
        while TimeInterval(expected + 1) * profile.flipInterval
            < profile.lateStageDateOffset {
            expected += 1
        }

        XCTAssertGreaterThan(expected, 1, "the fixture should leave room for flips")
        XCTAssertEqual(flips(), expected)
    }

    /// The count falls by exactly one per flip interval, which is what makes it
    /// a countdown rather than a static plan total.
    func testCountFallsByOneEachFlipInterval() {
        let interval = profile().flipInterval
        let initial = try! XCTUnwrap(flips())
        let later = try! XCTUnwrap(flips(at: interval))

        XCTAssertEqual(later, initial - 1)
    }

    /// Once the late stage is closer than one interval there is no flip left, so
    /// the line disappears rather than promising a flip that will not be asked
    /// for.
    func testNoFlipsRemainJustBeforeTheLateStage() {
        let profile = profile()

        XCTAssertEqual(flips(at: profile.lateStageDateOffset - profile.flipInterval / 2), 0)
        XCTAssertNil(flips(at: profile.lateStageDateOffset + 1))
    }

    /// Butter is the end of the flip flow, which is what the user asked the count
    /// to stop at.
    func testNoCountOnceButterIsInThePan() {
        XCTAssertNil(flips { $0.butterAddedAt = self.start.addingTimeInterval(10) })
    }

    /// Only the searing loop flips, so the count is not offered anywhere else.
    func testNoCountOutsideTheSearingLoop() {
        for phase: CookingPhase in [.prep, .heat, .fatCap, .baste, .checkTemperature, .finishing] {
            XCTAssertNil(
                flips { $0.phase = phase },
                "\(phase) must not show a flip countdown"
            )
        }
    }

    /// Frequent flipping is one journey milestone, and the countdown keeps
    /// falling rather than restarting.
    func testRepeatedFlipsKeepCountingDown() {
        let interval = profile().flipInterval
        let counts = (0..<3).map { try! XCTUnwrap(flips(at: Double($0) * interval)) }

        XCTAssertEqual(counts, counts.sorted(by: >))
        XCTAssertEqual(counts[0] - counts[2], 2)
    }
}

/// The probe-reading entry point is hidden, and the capability behind it is not.
@MainActor
final class ProbeReadingAvailabilityTests: XCTestCase {
    private func makeController(at start: Date) -> CookingSessionController {
        let suite = "ProbeReadingAvailabilityTests.\(UUID().uuidString)"
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
        at start: Date,
        cut: SteakCut = .ribeye
    ) {
        controller.updateConfiguration(SteakConfiguration(cut: cut, thicknessCM: 4))
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
    }

    /// With no reading entry point the cook has to run on the timing estimate,
    /// which is the engine's own no-thermometer path.
    func testPanIsReadyPutsTheCookOnTheTimingEstimate() {
        let start = Date(timeIntervalSince1970: 2_000_000)
        let controller = makeController(at: start)
        startCooking(controller, at: start)

        XCTAssertNotNil(
            controller.session.thermometerUnavailableAt,
            "the timing estimate is the only path when no reading can be entered"
        )
    }

    /// The reading-entry phase must never be reached, because there would be no
    /// way to satisfy it.
    func testTheReadingEntryPhaseIsNeverEntered() {
        let start = Date(timeIntervalSince1970: 2_100_000)
        let controller = makeController(at: start)
        startCooking(controller, at: start, cut: .strip)

        var now = start
        var seen: Set<CookingPhase> = []

        for _ in 0..<200 {
            controller.refresh(at: now)
            seen.insert(controller.session.phase)
            XCTAssertNotEqual(
                controller.session.phase,
                .checkTemperature,
                "the reading-entry phase has no way out any more"
            )
            if controller.session.phase == .finishing { break }

            if let due = controller.session.nextActionAt, due > now {
                now = due
            } else {
                now = now.addingTimeInterval(1)
            }
            controller.refresh(at: now)

            switch controller.guidance.currentAction {
            case .wait, .baste, .waitForFinish:
                continue
            case .standFatCap where controller.session.phase == .fatCap:
                continue
            default:
                controller.confirmCurrentAction(at: now)
            }
        }

        XCTAssertTrue(seen.contains(.sear))
        XCTAssertTrue(seen.contains(.finishing), "the cook should have finished")
    }

    /// Hiding the entry point must not have removed the capability: a reading
    /// still overrides the timing estimate, exactly as it always did.
    func testAReadingStillOverridesTheTimingEstimate() {
        let start = Date(timeIntervalSince1970: 2_200_000)
        let controller = makeController(at: start)
        startCooking(controller, at: start)

        let readingAt = start.addingTimeInterval(5)
        controller.recordManualTemperature(
            controller.guidance.pullTemperatureC + 5,
            at: readingAt
        )
        controller.refresh(at: readingAt)

        XCTAssertEqual(
            controller.guidance.currentAction,
            .takeOut,
            "a reading over the pull target must still win over the timing estimate"
        )
        XCTAssertEqual(controller.session.lastManualTemperatureC, controller.guidance.pullTemperatureC + 5)
        XCTAssertNil(
            controller.session.thermometerUnavailableAt,
            "a real reading takes the session off the timing fallback"
        )
    }

    /// The estimate is exposed for display, and is absent before the pan is on.
    func testEstimatedTemperatureIsAvailableOnceCooking() {
        let start = Date(timeIntervalSince1970: 2_300_000)
        let controller = makeController(at: start)

        XCTAssertNil(controller.estimatedCentreTemperatureC(at: start))

        startCooking(controller, at: start)
        let value = try! XCTUnwrap(controller.estimatedCentreTemperatureC(at: start))
        XCTAssertEqual(
            value,
            AppTuning.production.thermal.initialCentreTemperatureC,
            accuracy: 0.001
        )
    }

    /// A session saved by a build that still asked for a reading must not come
    /// back stuck on a screen it cannot satisfy.
    func testRestoredReadingEntrySessionIsPutBackOnTheTimingEstimate() {
        let suite = "ProbeReadingAvailabilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 2_400_000)

        var saved = CookingSession.fixture(
            phase: .checkTemperature,
            phaseStartedAt: start,
            nextActionAt: nil
        )
        saved.startedAt = start
        store.save(session: saved)

        let controller = CookingSessionController(store: store, now: start)

        XCTAssertEqual(controller.session.phase, .sear)
        XCTAssertNotNil(controller.session.thermometerUnavailableAt)
        XCTAssertNotNil(controller.session.nextActionAt)
    }
}
