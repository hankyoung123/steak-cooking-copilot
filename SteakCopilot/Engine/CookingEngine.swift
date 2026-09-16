import Foundation

struct CookingGuidance: Equatable, Sendable {
    let phase: CookingPhase
    let currentAction: CookingAction
    let nextAction: CookingAction?
    let nextActionAt: Date?
    let remainingTime: TimeInterval
    let estimatedProgress: Double
    let pullRecommendation: PullRecommendation
    let targetTemperatureC: Double
    let pullTemperatureC: Double
    let lastManualTemperatureC: Double?
    let finishingEstimate: ClosedRange<TimeInterval>
    let event: CookingEvent?

    static func idle(
        phase: CookingPhase = .setup,
        tuning: AppTuning = .production
    ) -> CookingGuidance {
        let baseline = tuning.doneness[.mediumRare]
        return CookingGuidance(
            phase: phase,
            currentAction: .wait,
            nextAction: nil,
            nextActionAt: nil,
            remainingTime: 0,
            estimatedProgress: 0,
            pullRecommendation: .keepCooking,
            targetTemperatureC: baseline.targetTemperatureC,
            pullTemperatureC: baseline.pullTemperatureC,
            lastManualTemperatureC: nil,
            finishingEstimate: tuning.finishing.idleEstimate,
            event: nil
        )
    }
}

/// Which candidate produced a scheduled sear-stage boundary. The kind is
/// derived by comparing dates against the same candidates the boundary was
/// scheduled from, so the announced next action and `nextActionAt` always
/// agree.
enum SearBoundaryKind: String, Equatable, Sendable {
    case estimatedPull
    case lateStage
    case flip

    /// Lower priority wins on an exact tie, so the user is never told to
    /// flip when the pull boundary or the late stage has already come due.
    var tieBreakPriority: Int {
        switch self {
        case .estimatedPull: 0
        case .lateStage: 1
        case .flip: 2
        }
    }
}

struct SearBoundary: Equatable, Sendable {
    let kind: SearBoundaryKind
    let date: Date
}

extension CookingGuidance {
    /// The action the user will actually be asked to perform when
    /// `nextActionAt` arrives. Notifications, the Live Activity and the
    /// in-app instruction all read this, so none of them can promise a
    /// different action than the app presents at that moment.
    ///
    /// While a stage timer is running (sear wait, fat cap, baste, finishing)
    /// the scheduled action is `nextAction`; once the boundary has passed
    /// the current action already is the pending one.
    var announcedNextAction: CookingAction {
        nextAction ?? currentAction
    }
}

struct CookingEngine: Sendable {
    /// Production tuning generated from Config/production.yaml. Every tunable
    /// number in this engine comes from here; there are no literals to drift.
    let tuning: AppTuning

    init(tuning: AppTuning = .production) {
        self.tuning = tuning
    }

    func flipInterval(for configuration: SteakConfiguration) -> TimeInterval {
        tuning.cooking.flipInterval(thicknessCM: configuration.thicknessCM)
    }

