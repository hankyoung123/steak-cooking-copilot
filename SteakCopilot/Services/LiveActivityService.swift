@preconcurrency import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    private var activity: Activity<SteakActivityAttributes>?
    private let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func start(for session: CookingSession, guidance: CookingGuidance) async {
        guard isEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              activity == nil
        else { return }

        let attributes = SteakActivityAttributes(
            steakName: "\(session.configuration.cut.title) · \(session.configuration.doneness.title)"
        )
        let content = ActivityContent(
            state: contentState(for: session, guidance: guidance),
            staleDate: guidance.nextActionAt?.addingTimeInterval(30)
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
        )
    }

    func update(for session: CookingSession, guidance: CookingGuidance) async {
        guard isEnabled, let activity else { return }
        let content = ActivityContent(
            state: contentState(for: session, guidance: guidance),
            staleDate: guidance.nextActionAt?.addingTimeInterval(30)
        )
        await activity.update(content)
    }

    func end(for session: CookingSession, guidance: CookingGuidance) async {
        guard let activity else { return }
        let final = SteakActivityAttributes.ContentState(
            phaseTitle: "READY",
            actionTitle: "TIME TO EAT",
            actionDate: nil,
            isUrgent: false
        )
        await activity.end(
            ActivityContent(state: final, staleDate: nil),
            dismissalPolicy: .after(.now.addingTimeInterval(60))
        )
        self.activity = nil
    }

    private func contentState(
        for session: CookingSession,
        guidance: CookingGuidance
    ) -> SteakActivityAttributes.ContentState {
        SteakActivityAttributes.ContentState(
            phaseTitle: phaseTitle(for: session.phase),
            actionTitle: guidance.currentAction.title,
            actionDate: guidance.nextActionAt,
            isUrgent: guidance.remainingTime <= 5
        )
    }

    private func phaseTitle(for phase: CookingPhase) -> String {
        switch phase {
        case .sear: "SEAR"
        case .fatCap: "FAT CAP"
        case .baste: "BASTE"
        case .checkTemperature: "CHECK TEMP"
        case .finishing: "FINISH"
        case .ready: "READY"
        default: "COOK"
        }
    }
}
