import SwiftUI

struct CookingActionReadout: View {
    let guidance: CookingGuidance
    let remainingTime: TimeInterval
    let secondaryColor: Color

    var body: some View {
        VStack(spacing: 7) {
            if remainingTime > 0 {
                Text("\(Int(ceil(remainingTime)))")
                    .font(
                        .system(
                            size: isFlipAttention ? 82 : 64,
                            weight: .medium,
                            design: .rounded
                        )
                        .monospacedDigit()
                    )
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel(countdownAccessibilityLabel)
            }

            Text(headline)
                .font(
                    .system(
                        size: isImmediateMoment ? 42 : 19,
                        weight: .black,
                        design: .rounded
                    )
                )
                .tracking(isImmediateMoment ? 1 : 2.6)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .accessibilityIdentifier("cook.action")

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(secondaryColor)
                .multilineTextAlignment(.center)

            if let nextAction = guidance.nextAction, remainingTime > 0 {
                Text(
                    String(
                        format: String(localized: "NEXT · %@"),
                        nextAction.title
                    )
                )
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(secondaryColor)
            }
        }
        .frame(minHeight: 138)
        .animation(
            .spring(duration: MotionTiming.emphasis, bounce: 0.12),
            value: isFlipAttention
        )
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        if case .flipNow = guidance.event {
            return String(localized: "FLIP\nNOW")
        }
        if guidance.event == .pullNow {
            return String(localized: "TAKE\nIT OUT")
        }
        return guidance.currentAction.title
    }

    private var detail: String {
        switch guidance.currentAction {
        case .wait: String(localized: "Let the crust build until the next check.")
        case .flip: String(localized: "Turn it over now.")
        case .standFatCap: String(localized: "Hold the fat edge against the pan.")
        case .addButter: String(localized: "Add butter, garlic, and herbs if you like.")
        case .baste: String(localized: "Tilt the pan and spoon the foaming butter.")
        case .checkTemperature: String(localized: "Probe through the side toward the center.")
        case .takeOut: String(localized: "Carryover heat will finish the center.")
        case .waitForFinish, .eat: ""
        }
    }

    private var countdownAccessibilityLabel: String {
        String(
            format: String(localized: "%lld seconds"),
            Int64(ceil(remainingTime))
        )
    }

    private var isFlipAttention: Bool {
        if case .flipApproaching = guidance.event { return true }
        return false
    }

    private var isImmediateMoment: Bool {
        switch guidance.event {
        case .flipNow, .pullNow: true
        default: false
        }
    }
}
