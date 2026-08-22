import SwiftUI

struct EatView: View {
    let controller: CookingSessionController
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sliced = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 28)

            Text(controller.session.phase == .ready ? "READY" : "ENJOY")
                .quietEyebrowStyle(color: theme.ink)

            Text(controller.session.phase == .ready ? "You nailed the timing." : "Time to eat.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            ZStack {
                SteakVisual(
                    configuration: controller.session.configuration,
                    cookedProgress: 1,
                    sliced: false
                )
                .opacity(sliced ? 0 : 1)

                SteakVisual(
                    configuration: controller.session.configuration,
                    cookedProgress: 1,
                    sliced: true
                )
                .opacity(sliced ? 1 : 0)
                .scaleEffect(sliced ? 1 : (reduceMotion ? 1 : 0.94))
            }
            .frame(height: 240)
            .padding(.horizontal, 26)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .easeInOut(duration: MotionTiming.cinematic),
                value: sliced
            )

            if controller.session.phase == .eat {
                VStack(spacing: 8) {
                    Text(controller.session.configuration.doneness.title)
                        .font(.title2.bold())
                    Text("Slice across the grain and serve now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            Spacer()

            PrimaryActionButton(
                title: controller.session.phase == .ready ? "Time to eat" : "How did it turn out?",
                icon: controller.session.phase == .ready ? "fork.knife" : "arrow.right"
            ) {
                controller.confirmCurrentAction()
            }
            .accessibilityIdentifier(
                controller.session.phase == .ready ? "ready.continue" : "eat.feedback"
            )
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .task(id: controller.session.phase) {
            if controller.session.phase == .ready {
                try? await Task.sleep(
                    for: .seconds(
                        reduceMotion ? 0.05 : MotionTiming.readyRevealDelay
                    )
                )
                sliced = true
            } else {
                sliced = true
            }
        }
    }
}
