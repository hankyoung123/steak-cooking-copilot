import Foundation

struct CookingProfile: Equatable, Sendable {
    let firstSearDuration: TimeInterval
    let secondSearDuration: TimeInterval
    let fatCapDuration: TimeInterval
    let butterDuration: TimeInterval
    let basteDuration: TimeInterval
    let temperatureCheckDuration: TimeInterval
    let pullTemperatureC: Double
    let restDuration: TimeInterval

    var totalCookingDuration: TimeInterval {
        firstSearDuration
            + secondSearDuration
            + fatCapDuration
            + butterDuration
            + basteDuration
            + temperatureCheckDuration
    }

    func duration(for phase: CookingPhase) -> TimeInterval {
        switch phase {
        case .searFirst: firstSearDuration
        case .searSecond: secondSearDuration
        case .fatCap: fatCapDuration
        case .butter: butterDuration
        case .baste: basteDuration
        case .checkTemperature: temperatureCheckDuration
        case .resting: restDuration
        default: 0
        }
    }
}
