import Foundation

struct CookingSession: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var configuration: SteakConfiguration
    var phase: CookingPhase
    var phaseStartedAt: Date
    var phaseDuration: TimeInterval
    var flipCount: Int
    var manualTemperatureC: Double?
    var startedAt: Date?

    static func fresh(at date: Date = .now) -> CookingSession {
        CookingSession(
            id: UUID(),
            configuration: SteakConfiguration(),
            phase: .setup,
            phaseStartedAt: date,
            phaseDuration: 0,
            flipCount: 0,
            manualTemperatureC: nil,
            startedAt: nil
        )
    }

    mutating func enter(
        _ phase: CookingPhase,
        at date: Date,
        duration: TimeInterval = 0
    ) {
        self.phase = phase
        phaseStartedAt = date
        phaseDuration = max(0, duration)
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, phaseDuration - date.timeIntervalSince(phaseStartedAt))
    }

    static func fixture(
        phase: CookingPhase,
        phaseStartedAt: Date,
        phaseDuration: TimeInterval
    ) -> CookingSession {
        CookingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            configuration: SteakConfiguration(),
            phase: phase,
            phaseStartedAt: phaseStartedAt,
            phaseDuration: phaseDuration,
            flipCount: 0,
            manualTemperatureC: nil,
            startedAt: phase == .setup ? nil : phaseStartedAt
        )
    }
}