    func profile(
        for configuration: SteakConfiguration,
        calibration: CookingCalibration,
        timeScale: Double = 1
    ) -> CookingProfile {
        let cooking = tuning.cooking
        let doneness = configuration.doneness.spec(in: tuning)
        let cut = configuration.cut.spec(in: tuning)
        let scale = max(0.01, timeScale)
        // Ideal in-pan heat exposure for this thickness: linear, anchored at
        // `referenceThickness`, with no allowance for how long the user takes
        // to react. Reaction delay is the interaction layer's problem (early
        // reminders, haptics, absolute deadlines, and compressing whatever
        // follows a late step), so it is deliberately not added back here.
        let exposure = cooking.exposureTime(thicknessCM: configuration.thicknessCM)
        let rawBudget = exposure
            * doneness.cookingBudgetFactor
            + cut.cookingBudgetOffset
            + calibration.cookingTimeAdjustment
        let budget = min(
            max(rawBudget, cooking.minCookingBudget),
            cooking.maxCookingBudget
        ) * scale
        let flip = flipInterval(for: configuration) * scale
        let budgetFinishAdjustment = min(
            max(
                (rawBudget - cooking.baseCookingBudget)
                    * cooking.budgetFinishAdjustmentRatio,
                cooking.budgetFinishAdjustmentMinSeconds
            ),
            cooking.budgetFinishAdjustmentMaxSeconds
        )
        let finishing = tuning.finishing
        let lowerFinish = (
            finishing.baseAdjustmentSeconds
                + configuration.thicknessCM * finishing.thicknessAdjustmentPerCM
                + finishing.donenessAdjustment[configuration.doneness]
                + budgetFinishAdjustment
        ) * scale
        let estimatedBudget = max(
            flip * cooking.minBudgetInFlipIntervals,
            budget
        )
        let lateStageDateOffset = max(
            max(cooking.minFlipInterval, flip) * cooking.lateStageMinFlipIntervals,
            estimatedBudget * cooking.lateStageRatio + calibration.searBias * scale
        )

        return CookingProfile(
            flipInterval: max(cooking.minFlipInterval, flip),
            estimatedCookingBudget: estimatedBudget,
            initialSearBias: calibration.searBias * scale,
            fatCapDuration: cut.fatCapDuration.map {
                max(cooking.minFatCapDuration, $0 * scale)
            },
            basteDuration: max(
                cooking.minBasteDuration,
                min(
                    cooking.maxBasteDuration,
                    // Shared baseline ratio, adjusted per cut. Clamp order
                    // (clamp, then time-scale) is unchanged.
                    rawBudget * cooking.basteRatio * cut.basteMultiplier
                ) * scale
            ),
            targetTemperatureC: doneness.targetTemperatureC,
            pullTemperatureC: doneness.pullTemperatureC,
            finishingEstimate: max(
                finishing.minLowerBoundSeconds,
                lowerFinish
            )...max(
                finishing.minUpperBoundSeconds,
                lowerFinish + finishing.spreadSeconds * scale
            ),
            flipPullGuard: cooking.minSecondsAfterFlipBeforePull * scale,
            lateStageDateOffset: lateStageDateOffset
        )
    }

    func guidance(
        for session: CookingSession,
        at date: Date,
        calibration: CookingCalibration = .neutral,
        timeScale: Double = 1
    ) -> CookingGuidance {
        let profile = profile(
            for: session.configuration,
            calibration: calibration,
            timeScale: timeScale
        )
        let remaining = session.remaining(at: date)
        let elapsed = max(0, date.timeIntervalSince(session.startedAt ?? date))
        let estimatedProgress = min(max(elapsed / profile.estimatedCookingBudget, 0), 1)
        let lateStageAt = lateStageDate(for: session, profile: profile)
        let estimatedPullAt = estimatedPullDate(for: session, profile: profile)
        let pullRecommendation = pullRecommendation(
            for: session,
            profile: profile,
            at: date,
            estimatedPullAt: estimatedPullAt
        )
        let action = currentAction(
            for: session,
            at: date,
            profile: profile,
            pullRecommendation: pullRecommendation,
            lateStageAt: lateStageAt
        )
        let nextAction = nextAction(
            for: session,
            action: action,
            at: date,
            profile: profile
        )
        let finishingEstimate = finishingEstimate(
            for: session,
            profile: profile
        )

        return CookingGuidance(
            phase: session.phase,
            currentAction: action,
            nextAction: nextAction,
            nextActionAt: session.nextActionAt,
            remainingTime: remaining,
            estimatedProgress: estimatedProgress,
            pullRecommendation: pullRecommendation,
            targetTemperatureC: profile.targetTemperatureC,
            pullTemperatureC: profile.pullTemperatureC,
            lastManualTemperatureC: session.lastManualTemperatureC,
            finishingEstimate: finishingEstimate,
            event: event(
                for: session,
                action: action,
                nextAction: nextAction,
                remaining: remaining
            )
        )
    }

