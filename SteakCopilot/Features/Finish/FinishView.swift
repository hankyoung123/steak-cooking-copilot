import SwiftUI

struct FinishView: View {
    let controller: CookingSessionController
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 20) {
                Text("FINISHING")
                    .quietEyebrowStyle(color: theme.ink)
                    .padding(.top, 22)

                Text("Out of the pan.\nCarryover heat is finishing the center.")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                SteakVisual(
                    configuration: controller.session.configuration,
                    cookedProgress: 1
                )
                .frame(height: 170)
                .padding(.horizontal, 48)
                .padding(.bottom, 14)
                .scaleEffect(reduceMotion ? 1 : breathingScale(at: context.date))

                readingSummary

                ProgressView(value: finishingProgress(at: context.date))
                    .tint(theme.ember)
                    .padding(.horizontal, 36)
                    .accessibilityLabel("Estimated finishing progress")

                Spacer()

                Text("This is an estimate, not a live temperature measurement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
        }
        .task(id: controller.session.nextActionAt) {
            await refreshAtFinishBoundary()
        }
    }

    @ViewBuilder
    private var readingSummary: some View {
        if let reading = controller.guidance.lastManualTemperatureC {
            VStack(spacing: 7) {
                Text("LAST READING")
                    .quietEyebrowStyle(color: theme.ink)
                Text("\(reading, specifier: "%.0f")°C")
                    .font(.system(size: 58, weight: .medium, design: .rounded).monospacedDigit())
                Text("Expected carryover +1–3°C · Estimated")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ember)
            }
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 7) {
                Text("ESTIMATED FINISH")
                    .quietEyebrowStyle(color: theme.ink)
                Text(estimatedRangeText)
                    .font(.system(size: 48, weight: .medium, design: .rounded).monospacedDigit())
                Text("No thermometer reading recorded")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var estimatedRangeText: String {
        let range = controller.guidance.finishingEstimate
        let lower = max(1, Int(ceil(range.lowerBound / 60)))
        let upper = max(lower + 1, Int(ceil(range.upperBound / 60)))
        return "\(lower)–\(upper) min"
    }

    private func finishingProgress(at date: Date) -> Double {
        guard let actionDate = controller.session.nextActionAt else { return 0 }
        let duration = actionDate.timeIntervalSince(controller.session.phaseStartedAt)
        guard duration > 0 else { return 1 }
        return min(max(date.timeIntervalSince(controller.session.phaseStartedAt) / duration, 0), 1)
    }

    private func breathingScale(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
        return 1 + 0.015 * sin(phase * .pi * 2)
    }

    private func refreshAtFinishBoundary() async {
        guard let actionDate = controller.session.nextActionAt else { return }
        let delay = actionDate.timeIntervalSinceNow
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
