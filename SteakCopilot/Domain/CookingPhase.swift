import Foundation

enum CookingPhase: String, Codable, Equatable, Sendable {
    case setup
    case prep
    case heat
    case sear
    case fatCap
    case baste
    case checkTemperature
    case finishing
    case ready
    case eat
    case feedback

    var flowStage: CookingFlowStage {
        switch self {
        case .setup: .setup
        case .prep: .prep
        case .heat: .heat
        case .sear, .fatCap, .baste, .checkTemperature: .cook
        case .finishing: .finish
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
    case standFatCap
    case addButter
    case baste
    case checkTemperature
    case takeOut
    case waitForFinish
    case eat

    var title: String {
        switch self {
        case .wait: String(localized: "KEEP COOKING")
        case .flip: String(localized: "FLIP")
        case .standFatCap: String(localized: "STAND IT UP")
        case .addButter: String(localized: "ADD BUTTER")
        case .baste: String(localized: "BASTE")
        case .checkTemperature: String(localized: "CHECK TEMP")
        case .takeOut: String(localized: "TAKE IT OUT")
        case .waitForFinish: String(localized: "FINISHING")
        case .eat: String(localized: "TIME TO EAT")
        }
    }
}

enum PullRecommendation: String, Equatable, Sendable {
    case keepCooking
    case checkTemperature
    case takeOut
}
