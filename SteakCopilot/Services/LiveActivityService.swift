@preconcurrency import ActivityKit
import Foundation

@MainActor
protocol CookingLiveActivityServing: AnyObject {
    func recover(for session: CookingSession, guidance: CookingGuidance) async
    func start(for session: CookingSession, guidance: CookingGuidance) async
    func update(for session: CookingSession, guidance: CookingGuidance) async
    func end(
        for session: CookingSession,
        guidance: CookingGuidance,
        reason: CookingLiveActivityEndReason
    ) async
}

@MainActor
final class LiveActivityService: CookingLiveActivityServing {
    private var activity: Activity<SteakActivityAttributes>?
    private let isEnabled: Bool
    /// Read at each update, so tuning changes apply to the next activity
    /// content instead of a stale snapshot taken at init.
    private let tuningProvider: any TuningProviding

    init(
        isEnabled: Bool = true,
        tuningProvider: any TuningProviding = StaticTuningProvider()
    ) {
        self.isEnabled = isEnabled
        self.tuningProvider = tuningProvider
    }

    /// Convenience for a fixed tuning (tests, previews).
    convenience init(isEnabled: Bool = true, tuning: AppTuning) {
        self.init(
            isEnabled: isEnabled,
            tuningProvider: StaticTuningProvider(tuning: tuning)
        )
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

        let attributes = SteakActivityAttributes(sessionID: session.id)
        let content = ActivityContent(
            state: Self.contentState(
                for: session,
                guidance: guidance,
                tuning: tuningProvider.effective
            ),
            staleDate: guidance.nextActionAt?.addingTimeInterval(
                tuningProvider.effective.notifications.staleDelaySeconds
            )
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
            state: Self.contentState(
                for: session,
                guidance: guidance,
                tuning: tuningProvider.effective
            ),
            staleDate: guidance.nextActionAt?.addingTimeInterval(
                tuningProvider.effective.notifications.staleDelaySeconds
            )
        )
        await activity.update(content)
    }

    func end(
        for session: CookingSession,
        guidance: CookingGuidance,
        reason: CookingLiveActivityEndReason
    ) async {
        if activity == nil {
            activity = matchingActivity(for: session)
        }
        guard let activity else { return }
        let final = SteakActivityAttributes.ContentState.endState(for: reason)
        await activity.end(
            ActivityContent(state: final, staleDate: nil),
            dismissalPolicy: dismissalPolicy(for: reason)
        )
        self.activity = nil
    }

    private func matchingActivity(
        for session: CookingSession
    ) -> Activity<SteakActivityAttributes>? {
        Activity<SteakActivityAttributes>.activities.first {
            $0.attributes.sessionID == session.id
        }
    }

    /// Internal so tests can prove the Live Activity announces exactly the
    /// same action as the notification and the in-app instruction.
    static func contentState(
        for session: CookingSession,
        guidance: CookingGuidance,
        tuning: AppTuning = .production
    ) -> SteakActivityAttributes.ContentState {
        SteakActivityAttributes.ContentState(
            phaseTitle: phaseTitle(for: session.phase),
            // Same announced action the notification and the in-app
            // instruction use, so they can never disagree.
            actionTitle: guidance.announcedNextAction.title,
            actionDate: guidance.nextActionAt,
            isUrgent: guidance.remainingTime
                <= tuning.notifications.urgentThresholdSeconds
        )
    }

    private func dismissalPolicy(
        for reason: CookingLiveActivityEndReason
    ) -> ActivityUIDismissalPolicy {
        switch reason {
        case .finished:
            // Celebration lingers briefly so the user can see the result.
            .after(
                .now.addingTimeInterval(
                    tuningProvider.effective.notifications.finishedDismissalSeconds
                )
            )
        case .cancelled:
            .after(
                .now.addingTimeInterval(
                    tuningProvider.effective.notifications.cancelledDismissalSeconds
                )
            )
        }
    }

    private static func phaseTitle(for phase: CookingPhase) -> String {
        switch phase {
        case .sear: String(localized: "SEAR")
        case .fatCap: String(localized: "FAT CAP")
        case .baste: String(localized: "BASTE")
        case .checkTemperature: String(localized: "CHECK TEMP")
        case .finishing: String(localized: "FINISHING")
        case .ready: String(localized: "READY")
        default: String(localized: "COOK")
        }
    }
}

extension SteakActivityAttributes.ContentState {
    /// Final activity content for the two end reasons. A cancelled session
    /// must never present itself as READY / TIME TO EAT.
    static func endState(
        for reason: CookingLiveActivityEndReason
    ) -> SteakActivityAttributes.ContentState {
        switch reason {
        case .finished:
            SteakActivityAttributes.ContentState(
                phaseTitle: String(localized: "READY"),
                actionTitle: String(localized: "TIME TO EAT"),
                actionDate: nil,
                isUrgent: false
            )
        case .cancelled:
            SteakActivityAttributes.ContentState(
                phaseTitle: String(localized: "SESSION ENDED"),
                actionTitle: String(localized: "CANCELLED"),
                actionDate: nil,
                isUrgent: false
            )
        }
    }
}
