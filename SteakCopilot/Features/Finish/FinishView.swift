import Charts
import SwiftUI

struct FinishView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController
    @State private var showsExplanation = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 5) {
                        Text("Finishing")
                            .font(.title2.bold())
                        Text("The steak is still cooking.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)

                    readingSummary

                    PrototypeCard(padding: 14) {
                        Chart(chartPoints) { point in
                            AreaMark(
                                x: .value("Time", point.minute),
                                y: .value("Progress", point.value)
                            )
                            .foregroundStyle(theme.ember.opacity(0.09))

                            LineMark(
                                x: .value("Time", point.minute),
                                y: .value("Progress", point.value)
                            )
                            .foregroundStyle(theme.ember)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                            PointMark(
                                x: .value("Time", point.minute),
                                y: .value("Progress", point.value)
                            )
                            .foregroundStyle(theme.ember)
                            .symbolSize(20)
                        }
                        .chartXAxisLabel("Estimated carryover")
                        .chartYScale(domain: chartDomain)
                        .frame(height: 190)
                    }

                    PrototypeCard(padding: 14) {
                        HStack(alignment: .top, spacing: 13) {
                            Image(systemName: "frying.pan")
                                .font(.title2)
                                .foregroundStyle(theme.butter)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rest on a rack or plate.")
                                    .font(.subheadline.weight(.semibold))
                                Text("Tent loosely with foil if needed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showsExplanation.toggle()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Why finishing matters?")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .rotationEffect(.degrees(showsExplanation ? 90 : 0))
                            }
                            if showsExplanation {
                                Text("Heat keeps moving toward the center after the steak leaves the pan.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(14)
                        .background(theme.porcelainDeep.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    Text("This is an estimate, not a live temperature measurement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task(id: controller.session.nextActionAt) {
            await refreshAtFinishBoundary()
        }
    }

    @ViewBuilder
    private var readingSummary: some View {
        if let reading = controller.guidance.lastManualTemperatureC {
            VStack(spacing: 4) {
                Text("LAST READING")
                    .quietEyebrowStyle(color: theme.ink)
                Text("\(reading, specifier: "%.0f")°C")
                    .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(theme.ember)
                Text("Expected carryover +1–3°C · Estimated")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.ember)
            }
            .accessibilityElement(children: .combine)
        } else {
            VStack(spacing: 4) {
                Text("ESTIMATED FINISH")
                    .quietEyebrowStyle(color: theme.ink)
                Text(estimatedRangeText)
                    .font(.system(size: 42, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(theme.ember)
                Text("No thermometer reading recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var chartPoints: [CarryoverPoint] {
        let reading = controller.guidance.lastManualTemperatureC
        return (0...6).map { index in
            let progress = Double(index) / 6
            let value = reading.map { $0 + 2 * pow(progress, 1.35) }
                ?? progress * 100
            return CarryoverPoint(minute: progress * finishMinutes, value: value)
        }
    }

    private var chartDomain: ClosedRange<Double> {
        if let reading = controller.guidance.lastManualTemperatureC {
            return (reading - 0.5)...(reading + 2.5)
        }
        return 0...100
    }

    private var finishMinutes: Double {
        max(1, ceil(controller.guidance.finishingEstimate.upperBound / 60))
    }

    private var estimatedRangeText: String {
        let range = controller.guidance.finishingEstimate
        let lower = max(1, Int(ceil(range.lowerBound / 60)))
        let upper = max(lower + 1, Int(ceil(range.upperBound / 60)))
        return String(
            format: String(localized: "%lld–%lld min"),
            Int64(lower),
            Int64(upper)
        )
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

private struct CarryoverPoint: Identifiable {
    let minute: Double
    let value: Double

    var id: Double { minute }
}
