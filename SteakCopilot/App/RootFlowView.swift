import SwiftUI

struct RootFlowView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var pendingControl: SessionControlConfirmation?
    let controller: CookingSessionController

    var body: some View {
        ZStack {
            theme.background(for: controller.flowStage)
                .ignoresSafeArea()

            Group {
                switch controller.flowStage {
                case .setup:
                    SetupView(controller: controller)
                case .prep:
                    PrepView(controller: controller)
                case .heat:
                    HeatView(controller: controller)
                case .cook:
                    CookView(controller: controller)
                case .finish:
                    FinishView(controller: controller)
                case .eat:
                    EatView(controller: controller)
                case .feedback:
                    FeedbackView(controller: controller)
                }
            }
            .id(controller.flowStage)
            .transition(stageTransition)
        }
        .foregroundStyle(theme.foreground(for: controller.flowStage))
        .animation(
            .easeInOut(duration: MotionTiming.stageTransition),
            value: controller.flowStage
        )
        .preferredColorScheme(controller.flowStage == .cook ? .dark : .light)
        .safeAreaInset(edge: .top, spacing: 0) {
            if controller.flowStage != .setup {
                SessionStageControls(
                    flowStage: controller.flowStage,
                    onExit: { pendingControl = .exit },
                    onSkip: { pendingControl = .skip }
                )
            }
        }
        .alert(item: $pendingControl, content: controlAlert)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                controller.refresh(at: .now)
            }
        }
    }

    private func controlAlert(
        for confirmation: SessionControlConfirmation
    ) -> Alert {
        switch confirmation {
        case .exit:
            Alert(
                title: Text("Exit this session?"),
                message: Text(
                    "Your progress will be cleared and you’ll return to setup."
                ),
                primaryButton: .destructive(Text("Exit Session")) {
                    Task { await controller.startOver() }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        case .skip:
            Alert(
                title: Text("Skip this stage?"),
                message: Text(skipMessage),
                primaryButton: skipAlertButton,
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }

    private var skipAlertButton: Alert.Button {
        let action: () -> Void = {
            Task { await controller.skipCurrentStage() }
        }
        if [.cook, .finish].contains(controller.flowStage) {
            return .destructive(Text("Skip Stage"), action: action)
        }
        return .default(Text("Skip Stage"), action: action)
    }

    private var skipMessage: String {
        switch controller.session.phase {
        case .prep:
            String(localized: "Continue without completing the prep steps?")
        case .heat:
            String(localized: "Start cooking without confirming the pan is hot?")
        case .sear, .fatCap, .baste, .checkTemperature:
            String(localized: "Only continue after taking the steak out of the pan.")
        case .finishing:
            String(localized: "The steak may still be finishing with carryover heat.")
        case .ready:
            String(localized: "Continue to serving?")
        case .eat:
            String(localized: "Continue to feedback?")
        case .feedback:
            String(localized: "Return to setup without saving feedback?")
        case .setup:
            ""
        }
    }

    private var stageTransition: AnyTransition {
        if controller.flowStage == .finish {
            .asymmetric(
                insertion: .opacity,
                removal: .move(edge: .top).combined(with: .opacity)
            )
        } else {
            .opacity
        }
    }
}

private enum SessionControlConfirmation: String, Identifiable {
    case exit
    case skip

    var id: Self { self }
}

#Preview("Setup") {
    RootFlowView(controller: CookingSessionController(store: CookingStore(defaults: UserDefaults(suiteName: "preview.setup")!)))
        .environment(AppTheme())
}
