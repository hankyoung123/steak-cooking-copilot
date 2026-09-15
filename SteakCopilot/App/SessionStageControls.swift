import SwiftUI

struct SessionStageControls: View {
    @Environment(AppTheme.self) private var theme
    let flowStage: CookingFlowStage
    var phaseTitle: String? = nil
    /// The flow counter to display, or `nil` to hide it.
    ///
    /// This control only renders the pair of numbers. Deciding what a step is,
    /// how many there are, and when the journey is over belongs to
    /// `CookingJourney`, so the chrome has no idea what a fat cap or a baste is.
    var progress: CookingProgress? = nil
    var dark: Bool? = nil
    let onExit: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            exitControl

            Spacer(minLength: 0)

            centerContent
                .frame(maxWidth: .infinity)
                .accessibilityLabel(phaseTitle ?? flowStage.title)

            Spacer(minLength: 0)

            trailingContent
        }
        .padding(.horizontal, 2)
        .frame(height: 42)
    }

    private var exitControl: some View {
        controlButton(
            title: String(localized: "Exit"),
            systemImage: "chevron.left",
            identifier: "session.exit",
            action: onExit
        )
    }

    @ViewBuilder
    private var centerContent: some View {
        if let phaseTitle {
            Text(phaseTitle)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.7)
                .foregroundStyle(isDark ? theme.porcelain.opacity(0.8) : theme.ink.opacity(0.72))
                .lineLimit(1)
                .accessibilityIdentifier("session.phase.title")
        } else {
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
        }
    }

    private var trailingContent: some View {
        VStack(alignment: .trailing, spacing: 1) {
            // The counter's row is reserved even when there is nothing to count.
            // FINISHING ends the in-pan journey, and letting the row collapse
            // there would move the skip control and change the row's own bounds —
            // the nav must not reflow just because a stage has no step number.
            Text(progress?.label ?? " ")
                .font(.system(size: 9, weight: .medium, design: .serif))
                .monospacedDigit()
                .foregroundStyle(isDark ? theme.porcelain.opacity(0.78) : theme.ink.opacity(0.68))
                .opacity(progress == nil ? 0 : 1)
                .frame(height: 12)
                .accessibilityHidden(progress == nil)
                .accessibilityIdentifier(
                    progress == nil ? "session.step.none" : "session.step"
                )
            skipButton(
                title: String(localized: "Skip"),
                identifier: "session.skip",
                action: onSkip
            )
        }
        .frame(width: 62, alignment: .trailing)
    }

    private func controlButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .light))
                .frame(width: 38, height: 38)
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
            .font(.system(size: 8, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(isDark ? .white.opacity(0.48) : theme.ember.opacity(0.8))
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier)
    }

    private var isDark: Bool {
        if let dark { return dark }
        return [.prep, .heat, .cook, .finish].contains(flowStage)
    }
}
