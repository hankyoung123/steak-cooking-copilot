import Foundation

struct SteakCutProfile: Equatable, Sendable {
    let needsFatCap: Bool
    let fatCapDuration: TimeInterval?
}

enum SteakCut: String, Codable, CaseIterable, Identifiable, Sendable {
    case ribeye
    case strip
    case tenderloin

    var id: Self { self }

    var title: String {
        switch self {
        case .ribeye: String(localized: "Ribeye")
        case .strip: String(localized: "New York Strip")
        case .tenderloin: String(localized: "Filet")
        }
    }

    var profile: SteakCutProfile {
        switch self {
        case .ribeye:
            SteakCutProfile(needsFatCap: false, fatCapDuration: nil)
        case .strip:
            SteakCutProfile(needsFatCap: true, fatCapDuration: 40)
        case .tenderloin:
            SteakCutProfile(needsFatCap: false, fatCapDuration: nil)
        }
    }

    var heroAssetName: String {
        switch self {
        case .ribeye: "RawRibeye"
        case .strip: "RawStrip"
        case .tenderloin: "RawFilet"
        }
    }
}

enum StartingCondition: String, Codable, CaseIterable, Identifiable, Sendable {
    case fridge
    case room

    var id: Self { self }

    var title: String {
        switch self {
        case .fridge: String(localized: "Fridge cold")
        case .room: String(localized: "Room temperature")
        }
    }
}

enum ThicknessBucket: String, Codable, Hashable, Sendable {
    case thin
    case standard
    case thick

    init(thicknessCM: Double) {
        switch thicknessCM {
        case ..<2.5: self = .thin
        case ...3.5: self = .standard
        default: self = .thick
        }
    }
}

struct SteakConfiguration: Codable, Equatable, Sendable {
    var cut: SteakCut = .ribeye
    var thicknessCM: Double = 3
    var doneness: Doneness = .mediumRare

    var thicknessBucket: ThicknessBucket {
        ThicknessBucket(thicknessCM: thicknessCM)
    }
}

struct SteakSetupPreferences: Codable, Equatable, Sendable {
    var configuration: SteakConfiguration
    var startingCondition: StartingCondition

    static func recommended(for cut: SteakCut) -> SteakSetupPreferences {
        SteakSetupPreferences(
            configuration: SteakConfiguration(
                cut: cut,
                thicknessCM: cut == .tenderloin ? 4 : 3,
                doneness: .mediumRare
            ),
            startingCondition: .fridge
        )
    }
}
