import SwiftUI

struct RootFlowView: View {
    let controller: CookingSessionController
    @Environment(AppTheme.self) private var theme

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
        .animation(.easeInOut(duration: 0.7), value: controller.flowStage)
        .preferredColorScheme(controller.flowStage == .cook ? .dark : .light)
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

#Preview("Setup") {
    RootFlowView(controller: CookingSessionController(store: CookingStore(defaults: UserDefaults(suiteName: "preview.setup")!)))
        .environment(AppTheme())
}
