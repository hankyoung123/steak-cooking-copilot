import SwiftUI

struct CookingSessionView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    let onExit: () -> Void
    let onSkip: () -> Void
    @State private var dried = false
    @State private var salted = false
    @State private var manualTemperature = 50.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.sm) {
                        SessionStageControls(
                            flowStage: controller.flowStage,
                            onExit: onExit,
                            onSkip: onSkip
                        )

                        sessionHeader(at: context.date)
                            .padding(.bottom, AppSpacing.xs)

                        CookingStageScene(
                            controller: controller,
                            prepIsDry: dried
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: max(260, min(proxy.size.height * 0.43, 420)))

                        instruction(at: context.date)

                        if controller.session.phase == .checkTemperature {
                            ManualTemperatureControl(
                                temperature: $manualTemperature,
                                pullTemperatureC: controller.guidance.pullTemperatureC,
                                accentColor: theme.butter,
                                onSubmit: {
                                    controller.recordManualTemperature(
                                        manualTemperature,
                                        at: context.date
                                    )
                                }
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        telemetry
                        primaryAction(at: context.date)
                    }
                    .padding(.bottom, AppSpacing.sm)
                    .frame(width: max(0, proxy.size.width - AppSpacing.sm * 2))
                    .padding(.horizontal, AppSpacing.sm)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(theme.porcelain)
        .background(theme.charcoal.ignoresSafeArea())
        .onAppear {
            manualTemperature = controller.session.lastManualTemperatureC
                ?? controller.guidance.pullTemperatureC - 2
        }
        .task(id: controller.session.nextActionAt) {
            await refreshAtKeyBoundaries()
        }
    }

    private func sessionHeader(at date: Date) -> some View {
        VStack(spacing: 7) {
            Text(phaseEyebrow)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(theme.butter)

            Text(heroValue(at: date))
                .font(.system(size: heroValue(at: date).contains(":") ? 82 : 44, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .contentTransition(.numericText(countsDown: true))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.16))
                    Rectangle()
                        .fill(theme.butter)
                        .frame(width: proxy.size.width * overallProgress)
                }
            }
            .frame(height: 2)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func instruction(at date: Date) -> some View {
        VStack(spacing: 7) {
            Text(instructionTitle(at: date))
                .font(.system(size: 26, weight: .semibold))
                .multilineTextAlignment(.center)
            Text(instructionDetail)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.42), value: controller.session.phase)
        .accessibilityIdentifier("session.instruction")
    }

    private var telemetry: some View {
        HStack {
            telemetryMetric(
                label: "DONENESS",
                value: controller.session.configuration.doneness.title
            )
            Spacer()
            telemetryMetric(
                label: "PULL TARGET",
                value: String(
                    format: "%.0f°C",
                    controller.guidance.pullTemperatureC
                ),
                trailing: true
            )
        }
        .padding(.vertical, AppSpacing.xs)
    }

    @ViewBuilder
    private func primaryAction(at date: Date) -> some View {
        switch controller.session.phase {
        case .prep:
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.xs) {
                    prepToggle("Dry", identifier: "prep.dry", isOn: $dried)
                    prepToggle("Salt", identifier: "prep.salt", isOn: $salted)
                }
                PrimaryActionButton(
                    title: String(localized: "Continue to preheat"),
                    isEnabled: dried && salted,
                    lightOnDark: true
                ) { controller.finishPrep(at: date) }
                .accessibilityIdentifier("prep.continue")
            }
        case .heat:
            PrimaryActionButton(
                title: String(localized: "Pan is ready"),
                lightOnDark: true
            ) { controller.panIsReady(at: date) }
            .accessibilityIdentifier("heat.ready")
        case .sear, .fatCap, .baste, .checkTemperature:
            if shouldShowCookConfirm {
                PrimaryActionButton(
                    title: cookConfirmTitle,
                    isEnabled: remaining(at: date) <= 0,
                    lightOnDark: true
                ) { controller.confirmCurrentAction(at: date) }
                .accessibilityIdentifier("cook.confirm")
            }
        case .finishing:
            Text("Carryover heat is finishing the center.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        default:
            EmptyView()
        }
    }

    private func prepToggle(
        _ title: LocalizedStringKey,
        identifier: String,
        isOn: Binding<Bool>
    ) -> some View {
        Button { isOn.wrappedValue.toggle() } label: {
            HStack {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                Text(title)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    private func telemetryMetric(
        label: LocalizedStringKey,
        value: String,
        trailing: Bool = false
    ) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 3) {
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(1.1).foregroundStyle(.white.opacity(0.48))
            Text(value).font(.subheadline.weight(.semibold))
        }
    }

    private var phaseEyebrow: String {
        switch controller.session.phase {
        case .prep: String(localized: "PREP")
        case .heat: String(localized: "PREHEAT")
        case .sear, .fatCap: String(localized: "SEAR")
        case .baste: String(localized: "BASTE")
        case .checkTemperature: String(localized: "CHECK")
        case .finishing: String(localized: "REST")
        default: ""
        }
    }

    private func heroValue(at date: Date) -> String {
        switch controller.session.phase {
        case .prep: String(localized: "Ready the steak")
        case .heat: String(localized: "Heat the pan")
        case .finishing: countdown(at: date)
        default:
            remaining(at: date) > 0 ? countdown(at: date) : controller.guidance.currentAction.title
        }
    }

    private func instructionTitle(at date: Date) -> String {
        switch controller.session.phase {
        case .prep: dried ? String(localized: "Season both sides") : String(localized: "Pat every surface dry")
        case .heat: String(localized: "Wait for a hard sizzle")
        case .finishing: String(localized: "Rest off the heat")
        default:
            switch controller.guidance.currentAction {
            case .wait: String(localized: "Build the crust")
            case .flip: String(localized: "Flip with tongs")
            case .standFatCap: String(localized: "Sear the fat edge")
            case .addButter: String(localized: "Add butter and aromatics")
            case .baste: String(localized: "Baste continuously")
            case .checkTemperature: String(localized: "Probe through the side")
            case .takeOut: String(localized: "Remove from the pan")
            default: controller.guidance.currentAction.title
            }
        }
    }

    private var instructionDetail: String {
        switch controller.session.phase {
        case .prep: String(localized: "A dry surface gives you a deeper, faster crust.")
        case .heat: String(localized: "A few drops of water should sizzle and dance.")
        case .finishing: String(localized: "Let heat move gently toward the center.")
        default:
            switch controller.guidance.currentAction {
            case .wait: String(localized: "Keep the steak still against the pan.")
            case .flip: String(localized: "Turn once, then set it down cleanly.")
            case .standFatCap: String(localized: "Hold the edge against the pan.")
            case .addButter: String(localized: "Add garlic and rosemary if you like.")
            case .baste: String(localized: "Tilt the pan and spoon over the steak.")
            case .checkTemperature: String(localized: "Aim the probe at the center.")
            case .takeOut: String(localized: "Carryover heat will finish the cook.")
            default: ""
            }
        }
    }

    private var overallProgress: Double {
        switch controller.session.phase {
        case .prep: 0.08
        case .heat: 0.18
        case .sear, .fatCap: 0.28 + controller.guidance.estimatedProgress * 0.42
        case .baste: 0.76
        case .checkTemperature: 0.86
        case .finishing: 0.94
        default: 0
        }
    }

    private func remaining(at date: Date) -> TimeInterval {
        controller.session.remaining(at: date)
    }

    private func countdown(at date: Date) -> String {
        let total = max(0, Int(ceil(remaining(at: date))))
        return String(format: "%01lld:%02lld", Int64(total / 60), Int64(total % 60))
    }

    private var shouldShowCookConfirm: Bool {
        ![.wait, .baste, .waitForFinish].contains(controller.guidance.currentAction)
    }

    private var cookConfirmTitle: String {
        switch controller.guidance.currentAction {
        case .flip: String(localized: "Flipped")
        case .standFatCap: String(localized: "Start fat cap")
        case .addButter: String(localized: "Butter added")
        case .checkTemperature: String(localized: "No thermometer — continue")
        case .takeOut: String(localized: "Steak is out")
        default: String(localized: "Done")
        }
    }

    private func refreshAtKeyBoundaries() async {
        guard let actionDate = controller.session.nextActionAt else { return }
        for secondsBefore in [5.0, 3.0, 2.0, 0.0] {
            let delay = actionDate.addingTimeInterval(-secondsBefore).timeIntervalSinceNow
            if delay > 0 {
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            controller.refresh(at: .now)
        }
    }
}
