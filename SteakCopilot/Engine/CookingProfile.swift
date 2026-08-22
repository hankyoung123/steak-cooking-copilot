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

    var lateStageDateOffset: TimeInterval {
        max(flipInterval * 2, estimatedCookingBudget * 0.65 + initialSearBias)
    }
}
