import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    private let center: UNUserNotificationCenter
    private let isEnabled: Bool

    init(center: UNUserNotificationCenter = .current(), isEnabled: Bool = true) {
        self.center = center
        self.isEnabled = isEnabled
    }

    func requestAuthorization() async -> Bool {
        guard isEnabled else { return false }
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleNextAction(
        for session: CookingSession,
        guidance: CookingGuidance
    ) async {
        guard isEnabled else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["next-cooking-action"])
        guard session.phaseDuration > 0 else { return }

        let fireDate = session.phaseStartedAt.addingTimeInterval(session.phaseDuration)
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: session.phase)
        content.body = notificationBody(for: session.phase, target: guidance.pullTemperatureC)
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "next-cooking-action",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func clearCookingNotifications() {
        guard isEnabled else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["next-cooking-action"])
    }

    private func notificationTitle(for phase: CookingPhase) -> String {
        switch phase {
        case .searFirst, .searSecond: "FLIP NOW"
        case .fatCap: "ADD BUTTER"
        case .butter: "BASTE"
        case .baste: "CHECK TEMP"
        case .checkTemperature: "TAKE IT OUT"
        case .resting: "READY"
        default: "Steak needs you"
        }
    }

    private func notificationBody(for phase: CookingPhase, target: Double) -> String {
        switch phase {
        case .checkTemperature: "Pull at about \(target.formatted(.number.precision(.fractionLength(0))))°C."
        case .resting: "Carryover cooking is complete. Time to eat."
        default: "Open Perfect Steak for the next step."
        }
    }
}
