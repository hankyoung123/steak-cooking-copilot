import SwiftUI

struct CookView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    @State private var manualTemperature = 50.0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            GeometryReader { proxy in
                content(at: context.date)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .task(id: controller.session.nextActionAt) {
            await refreshAtKeyBoundaries()
        }
    }

    private func content(at date: Date) -> some View {
        let remaining = remainingTime(at: date)
        return VStack(spacing: 10) {
            ZStack {
                CookingStageVisual(
                    configuration: controller.session.configuration,
                    cookedProgress: overallCookedProgress,
                    showsButter: controller.session.butterAddedAt != nil,
                    action: controller.guidance.currentAction,
                    motion: controller.motionDirector,
                    butterColor: theme.butter
                )

                VStack(spacing: 0) {
                    CookingActionReadout(
                        guidance: controller.guidance,
                        remainingTime: remaining,
                        secondaryColor: .white.opacity(0.72)
                    )
                    .padding(.top, 20)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 430)

            CookTemperatureRail(
                progress: controller.guidance.estimatedProgress,
                lastReading: controller.guidance.lastManualTemperatureC,
                pullTemperature: controller.guidance.pullTemperatureC
            )
            .padding(.horizontal, 16)

            if controller.guidance.currentAction == .checkTemperature {
                ManualTemperatureControl(
                    temperature: $manualTemperature,
                    pullTemperatureC: controller.guidance.pullTemperatureC,
                    accentColor: theme.butter,
                    onSubmit: { recordTemperature(at: date) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 16)
            }

            if shouldShowConfirmButton {
                PrimaryActionButton(
                    title: confirmButtonTitle,
                    icon: controller.guidance.currentAction == .takeOut
                        ? "arrow.up"
                        : "checkmark",
                    isEnabled: remaining <= 0,
                    lightOnDark: false,
                    action: { confirmAction(at: date) }
                )
                .accessibilityIdentifier("cook.confirm")
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 12)
        .foregroundStyle(theme.porcelain)
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

private struct CookTemperatureRail: View {
    @Environment(AppTheme.self) private var theme
    let progress: Double
    let lastReading: Double?
    let pullTemperature: Double

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(leftValue)
                        .font(.subheadline.bold().monospacedDigit())
                    Text(leftLabel)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Image(systemName: "thermometer.medium")
                    .font(.caption)
                    .foregroundStyle(theme.emberBright)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(pullTemperature, specifier: "%.0f")°C")
                        .font(.subheadline.bold().monospacedDigit())
                    Text("Pull target")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule()
                        .fill(theme.emberBright)
                        .frame(width: proxy.size.width * min(max(progress, 0.04), 1))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    private var leftValue: String {
        if let lastReading {
            return String(format: "%.0f°C", lastReading)
        }
        return String(format: "%.0f%%", min(max(progress, 0), 1) * 100)
    }

    private var leftLabel: String {
        lastReading == nil
            ? String(localized: "Estimated")
            : String(localized: "Last reading")
    }
}
