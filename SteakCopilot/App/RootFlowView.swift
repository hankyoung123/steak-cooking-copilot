import SwiftUI

struct RootFlowView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingControl: SessionControlConfirmation?
    @State private var showsTuningLab = false
    let controller: CookingSessionController
    /// Development-only parameter override store (`-tuningLab`).
    var tuningStore: TuningStore?

    var body: some View {
        ZStack {
            EditorialCanvas(
                dark: usesDarkCanvas
            )

            if usesDarkCanvas {
                CookingStageScene(
                    controller: controller,
                    prepIsDry: false,
                    darkBackground: true,
                    presentation: .fullBleed
                )
                .ignoresSafeArea()
            }

            Group {
                switch controller.flowStage {
                case .setup:
                    CookingHomeView(controller: controller)
                case .prep:
                    sessionView
                case .heat:
                    sessionView
                case .cook:
                    sessionView
                case .finish:
                    sessionView
                case .eat:
                    resultView
                case .feedback:
                    resultView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .id(controller.flowStage)
            .transition(stageTransition)
        }
        .foregroundStyle(theme.foreground(for: controller.flowStage))
        .animation(
            reduceMotion
                ? .easeOut(duration: controller.tuning.motion.subtle)
                : .smooth(duration: controller.tuning.motion.stageTransition),
            value: controller.flowStage
        )
        .preferredColorScheme(
            usesDarkCanvas ? .dark : .light
        )
        .alert(item: $pendingControl, content: controlAlert)
        .sheet(isPresented: $showsTuningLab) {
            if let tuningStore {
                TuningLabView(
                    store: tuningStore,
                    onApply: { controller.applyTuning($0) }
                )
            }
        }
        .onAppear {
            showsTuningLab = ProcessInfo.processInfo.arguments.contains("-tuningLab")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                controller.refresh(at: .now)
            }
        }
    }

    private var sessionView: some View {
        CookingSessionView(
            controller: controller,
            onExit: { pendingControl = .exit },
            onSkip: { pendingControl = .skip }
        )
    }

    private var resultView: some View {
        CookingResultView(
            controller: controller,
            onExit: { pendingControl = .exit },
            onSkip: { pendingControl = .skip }
        )
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
        if reduceMotion {
            return .opacity
        }

        if controller.flowStage == .finish {
            return .asymmetric(
                insertion: .scale(scale: 1.02).combined(with: .opacity),
                removal: .scale(scale: 0.98).combined(with: .opacity)
            )
        } else {
            return .asymmetric(
                insertion: .scale(scale: 1.015).combined(with: .opacity),
                removal: .scale(scale: 0.985).combined(with: .opacity)
            )
        }
    }

    private var usesDarkCanvas: Bool {
        switch controller.session.phase {
        case .sear, .fatCap, .baste, .checkTemperature, .finishing:
            true
        default:
            false
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
