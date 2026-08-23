import SwiftUI

struct CookingStageScene: View {
    let controller: CookingSessionController
    let prepIsDry: Bool

    var body: some View {
        ZStack {
            Image(sceneAsset)
                .resizable()
                .scaledToFill()

            Color.black.opacity(0.18)

            if showsSteakInPan {
                Image("SteakSurface")
                    .resizable()
                    .scaledToFill()
                    .saturation(0.9)
                    .contrast(1.12)
                    .brightness(-0.08)
                    .frame(width: 300, height: 175)
                    .mask {
                        Image(controller.session.configuration.cut.heroAssetName)
                            .resizable()
                            .scaledToFit()
                    }
                    .rotationEffect(.degrees(-7))
                    .rotation3DEffect(
                        .degrees(controller.guidance.currentAction == .flip ? 14 : 0),
                        axis: (x: 1, y: 0.08, z: 0)
                    )
                    .offset(y: 46)
                    .shadow(color: .black.opacity(0.5), radius: 18, y: 12)
                    .animation(
                        .easeInOut(duration: 0.5),
                        value: controller.guidance.currentAction
                    )
            }

            if controller.session.phase == .checkTemperature {
                Image(systemName: "thermometer.and.liquid.waves")
                    .font(.system(size: 66, weight: .thin))
                    .foregroundStyle(.white)
                    .padding(28)
                    .background(.black.opacity(0.55), in: Circle())
            }

            if controller.session.phase == .finishing {
                VStack(spacing: 10) {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .font(.system(size: 54, weight: .thin))
                    Text("Rest off the heat")
                        .font(.title2.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentTransition(.opacity)
        .animation(.easeInOut(duration: 0.48), value: sceneAsset)
        .accessibilityHidden(true)
    }

    private var sceneAsset: String {
        switch controller.session.phase {
        case .prep: prepIsDry ? "PrepSalt" : "PrepDry"
        case .heat: "HotPan"
        case .baste: "BasteScene"
        case .finishing: controller.session.configuration.doneness.assetName
        default:
            controller.guidance.currentAction == .baste ? "BasteScene" : "CookPan"
        }
    }

    private var showsSteakInPan: Bool {
        switch controller.session.phase {
        case .sear, .fatCap, .checkTemperature: true
        default: false
        }
    }
}
