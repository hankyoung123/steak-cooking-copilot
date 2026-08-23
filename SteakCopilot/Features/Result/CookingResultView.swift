import SwiftUI

struct CookingResultView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    let onExit: () -> Void
    let onSkip: () -> Void
    @State private var doneness: DonenessFeedback = .perfect
    @State private var crust: CrustFeedback = .perfect
    @State private var showsHistory = false

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sm) {
                SessionStageControls(
                    flowStage: controller.flowStage,
                    onExit: onExit,
                    onSkip: onSkip
                )

                VStack(spacing: 6) {
                    Text(resultEyebrow)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(theme.ember)
                    Text(resultTitle)
                        .font(.system(size: 38, weight: .semibold, design: .serif))
                    Text(controller.session.configuration.doneness.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Image(controller.session.configuration.doneness.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .accessibilityLabel("Sliced steak")

                HStack {
                    resultMetric(temperatureLabel, finalTemperature)
                    Spacer()
                    resultMetric("TOTAL TIME", totalTime, trailing: true)
                }
                .padding(.horizontal, AppSpacing.sm)

                if controller.session.phase == .feedback {
                    feedbackControls
                        .transition(.opacity)
                }

                PrimaryActionButton(title: primaryTitle) {
                    performPrimaryAction()
                }
                .accessibilityIdentifier(primaryIdentifier)

                HStack(spacing: AppSpacing.md) {
                    Button("Cook Again") {
                        Task { await controller.startOver() }
                    }
                    Button("View Cook Log") { showsHistory = true }
                        .accessibilityIdentifier("result.history")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink.opacity(0.68))
                .padding(.vertical, AppSpacing.xs)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.bottom, AppSpacing.md)
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showsHistory) {
            CookLogView(records: controller.cookHistory)
                .presentationDetents([.large])
        }
    }

    private var feedbackControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("HOW WAS IT?")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            HStack(spacing: 5) {
                ForEach(DonenessFeedback.allCases) { option in
                    Button {
                        doneness = option
                    } label: {
                        VStack(spacing: 5) {
                            Image(donenessAsset(for: option))
                                .resizable()
                                .scaledToFit()
                                .frame(height: 38)
                            Text(option.title)
                                .font(.caption2)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(doneness == option ? theme.ember : .clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: AppSpacing.xs) {
                ForEach(CrustFeedback.allCases) { option in
                    Button(option.title) { crust = option }
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(crust == option ? theme.ember : theme.ink.opacity(0.12))
                                .frame(height: crust == option ? 2 : 1)
                        }
                        .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private func resultMetric(
        _ label: LocalizedStringKey,
        _ value: String,
        trailing: Bool = false
    ) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
        }
    }

    private var resultEyebrow: String {
        controller.session.phase == .feedback
            ? String(localized: "COOK COMPLETE")
            : String(localized: "DONE")
    }

    private var resultTitle: String {
        switch controller.session.phase {
        case .ready: String(localized: "Ready to enjoy")
        case .eat: String(localized: "Slice and serve")
        case .feedback: String(localized: "How was it?")
        default: String(localized: "Done")
        }
    }

    private var finalTemperature: String {
        let value = controller.session.lastManualTemperatureC
            ?? controller.session.configuration.doneness.targetTemperatureC
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
        return String(format: "%lld:%02lld", Int64(seconds / 60), Int64(seconds % 60))
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
