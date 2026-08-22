import Foundation

enum CookingPhase: String, Codable, Equatable, Sendable {
    case setup
    case prep
    case heat
    case searFirst
    case searSecond
    case fatCap
    case butter
    case baste
    case checkTemperature
    case pull
    case resting
    case ready
    case eat
    case feedback

    var flowStage: CookingFlowStage {
        switch self {
        case .setup: .setup
        case .prep: .prep
        case .heat: .heat
        case .searFirst, .searSecond, .fatCap, .butter, .baste, .checkTemperature, .pull: .cook
        case .resting: .finish
        case .ready, .eat: .eat
        case .feedback: .feedback
        }
    }
}

enum CookingFlowStage: String, Equatable, Sendable {
    case setup
    case prep
    case heat
    case cook
    case finish
    case eat
    case feedback
}

enum FlipStyle: String, Codable, Equatable, Sendable {
    case hero
    case compact
}

enum CookingEvent: Equatable, Sendable {
    case flipApproaching(seconds: Int)
    case flipNow(style: FlipStyle)
    case standFatCap
    case addButter
    case baste
    case checkTemperature
    case pullNow
    case ready
}

enum CookingAction: String, Equatable, Sendable {
    case wait
    case flip
    case standItUp
    case addButter
    case baste
    case checkTemperature
    case takeItOut
    case rest
    case eat

    var title: String {
        switch self {
        case .wait: "DON'T TOUCH IT"
        case .flip: "FLIP"
        case .standItUp: "STAND IT UP"
        case .addButter: "ADD BUTTER"
        case .baste: "BASTE"
        case .checkTemperature: "CHECK TEMP"
        case .takeItOut: "TAKE IT OUT"
        case .rest: "RESTING"
        case .eat: "TIME TO EAT"
        }
    }
}
