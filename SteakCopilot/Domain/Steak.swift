import Foundation

enum SteakCut: String, Codable, CaseIterable, Identifiable, Sendable {
    case ribeye
    case strip
    case tenderloin

    var id: Self { self }

    var title: String {
        switch self {
        case .ribeye: "Ribeye"
        case .strip: "New York Strip"
        case .tenderloin: "Tenderloin"
        }
    }

    var cookingMultiplier: Double {
        switch self {
        case .ribeye: 1.05
        case .strip: 1
        case .tenderloin: 0.92
        }
    }
}

struct SteakConfiguration: Codable, Equatable, Sendable {
    var cut: SteakCut = .ribeye
    var thicknessCM: Double = 3
    var doneness: Doneness = .mediumRare
}
