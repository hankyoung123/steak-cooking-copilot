import Foundation

struct CookingGuidance: Equatable, Sendable {
    let phase: CookingPhase
    let action: CookingAction
    let remainingTime: TimeInterval
    let progress: Double
    let pullTemperatureC: Double
    let event: CookingEvent?

    static func idle(phase: CookingPhase = .setup, pullTemperatureC: Double = 52) -> CookingGuidance {
        CookingGuidance(
            phase: phase,
            action: .wait,
            remainingTime: 0,
            progress: 0,
            pullTemperatureC: pullTemperatureC,
            event: nil
        )
    }
}

struct CookingEngine: Sendable {
    func profile(
        for configuration: SteakConfiguration,
        calibration: CookingCalibration,
        timeScale: Double = 1
    ) -> CookingProfile {
        let thicknessFactor = max(0.65, configuration.thicknessCM / 2.5)
        let rawTotal = 300
            * thicknessFactor
            * configuration.cut.cookingMultiplier
            * configuration.doneness.cookingMultiplier
            + calibration.durationAdjustment
        let total = min(max(rawTotal, 180), 720) * max(0.01, timeScale)
        let scaledSearAdjustment = calibration.searAdjustment * max(0.01, timeScale)

        return CookingProfile(
            firstSearDuration: max(3, total * 0.32 + scaledSearAdjustment),
            secondSearDuration: max(3, total * 0.28 - scaledSearAdjustment),
            fatCapDuration: max(2, total * 0.08),
            butterDuration: max(2, total * 0.08),
            basteDuration: max(3, total * 0.16),
            temperatureCheckDuration: max(2, total * 0.08),
            pullTemperatureC: configuration.doneness.pullTemperatureC,
            restDuration: max(8, 240 * max(0.01, timeScale))
        )
    }

    func guidance(
        for session: CookingSession,
        at date: Date,
        calibration: CookingCalibration = .neutral
    ) -> CookingGuidance {
        let profile = profile(for: session.configuration, calibration: calibration)
        let remaining = session.remaining(at: date)
        let progress: Double
        if session.phaseDuration > 0 {
            progress = min(max(1 - remaining / session.phaseDuration, 0), 1)
        } else {
            progress = 0
        }

        return CookingGuidance(
            phase: session.phase,
            action: action(for: session.phase, remaining: remaining),
            remainingTime: remaining,
            progress: progress,
            pullTemperatureC: profile.pullTemperatureC,
            event: event(for: session, remaining: remaining, targetTemperature: profile.pullTemperatureC)
        )
    }

    private func action(for phase: CookingPhase, remaining: TimeInterval) -> CookingAction {
        switch phase {
        case .searFirst, .searSecond: remaining <= 5 ? .flip : .wait
        case .fatCap: .standItUp
        case .butter: .addButter
        case .baste: .baste
        case .checkTemperature: .checkTemperature
        case .pull: .takeItOut
        case .resting: .rest
        case .ready, .eat: .eat
        default: .wait
        }
    }

    private func event(
        for session: CookingSession,
        remaining: TimeInterval,
        targetTemperature: Double
    ) -> CookingEvent? {
        if let temperature = session.manualTemperatureC,
           temperature >= targetTemperature,
           session.phase.flowStage == .cook {
            return .pullNow
        }

        switch session.phase {
        case .searFirst, .searSecond:
            if remaining <= 0 {
                return .flipNow(style: session.flipCount == 0 ? .hero : .compact)
            }
            if remaining <= 5 {
                return .flipApproaching(seconds: max(1, Int(ceil(remaining))))
            }
            return nil
        case .fatCap: return remaining <= 0 ? .addButter : .standFatCap
        case .butter: return remaining <= 0 ? .baste : .addButter
        case .baste: return remaining <= 0 ? .checkTemperature : .baste
        case .checkTemperature: return remaining <= 0 ? .pullNow : .checkTemperature
        case .pull: return .pullNow
        case .resting: return remaining <= 0 ? .ready : nil
        case .ready: return .ready
        default: return nil
        }
    }
}
