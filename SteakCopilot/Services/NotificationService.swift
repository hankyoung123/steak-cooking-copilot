import Foundation
import UserNotifications

@MainActor
protocol CookingNotificationServing: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleNextAction(guidance: CookingGuidance) async
    func clearCookingNotifications()
}

@MainActor
final class NotificationService: CookingNotificationServing {
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

    func scheduleNextAction(guidance: CookingGuidance) async {
        guard isEnabled else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["next-cooking-action"])
        guard let fireDate = guidance.nextActionAt,
              let action = guidance.nextAction
        else { return }
        guard fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: action)
        content.body = notificationBody(for: action, target: guidance.pullTemperatureC)
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

    private func notificationTitle(for action: CookingAction) -> String {
        switch action {
        case .flip: String(localized: "FLIP NOW")
        case .standFatCap: String(localized: "STAND THE FAT CAP")
        case .addButter: String(localized: "ADD BUTTER")
        case .baste: String(localized: "BASTE")
        case .checkTemperature: String(localized: "CHECK TEMP")
        case .takeOut: String(localized: "TAKE IT OUT")
        case .eat: String(localized: "READY")
        default: String(localized: "Steak needs you")
        }
    }

    private func notificationBody(for action: CookingAction, target: Double) -> String {
        switch action {
        case .checkTemperature:
            String(
                format: String(localized: "Pull at about %@°C."),
                target.formatted(.number.precision(.fractionLength(0)))
            )
        case .eat:
            String(localized: "Estimated finishing time is complete. Time to eat.")
        default:
            String(localized: "Open Perfect Steak for the next step.")
        }
    }
}
