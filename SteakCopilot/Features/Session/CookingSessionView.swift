import SwiftUI

struct CookingSessionView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    VStack(spacing: 0) {
                        SessionStageControls(
                            flowStage: controller.flowStage,
                            phaseTitle: navigationTitle,
                            stepLabel: stepLabel,
                            dark: isDarkStage,
                            onExit: onExit,
                            onSkip: onSkip
                        )
                        .padding(.horizontal, 18)

                        sessionHeader(at: context.date)
                            .padding(.horizontal, 22)
                            .padding(.top, 12)

                        Group {
                            if isDarkStage {
                                Color.clear
                                    .accessibilityHidden(true)
                            } else {
                                CookingStageScene(
                                    controller: controller,
                                    prepIsDry: dried,
                                    darkBackground: false
                                )
                            }
                        }
                        .frame(width: proxy.size.width)
                        .frame(height: sceneHeight(for: proxy.size.height))
                        .padding(.top, 5)

                        instructionAction(at: context.date)
                            .padding(.horizontal, 26)
                            .padding(.top, 18)

                        if controller.session.phase == .checkTemperature {
                            ManualTemperatureControl(
                                temperature: $manualTemperature,
                                pullTemperatureC: controller.guidance.pullTemperatureC,
                                accentColor: isDarkStage ? theme.butter : theme.ember,
                                onSubmit: {
                                    controller.recordManualTemperature(
                                        manualTemperature,
                                        at: context.date
                                    )
                                }
                            )
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                            .transition(.move(edge: .bottom).combined(with: .opacity))

                            Button {
                                controller.continueWithoutThermometer(at: context.date)
                            } label: {
                                Text("No thermometer — use timing")
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundStyle(secondaryText)
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(hairlineColor)
                                            .frame(height: 0.7)
                                            .offset(y: 4)
                                    }
                            }
                            .buttonStyle(EditorialPressStyle())
                            .accessibilityIdentifier("cook.noThermometer")
                            .padding(.top, 10)
                        }

                        if controller.session.phase == .finishing {
                            finishingCard(at: context.date)
                                .padding(.horizontal, 22)
                                .padding(.top, 14)
                        } else {
                            progressRail
                                .padding(.horizontal, 26)
                                .padding(.top, 20)

                            telemetry
                                .padding(.horizontal, 28)
                                .padding(.top, 16)
                        }

                        explicitPhaseAction(at: context.date)
                            .padding(.horizontal, 26)
                            .padding(.top, 16)
                            .padding(.bottom, 20)
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
            }
        }
        .foregroundStyle(isDarkStage ? theme.porcelain : theme.ink)
        .onAppear {
            manualTemperature = controller.session.lastManualTemperatureC
                ?? controller.guidance.pullTemperatureC - 2
        }
        .task(id: controller.session.nextActionAt) {
            await refreshAtKeyBoundaries()
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.5),
            value: controller.session.phase
        )
    }

    private func sessionHeader(at date: Date) -> some View {
        Group {
            if usesTimer(at: date) {
                Text(countdown(at: date))
                    .editorialDisplayStyle(size: 78, color: primaryText.opacity(0.88))
                    .monospacedDigit()
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Text(heroValue(at: date))
                    .editorialDisplayStyle(size: 40, color: primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .shadow(
            color: .black.opacity(isDarkStage ? 0.84 : 0),
            radius: 10,
            y: 2
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func instructionAction(at date: Date) -> some View {
        if isCookPhase, shouldShowCookConfirm {
            Button {
                controller.confirmCurrentAction(at: date)
            } label: {
                instructionLabel(at: date, interactive: true)
            }
            .buttonStyle(EditorialPressStyle())
            .disabled(remaining(at: date) > 0)
            .opacity(remaining(at: date) > 0 ? 0.48 : 1)
            .accessibilityLabel(cookConfirmTitle)
            .accessibilityIdentifier("cook.confirm")
        } else {
            instructionLabel(at: date, interactive: false)
                .accessibilityIdentifier("session.instruction")
        }
    }

    private func instructionLabel(at date: Date, interactive: Bool) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 9) {
                Text(instructionTitle(at: date))
                    .font(.system(size: 21, weight: .regular, design: .serif))
                if interactive {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .light))
                }
            }
            .foregroundStyle(interactive ? accentColor : primaryText.opacity(0.88))

            if showsInstructionDetail {
                Text(instructionDetail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: showsInstructionDetail ? 52 : 34)
        .shadow(
            color: .black.opacity(isDarkStage ? 0.88 : 0),
            radius: 8,
            y: 2
        )
        .contentShape(Rectangle())
        .contentTransition(.opacity)
    }

    private var progressRail: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(hairlineColor)
                    .frame(height: 1)
                Rectangle()
                    .fill(accentColor)
                    .frame(width: proxy.size.width * overallProgress, height: 1.4)
                Circle()
                    .fill(isDarkStage ? theme.charcoal : theme.porcelain)
                    .frame(width: 10, height: 10)
                    .overlay {
                        Circle().stroke(accentColor, lineWidth: 1.3)
                        Circle().fill(accentColor).frame(width: 3, height: 3)
                    }
                    .offset(x: max(0, proxy.size.width * overallProgress - 5))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 12)
        .animation(
            reduceMotion ? nil : .spring(duration: 0.52, bounce: 0.12),
            value: overallProgress
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func finishingCard(at date: Date) -> some View {
        VStack(spacing: 12) {
            if let reading = controller.guidance.lastManualTemperatureC {
                HStack(spacing: 0) {
                    sessionMetric(
                        label: "LAST READING",
                        value: String(format: "%.0f°C", reading)
                    )
                    Rectangle()
                        .fill(hairlineColor.opacity(0.72))
                        .frame(width: 0.7, height: 42)
                    sessionMetric(
                        label: "PULL TARGET",
                        value: String(format: "%.0f°C", controller.guidance.pullTemperatureC)
                    )
                    Rectangle()
                        .fill(hairlineColor.opacity(0.72))
                        .frame(width: 0.7, height: 42)
                    sessionMetric(
                        label: "TARGET TEMP",
                        value: String(format: "%.0f°C", controller.guidance.targetTemperatureC)
                    )
                }
                Text("Expected carryover +1–3°C · Estimated")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor.opacity(0.92))
            } else {
                VStack(spacing: 4) {
                    Text("ESTIMATED FINISH")
                        .font(.system(size: 8, weight: .medium))
                        .tracking(1.1)
                        .foregroundStyle(secondaryText)
                    Text("No thermometer reading recorded")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(primaryText.opacity(0.84))
                        .multilineTextAlignment(.center)
                }
            }

            finishingHeatIndicator(at: date)

            Text("This is an estimate, not a live temperature measurement.")
                .font(.system(size: 10))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(hairlineColor, lineWidth: 0.8)
        }
    }

    /// Abstract finishing-heat progress derived from estimated time
    /// (phaseStartedAt → nextActionAt), never from a temperature. No
    /// percentage is shown: carryover is an estimate, not a measurement.
    private func finishingHeatIndicator(at date: Date) -> some View {
        let progress = finishingProgress(at: date)
        return VStack(spacing: 6) {
            Label("Finishing heat", systemImage: "flame")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(hairlineColor.opacity(0.55))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.55), accentColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, proxy.size.width * progress))
                }
            }
            .frame(height: 5)
            .animation(
                reduceMotion ? nil : .easeOut(duration: MotionTiming.responsive),
                value: progress
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finishing heat")
    }

    private func finishingProgress(at date: Date) -> Double {
        guard let nextActionAt = controller.session.nextActionAt else { return 0 }
        let total = nextActionAt.timeIntervalSince(controller.session.phaseStartedAt)
        guard total > 0 else { return 1 }
        let remaining = controller.session.remaining(at: date)
        return min(max(1 - remaining / total, 0), 1)
    }

    private var estimatedFinishRange: String {
        FinishingDisplay.rangeText(for: controller.guidance.finishingEstimate)
    }

    private var telemetry: some View {
        HStack(spacing: 0) {
            sessionMetric(
                label: "TARGET TEMP",
                value: String(format: "%.0f°C", controller.session.configuration.doneness.targetTemperatureC)
            )
            Rectangle()
                .fill(hairlineColor.opacity(0.72))
                .frame(width: 0.7, height: 42)
            sessionMetric(
                label: "LAST READING",
                value: currentTemperatureText
            )
        }
    }

    @ViewBuilder
    private func explicitPhaseAction(at date: Date) -> some View {
        switch controller.session.phase {
        case .prep:
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    prepToggle("Dry", identifier: "prep.dry", isOn: $dried)
                    prepToggle("Salt", identifier: "prep.salt", isOn: $salted)
                }
                PrimaryActionButton(
                    title: String(localized: "Continue to preheat"),
                    icon: "arrow.right",
                    isEnabled: dried && salted,
                    lightOnDark: isDarkStage
                ) { controller.finishPrep(at: date) }
                .accessibilityIdentifier("prep.continue")
            }
        case .heat:
            PrimaryActionButton(
                title: String(localized: "Pan is ready"),
                icon: "arrow.right",
                lightOnDark: isDarkStage
            ) { controller.panIsReady(at: date) }
            .accessibilityIdentifier("heat.ready")
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
            HStack(spacing: 8) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn.wrappedValue ? accentColor : secondaryText)
                Text(title)
            }
            .font(.system(size: 13, weight: .regular, design: .serif))
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(hairlineColor, lineWidth: 0.8)
            }
        }
        .buttonStyle(EditorialPressStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(isOn.wrappedValue ? .isSelected : [])
    }

    private func sessionMetric(
        label: LocalizedStringKey,
        value: String
    ) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(1.1)
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(primaryText.opacity(0.84))
        }
        .frame(maxWidth: .infinity)
    }

    private var navigationTitle: String {
        if isCookPhase {
            switch controller.guidance.currentAction {
            case .flip:
                return String(localized: "SEAR · FLIP")
            case .standFatCap:
                return String(localized: "SEAR · FAT CAP")
            case .addButter, .baste:
                return String(localized: "BUTTER · BASTE")
            case .checkTemperature, .takeOut:
                return String(localized: "CHECK")
            default:
                break
            }
        }

        switch controller.session.phase {
        case .prep: return String(localized: "PREP")
        case .heat: return String(localized: "PREHEAT")
        case .sear, .fatCap: return String(localized: "SEAR · SIDE ONE")
        case .baste: return String(localized: "BUTTER · BASTE")
        case .checkTemperature: return String(localized: "CHECK")
        case .finishing: return String(localized: "FINISHING")
        default: return ""
        }
    }

    private var stepLabel: String {
        let step: Int
        if isCookPhase {
            switch controller.guidance.currentAction {
            case .flip: step = 2
            case .standFatCap: step = 3
            case .addButter, .baste: step = 4
            case .checkTemperature, .takeOut: step = 5
            default: step = 1
            }
        } else {
            switch controller.session.phase {
            case .prep, .heat: step = 0
            case .finishing: step = 6
            default: step = 7
            }
        }
        return String(format: "%02d / 07", step)
    }

    private func sceneHeight(for availableHeight: CGFloat) -> CGFloat {
        max(310, min(availableHeight * 0.43, 390))
    }

    private func usesTimer(at date: Date) -> Bool {
        switch controller.session.phase {
        case .sear, .fatCap, .baste:
            remaining(at: date) > 0
        default:
            // FINISHING is an estimate, never a precise second countdown.
            false
        }
    }

    private func heroValue(at date: Date) -> String {
        switch controller.session.phase {
        case .prep: String(localized: "Ready the steak")
        case .heat: String(localized: "Heat the pan")
        case .checkTemperature: String(localized: "Check doneness")
        case .finishing: estimatedFinishRange
        default: instructionTitle(at: date)
        }
    }

    private func instructionTitle(at date: Date) -> String {
        switch controller.session.phase {
        case .prep:
            dried ? String(localized: "Season both sides") : String(localized: "Pat every surface dry")
        case .heat:
            String(localized: "Wait for a hard sizzle")
        case .finishing:
            String(localized: "Carryover heat will finish the center.")
        default:
            switch controller.guidance.currentAction {
            case .wait: String(localized: "Don’t move it yet.")
            case .flip: String(localized: "Flip now.")
            case .standFatCap: String(localized: "Sear the fat edge.")
            case .addButter: String(localized: "Add butter and aromatics.")
            case .baste: String(localized: "Tilt pan & baste.")
            case .checkTemperature: String(localized: "Insert probe in the thickest part.")
            case .takeOut: String(localized: "Remove from the pan.")
            default: controller.guidance.currentAction.title
            }
        }
    }

    private var instructionDetail: String {
        switch controller.session.phase {
        case .prep: String(localized: "A dry surface gives you a deeper, faster crust.")
        case .heat: String(localized: "Oil should shimmer and the steak should sizzle immediately on contact.")
        default: ""
        }
    }

    private var showsInstructionDetail: Bool {
        [.prep, .heat].contains(controller.session.phase)
    }

    private var overallProgress: Double {
        switch controller.session.phase {
        case .prep: 0.04
        case .heat: 0.08
        case .sear, .fatCap: 0.12 + controller.guidance.estimatedProgress * 0.48
        case .baste: 0.62
        case .checkTemperature: 0.78
        case .finishing: 0.9
        default: 1
        }
    }

    private var currentTemperatureText: String {
        guard let value = controller.session.lastManualTemperatureC else { return "—" }
        return String(format: "%.0f°C", value)
    }

    private var isCookPhase: Bool {
        [.sear, .fatCap, .baste, .checkTemperature].contains(controller.session.phase)
    }

    private var isDarkStage: Bool {
        switch controller.session.phase {
        case .sear, .fatCap, .baste, .checkTemperature, .finishing:
            true
        default:
            false
        }
    }

    private var primaryText: Color {
        isDarkStage ? theme.porcelain : theme.ink
    }

    private var secondaryText: Color {
        isDarkStage ? .white.opacity(0.43) : theme.ink.opacity(0.48)
    }

    private var hairlineColor: Color {
        isDarkStage ? .white.opacity(0.22) : theme.ink.opacity(0.16)
    }

    private var accentColor: Color {
        isDarkStage ? theme.butter : theme.ember
    }

    private func remaining(at date: Date) -> TimeInterval {
        controller.session.remaining(at: date)
    }

    private func countdown(at date: Date) -> String {
        let total = max(0, Int(ceil(remaining(at: date))))
        return String(format: "%02lld:%02lld", Int64(total / 60), Int64(total % 60))
    }

    private var shouldShowCookConfirm: Bool {
        switch controller.guidance.currentAction {
        case .wait, .baste, .waitForFinish:
            return false
        case .checkTemperature:
            // In the CHECK TEMP phase the manual control and the
            // no-thermometer button take over; in other cook phases the
            // CHECK TEMP prompt itself is the confirmable action.
            return controller.session.phase != .checkTemperature
        default:
            return true
        }
    }

    private var cookConfirmTitle: String {
        switch controller.guidance.currentAction {
        case .flip: String(localized: "Flipped")
        case .standFatCap: String(localized: "Start fat cap")
        case .addButter: String(localized: "Butter added")
        case .checkTemperature: String(localized: "CHECK TEMP")
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

/// Honest finishing presentation. Carryover is estimated, so the UI shows a
/// minute range — never a precise second-level countdown that would imply
/// temperature-level accuracy.
enum FinishingDisplay {
    static func rangeText(for estimate: ClosedRange<TimeInterval>) -> String {
        let lower = max(1, Int(ceil(estimate.lowerBound / 60)))
        let upper = max(lower + 1, Int(ceil(estimate.upperBound / 60)))
        return String(
            format: String(localized: "%lld–%lld min"),
            Int64(lower),
            Int64(upper)
        )
    }
}
