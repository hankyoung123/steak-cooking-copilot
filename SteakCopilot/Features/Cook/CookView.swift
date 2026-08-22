import SwiftUI

struct CookView: View {
    let controller: CookingSessionController
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heroFlipTrigger = 0
    @State private var compactFlipTrigger = 0
    @State private var manualTemperature = 50.0

    private var motion: MotionDirector { controller.motionDirector }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            content(at: context.date)
                .onChange(of: context.date, initial: true) { _, date in
                    controller.refresh(at: date)
                }
        }
        .onChange(of: motion.sequence) { _, _ in
            switch motion.cue.visual {
            case .heroFlip: heroFlipTrigger += 1
            case .compactFlip: compactFlipTrigger += 1
            default: break
            }
        }
    }

    private func content(at date: Date) -> some View {
        VStack(spacing: 0) {
            cookHeader

            Spacer(minLength: 12)

            ZStack {
                PanVisual(isCooking: true)
                    .frame(width: 315)

                animatedSteak
                    .frame(width: 235)
                    .offset(y: 10)

                cookingAccent
            }
            .frame(height: 350)

            actionReadout(at: date)

            if controller.guidance.currentAction == .checkTemperature {
                temperatureControl(at: date)
                    .transition(.opacity)
            }

            Spacer(minLength: 18)

            if shouldShowConfirmButton {
                PrimaryActionButton(
                    title: confirmButtonTitle,
                    icon: controller.guidance.currentAction == .takeOut ? "arrow.up" : "checkmark",
                    isEnabled: canConfirm,
                    lightOnDark: true
                ) {
                    controller.confirmCurrentAction(at: date)
                }
                .accessibilityIdentifier("cook.confirm")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .foregroundStyle(theme.cream)
        .animation(.easeOut(duration: 0.24), value: controller.guidance.currentAction)
    }

    private var cookHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("COOK")
                    .quietEyebrowStyle(color: theme.cream)
                Text(phaseTitle)
                    .font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PULL AT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.cream.opacity(0.5))
                Text("\(controller.guidance.pullTemperatureC, specifier: "%.0f")°C")
                    .font(.headline.monospacedDigit())
            }
        }
    }

    @ViewBuilder
    private var animatedSteak: some View {
        let steak = SteakVisual(
            configuration: controller.session.configuration,
            cookedProgress: overallCookedProgress,
            showButter: showsButter
        )

        if reduceMotion {
            steak
                .contentTransition(.opacity)
        } else {
            steak
                .keyframeAnimator(
                    initialValue: FlipValues(),
                    trigger: heroFlipTrigger
                ) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .offset(y: value.verticalOffset)
                        .rotation3DEffect(
                            .degrees(value.rotation),
                            axis: (x: 1, y: 0.08, z: 0)
                        )
                        .shadow(color: .black.opacity(value.shadowOpacity), radius: value.shadowRadius, y: value.shadowY)
                } keyframes: { _ in
                    KeyframeTrack(\.verticalOffset) {
                        CubicKeyframe(-42, duration: 0.10)
                        CubicKeyframe(-58, duration: 0.15)
                        CubicKeyframe(0, duration: 0.23)
                        SpringKeyframe(0, duration: 0.07, spring: .bouncy)
                    }
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(0, duration: 0.10)
                        CubicKeyframe(90, duration: 0.15)
                        CubicKeyframe(180, duration: 0.23)
                        LinearKeyframe(180, duration: 0.07)
                    }
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.06, duration: 0.10)
                        CubicKeyframe(1.08, duration: 0.15)
                        CubicKeyframe(0.98, duration: 0.23)
                        SpringKeyframe(1, duration: 0.07, spring: .bouncy)
                    }
                    KeyframeTrack(\.shadowRadius) {
                        LinearKeyframe(26, duration: 0.25)
                        LinearKeyframe(8, duration: 0.23)
                        LinearKeyframe(16, duration: 0.07)
                    }
                    KeyframeTrack(\.shadowOpacity) {
                        LinearKeyframe(0.48, duration: 0.25)
                        LinearKeyframe(0.18, duration: 0.23)
                        LinearKeyframe(0.3, duration: 0.07)
                    }
                    KeyframeTrack(\.shadowY) {
                        LinearKeyframe(34, duration: 0.25)
                        LinearKeyframe(5, duration: 0.23)
                        LinearKeyframe(12, duration: 0.07)
                    }
                }
                .keyframeAnimator(
                    initialValue: CompactFlipValues(),
                    trigger: compactFlipTrigger
                ) { content, value in
                    content
                        .rotationEffect(.degrees(value.rotation))
                        .scaleEffect(value.scale)
                } keyframes: { _ in
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(-7, duration: 0.16)
                        SpringKeyframe(0, duration: 0.22, spring: .bouncy)
                    }
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.035, duration: 0.16)
                        SpringKeyframe(1, duration: 0.22, spring: .bouncy)
                    }
                }
        }
    }

    @ViewBuilder
    private var cookingAccent: some View {
        switch controller.guidance.currentAction {
        case .addButter:
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .stroke(theme.butter.opacity(0.52), lineWidth: 2)
                    .frame(width: 10 + CGFloat(index % 3) * 5)
                    .offset(x: CGFloat((index * 43) % 150) - 74, y: CGFloat((index * 31) % 86) - 28)
            }
            .transition(.opacity)
        case .baste:
            BasteAccent()
                .transition(.opacity)
        default:
            EmptyView()
        }
    }

    private func actionReadout(at date: Date) -> some View {
        VStack(spacing: 7) {
            if controller.guidance.remainingTime > 0 {
                Text("\(Int(ceil(controller.guidance.remainingTime)))")
                    .font(.system(size: isFlipAttention ? 82 : 64, weight: .medium, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel("\(Int(ceil(controller.guidance.remainingTime))) seconds")
            }

            Text(actionHeadline)
                .font(.system(size: isImmediateMoment ? 42 : 19, weight: .black, design: .rounded))
                .tracking(isImmediateMoment ? 1 : 2.6)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)

            Text(actionDetail)
                .font(.subheadline)
                .foregroundStyle(theme.cream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(minHeight: 138)
        .animation(.spring(duration: 0.34, bounce: 0.12), value: isFlipAttention)
        .accessibilityElement(children: .combine)
    }

    private var phaseTitle: String {
        switch controller.session.phase {
        case .sear: "Searing"
        case .fatCap: "Fat cap"
        case .baste: "Basting"
        case .checkTemperature: "Temperature"
        default: "Cooking"
        }
    }

    private var actionHeadline: String {
        if case .flipNow = controller.guidance.event { return "FLIP\nNOW" }
        if controller.guidance.event == .pullNow { return "TAKE\nIT OUT" }
        return controller.guidance.currentAction.title
    }

    private var actionDetail: String {
        switch controller.guidance.currentAction {
        case .wait: "Let the crust build until the next check."
        case .flip: controller.guidance.remainingTime > 0 ? "Get your tongs ready." : "Turn it over now."
        case .standFatCap: "Hold the fat edge against the pan."
        case .addButter: "Add butter, garlic, and herbs if you like."
        case .baste: "Tilt the pan and spoon the foaming butter."
        case .checkTemperature: "Probe through the side toward the center."
        case .takeOut: "Carryover heat will finish the center."
        case .waitForFinish, .eat: ""
        }
    }

    private var isFlipAttention: Bool {
        if case .flipApproaching = controller.guidance.event { return true }
        return false
    }

    private var isImmediateMoment: Bool {
        switch controller.guidance.event {
        case .flipNow, .pullNow: true
        default: false
        }
    }

    private var shouldShowConfirmButton: Bool {
        ![.wait, .baste, .waitForFinish].contains(controller.guidance.currentAction)
    }

    private var canConfirm: Bool {
        controller.guidance.remainingTime <= 0
            || controller.guidance.event == .pullNow
    }

    private var confirmButtonTitle: String {
        switch controller.guidance.currentAction {
        case .flip: "Flipped"
        case .standFatCap: "Start fat cap"
        case .addButter: "Butter added"
        case .checkTemperature: "No thermometer — continue"
        case .takeOut: "Steak is out"
        default: "Done"
        }
    }

    private var showsButter: Bool {
        controller.session.butterAddedAt != nil
    }

    private var overallCookedProgress: Double {
        switch controller.session.phase {
        case .sear: 0.1 + controller.guidance.estimatedProgress * 0.5
        case .fatCap: 0.6
        case .baste: 0.76 + controller.guidance.estimatedProgress * 0.12
        case .checkTemperature: 0.92
        default: 0
        }
    }

    private func temperatureControl(at date: Date) -> some View {
        VStack(spacing: 9) {
            HStack {
                Text("Center temperature")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(manualTemperature, specifier: "%.0f")°C")
                    .font(.headline.monospacedDigit())
            }
            Slider(value: $manualTemperature, in: 35...70, step: 1)
                .tint(theme.butter)
                .accessibilityLabel("Center temperature")
            Button("Use this reading") {
                controller.recordManualTemperature(manualTemperature, at: date)
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(theme.butter)
        }
        .padding(14)
        .background(theme.cream.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        .onAppear {
            manualTemperature = controller.session.lastManualTemperatureC
                ?? controller.guidance.pullTemperatureC - 2
        }
    }
}

private struct FlipValues {
    var verticalOffset: CGFloat = 0
    var rotation: Double = 0
    var scale: CGFloat = 1
    var shadowRadius: CGFloat = 16
    var shadowOpacity: Double = 0.3
    var shadowY: CGFloat = 12
}

private struct CompactFlipValues {
    var rotation: Double = 0
    var scale: CGFloat = 1
}

private struct BasteAccent: View {
    var body: some View {
        ZStack {
            ArcShape()
                .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .frame(width: 130, height: 90)
                .rotationEffect(.degrees(-18))
                .offset(x: 44, y: -42)
            Capsule()
                .fill(.white.opacity(0.7))
                .frame(width: 90, height: 10)
                .rotationEffect(.degrees(-35))
                .offset(x: 82, y: -78)
        }
        .accessibilityHidden(true)
    }
}

private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * 0.58),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}