    /// Authoritative boundary where frequent-flip searing ends and the
    /// late stage (fat cap / butter) begins. Derived from the absolute
    /// cooking start date, so it is stable across refreshes.
    func lateStageDate(
        for session: CookingSession,
        profile: CookingProfile
    ) -> Date {
        (session.startedAt ?? session.phaseStartedAt)
            .addingTimeInterval(profile.lateStageDateOffset)
    }

    /// Authoritative estimated pull boundary used by the no-thermometer
    /// timing fallback. Never represented as a temperature.
    func estimatedPullDate(
        for session: CookingSession,
        profile: CookingProfile
    ) -> Date {
        (session.startedAt ?? session.phaseStartedAt)
            .addingTimeInterval(profile.estimatedCookingBudget)
    }

    /// The estimated pull date when — and only when — the timing fallback is
    /// what decides the pull.
    ///
    /// With a probe in play the pull depends on a reading that has not happened
    /// yet, so there is no absolute deadline for the late stage to compress
    /// against; the estimate is a display anchor, not a decision.
    func fallbackPullDate(
        for session: CookingSession,
        profile: CookingProfile
    ) -> Date? {
        session.thermometerUnavailableAt != nil
            ? estimatedPullDate(for: session, profile: profile)
            : nil
    }

    /// Absolute end of the fat-cap window.
    func fatCapEndDate(
        for session: CookingSession,
        profile: CookingProfile
    ) -> Date {
        lateStagePlanEnd(for: session, profile: profile, extra: 0)
    }

    /// Absolute end of the baste window: the plan's fat-cap end plus the baste
    /// duration, so a late ADD BUTTER shortens the baste instead of delaying
    /// TAKE IT OUT.
    func basteEndDate(
        for session: CookingSession,
        profile: CookingProfile
    ) -> Date {
        lateStagePlanEnd(
            for: session,
            profile: profile,
            extra: profile.basteDuration
        )
    }

    /// The late stage runs on the **plan's** absolute timeline — fat cap first,
    /// then the baste, then TAKE IT OUT — rather than each window starting when
    /// the user finally taps. A step taken 8s late therefore eats 8s out of the
    /// window that follows it instead of pushing the pull 8s later.
    ///
    /// In the timing fallback the estimated pull date caps the whole sequence,
    /// so the late stage can never run past the moment the plan says to pull.
    private func lateStagePlanEnd(
        for session: CookingSession,
        profile: CookingProfile,
        extra: TimeInterval
    ) -> Date {
        let planned = lateStageDate(for: session, profile: profile)
            .addingTimeInterval((profile.fatCapDuration ?? 0) + extra)
        guard let pull = fallbackPullDate(for: session, profile: profile) else {
            return planned
        }
        return min(planned, pull)
    }

    /// Whether a flip taken at `date` would be immediately followed by TAKE IT
    /// OUT. Only the timing fallback can answer this: with a probe the pull
    /// follows a reading that has not happened yet.
    ///
    /// The guard scales with the profile, so a fast-cooked (test time scale)
    /// session keeps the same route instead of having every flip suppressed by
    /// a guard that is longer than the whole cook.
    func isFlipPointless(
        for session: CookingSession,
        profile: CookingProfile,
        at date: Date
    ) -> Bool {
        guard let pull = fallbackPullDate(for: session, profile: profile) else {
            return false
        }
        return pull.timeIntervalSince(date) < profile.flipPullGuard
    }

