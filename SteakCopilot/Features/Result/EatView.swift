import SwiftUI

struct EatView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let controller: CookingSessionController
    @State private var revealsSlices = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 5) {
                Text("Ready to eat!")
                    .font(.title2.bold())
                HStack(spacing: 5) {
                    Text(
                        String(
                            format: String(localized: "Perfect %@"),
                            controller.session.configuration.doneness.title
                        )
                    )
                    Image(systemName: "heart.fill")
                        .foregroundStyle(theme.ember)
                }
                .font(.subheadline)
            }
            .padding(.top, 10)

            ZStack {
                SteakVisual(
                    configuration: controller.session.configuration,
                    cookedProgress: 1,
                    sliced: true
                )
                .scaleEffect(revealsSlices ? 1 : 0.96)
                .opacity(revealsSlices ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 360)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.09), radius: 18, y: 8)

            if controller.session.phase == .eat {
                VStack(spacing: 3) {
                    Text("Slice across the grain")
                        .font(.headline)
                    Text("Serve while the crust is still crisp.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }

            PrimaryActionButton(title: primaryTitle) {
                controller.confirmCurrentAction()
            }
            .accessibilityIdentifier(
                controller.session.phase == .ready ? "ready.continue" : "eat.feedback"
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .task(id: controller.session.phase) {
            if !revealsSlices {
                try? await Task.sleep(
                    for: .seconds(reduceMotion ? 0.05 : MotionTiming.readyRevealDelay)
                )
            }
            withAnimation(
                reduceMotion
                    ? .easeOut(duration: 0.15)
                    : .easeOut(duration: MotionTiming.cinematic)
            ) {
                revealsSlices = true
            }
        }
    }

    private var primaryTitle: String {
        controller.session.phase == .ready
            ? String(localized: "Time to eat")
            : String(localized: "Log this cook")
    }
}
