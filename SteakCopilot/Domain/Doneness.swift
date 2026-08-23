import Foundation

enum Doneness: String, Codable, CaseIterable, Identifiable, Sendable {
    case rare
    case mediumRare
    case medium

    var id: Self { self }

    var title: String {
        switch self {
        case .rare: String(localized: "Rare")
        case .mediumRare: String(localized: "Medium Rare")
        case .medium: String(localized: "Medium")
        }
    }

    var targetTemperatureC: Double {
        switch self {
        case .rare: 52
        case .mediumRare: 54
        case .medium: 60
        }
    }

    var pullTemperatureC: Double {
        switch self {
        case .rare: 49
        case .mediumRare: 52
        case .medium: 57
        }
    }

    var cookingBudgetFactor: Double {
        switch self {
        case .rare: 0.88
        case .mediumRare: 1
        case .medium: 1.14
        }
    }
}

enum DonenessFeedback: Int, Codable, CaseIterable, Identifiable, Sendable {
    case tooRare = -2
    case slightlyRare = -1
    case perfect = 0
    case slightlyDone = 1
    case tooDone = 2

    var id: Self { self }

    var title: String {
        switch self {
        case .tooRare: String(localized: "Too rare")
        case .slightlyRare: String(localized: "Slightly rare")
        case .perfect: String(localized: "Perfect")
        case .slightlyDone: String(localized: "Slightly done")
        case .tooDone: String(localized: "Too done")
        }
    }
}

enum CrustFeedback: Int, Codable, CaseIterable, Identifiable, Sendable {
    case tooLight = -1
    case perfect = 0
    case tooDark = 1

    var id: Self { self }

    var title: String {
        switch self {
        case .tooLight: String(localized: "Too light")
        case .perfect: String(localized: "Perfect")
        case .tooDark: String(localized: "Too dark")
        }
    }
}
