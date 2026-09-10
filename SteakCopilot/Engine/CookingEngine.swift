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
        targetTemperatureC: Double = 54,
        pullTemperatureC: Double = 52
    ) -> CookingGuidance {
        CookingGuidance(
            phase: phase,
            currentAction: .wait,
            nextAction: nil,
            nextActionAt: nil,
            remainingTime: 0,
            estimatedProgress: 0,
            pullRecommendation: .keepCooking,
            targetTemperatureC: targetTemperatureC,
            pullTemperatureC: pullTemperatureC,
            lastManualTemperatureC: nil,
            finishingEstimate: 120...225,
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
    func flipInterval(for configuration: SteakConfiguration) -> TimeInterval {
        switch configuration.thicknessCM {
        case ..<2.5: 25
        case ...4: 30
        default: 40
        }
    }

    func profile(
        for configuration: SteakConfiguration,
        calibration: CookingCalibration,
        timeScale: Double = 1
    ) -> CookingProfile {
        let scale = max(0.01, timeScale)
        let thicknessFactor = max(0.72, configuration.thicknessCM / 2.5)
        let cutBudgetOffset: TimeInterval = switch configuration.cut {
        case .ribeye: 12
        case .strip: 0
        case .tenderloin: -12
        }
        let rawBudget = 300
            * thicknessFactor
            * configuration.doneness.cookingBudgetFactor
            + cutBudgetOffset
            + calibration.cookingTimeAdjustment
        let budget = min(max(rawBudget, 180), 720) * scale
        let flip = flipInterval(for: configuration) * scale
        let budgetFinishAdjustment = min(
            max((rawBudget - 300) * 0.08, -15),
            30
        )
        let lowerFinish = (
            65
                + configuration.thicknessCM * 15
                + (configuration.doneness == .medium ? 15 : 0)
                + budgetFinishAdjustment
        ) * scale

        return CookingProfile(
            flipInterval: max(0.3, flip),
            estimatedCookingBudget: max(flip * 3, budget),
            initialSearBias: calibration.searBias * scale,
            fatCapDuration: configuration.cut.profile.fatCapDuration.map { max(0.5, $0 * scale) },
            basteDuration: max(0.8, min(75, rawBudget * 0.16) * scale),
            targetTemperatureC: configuration.doneness.targetTemperatureC,
            pullTemperatureC: configuration.doneness.pullTemperatureC,
            finishingEstimate: max(1, lowerFinish)...max(
                2,
                lowerFinish + 105 * scale
            )
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
            configuration.cut.profile.needsFatCap ? .standFatCap : .addButter
        case .estimatedPull: .takeOut
        }
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
                return session.configuration.cut.profile.needsFatCap
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
        if nextAction == .flip, remaining <= 5, remaining > 0 {
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
        let remainingRise = max(0, profile.targetTemperatureC - temperature)
        let adjustment = min(30, remainingRise * 6)
        return (profile.finishingEstimate.lowerBound + adjustment)...(
            profile.finishingEstimate.upperBound + adjustment
        )
    }
}
