import SwiftUI

struct CookView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    @State private var manualTemperature = 50.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(at: context.date)
        }
        .task(id: controller.session.nextActionAt) {
            await refreshAtKeyBoundaries()
        }
    }

    private func content(at date: Date) -> some View {
        let remaining = remainingTime(at: date)
        return VStack(spacing: 0) {
            CookingHeader(
                phase: controller.session.phase,
                pullTemperatureC: controller.guidance.pullTemperatureC,
                color: theme.cream
            )

            Spacer(minLength: 12)

            CookingStageVisual(
                configuration: controller.session.configuration,
                cookedProgress: overallCookedProgress,
                showsButter: controller.session.butterAddedAt != nil,
                action: controller.guidance.currentAction,
                motion: controller.motionDirector,
                butterColor: theme.butter
            )
            .frame(height: 350)

            CookingActionReadout(
                guidance: controller.guidance,
                remainingTime: remaining,
                secondaryColor: theme.cream.opacity(0.6)
            )

            if controller.guidance.currentAction == .checkTemperature {
                ManualTemperatureControl(
                    temperature: $manualTemperature,
                    pullTemperatureC: controller.guidance.pullTemperatureC,
                    accentColor: theme.butter,
                    onSubmit: { recordTemperature(at: date) }
                )
                .transition(.opacity)
            }

            Spacer(minLength: 18)

            if shouldShowConfirmButton {
                PrimaryActionButton(
                    title: confirmButtonTitle,
                    icon: controller.guidance.currentAction == .takeOut
                        ? "arrow.up"
                        : "checkmark",
                    isEnabled: remaining <= 0,
                    lightOnDark: true,
                    action: { confirmAction(at: date) }
                )
                .accessibilityIdentifier("cook.confirm")
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .foregroundStyle(theme.cream)
        .animation(
            .easeOut(duration: MotionTiming.responsive),
            value: controller.guidance.currentAction
        )
        .onAppear(perform: restoreTemperatureControl)
    }

    private var shouldShowConfirmButton: Bool {
        ![.wait, .baste, .waitForFinish].contains(
            controller.guidance.currentAction
        )
    }

    private var confirmButtonTitle: String {
        switch controller.guidance.currentAction {
        case .flip: String(localized: "Flipped")
        case .standFatCap: String(localized: "Start fat cap")
        case .addButter: String(localized: "Butter added")
        case .checkTemperature: String(localized: "No thermometer — continue")
        case .takeOut: String(localized: "Steak is out")
        default: String(localized: "Done")
        }
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

    private func remainingTime(at date: Date) -> TimeInterval {
        guard let actionDate = controller.session.nextActionAt else { return 0 }
        return max(0, actionDate.timeIntervalSince(date))
    }

    private func confirmAction(at date: Date) {
        controller.confirmCurrentAction(at: date)
    }

    private func recordTemperature(at date: Date) {
        controller.recordManualTemperature(manualTemperature, at: date)
    }

    private func restoreTemperatureControl() {
        manualTemperature = controller.session.lastManualTemperatureC
            ?? controller.guidance.pullTemperatureC - 2
    }

    private func refreshAtKeyBoundaries() async {
        guard let actionDate = controller.session.nextActionAt else { return }
        for secondsBefore in [5.0, 3.0, 2.0, 0.0] {
            let boundary = actionDate.addingTimeInterval(-secondsBefore)
            let delay = boundary.timeIntervalSinceNow
            if delay > 0 {
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            controller.refresh(at: .now)
        }
    }
}

private struct CookingHeader: View {
    let phase: CookingPhase
    let pullTemperatureC: Double
    let color: Color

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("COOK")
                    .quietEyebrowStyle(color: color)
                Text(phaseTitle)
                    .font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PULL AT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color.opacity(0.5))
                Text("\(pullTemperatureC, specifier: "%.0f")°C")
                    .font(.headline.monospacedDigit())
            }
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .sear: String(localized: "Searing")
        case .fatCap: String(localized: "Fat cap")
        case .baste: String(localized: "Basting")
        case .checkTemperature: String(localized: "Temperature")
        default: String(localized: "Cooking")
        }
    }
}
