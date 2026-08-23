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
        case .tenderloin: String(localized: "Tenderloin")
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