    /// Estimated centre temperature at `date`, in °C.
    ///
    /// **Display only.** This value is never an input to `pullRecommendation`,
    /// `searBoundary`, `nextActionAt`, or any other decision — it exists so the
    /// screen can show a model estimate where it used to show a probe reading.
    /// `TuningConfigurationTests` asserts that the estimate cannot move the
    /// schedule.
    ///
    /// The shape is the first term of the one-dimensional slab solution: the
    /// centre's temperature deficit decays exponentially towards the effective
    /// surface temperature, so the rise is fast early and saturates late rather
    /// than interpolating linearly. The time constant is solved from the app's
    /// own pull estimate,
    ///
    ///     T(t) = T_s − (T_s − T_0)·exp(−t/τ),   τ = t_pull / ln((T_s − T_0)/(T_s − T_pull))
    ///
    /// which anchors the curve so the estimate reaches the suggested pull
    /// temperature exactly when the schedule says to pull. Substituting a
    /// measured diffusivity instead would let the estimate disagree with the
    /// timing and tell the user to keep cooking while the app says to take the
    /// steak out.
    ///
    /// Returns `nil` before the pan is on the heat, and whenever the anchors do
    /// not bracket the pull temperature (an override could otherwise make the
    /// logarithm undefined).
    func estimatedCentreTemperatureC(
        for session: CookingSession,
        at date: Date,
        profile: CookingProfile
    ) -> Double? {
        guard let startedAt = session.startedAt else { return nil }

        let thermal = tuning.thermal
        let initial = thermal.initialCentreTemperatureC
        let surface = thermal.surfaceTemperatureC
        let pull = profile.pullTemperatureC
        let pullSeconds = profile.estimatedCookingBudget

        guard pullSeconds > 0,
              surface > pull,
              pull > initial else { return nil }

        let tau = pullSeconds / log((surface - initial) / (surface - pull))
        guard tau.isFinite, tau > 0 else { return nil }

        let elapsed = max(0, date.timeIntervalSince(startedAt))
        let estimate = surface - (surface - initial) * exp(-elapsed / tau)
        return min(max(estimate, initial), surface)
    }

    /// How many flips the plan still expects before the late stage (fat cap or
    /// butter) begins, or `nil` when the searing loop is not the current work.
    ///
    /// Frequent flipping is one milestone in the journey, so this counts the
    /// flips that are still *scheduled* rather than the ones already taken: it
    /// falls out of the absolute late-stage date, which does not move when the
    /// user flips late. Once butter is in the pan the count is no longer
    /// meaningful and the answer is `nil`.
    func remainingSearFlips(
        for session: CookingSession,
        profile: CookingProfile,
        at date: Date
    ) -> Int? {
        guard session.phase == .sear, session.butterAddedAt == nil else { return nil }

        let untilLateStage = lateStageDate(for: session, profile: profile)
            .timeIntervalSince(date)
        guard untilLateStage > 0 else { return nil }

        let interval = max(profile.flipInterval, 0.01)
        // Flips land on multiples of the interval from now, and a flip that
        // coincides exactly with the late stage loses the tie, so the count is
        // the number of multiples strictly below the late stage.
        return max(0, Int(floor(untilLateStage / interval - 1e-6)))
    }

    /// Candidate boundaries for the frequent-flip sear stage, in tie-break
    /// priority order (pull, late stage, flip).
    ///
    /// A flip that would land within `minSecondsAfterFlipBeforePull` of the
    /// estimated pull is not offered at all in the timing fallback: the user
    /// would flip and then be told to take the steak out seconds later. The
    /// plan simply waits the remaining seconds out.
    func searBoundaryCandidates(
        for session: CookingSession,
        profile: CookingProfile,
        from date: Date
    ) -> [SearBoundary] {
        var candidates: [SearBoundary] = []
        let flipDate = date.addingTimeInterval(profile.flipInterval)
        if !isFlipPointless(for: session, profile: profile, at: flipDate) {
            candidates.append(SearBoundary(kind: .flip, date: flipDate))
        }
        if session.butterAddedAt == nil {
            candidates.append(
                SearBoundary(
                    kind: .lateStage,
                    date: lateStageDate(for: session, profile: profile)
                )
            )
        }
        if let pull = fallbackPullDate(for: session, profile: profile) {
            candidates.append(
                SearBoundary(kind: .estimatedPull, date: pull)
            )
        }
        return candidates
    }

