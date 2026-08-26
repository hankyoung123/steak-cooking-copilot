import SwiftUI

enum CookingStageArtwork {
    static func backgroundAsset(
        for phase: CookingPhase,
        action: CookingAction
    ) -> String? {
        switch phase {
        case .sear, .fatCap:
            switch action {
            case .flip, .standFatCap:
                "CookFlipBackground"
            case .addButter, .baste:
                "CookBasteBackground"
            case .checkTemperature, .takeOut:
                "CookCheckBackground"
            default:
                "CookSearBackground"
            }
        case .baste:
            [.checkTemperature, .takeOut].contains(action)
                ? "CookCheckBackground"
                : "CookBasteBackground"
        case .checkTemperature:
            "CookCheckBackground"
        case .finishing:
            "CookRestBackground"
        default:
            nil
        }
    }
}

struct CookingStageScene: View {
    enum Presentation: Equatable {
        case inline
        case fullBleed
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let controller: CookingSessionController
    let prepIsDry: Bool
    let darkBackground: Bool
    var presentation: Presentation = .inline
    @State private var photoMotion = FullBleedPhotoMotion.none
    @State private var photoMotionTrigger = 0

    var body: some View {
        GeometryReader { proxy in
            switch presentation {
            case .inline:
                inlineScene
                    .frame(width: proxy.size.width, height: proxy.size.height)
            case .fullBleed:
                fullBleedScene(in: proxy.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentTransition(.opacity)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.58),
            value: sceneAsset
        )
        .onChange(of: controller.motionDirector.sequence) { _, _ in
            guard presentation == .fullBleed, !reduceMotion else { return }
            let motion = FullBleedPhotoMotion(
                visual: controller.motionDirector.cue.visual
            )
            guard motion != .none else { return }
            photoMotion = motion
            photoMotionTrigger += 1
        }
        .accessibilityHidden(true)
    }

    private var inlineScene: some View {
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
    }

    private func fullBleedScene(in size: CGSize) -> some View {
        ZStack {
            Image(sceneAsset)
                .resizable()
                .scaledToFill()
                .frame(
                    width: size.width,
                    height: size.height,
                    alignment: focalAlignment
                )
                .clipped()
                .id(sceneAsset)
                .transition(.opacity)
                .modifier(
                    FullBleedPhotoMotionModifier(
                        trigger: photoMotionTrigger,
                        motion: photoMotion
                    )
                )

            Color.black.opacity(0.06)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.96), location: 0),
                    .init(color: .black.opacity(0.72), location: 0.15),
                    .init(color: .black.opacity(0.22), location: 0.31),
                    .init(color: .clear, location: 0.46)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.42),
                    .init(color: .black.opacity(0.10), location: 0.52),
                    .init(color: .black.opacity(0.68), location: 0.76),
                    .init(color: .black.opacity(0.98), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private var sceneAsset: String {
        if presentation == .fullBleed {
            return CookingStageArtwork.backgroundAsset(
                for: controller.session.phase,
                action: controller.guidance.currentAction
            ) ?? "CookSearBackground"
        }

        switch controller.session.phase {
        case .prep:
            return prepIsDry ? "PrepSaltCutout" : "PrepDryCutout"
        case .heat:
            return "HotPanCutout"
        case .baste:
            return [.checkTemperature, .takeOut].contains(controller.guidance.currentAction)
                ? "CheckCutout"
                : "BasteCutout"
        case .checkTemperature:
            return "CheckCutout"
        case .finishing:
            return "RestCutout"
        case .sear, .fatCap:
            switch controller.guidance.currentAction {
            case .flip, .standFatCap:
                return "FlipCutout"
            case .addButter, .baste:
                return "BasteCutout"
            case .checkTemperature, .takeOut:
                return "CheckCutout"
            default:
                return "SearCutout"
            }
        default:
            return "SearCutout"
        }
    }

    private var focalAlignment: Alignment {
        switch sceneAsset {
        case "CookCheckBackground": .trailing
        default: .center
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

private enum FullBleedPhotoMotion: Equatable {
    case none
    case attention
    case heroFlip
    case compactFlip
    case pull

    init(visual: MotionVisual) {
        switch visual {
        case .attention:
            self = .attention
        case .heroFlip:
            self = .heroFlip
        case .compactFlip:
            self = .compactFlip
        case .pull:
            self = .pull
        default:
            self = .none
        }
    }
}

private struct FullBleedPhotoMotionModifier: ViewModifier {
    let trigger: Int
    let motion: FullBleedPhotoMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: FullBleedPhotoMotionValues(),
            trigger: trigger
        ) { content, value in
            content
                .scaleEffect(value.scale)
                .offset(y: value.verticalOffset)
                .rotationEffect(.degrees(value.rotation))
                .rotation3DEffect(
                    .degrees(value.perspectiveTilt),
                    axis: (x: 1, y: 0.08, z: 0),
                    perspective: 0.45
                )
                .brightness(value.brightness)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(peakScale, duration: riseDuration)
                SpringKeyframe(
                    1,
                    duration: settleDuration,
                    spring: .smooth
                )
            }
            KeyframeTrack(\.verticalOffset) {
                CubicKeyframe(peakOffset, duration: riseDuration)
                SpringKeyframe(
                    0,
                    duration: settleDuration,
                    spring: .smooth
                )
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(peakRotation, duration: riseDuration)
                SpringKeyframe(
                    0,
                    duration: settleDuration,
                    spring: .smooth
                )
            }
            KeyframeTrack(\.perspectiveTilt) {
                CubicKeyframe(peakPerspectiveTilt, duration: riseDuration)
                SpringKeyframe(
                    0,
                    duration: settleDuration,
                    spring: .smooth
                )
            }
            KeyframeTrack(\.brightness) {
                CubicKeyframe(peakBrightness, duration: riseDuration)
                LinearKeyframe(0, duration: settleDuration)
            }
        }
    }

    private var peakScale: CGFloat {
        switch motion {
        case .none: 1
        case .attention: 1.012
        case .heroFlip: 1.065
        case .compactFlip: 1.032
        case .pull: 1.085
        }
    }

    private var peakOffset: CGFloat {
        switch motion {
        case .none, .attention: 0
        case .heroFlip: -18
        case .compactFlip: -6
        case .pull: -24
        }
    }

    private var peakRotation: Double {
        switch motion {
        case .heroFlip: -0.9
        case .compactFlip: 0.55
        default: 0
        }
    }

    private var peakPerspectiveTilt: Double {
        switch motion {
        case .heroFlip: 5.5
        case .compactFlip: 2
        case .pull: 3.5
        default: 0
        }
    }

    private var peakBrightness: Double {
        switch motion {
        case .none: 0
        case .attention: 0.018
        case .heroFlip: 0.055
        case .compactFlip: 0.025
        case .pull: 0.045
        }
    }

    private var riseDuration: TimeInterval {
        switch motion {
        case .none: MotionTiming.subtle
        case .attention: MotionTiming.responsive
        case .heroFlip: MotionTiming.flipLift + MotionTiming.flipRotate
        case .compactFlip: MotionTiming.compactFlipOut
        case .pull: MotionTiming.takeOutLift + MotionTiming.takeOutHold
        }
    }

    private var settleDuration: TimeInterval {
        switch motion {
        case .none, .attention: MotionTiming.responsive
        case .heroFlip: MotionTiming.flipLand + MotionTiming.flipSettle
        case .compactFlip: MotionTiming.compactFlipLand
        case .pull: MotionTiming.takeOutSettle
        }
    }
}

private struct FullBleedPhotoMotionValues {
    var scale: CGFloat = 1
    var verticalOffset: CGFloat = 0
    var rotation: Double = 0
    var perspectiveTilt: Double = 0
    var brightness: Double = 0
}
