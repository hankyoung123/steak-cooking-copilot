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
                    .accessibilityLabel("\(Int(ceil(remainingTime))) seconds")
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
                Text("NEXT · \(nextAction.title)")
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
        if case .flipNow = guidance.event { return "FLIP\nNOW" }
        if guidance.event == .pullNow { return "TAKE\nIT OUT" }
        return guidance.currentAction.title
    }

    private var detail: String {
        switch guidance.currentAction {
        case .wait: "Let the crust build until the next check."
        case .flip: "Turn it over now."
        case .standFatCap: "Hold the fat edge against the pan."
        case .addButter: "Add butter, garlic, and herbs if you like."
        case .baste: "Tilt the pan and spoon the foaming butter."
        case .checkTemperature: "Probe through the side toward the center."
        case .takeOut: "Carryover heat will finish the center."
        case .waitForFinish, .eat: ""
        }
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
