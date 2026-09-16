import Foundation

struct CookingProfile: Equatable, Sendable {
    let flipInterval: TimeInterval
    let estimatedCookingBudget: TimeInterval
    let initialSearBias: TimeInterval
    let fatCapDuration: TimeInterval?
    let basteDuration: TimeInterval
    let targetTemperatureC: Double
    let pullTemperatureC: Double
    let finishingEstimate: ClosedRange<TimeInterval>

    /// Minimum gap that must remain before the pull for a flip to be worth
    /// scheduling. Scaled with the rest of the profile so that the plan keeps
    /// its shape under the test time scales: an unscaled guard would be longer
    /// than a fast-cooked steak and would suppress every flip.
    let flipPullGuard: TimeInterval

    /// Absolute offset from the cook start at which the late stage (fat cap /
    /// butter) begins. Computed by `CookingEngine` from tunable values:
    /// `lateStageRatio`, `lateStageMinFlipIntervals` and the learned sear bias.
    let lateStageDateOffset: TimeInterval
}
