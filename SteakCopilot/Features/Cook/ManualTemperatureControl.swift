import SwiftUI

struct ManualTemperatureControl: View {
    @Binding var temperature: Double
    let pullTemperatureC: Double
    let accentColor: Color
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Center temperature")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        String(
                            format: String(localized: "Pull near %.0f°C"),
                            pullTemperatureC
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(temperature, specifier: "%.0f")°C")
                    .font(.headline.monospacedDigit())
            }
            Slider(value: $temperature, in: 35...70, step: 0.5)
                .tint(accentColor)
                .accessibilityLabel("Center temperature")
                .accessibilityIdentifier("cook.temperature.slider")
            Button("Use this reading", action: onSubmit)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accentColor)
                .accessibilityIdentifier("cook.temperature.submit")
        }
        .padding(14)
        .background(
            .white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 18)
        )
    }
}
