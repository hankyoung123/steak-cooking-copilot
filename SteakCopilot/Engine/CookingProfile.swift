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

    /// Absolute offset from the cook start at which the late stage (fat cap /
    /// butter) begins. Computed by `CookingEngine` from tunable values:
    /// `lateStageRatio`, `lateStageMinFlipIntervals` and the learned sear bias.
    let lateStageDateOffset: TimeInterval
}
