import Foundation

enum Doneness: String, Codable, CaseIterable, Identifiable, Sendable {
    case rare
    case mediumRare
    case medium

    var id: Self { self }

    var title: String {
        switch self {
        case .rare: "Rare"
        case .mediumRare: "Medium Rare"
        case .medium: "Medium"
        }
    }

    var pullTemperatureC: Double {
        switch self {
        case .rare: 48
        case .mediumRare: 52
        case .medium: 57
        }
    }

    var cookingMultiplier: Double {
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
        case .tooRare: "Too rare"
        case .slightlyRare: "Slightly rare"
        case .perfect: "Perfect"
        case .slightlyDone: "Slightly done"
        case .tooDone: "Too done"
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
        case .tooLight: "Too light"
        case .perfect: "Perfect"
        case .tooDark: "Too dark"
        }
    }
}
