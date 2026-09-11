import SwiftUI

/// READY → EAT → FEEDBACK.
///
/// The bands use `SessionLayoutMetrics.Result`, which reuses the session's top
/// rule: one control band, one title band, one hero band, one summary band, one
/// reserved middle band, and the primary action pinned to the bottom action row.
/// The middle band is the only one whose content changes length — the feedback
/// form is taller than the result note — so its height is reserved for the
/// taller of the two and its content is top aligned. That is what keeps the hero,
/// the summary card and the CTA from moving when the form appears; previously the
/// CTA sat *below* the form and dropped by more than a hundred points.
struct CookingResultView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let controller: CookingSessionController
    let onExit: () -> Void
    let onSkip: () -> Void
    @State private var doneness: DonenessFeedback = .perfect
    @State private var crust: CrustFeedback = .perfect
    @State private var showsHistory = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            EditorialCanvas(dark: false)

            GeometryReader { proxy in
                let layout = SessionLayoutMetrics.Result.resolve(
                    for: proxy.size,
                    dynamicTypeSize: dynamicTypeSize
                )
                ScrollView {
                    skeleton(layout: layout)
                        .frame(width: proxy.size.width)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $showsHistory) {
            CookLogView(
                records: controller.cookHistory,
                tuning: controller.tuning
            )
                .presentationDetents([.large])
                .presentationCornerRadius(28)
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            // Fade only. A scale or offset here reads as the hero itself
            // moving, which is the illusion the fixed skeleton removes.
            withAnimation(.easeOut(duration: controller.tuning.motion.resultAppear)) {
                appeared = true
            }
        }
    }

    // MARK: - Skeleton

    private func skeleton(layout: SessionLayoutMetrics.Result) -> some View {
        VStack(spacing: 0) {
            topControlsSlot(layout)
            titleSlot(layout)
            heroSlot(layout)
            summarySlot(layout)
            middleSlot(layout)
            Spacer(minLength: 0)
            bottomActionSlot(layout)
        }
    }

    private func topControlsSlot(_ layout: SessionLayoutMetrics.Result) -> some View {
        SessionStageControls(
            flowStage: controller.flowStage,
            phaseTitle: resultEyebrow,
            onExit: onExit,
            onSkip: onSkip
        )
        .padding(.horizontal, layout.screenInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.topControlHeight)
        .padding(.bottom, layout.controlsSpacing)
        .sessionLayoutProbe(ResultLayoutID.topControls)
    }

    private func titleSlot(_ layout: SessionLayoutMetrics.Result) -> some View {
        VStack(spacing: 5) {
            Text(controller.session.configuration.doneness.title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(theme.ember)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(resultTitle)
                .editorialDisplayStyle(size: 43, color: theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .padding(.horizontal, layout.contentInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.titleHeight)
        .padding(.top, layout.titleSpacing)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(ResultLayoutID.title)
    }

    private func heroSlot(_ layout: SessionLayoutMetrics.Result) -> some View {
        Image("ResultHeroCutout")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: layout.heroHeight)
            .padding(.horizontal, layout.sceneInset)
            .shadow(color: .black.opacity(0.13), radius: 18, y: 12)
            .opacity(appeared ? 1 : 0)
            .accessibilityLabel("Sliced steak")
            .padding(.top, layout.heroSpacing)
            .sessionLayoutProbe(ResultLayoutID.hero)
    }

    private func summarySlot(_ layout: SessionLayoutMetrics.Result) -> some View {
        summaryCard
            .padding(.horizontal, layout.contentInset)
            .frame(height: layout.summaryHeight)
            .opacity(appeared ? 1 : 0)
            .padding(.top, layout.summarySpacing)
            .sessionLayoutProbe(ResultLayoutID.summary)
    }

    /// The only band whose content length differs between phases ("how it went"
    /// note vs the feedback form). Its height is reserved for the taller of the
    /// two, and the content is top aligned inside it, so the feedback form
    /// appearing never pushes the hero or the summary card.
    private func middleSlot(_ layout: SessionLayoutMetrics.Result) -> some View {
        Group {
            if controller.session.phase == .feedback {
                feedbackControls
            } else {
                resultNote
            }
        }
        .padding(.horizontal, layout.contentInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.middleHeight, alignment: .top)
        .contentTransition(.opacity)
    }

    private func bottomActionSlot(_ layout: SessionLayoutMetrics.Result) -> some View {
        VStack(spacing: layout.bottomPrimarySpacing) {
            Group {
                HStack(spacing: 12) {
                    outlineButton("View Cook Log", icon: "chevron.right") {
                        showsHistory = true
                    }
                    .accessibilityIdentifier("result.history")

                    outlineButton("Cook Again", icon: "arrow.right") {
                        Task { await controller.startOver() }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: layout.bottomSecondaryHeight)

            Group {
                PrimaryActionButton(
                    title: primaryTitle,
                    icon: "arrow.right"
                ) {
                    performPrimaryAction()
                }
                .accessibilityIdentifier(primaryIdentifier)
            }
            .frame(maxWidth: .infinity)
            .frame(height: layout.bottomPrimaryHeight)
            .sessionLayoutProbe(ResultLayoutID.primaryAction)
        }
        .padding(.horizontal, layout.contentInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.bottomActionHeight, alignment: .bottom)
        .padding(.top, layout.bottomActionSpacing)
    }

    // MARK: - Band content

    private var summaryCard: some View {
        HStack(spacing: 0) {
            resultMetric(temperatureLabel, finalTemperature)
            Rectangle()
                .fill(theme.ink.opacity(0.1))
                .frame(width: 0.7, height: 56)
            resultMetric("TIME", totalTime)
        }
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.card.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.ink.opacity(0.08), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }

    private var resultNote: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(format: String(localized: "Perfect %@"), controller.session.configuration.doneness.title))
                .font(.system(size: 14, weight: .regular, design: .serif))
            Text("Juicy and tender. Great job!")
                .font(.system(size: 11))
                .foregroundStyle(theme.ink.opacity(0.58))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(theme.card.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.ink.opacity(0.08), lineWidth: 0.8)
        }
    }

    private var feedbackControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW WAS IT?")
                .quietEyebrowStyle(color: theme.ink)

            HStack(spacing: 3) {
                ForEach(DonenessFeedback.allCases) { option in
                    Button {
                        doneness = option
                    } label: {
                        VStack(spacing: 5) {
                            Image(donenessAsset(for: option))
                                .resizable()
                                .scaledToFit()
                                .frame(height: 36)
                            Text(option.title)
                                .font(.system(size: 7, weight: .regular, design: .serif))
                                .lineLimit(2)
                                .minimumScaleFactor(0.65)
                        }
                        .frame(maxWidth: .infinity, minHeight: 66)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(doneness == option ? theme.ember : .clear)
                                .frame(height: 1)
                        }
                    }
                    .buttonStyle(EditorialPressStyle())
                }
            }

            HStack(spacing: 8) {
                ForEach(CrustFeedback.allCases) { option in
                    Button(option.title) { crust = option }
                        .font(.system(size: 9, weight: .medium, design: .serif))
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(crust == option ? theme.ember : theme.ink.opacity(0.11))
                                .frame(height: crust == option ? 1.3 : 0.7)
                        }
                        .buttonStyle(EditorialPressStyle())
                }
            }
        }
        .padding(14)
        .background(theme.card.opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
    }

    private func outlineButton(
        _ title: LocalizedStringKey,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: icon)
            }
            .font(.system(size: 12, weight: .regular, design: .serif))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(theme.ink.opacity(0.16), lineWidth: 0.8)
            }
        }
        .buttonStyle(EditorialPressStyle())
    }

    private func resultMetric(
        _ label: LocalizedStringKey,
        _ value: String
    ) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(theme.ink.opacity(0.44))
            Text(value)
                .font(.system(size: 22, weight: .regular, design: .serif))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var resultEyebrow: String {
        controller.session.phase == .feedback
            ? String(localized: "COOK COMPLETE")
            : String(localized: "WELL DONE")
    }

    private var resultTitle: String {
        switch controller.session.phase {
        case .ready: String(localized: "Enjoy!")
        case .eat: String(localized: "Enjoy!")
        case .feedback: String(localized: "How was it?")
        default: String(localized: "Enjoy!")
        }
    }

    private var finalTemperature: String {
        let value = controller.session.lastManualTemperatureC
            ?? controller.tuning.doneness[
                controller.session.configuration.doneness
            ].targetTemperatureC
        return String(format: "%.0f°C", value)
    }

    private var temperatureLabel: LocalizedStringKey {
        controller.session.lastManualTemperatureC == nil
            ? "TARGET TEMP"
            : "FINAL TEMP"
    }

    private var totalTime: String {
        guard let started = controller.session.startedAt else { return "—" }
        let end = controller.session.finishedAt ?? .now
        let seconds = max(0, Int(end.timeIntervalSince(started)))
        return String(format: "%02lld:%02lld", Int64(seconds / 60), Int64(seconds % 60))
    }

    private var primaryTitle: String {
        switch controller.session.phase {
        case .ready: String(localized: "Enjoy")
        case .eat: String(localized: "Log this cook")
        case .feedback: String(localized: "Save & Cook Again")
        default: String(localized: "Done")
        }
    }

    private var primaryIdentifier: String {
        switch controller.session.phase {
        case .ready: "ready.continue"
        case .eat: "eat.feedback"
        case .feedback: "feedback.save"
        default: "result.primary"
        }
    }

    private func performPrimaryAction() {
        if controller.session.phase == .feedback {
            controller.submitFeedback(doneness: doneness, crust: crust)
        } else {
            controller.confirmCurrentAction()
        }
    }

    private func donenessAsset(for option: DonenessFeedback) -> String {
        switch option {
        case .tooRare: Doneness.rare.assetName
        case .slightlyRare: Doneness.mediumRare.assetName
        case .perfect: controller.session.configuration.doneness.assetName
        case .slightlyDone: Doneness.mediumWell.assetName
        case .tooDone: Doneness.wellDone.assetName
        }
    }
}