    /// The authoritative earliest sear boundary. The controller schedules
    /// `nextActionAt` from this, and the announced action is derived from
    /// the resulting kind, so both always describe the same moment.
    func searBoundary(
        for session: CookingSession,
        profile: CookingProfile,
        from date: Date
    ) -> SearBoundary {
        let candidates = searBoundaryCandidates(
            for: session,
            profile: profile,
            from: date
        )
        guard let first = candidates.first else {
            // Unreachable in practice: a suppressed flip implies a live pull
            // candidate, and otherwise the flip candidate is always present.
            // Kept total rather than force-unwrapped.
            return SearBoundary(
                kind: .flip,
                date: date.addingTimeInterval(profile.flipInterval)
            )
        }
        return candidates.dropFirst().reduce(first) { earliest, candidate in
            if candidate.date < earliest.date { return candidate }
            if candidate.date == earliest.date,
               candidate.kind.tieBreakPriority < earliest.kind.tieBreakPriority {
                return candidate
            }
            return earliest
        }
    }

    /// Which kind of boundary `session.nextActionAt` currently represents.
    /// Boundaries are scheduled from `searBoundary`, so the scheduled date
    /// equals one of these candidates exactly.
    func scheduledSearBoundaryKind(
        for session: CookingSession,
        profile: CookingProfile
    ) -> SearBoundaryKind {
        guard let nextActionAt = session.nextActionAt else { return .flip }
        if let pull = fallbackPullDate(for: session, profile: profile),
           pull <= nextActionAt {
            return .estimatedPull
        }
        if session.butterAddedAt == nil,
           lateStageDate(for: session, profile: profile) <= nextActionAt {
            return .lateStage
        }
        // A flip boundary the user never confirmed can drift into the guard
        // window before the pull. The app will not ask for that flip any more
        // (it waits for TAKE IT OUT), so the announced action has to follow.
        if isFlipPointless(for: session, profile: profile, at: nextActionAt) {
            return .estimatedPull
        }
        return .flip
    }

    /// The action a sear boundary of the given kind actually performs.
    func action(
        for kind: SearBoundaryKind,
        configuration: SteakConfiguration
    ) -> CookingAction {
        switch kind {
        case .flip: .flip
        case .lateStage:
            needsFatCap(for: configuration) ? .standFatCap : .addButter
        case .estimatedPull: .takeOut
        }
    }

    /// Whether this cut needs a fat-cap stage, from production tuning.
    func needsFatCap(for configuration: SteakConfiguration) -> Bool {
        configuration.cut.spec(in: tuning).needsFatCap
    }

    private func pullRecommendation(
        for session: CookingSession,
        profile: CookingProfile,
        at date: Date,
        estimatedPullAt: Date
    ) -> PullRecommendation {
        // A real thermometer reading always wins over time estimation.
        if let temperature = session.lastManualTemperatureC {
            return temperature >= profile.pullTemperatureC ? .takeOut : .keepCooking
        }
        // Explicit no-thermometer fallback: pull only when the estimated
        // cooking budget has elapsed. Selecting the fallback never means
        // “pull temperature reached”.
        if session.thermometerUnavailableAt != nil {
            return date >= estimatedPullAt ? .takeOut : .keepCooking
        }
        if session.phase == .baste || session.phase == .checkTemperature {
            return .checkTemperature
        }
        return .keepCooking
    }

    private func currentAction(
        for session: CookingSession,
        at date: Date,
        profile: CookingProfile,
        pullRecommendation: PullRecommendation,
        lateStageAt: Date
    ) -> CookingAction {
        if pullRecommendation == .takeOut,
           session.phase.flowStage == .cook {
            return .takeOut
        }

        switch session.phase {
        case .sear:
            guard session.remaining(at: date) <= 0 else { return .wait }
            if session.butterAddedAt != nil {
                // After butter, prompt one more flip before checking again
                // when a real reading exists. Without a thermometer the
                // fallback keeps the frequent-flip loop until the estimated
                // pull boundary.
                if let temperatureAt = session.lastManualTemperatureAt,
                   (session.lastFlipAt ?? .distantPast) <= temperatureAt,
                   session.thermometerUnavailableAt == nil {
                    return .flip
                }
                if session.thermometerUnavailableAt == nil {
                    return .checkTemperature
                }
                // Waiting out the last seconds before the pull anchor beats a
                // flip the user would be told to undo immediately.
                return isFlipPointless(for: session, profile: profile, at: date)
                    ? .wait
                    : .flip
            }
            guard date < lateStageAt else {
                return needsFatCap(for: session.configuration)
                    ? .standFatCap
                    : .addButter
            }
            return .flip
        case .fatCap:
            return session.remaining(at: date) > 0 ? .standFatCap : .addButter
        case .baste:
            guard session.remaining(at: date) <= 0 else { return .baste }
            if session.thermometerUnavailableAt == nil { return .checkTemperature }
            return isFlipPointless(for: session, profile: profile, at: date)
                ? .wait
                : .flip
        case .checkTemperature:
            return .checkTemperature
        case .finishing:
            return .waitForFinish
        case .ready, .eat:
            return .eat
        default:
            return .wait
        }
    }

