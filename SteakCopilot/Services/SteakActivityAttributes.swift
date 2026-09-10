import ActivityKit
import Foundation

/// Why a Live Activity is being ended. The final activity content differs:
/// a finished cook celebrates, a cancelled session does not pretend to be
/// ready to eat.
enum CookingLiveActivityEndReason: Sendable {
    case finished
    case cancelled
}

struct SteakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let phaseTitle: String
        let actionTitle: String
        let actionDate: Date?
        let isUrgent: Bool
    }

    /// Stable identity of the cooking session. Activities are matched by
    /// this UUID, never by cut/doneness display strings, so two sessions
    /// with the same configuration cannot collide.
    let sessionID: UUID
}
