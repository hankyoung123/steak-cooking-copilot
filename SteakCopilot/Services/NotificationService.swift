@preconcurrency import UserNotifications
import Foundation

@MainActor
protocol CookingNotificationServing: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleNextAction(guidance: CookingGuidance) async
    func clearCookingNotifications()
}

@MainActor
final class NotificationService: CookingNotificationServing {
    private static let nextActionIdentifier = "next-cooking-action"

    private let center: UNUserNotificationCenter
    private let isEnabled: Bool

    init(center: UNUserNotificationCenter = .current(), isEnabled: Bool = true) {
        self.center = center
        self.isEnabled = isEnabled
    }

    func requestAuthorization() async -> Bool {
        guard isEnabled else { return false }
        // The completion-handler API is used through a continuation so the
        // non-Sendable UNUserNotificationCenter never crosses an isolation
        // boundary via a nonisolated async method call (Swift 6 strict
        // concurrency). `@preconcurrency import` covers the remaining
        // framework sendability annotations.
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func scheduleNextAction(guidance: CookingGuidance) async {
        guard isEnabled else { return }
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.nextActionIdentifier]
        )
        guard let fireDate = guidance.nextActionAt else { return }
        guard guidance.announcedNextAction != .wait else { return }
        guard fireDate > .now else { return }

        // Same announced action the Live Activity and the in-app
        // instruction use, so a notification can never promise a different
        // step than the app performs at that moment.
        let action = guidance.announcedNextAction

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: action)
        content.body = notificationBody(
            for: action,
            target: guidance.pullTemperatureC
        )
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, fireDate.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: Self.nextActionIdentifier,
            content: content,
            trigger: trigger
        )
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }

    func clearCookingNotifications() {
        guard isEnabled else { return }
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.nextActionIdentifier]
        )
    }

    private func notificationTitle(for action: CookingAction) -> String {
        Self.title(for: action)
    }

    private func notificationBody(for action: CookingAction, target: Double) -> String {
        Self.body(for: action, target: target)
    }

    /// Internal so tests can prove the notification copy follows the same
    /// announced action the app performs.
    static func title(for action: CookingAction) -> String {
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

    static func body(for action: CookingAction, target: Double) -> String {
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
