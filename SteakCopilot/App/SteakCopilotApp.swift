import SwiftUI

@main
struct SteakCopilotApp: App {
    @State private var theme = AppTheme()
    @State private var tuningStore: TuningStore
    @State private var controller: CookingSessionController

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isFastPreview = arguments.contains("-fastCook")
        let isVisualPreview = arguments.contains("-visualCook")
        let store = CookingStore()
        if arguments.contains("-resetSession") {
            store.clearSession()
        }
        // Effective tuning = generated production defaults + optional local
        // development override. Test launch arguments can force production
        // values so UI tests always run the shipped configuration.
        let tuningStore = TuningStore()
        if arguments.contains("-resetTuning") {
            tuningStore.resetToProduction()
        }
        // Every tuning consumer shares one store, so a change made in the
        // Tuning Lab is read live instead of being frozen at launch.
        let motion = MotionDirector(
            haptics: HapticService(isEnabled: !arguments.contains("-quietFeedback")),
            sounds: SoundService(isEnabled: !arguments.contains("-quietFeedback")),
            tuningProvider: tuningStore
        )
        _tuningStore = State(initialValue: tuningStore)
        _controller = State(
            initialValue: CookingSessionController(
                store: store,
                motionDirector: motion,
                notificationService: NotificationService(
                    isEnabled: !arguments.contains("-disableNotifications")
                ),
                liveActivityService: LiveActivityService(
                    isEnabled: !arguments.contains("-disableLiveActivity"),
                    tuningProvider: tuningStore
                ),
                tuningStore: tuningStore,
                timeScale: isVisualPreview ? 0.08 : (isFastPreview ? 0.035 : 1)
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView(controller: controller, tuningStore: tuningStore)
                .environment(theme)
        }
    }
}
