import Foundation

enum Doneness: String, Codable, CaseIterable, Identifiable, Sendable {
    case rare
    case mediumRare
    case medium
    case mediumWell
    case wellDone

    var id: Self { self }

    var title: String {
        switch self {
        case .rare: String(localized: "Rare")
        case .mediumRare: String(localized: "Medium Rare")
        case .medium: String(localized: "Medium")
        case .mediumWell: String(localized: "Medium Well")
        case .wellDone: String(localized: "Well Done")
        }
    }

    var assetName: String {
        switch self {
        case .rare: "DonenessRare"
        case .mediumRare: "DonenessMediumRare"
        case .medium: "DonenessMedium"
        case .mediumWell: "DonenessMediumWell"
        case .wellDone: "DonenessWellDone"
        }
    }

    /// Temperature and cooking-budget parameters. These come from the
    /// production tuning generated from `Config/production.yaml`; there are no
    /// numeric defaults here on purpose, so tunable values have exactly one
    /// source of truth.
    func spec(in tuning: AppTuning) -> DonenessSpecTuning {
        tuning.doneness[self]
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
