import SwiftUI

struct CookingResultView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

            ScrollView {
                VStack(spacing: 0) {
                    SessionStageControls(
                        flowStage: controller.flowStage,
                        phaseTitle: resultEyebrow,
                        onExit: onExit,
                        onSkip: onSkip
                    )
                    .padding(.horizontal, 18)

                    VStack(spacing: 5) {
                        Text(controller.session.configuration.doneness.title.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.6)
                            .foregroundStyle(theme.ember)
                        Text(resultTitle)
                            .editorialDisplayStyle(size: 43, color: theme.ink)
                    }
                    .padding(.top, 14)
                    .offset(y: appeared ? 0 : 10)
                    .opacity(appeared ? 1 : 0)

                    Image("ResultHeroCutout")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 306)
                        .padding(.horizontal, 14)
                        .shadow(color: .black.opacity(0.13), radius: 18, y: 12)
                        .scaleEffect(appeared ? 1 : 0.94)
                        .opacity(appeared ? 1 : 0)
                        .accessibilityLabel("Sliced steak")

                    summaryCard
                        .padding(.horizontal, 26)
                        .offset(y: appeared ? 0 : 12)
                        .opacity(appeared ? 1 : 0)

                    if controller.session.phase == .feedback {
                        feedbackControls
                            .padding(.horizontal, 26)
                            .padding(.top, 14)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        resultNote
                            .padding(.horizontal, 26)
                            .padding(.top, 14)
                    }

                    PrimaryActionButton(
                        title: primaryTitle,
                        icon: "arrow.right"
                    ) {
                        performPrimaryAction()
                    }
                    .accessibilityIdentifier(primaryIdentifier)
                    .padding(.horizontal, 26)
                    .padding(.top, 14)

                    HStack(spacing: 12) {
                        outlineButton("View Cook Log", icon: "chevron.right") {
                            showsHistory = true
                        }
                        .accessibilityIdentifier("result.history")

                        outlineButton("Cook Again", icon: "arrow.right") {
                            Task { await controller.startOver() }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
            .scrollIndicators(.hidden)
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
            withAnimation(.easeOut(duration: controller.tuning.motion.resultAppear)) {
                appeared = true
            }
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            resultMetric(temperatureLabel, finalTemperature)
            Rectangle()
                .fill(theme.ink.opacity(0.1))
                .frame(width: 0.7, height: 56)
            resultMetric("TIME", totalTime)
        }
        .padding(.vertical, 13)
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
            .frame(maxWidth: .infinity, minHeight: 46)
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
