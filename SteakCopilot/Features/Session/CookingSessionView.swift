import SwiftUI

/// The session screen.
///
/// The whole view is a fixed skeleton: `SessionLayoutMetrics` decides the
/// geometry of every slot from the device size alone, and each phase only
/// replaces what is *inside* a slot. That is what stops PREP → HEAT → SEAR →
/// FLIP → FAT CAP → BASTE → CHECK TEMP → FINISHING from moving the top
/// controls, the hero, the scene, the instruction, the rail or the primary
/// action.
///
/// Two rules keep the skeleton honest:
///
/// 1. A phase may leave a slot empty or swap its content. It may never change
///    a slot's height, inset or order.
/// 2. Optional controls (the manual temperature control, the prep toggles, the
///    no-thermometer escape hatch) live in the reserved status / bottom rows.
///    They are never inserted into the middle of the column, because anything
///    inserted there reflows every row below it.
struct CookingSessionView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let controller: CookingSessionController
    let onExit: () -> Void
    let onSkip: () -> Void
    @State private var dried = false
    @State private var salted = false
    @State private var manualTemperature = 50.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { proxy in
                let layout = SessionLayoutMetrics.resolve(
                    for: proxy.size,
                    dynamicTypeSize: dynamicTypeSize
                )
                ScrollView {
                    skeleton(layout: layout, at: context.date)
                        .frame(width: proxy.size.width)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollIndicators(.hidden)
                // Scrolls only when the resolved skeleton genuinely cannot fit
                // (very large Dynamic Type on a small phone). On every
                // supported device at a normal text size it is inert, which is
                // what makes the slot positions trustworthy.
                .scrollBounceBehavior(.basedOnSize)
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
            reduceMotion ? nil : .smooth(duration: controller.tuning.motion.sessionPhaseChange),
            value: controller.session.phase
        )
    }

    // MARK: - Skeleton

    /// Slot order is fixed for every phase. `Spacer` absorbs the slack on tall
    /// devices, so the bottom action stays pinned to the bottom edge and the
    /// rows above it keep their exact offsets.
    private func skeleton(layout: SessionLayoutMetrics, at date: Date) -> some View {
        VStack(spacing: 0) {
            topControlsSlot(layout)
            heroSlot(layout, at: date)
            sceneSlot(layout)
            instructionSlot(layout, at: date)
            statusSlot(layout, at: date)
            Spacer(minLength: 0)
            bottomActionSlot(layout, at: date)
        }
    }

    private func topControlsSlot(_ layout: SessionLayoutMetrics) -> some View {
        SessionStageControls(
            flowStage: controller.flowStage,
            phaseTitle: navigationTitle,
            stepLabel: stepLabel,
            dark: isDarkStage,
            onExit: onExit,
            onSkip: onSkip
        )
        .padding(.horizontal, layout.screenInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.topControlHeight)
        // Probed rather than permanently identified: this row owns real
        // buttons (exit / skip), and a container identifier placed over them
        // risks replacing their own identifiers.
        .sessionLayoutProbe(SessionLayoutID.topControls)
    }

    private func heroSlot(_ layout: SessionLayoutMetrics, at date: Date) -> some View {
        sessionHeader(at: date)
            .padding(.horizontal, layout.sceneInset)
            .frame(maxWidth: .infinity)
            .frame(height: layout.headerHeight)
            .padding(.top, layout.headerSpacing)
    }

    private func sceneSlot(_ layout: SessionLayoutMetrics) -> some View {
        Group {
            if isDarkStage {
                // The complete composition is drawn once, full bleed, behind
                // the whole session (RootFlowView). This slot only reserves the
                // band it occupies, so the light and dark stages share one
                // geometry. Layering a cutout here is what produced the double
                // steak; the slot stays empty on purpose.
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
        .frame(maxWidth: .infinity)
        .frame(height: layout.sceneHeight)
        .padding(.top, layout.sceneSpacing)
        .sessionLayoutProbe(SessionLayoutID.scene)
    }

    private func instructionSlot(_ layout: SessionLayoutMetrics, at date: Date) -> some View {
        instructionLabel(at: date)
            .padding(.horizontal, layout.contentInset)
            .frame(maxWidth: .infinity)
            .frame(height: layout.instructionHeight)
            .padding(.top, layout.instructionSpacing)
    }

    /// The status band: progress rail on top, then whichever status content the
    /// phase owns. The rail is pinned to the top of the band in every phase
    /// that shows one, so its position never depends on the content below it.
    private func statusSlot(_ layout: SessionLayoutMetrics, at date: Date) -> some View {
        VStack(spacing: layout.statusContentSpacing) {
            if controller.session.phase != .finishing {
                progressRail(height: layout.progressRailHeight)
                    .sessionLayoutProbe(SessionLayoutID.progress)
            }
            statusContent(layout: layout, at: date)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, layout.contentInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.statusHeight, alignment: .top)
        .padding(.top, layout.statusSpacing)
    }

    @ViewBuilder
    private func statusContent(layout: SessionLayoutMetrics, at date: Date) -> some View {
        switch controller.session.phase {
        case .finishing:
            // FINISHING owns the whole band: the estimate card replaces the
            // telemetry, and there is no rail to show (carryover has no
            // measurable progress).
            finishingCard(
                at: date,
                height: layout.statusHeight
            )
        case .checkTemperature:
            // The reading entry swaps in for the telemetry: it shows the value
            // being entered and the pull target, which is the same information
            // in an editable form. It sits *inside* the reserved band, so the
            // rail above it and the CTA below it do not move.
            ManualTemperatureControl(
                temperature: $manualTemperature,
                pullTemperatureC: controller.guidance.pullTemperatureC,
                accentColor: accentColor
            )
            .frame(
                height: layout.statusHeight
                    - layout.progressRailHeight
                    - layout.statusContentSpacing
            )
        default:
            // The rail, the telemetry row and the slack below it are all inside
            // the reserved band, so a longer or shorter telemetry value can
            // never reach the bottom action row.
            telemetry
        }
    }

    private func bottomActionSlot(_ layout: SessionLayoutMetrics, at date: Date) -> some View {
        VStack(spacing: layout.bottomSecondarySpacing) {
            bottomSecondaryControl(layout: layout, at: date)
            bottomPrimaryControl(layout: layout, at: date)
        }
        .padding(.horizontal, layout.contentInset)
        .frame(maxWidth: .infinity)
        .frame(height: layout.bottomActionHeight, alignment: .bottom)
        .padding(.top, layout.bottomActionSpacing)
    }

    /// The contextual row. Its height is reserved in every phase, so the
    /// primary action below keeps one baseline whether PREP shows two toggles,
    /// CHECK TEMP shows the no-thermometer escape hatch, or the cook phases
    /// show nothing at all.
    @ViewBuilder
    private func bottomSecondaryControl(
        layout: SessionLayoutMetrics,
        at date: Date
    ) -> some View {
        Group {
            switch controller.session.phase {
            case .prep:
                HStack(spacing: 10) {
                    prepToggle("Dry", identifier: "prep.dry", isOn: $dried)
                    prepToggle("Salt", identifier: "prep.salt", isOn: $salted)
                }
            case .checkTemperature:
                Button {
                    controller.continueWithoutThermometer(at: date)
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
            default:
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: layout.bottomSecondaryHeight)
    }

    /// The one primary action per phase, always bottom aligned inside the
    /// reserved bottom band.
    @ViewBuilder
    private func bottomPrimaryControl(
        layout: SessionLayoutMetrics,
        at date: Date
    ) -> some View {
        Group {
            switch controller.session.phase {
            case .prep:
                PrimaryActionButton(
                    title: String(localized: "Continue to preheat"),
                    icon: "arrow.right",
                    isEnabled: dried && salted,
                    lightOnDark: isDarkStage
                ) { controller.finishPrep(at: date) }
                .accessibilityIdentifier("prep.continue")
            case .heat:
                PrimaryActionButton(
                    title: String(localized: "Pan is ready"),
                    icon: "arrow.right",
                    lightOnDark: isDarkStage
                ) { controller.panIsReady(at: date) }
                .accessibilityIdentifier("heat.ready")
            case .sear, .fatCap, .baste, .checkTemperature:
                // Two things can occupy the CTA row in the cook phases: the
                // action to confirm, and — in CHECK TEMP while a reading is
                // still being entered — the reading itself.
                if let title = confirmTitle {
                    PrimaryActionButton(
                        title: title,
                        icon: "arrow.right",
                        isEnabled: isConfirmable(at: date),
                        lightOnDark: isDarkStage
                    ) { controller.confirmCurrentAction(at: date) }
                    .accessibilityLabel(title)
                    .accessibilityIdentifier("cook.confirm")
                } else if controller.session.phase == .checkTemperature {
                    PrimaryActionButton(
                        title: String(localized: "Use this reading"),
                        icon: "arrow.right",
                        lightOnDark: isDarkStage
                    ) { controller.recordManualTemperature(manualTemperature, at: date) }
                    .accessibilityIdentifier("cook.temperature.submit")
                }
            case .finishing, .ready, .eat, .feedback, .setup:
                // FINISHING ends on its own; the result phases have their own
                // primary action on the result screen. The row stays reserved
                // so the CTA keeps one baseline whenever it is present.
                Color.clear
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: layout.bottomPrimaryHeight)
        .sessionLayoutProbe(SessionLayoutID.primaryAction)
    }

    // MARK: - Slots' content

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(
            color: .black.opacity(isDarkStage ? 0.84 : 0),
            radius: 10,
            y: 2
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(SessionLayoutID.hero)
    }

    /// The instruction band is informational in every phase: the actionable
    /// control lives in the bottom action row. Keeping the two separate is what
    /// lets the band keep one height, one baseline and one tap target.
    private func instructionLabel(at date: Date) -> some View {
        VStack(spacing: 6) {
            Text(instructionTitle(at: date))
                .font(.system(size: 21, weight: .regular, design: .serif))
                .foregroundStyle(primaryText.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            if showsInstructionDetail {
                Text(instructionDetail)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        // Top aligned inside the fixed band: the title's own baseline is then
        // the same whether or not the phase has a detail line, and the detail
        // line's absence never pulls the rows above or below it.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .shadow(
            color: .black.opacity(isDarkStage ? 0.88 : 0),
            radius: 8,
            y: 2
        )
        .contentTransition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(SessionLayoutID.instruction)
    }

    private func progressRail(height: CGFloat) -> some View {
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
        .frame(height: height)
        .animation(
            reduceMotion
                ? nil
                : .spring(
                    duration: controller.tuning.motion.progressRailSpring,
                    bounce: controller.tuning.motion.progressRailBounce
                ),
            value: overallProgress
        )
        .accessibilityHidden(true)
    }

    /// Fits inside the status band. The band's height is fixed by the layout,
    /// not by this card, so the card may never push the rows below it.
    private func finishingCard(at date: Date, height: CGFloat) -> some View {
        VStack(spacing: 5) {
            Group {
                if let reading = controller.guidance.lastManualTemperatureC {
                    HStack(spacing: 0) {
                        sessionMetric(
                            label: "LAST READING",
                            value: String(format: "%.0f°C", reading)
                        )
                        metricDivider
                        sessionMetric(
                            label: "PULL TARGET",
                            value: String(format: "%.0f°C", controller.guidance.pullTemperatureC)
                        )
                        metricDivider
                        sessionMetric(
                            label: "TARGET TEMP",
                            value: String(format: "%.0f°C", controller.guidance.targetTemperatureC)
                        )
                    }
                } else {
                    VStack(spacing: 3) {
                        Text("ESTIMATED FINISH")
                            .font(.system(size: 8, weight: .medium))
                            .tracking(1.1)
                            .foregroundStyle(secondaryText)
                        Text("No thermometer reading recorded")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(primaryText.opacity(0.84))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(height: 32)

            finishingHeatIndicator(at: date)

            Text(
                String(
                    format: String(
                        localized: "Expected carryover +%lld–%lld°C"
                    ),
                    Int64(controller.tuning.finishing.carryoverMinC.rounded()),
                    Int64(controller.tuning.finishing.carryoverMaxC.rounded())
                )
            )
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(accentColor.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            Text("This is an estimate, not a live temperature measurement.")
                .font(.system(size: 10))
                .foregroundStyle(secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: height)
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
        return VStack(spacing: 4) {
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
                reduceMotion
                    ? nil
                    : .easeOut(duration: controller.tuning.motion.responsive),
                value: progress
            )
        }
        .frame(height: 22)
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
                value: String(format: "%.0f°C", controller.guidance.targetTemperatureC)
            )
            metricDivider
            sessionMetric(
                label: "LAST READING",
                value: currentTemperatureText
            )
        }
        .frame(height: 46)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(SessionLayoutID.telemetry)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(hairlineColor.opacity(0.72))
            .frame(width: 0.7, height: 42)
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: 13, weight: .regular, design: .serif))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(size: 20, weight: .regular, design: .serif))
                .monospacedDigit()
                .foregroundStyle(primaryText.opacity(0.84))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Copy

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

    private func usesTimer(at date: Date) -> Bool {
        switch controller.session.phase {
        case .sear, .fatCap, .baste:
            remaining(at: date) > 0
        default:
            // FINISHING is an estimate, never a precise second countdown.
            false
        }
    }

    /// The hero band holds a **timer or readout**; the instruction band carries
    /// the sentence (see the editorial design: "a hero timer/readout … and one
    /// instruction").
    ///
    /// When no stage timer is running, the readout names the pending action.
    /// It used to fall through to `instructionTitle`, which printed the same
    /// sentence twice — once at 40pt and again at 21pt — at every action moment
    /// (FLIP, FAT CAP, BUTTER, CHECK).
    private func heroValue(at date: Date) -> String {
        switch controller.session.phase {
        case .prep: String(localized: "Ready the steak")
        case .heat: String(localized: "Heat the pan")
        case .checkTemperature: String(localized: "Check doneness")
        case .finishing: estimatedFinishRange
        default: heroReadout
        }
    }

    /// The readout naming the action in flight. The CHECK TEMP action reuses the
    /// phase's existing readout so the hero does not echo the CHECK TEMP button
    /// label sitting right below it.
    private var heroReadout: String {
        switch controller.guidance.currentAction {
        case .checkTemperature: String(localized: "Check doneness")
        default: controller.guidance.currentAction.title
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

    /// Whether the announced action is one the user confirms with a tap. The
    /// waiting actions have no button to press, so the bottom action row is
    /// simply empty for them — reserved, never moved.
    private var showsCookConfirm: Bool {
        switch controller.guidance.currentAction {
        case .flip, .standFatCap, .addButter, .takeOut:
            return true
        case .checkTemperature:
            // In the CHECK TEMP phase the reading entry and the no-thermometer
            // escape hatch take over; in the other cook phases this action means
            // "insert the probe", which the user confirms to move on.
            return controller.session.phase != .checkTemperature
        case .wait, .baste, .waitForFinish, .eat:
            return false
        }
    }

    /// The label of the confirm button, or `nil` when the phase has nothing to
    /// confirm. While a stage timer runs (the fat-cap stand, for example) the
    /// label is already the pending action but the button stays disabled until
    /// the boundary passes, so it never invites a tap that would do nothing.
    /// Actions that are pure waiting (`.wait`, `.baste`, `.waitForFinish`) have
    /// no button at all; the row is still reserved, so nothing below it moves.
    private var confirmTitle: String? {
        showsCookConfirm
            ? cookConfirmTitle(for: controller.guidance.currentAction)
            : nil
    }
    private func isConfirmable(at date: Date) -> Bool {
        showsCookConfirm && remaining(at: date) <= 0
    }

    private func cookConfirmTitle(for action: CookingAction) -> String {
        switch action {
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
