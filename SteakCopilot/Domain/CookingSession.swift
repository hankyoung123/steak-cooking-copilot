import Foundation

struct CookingSession: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var configuration: SteakConfiguration
    var phase: CookingPhase
    var startedAt: Date?
    var phaseStartedAt: Date
    var nextActionAt: Date?
    var flipCount: Int
    var lastFlipAt: Date?
    var lastManualTemperatureC: Double?
    var lastManualTemperatureAt: Date?
    var butterAddedAt: Date?
    /// Set when the user explicitly chose the no-thermometer timing fallback.
    /// It means “estimate cooking by time”, never “pull temperature reached”.
    var thermometerUnavailableAt: Date?
    var pulledAt: Date?
    var finishedAt: Date?

    static func fresh(at date: Date = .now) -> CookingSession {
        CookingSession(
            id: UUID(),
            configuration: SteakConfiguration(),
            phase: .setup,
            startedAt: nil,
            phaseStartedAt: date,
            nextActionAt: nil,
            flipCount: 0,
            lastFlipAt: nil,
            lastManualTemperatureC: nil,
            lastManualTemperatureAt: nil,
            butterAddedAt: nil,
            thermometerUnavailableAt: nil,
            pulledAt: nil,
            finishedAt: nil
        )
    }

    mutating func enter(
        _ phase: CookingPhase,
        at date: Date,
        nextActionAt: Date? = nil
    ) {
        self.phase = phase
        phaseStartedAt = date
        self.nextActionAt = nextActionAt
    }

    func remaining(at date: Date) -> TimeInterval {
        guard let nextActionAt else { return 0 }
        return max(0, nextActionAt.timeIntervalSince(date))
    }

    static func fixture(
        phase: CookingPhase,
        phaseStartedAt: Date,
        nextActionAt: Date?
    ) -> CookingSession {
        var session = CookingSession.fresh(at: phaseStartedAt)
        session.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        session.phase = phase
        session.phaseStartedAt = phaseStartedAt
        session.nextActionAt = nextActionAt
        session.startedAt = phase == .setup ? nil : phaseStartedAt
        return session
    }
}
