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
        let thicknessFactor = max(
            cooking.minThicknessFactor,
            configuration.thicknessCM / cooking.referenceThickness
        )
        let rawBudget = cooking.baseCookingBudget
            * thicknessFactor
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
                    rawBudget * cooking.basteRatio
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

    /// Candidate boundaries for the frequent-flip sear stage, in tie-break
    /// priority order (pull, late stage, flip).
    func searBoundaryCandidates(
        for session: CookingSession,
        profile: CookingProfile,
        from date: Date
    ) -> [SearBoundary] {
        var candidates = [
            SearBoundary(
                kind: .flip,
                date: date.addingTimeInterval(profile.flipInterval)
            )
        ]
        if session.butterAddedAt == nil {
            candidates.append(
                SearBoundary(
                    kind: .lateStage,
                    date: lateStageDate(for: session, profile: profile)
                )
            )
        }
        if session.thermometerUnavailableAt != nil {
            candidates.append(
                SearBoundary(
                    kind: .estimatedPull,
                    date: estimatedPullDate(for: session, profile: profile)
                )
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
        let fallback = SearBoundary(
            kind: .flip,
            date: date.addingTimeInterval(profile.flipInterval)
        )
        return searBoundaryCandidates(for: session, profile: profile, from: date)
            .reduce(fallback) { earliest, candidate in
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
        if session.thermometerUnavailableAt != nil,
           estimatedPullDate(for: session, profile: profile) <= nextActionAt {
            return .estimatedPull
        }
        if session.butterAddedAt == nil,
           lateStageDate(for: session, profile: profile) <= nextActionAt {
            return .lateStage
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
                return session.thermometerUnavailableAt == nil
                    ? .checkTemperature
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
            return session.remaining(at: date) > 0
                ? .baste
                : (session.thermometerUnavailableAt == nil
                    ? .checkTemperature
                    : .flip)
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
        case .baste where action == .baste:
            if fallbackPullIsDue(session: session, profile: profile) {
                return .takeOut
            }
            return session.thermometerUnavailableAt == nil
                ? .checkTemperature
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
