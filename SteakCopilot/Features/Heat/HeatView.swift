import SwiftUI

struct HeatView: View {
    let controller: CookingSessionController

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 24)

            Text("HEAT")
                .quietEyebrowStyle(color: .primary)
            Text("Give the pan\ntime to get hot.")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Watch the pan, not a fake countdown.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 290, height: 290)
                    .blur(radius: 24)
                PanVisual(isHeating: true)
                    .frame(width: 270)
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 9) {
                Label("A drop of water should dance and evaporate.", systemImage: "drop.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PrimaryActionButton(title: "Pan is ready", icon: "flame.fill") {
                    controller.panIsReady()
                }
                .accessibilityIdentifier("heat.ready")
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }
}
