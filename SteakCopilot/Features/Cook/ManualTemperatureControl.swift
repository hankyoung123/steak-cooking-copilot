import SwiftUI

/// Reading entry for CHECK TEMP.
///
/// This control lives inside the reserved status band, so it is deliberately
/// two compact rows: the editable value on top, the slider under it. The
/// confirm action is NOT here — it is the primary action of the bottom action
/// row, which keeps one baseline in every phase. Previously this control was
/// inserted into the middle of the scrolling column, which pushed the progress
/// rail, the telemetry and the button down for this phase only.
struct ManualTemperatureControl: View {
    @Binding var temperature: Double
    let pullTemperatureC: Double
    let accentColor: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Center temperature")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(
                        String(
                            format: String(localized: "Pull near %.0f°C"),
                            pullTemperatureC
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(temperature, specifier: "%.0f")°C")
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
            }
            Slider(value: $temperature, in: 35...70, step: 0.5)
                .tint(accentColor)
                .accessibilityLabel("Center temperature")
                .accessibilityIdentifier("cook.temperature.slider")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            .white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }
}
