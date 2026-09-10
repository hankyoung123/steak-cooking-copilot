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
            lateStageAt: lateStageAt
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
        lateStageAt: Date
    ) -> CookingAction? {
        switch session.phase {
        case .sear where action == .wait:
            if session.butterAddedAt != nil {
                if let temperatureAt = session.lastManualTemperatureAt,
                   (session.lastFlipAt ?? .distantPast) <= temperatureAt,
                   session.thermometerUnavailableAt == nil {
                    return .flip
                }
                return session.thermometerUnavailableAt == nil
                    ? .checkTemperature
                    : .flip
            }
            if date >= lateStageAt {
                return session.configuration.cut.profile.needsFatCap
                    ? .standFatCap
                    : .addButter
            }
            return .flip
        case .fatCap where action == .standFatCap:
            return .addButter
        case .baste where action == .baste:
            return session.thermometerUnavailableAt == nil
                ? .checkTemperature
                : .flip
        case .finishing:
            return .eat
        default:
            return nil
        }
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
