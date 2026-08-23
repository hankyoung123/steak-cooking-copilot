import SwiftUI

struct CookingActionReadout: View {
    @Environment(AppTheme.self) private var theme
    let guidance: CookingGuidance
    let remainingTime: TimeInterval
    let secondaryColor: Color

    var body: some View {
        VStack(spacing: 7) {
            Label(badgeTitle, systemImage: badgeIcon)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(badgeColor)
                .background(badgeColor.opacity(0.16), in: Capsule())

            if remainingTime > 0 {
                Text(countdownLead)
                    .font(.title3.weight(.semibold))
                Text(countdownText)
                    .font(.system(size: 58, weight: .medium, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityLabel(countdownAccessibilityLabel)
            } else {
                Text(headline)
                    .font(.system(size: isImmediateMoment ? 38 : 30, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(secondaryColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if let nextAction = guidance.nextAction, remainingTime > 0 {
                Text(String(format: String(localized: "Next: %@"), nextAction.title))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secondaryColor)
            }
        }
        .padding(.horizontal, 18)
        .accessibilityIdentifier("cook.action")
        .accessibilityElement(children: .combine)
    }

    private var countdownLead: String {
        guidance.nextAction == .flip
            ? String(localized: "Flip in")
            : guidance.currentAction.title
    }

    private var countdownText: String {
        let seconds = max(0, Int(ceil(remainingTime)))
        return String(format: "0:%02lld", Int64(seconds))
    }

    private var badgeTitle: String {
        switch guidance.currentAction {
        case .baste, .addButter: String(localized: "BASTE")
        case .checkTemperature: String(localized: "CHECK TEMP")
        case .takeOut: String(localized: "TAKE IT OUT")
        default: String(localized: "SEAR")
        }
    }

    private var badgeIcon: String {
        switch guidance.currentAction {
        case .baste, .addButter: "hand.raised.fill"
        case .checkTemperature: "thermometer.medium"
        case .takeOut: "arrow.up"
        default: "flame.fill"
        }
    }

    private var badgeColor: Color {
        [.baste, .addButter].contains(guidance.currentAction)
            ? theme.butter
            : theme.emberBright
    }

    private var headline: String {
        if case .flipNow = guidance.event {
            return String(localized: "Now!")
        }
        if guidance.event == .pullNow {
            return String(localized: "Take it out")
        }
        return guidance.currentAction.title
    }

    private var detail: String {
        switch guidance.currentAction {
        case .wait: String(localized: "Don't move the steak.")
        case .flip: String(localized: "Flip your steak.")
        case .standFatCap: String(localized: "Hold the fat edge against the pan.")
        case .addButter: String(localized: "Add butter, garlic, and herbs if you like.")
        case .baste: String(localized: "Tilt the pan and spoon the butter over the steak.")
        case .checkTemperature: String(localized: "Probe through the side toward the center.")
        case .takeOut: String(localized: "Carryover heat will finish the center.")
        case .waitForFinish, .eat: ""
        }
    }

    private var countdownAccessibilityLabel: String {
        String(format: String(localized: "%lld seconds"), Int64(ceil(remainingTime)))
    }

    private var isImmediateMoment: Bool {
        switch guidance.event {
        case .flipNow, .pullNow: true
        default: false
        }
    }
}
