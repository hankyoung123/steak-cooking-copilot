import ActivityKit
import Foundation

struct SteakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let phaseTitle: String
        let actionTitle: String
        let actionDate: Date?
        let isUrgent: Bool
    }

    let steakName: String
}
