@preconcurrency import ActivityKit
import Foundation

@MainActor
protocol CookingLiveActivityServing: AnyObject {
    func recover(for session: CookingSession, guidance: CookingGuidance) async
    func start(for session: CookingSession, guidance: CookingGuidance) async
    func update(for session: CookingSession, guidance: CookingGuidance) async
    func end(for session: CookingSession, guidance: CookingGuidance) async
}

@MainActor
final class LiveActivityService: CookingLiveActivityServing {
    private var activity: Activity<SteakActivityAttributes>?
    private let isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func recover(for session: CookingSession, guidance: CookingGuidance) async {
        guard isEnabled else { return }
        activity = matchingActivity(for: session)
        if activity != nil {
            await update(for: session, guidance: guidance)
        } else if session.phase.flowStage == .cook || session.phase == .finishing {
            await start(for: session, guidance: guidance)
        }
    }

    func start(for session: CookingSession, guidance: CookingGuidance) async {
        guard isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if activity == nil {
            activity = matchingActivity(for: session)
        }
        if activity != nil {
            await update(for: session, guidance: guidance)
            return
        }

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
        guard isEnabled else { return }
        if activity == nil {
            activity = matchingActivity(for: session)
        }
        guard let activity else { return }
        let content = ActivityContent(
            state: contentState(for: session, guidance: guidance),
            staleDate: guidance.nextActionAt?.addingTimeInterval(30)
        )
        await activity.update(content)
    }

    func end(for session: CookingSession, guidance: CookingGuidance) async {
        if activity == nil {
            activity = matchingActivity(for: session)
        }
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

    private func matchingActivity(
        for session: CookingSession
    ) -> Activity<SteakActivityAttributes>? {
        let steakName = "\(session.configuration.cut.title) · \(session.configuration.doneness.title)"
        return Activity<SteakActivityAttributes>.activities.first {
            $0.attributes.steakName == steakName
        }
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
