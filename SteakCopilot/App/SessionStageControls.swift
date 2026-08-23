import SwiftUI

struct SessionStageControls: View {
    let flowStage: CookingFlowStage
    let onExit: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack {
            controlButton(
                title: String(localized: "Exit"),
                systemImage: "xmark",
                identifier: "session.exit",
                action: onExit
            )

            Spacer()

            controlButton(
                title: String(localized: "Skip"),
                systemImage: "forward.end",
                identifier: "session.skip",
                action: onSkip
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
    }

    private func controlButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 13)
                .frame(minHeight: 36)
                .background(
                    .white.opacity(flowStage == .cook ? 0.1 : 0.48),
                    in: Capsule()
                )
                .overlay {
                    Capsule()
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}