    private func nextAction(
        for session: CookingSession,
        action: CookingAction,
        at date: Date,
        profile: CookingProfile
    ) -> CookingAction? {
        switch session.phase {
        case .sear where action == .wait:
            if session.butterAddedAt != nil,
               session.thermometerUnavailableAt == nil {
                // Manual path: after a low reading, flip once more and then
                // ask for another reading.
                if let temperatureAt = session.lastManualTemperatureAt,
                   (session.lastFlipAt ?? .distantPast) <= temperatureAt {
                    return .flip
                }
                return .checkTemperature
            }
            // Announce exactly the action the scheduled boundary performs.
            return self.action(
                for: scheduledSearBoundaryKind(for: session, profile: profile),
                configuration: session.configuration
            )
        case .fatCap where action == .standFatCap:
            return fallbackPullIsDue(session: session, profile: profile)
                ? .takeOut
                : .addButter
        case .baste:
            // What the end of this window performs, announced while it runs.
            if fallbackPullIsDue(session: session, profile: profile) {
                return .takeOut
            }
            if session.thermometerUnavailableAt == nil {
                return .checkTemperature
            }
            let windowEnd = session.nextActionAt ?? date
            return isFlipPointless(for: session, profile: profile, at: windowEnd)
                ? .takeOut
                : .flip
        case .finishing:
            return .eat
        default:
            return nil
        }
    }

    /// In the no-thermometer fallback the estimated pull boundary can fall
    /// inside a late-stage timer (fat cap / baste). When it does, the next
    /// action is TAKE IT OUT — matching what the app shows at that moment.
    private func fallbackPullIsDue(
        session: CookingSession,
        profile: CookingProfile
    ) -> Bool {
        guard session.thermometerUnavailableAt != nil,
              let nextActionAt = session.nextActionAt else { return false }
        return estimatedPullDate(for: session, profile: profile) <= nextActionAt
    }

    private func event(
        for session: CookingSession,
        action: CookingAction,
        nextAction: CookingAction?,
        remaining: TimeInterval
    ) -> CookingEvent? {
        if action == .takeOut { return .pullNow }
        if session.phase == .finishing, remaining <= 0 { return .ready }
        if action == .flip {
            return .flipNow(style: session.flipCount == 0 ? .hero : .compact)
        }
        let approaching = tuning.notifications.approachingThresholdSeconds
        if nextAction == .flip, remaining <= approaching, remaining > 0 {
            return .flipApproaching(seconds: max(1, Int(ceil(remaining))))
        }

        switch action {
        case .standFatCap: return .standFatCap
        case .addButter: return .addButter
        case .baste: return .baste
        case .checkTemperature: return .checkTemperature
        default: return nil
        }
    }

    private func finishingEstimate(
        for session: CookingSession,
        profile: CookingProfile
    ) -> ClosedRange<TimeInterval> {
        guard let temperature = session.lastManualTemperatureC else {
            return profile.finishingEstimate
        }
        let finishing = tuning.finishing
        let remainingRise = max(0, profile.targetTemperatureC - temperature)
        let adjustment = min(
            finishing.maxManualAdjustmentSeconds,
            remainingRise * finishing.remainingRiseSecondsPerDegree
        )
        return (profile.finishingEstimate.lowerBound + adjustment)...(
            profile.finishingEstimate.upperBound + adjustment
        )
    }
}
