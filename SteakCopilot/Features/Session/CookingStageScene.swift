import SwiftUI

struct CookingStageScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let controller: CookingSessionController
    let prepIsDry: Bool
    let darkBackground: Bool

    var body: some View {
        ZStack {
            Image(sceneAsset)
                .resizable()
                .scaledToFit()
                .padding(.horizontal, horizontalInset)
                .padding(.vertical, 6)
                .shadow(
                    color: .black.opacity(darkBackground ? 0.32 : 0.14),
                    radius: 18,
                    y: 13
                )
                .scaleEffect(sceneScale)
                .id(sceneAsset)
                .transition(.opacity)

            LinearGradient(
                colors: [
                    .clear,
                    .clear,
                    .black.opacity(darkBackground ? 0.18 : 0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentTransition(.opacity)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.58),
            value: sceneAsset
        )
        .accessibilityHidden(true)
    }

    private var sceneAsset: String {
        switch controller.session.phase {
        case .prep:
            prepIsDry ? "PrepSaltCutout" : "PrepDryCutout"
        case .heat:
            "HotPanCutout"
        case .baste:
            [.checkTemperature, .takeOut].contains(controller.guidance.currentAction)
                ? "CheckCutout"
                : "BasteCutout"
        case .checkTemperature:
            "CheckCutout"
        case .finishing:
            "RestCutout"
        case .sear, .fatCap:
            switch controller.guidance.currentAction {
            case .flip, .standFatCap:
                "FlipCutout"
            case .addButter, .baste:
                "BasteCutout"
            case .checkTemperature, .takeOut:
                "CheckCutout"
            default:
                "SearCutout"
            }
        default:
            "SearCutout"
        }
    }

    private var horizontalInset: CGFloat {
        switch controller.session.phase {
        case .prep: 22
        case .heat: 34
        case .finishing: 10
        default: 0
        }
    }

    private var sceneScale: CGFloat {
        switch controller.session.phase {
        case .sear, .fatCap: 1.24
        case .baste, .checkTemperature: 1.12
        case .finishing: 1.08
        default: 1
        }
    }
}
