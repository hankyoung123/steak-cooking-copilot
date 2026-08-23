import SwiftUI

struct HeatView: View {
    @Environment(AppTheme.self) private var theme
    let controller: CookingSessionController

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 5) {
                Text("Heat the pan")
                    .font(.title2.bold())
                Text("Medium-high heat")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 10)

            Image("HotPan")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 390)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Image(systemName: "flame")
                    .font(.title2)
                    .foregroundStyle(theme.ember)
                Text("Wait until the pan is hot.")
                    .font(.headline)
                Text("A few drops of water should sizzle and dance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 8)

            PrimaryActionButton(title: String(localized: "Pan is ready")) {
                controller.panIsReady()
            }
            .accessibilityIdentifier("heat.ready")

            Text("Not ready yet")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.ember)
                .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
