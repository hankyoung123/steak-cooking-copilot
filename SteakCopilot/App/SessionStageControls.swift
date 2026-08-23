import SwiftUI

struct SessionStageControls: View {
    @Environment(AppTheme.self) private var theme
    let flowStage: CookingFlowStage
    let onExit: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            controlButton(
                title: String(localized: "Exit"),
                systemImage: "xmark",
                identifier: "session.exit",
                action: onExit
            )

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                ForEach(CookingFlowStage.ordered.indices, id: \.self) { index in
                    Rectangle()
                        .fill(
                            index <= flowStage.index
                                ? (isDark ? theme.butter : theme.ember)
                                : Color.secondary.opacity(0.22)
                        )
                        .frame(width: index == flowStage.index ? 18 : 6, height: 2)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(flowStage.title)

            Spacer(minLength: 0)

            skipButton(
                title: String(localized: "Skip"),
                identifier: "session.skip",
                action: onSkip
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func controlButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 38, height: 38)
                .background(
                    .white.opacity(isDark ? 0.10 : 0.58),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(width: 62, alignment: .leading)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }

    private func skipButton(
        title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isDark ? .white.opacity(0.8) : theme.ember)
            .frame(width: 62, alignment: .trailing)
            .frame(minHeight: 38)
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
    }

    private var isDark: Bool {
        [.prep, .heat, .cook, .finish].contains(flowStage)
    }
}
