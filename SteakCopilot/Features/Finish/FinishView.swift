import SwiftUI

struct FinishView: View {
    let controller: CookingSessionController
    @Environment(AppTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { context in
            VStack(spacing: 24) {
                Text("FINISH")
                    .quietEyebrowStyle(color: theme.ink)
                    .padding(.top, 22)

                Text("Out of the pan.\nStill becoming perfect.")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                SteakVisual(
                    configuration: controller.session.configuration,
                    cookedProgress: 1
                )
                .frame(height: 205)
                .padding(.horizontal, 36)
                .scaleEffect(reduceMotion ? 1 : breathingScale(at: context.date))

                VStack(spacing: 4) {
                    Text("\(carryoverTemperature, specifier: "%.1f")°C")
                        .font(.system(size: 60, weight: .medium, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                    Label("Rising", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ember)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Temperature \(carryoverTemperature, specifier: "%.1f") degrees Celsius, rising")

                TemperatureCurve(progress: controller.guidance.progress)
                    .stroke(theme.ember, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(height: 82)
                    .padding(.horizontal, 36)

                Spacer()

                Text("Carryover heat is finishing the center.\nNo need to touch it yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 22)
            .onChange(of: context.date, initial: true) { _, date in
                controller.refresh(at: date)
            }
        }
    }

    private var carryoverTemperature: Double {
        controller.guidance.pullTemperatureC + controller.guidance.progress * 2
    }

    private func breathingScale(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4
        return 1 + 0.015 * sin(phase * .pi * 2)
    }
}

private struct TemperatureCurve: Shape {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width * max(0.02, min(progress, 1))
        path.move(to: CGPoint(x: 0, y: rect.maxY * 0.82))
        path.addCurve(
            to: CGPoint(x: width, y: rect.maxY * 0.18),
            control1: CGPoint(x: width * 0.28, y: rect.maxY * 0.82),
            control2: CGPoint(x: width * 0.62, y: rect.maxY * 0.28)
        )
        return path
    }
}
