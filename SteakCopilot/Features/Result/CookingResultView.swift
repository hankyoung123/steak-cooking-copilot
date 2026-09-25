import SwiftUI

/// The single ending page.
///
/// TAKE OUT hands over to FINISHING (the rest), and when the carryover estimate
/// elapses the cook lands **here, once**. It used to be three pages: READY and
/// EAT were the same screen with a different button label ("Enjoy", then "Log
/// this cook"), and only the third carried the feedback form, so logging a cook
/// cost three taps through two identical pages. The form is now part of this
/// page, and the primary action logs the cook and returns to setup in one tap.
///
/// `.eat` and `.feedback` still render this page, because that is what a session
/// persisted by an older build restores into; the flow itself only ever enters
/// `.ready`.
///
/// The bands use `SessionLayoutMetrics.Result`, which reuses the session's top
/// rule: one control band, one title band, one hero band, one summary band, one
/// reserved middle band, and the primary action pinned to the bottom action row.
/// The middle band is reserved for the feedback form, which is now always the
/// content there, so the hero, the summary card and the CTA cannot move while
/// the form is used.
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

    /// The feedback form, which is the page's purpose: it is the only way the
    /// app learns anything from a cook, and it is why "how was it" belongs on
    /// the result page rather than behind two more taps.
    private func middleSlot(_ layout: SessionLayoutMetrics.Result) -> some View {
        feedbackControls
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
                    .accessibilityIdentifier("feedback.doneness.\(option.rawValue)")
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
                        .accessibilityIdentifier("feedback.crust.\(option.rawValue)")
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

    /// "WELL DONE" is the state the cook ends in; the form below asks the
    /// question. A session restored in the legacy `.feedback` phase keeps its own
    /// eyebrow.
    private var resultEyebrow: String {
        controller.session.phase == .feedback
            ? String(localized: "COOK COMPLETE")
            : String(localized: "WELL DONE")
    }

    private var resultTitle: String {
        switch controller.session.phase {
        case .ready, .eat: String(localized: "Enjoy!")
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

    /// One action, one identifier, whichever ending phase a session is in: the
    /// page logs the cook and goes back to setup.
    private var primaryTitle: String { String(localized: "Save & Cook Again") }

    private var primaryIdentifier: String { "feedback.save" }

    private func performPrimaryAction() {
        controller.submitFeedback(doneness: doneness, crust: crust)
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
