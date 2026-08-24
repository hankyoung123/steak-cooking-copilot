import SwiftUI

@main
struct SteakCopilotApp: App {
    @State private var theme = AppTheme()
    @State private var controller: CookingSessionController

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isFastPreview = arguments.contains("-fastCook")
        let isVisualPreview = arguments.contains("-visualCook")
        let store = CookingStore()
        if arguments.contains("-resetSession") {
            store.clearSession()
        }
        let motion = MotionDirector(
            haptics: HapticService(isEnabled: !arguments.contains("-quietFeedback")),
            sounds: SoundService(isEnabled: !arguments.contains("-quietFeedback"))
        )
        _controller = State(
            initialValue: CookingSessionController(
                store: store,
                motionDirector: motion,
                notificationService: NotificationService(
                    isEnabled: !arguments.contains("-disableNotifications")
                ),
                liveActivityService: LiveActivityService(
                    isEnabled: !arguments.contains("-disableLiveActivity")
                ),
                timeScale: isVisualPreview ? 0.08 : (isFastPreview ? 0.035 : 1)
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView(controller: controller)
                .environment(theme)
        }
    }
}
