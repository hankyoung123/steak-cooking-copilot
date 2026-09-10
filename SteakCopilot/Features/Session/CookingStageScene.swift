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

    /// Transparent object layer for the layered cooking scene.
    static func objectAsset(
        for phase: CookingPhase,
        action: CookingAction
    ) -> String? {
        switch phase {
        case .sear, .fatCap:
            switch action {
            case .flip, .standFatCap:
                "FlipCutout"
            case .addButter, .baste:
                "BasteCutout"
            case .checkTemperature, .takeOut:
                "CheckCutout"
            default:
                "SearCutout"
            }
        case .baste:
            [.checkTemperature, .takeOut].contains(action)
                ? "CheckCutout"
                : "BasteCutout"
        case .checkTemperature:
            "CheckCutout"
        case .finishing:
            "RestCutout"
        default:
            nil
        }
    }
}

/// Pure mapping from a motion cue to object-layer motion. Kept value-level
/// so it is testable without rendering; `reduceMotion` disables everything.
enum SignatureObjectMotion: Equatable, Sendable {
    case none
    case attention
    case heroFlip
    case compactFlip
    case pull

    init(visual: MotionVisual, reduceMotion: Bool) {
        guard !reduceMotion else {
            self = .none
            return
        }
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

    /// Flip animations crossfade between two cutout states near the
    /// midpoint of the turn.
    var swapsObjectMidway: Bool {
        self == .heroFlip || self == .compactFlip
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
    @State private var objectMotion = SignatureObjectMotion.none
    @State private var objectMotionTrigger = 0
    @State private var flipPair: (pre: String, post: String)?
    @State private var settledObjectAsset = "SearCutout"

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
            guard presentation == .fullBleed else { return }
            let motion = SignatureObjectMotion(
                visual: controller.motionDirector.cue.visual,
                reduceMotion: reduceMotion
            )
            guard motion != .none else { return }
            if motion.swapsObjectMidway {
                // The object layer before this flip is whatever settled
                // during the previous non-flip state.
                flipPair = (
                    pre: settledObjectAsset,
                    post: objectAssetForOverlay ?? "FlipCutout"
                )
            } else {
                flipPair = nil
                settledObjectAsset = objectAssetForOverlay ?? settledObjectAsset
            }
            objectMotion = motion
            objectMotionTrigger += 1
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
            // Background stays essentially still; only a subtle brightness /
            // micro-scale response so motion never reads as camera shake.
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
                    BackgroundPhotoResponseModifier(
                        trigger: objectMotionTrigger,
                        motion: objectMotion
                    )
                )

            Color.black.opacity(0.06)

            if let overlayAsset = objectAssetForOverlay {
                objectLayer(overlayAsset, in: size)
            }

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

    @ViewBuilder
    private func objectLayer(_ asset: String, in size: CGSize) -> some View {
        if let flipPair,
           objectMotion.swapsObjectMidway,
           flipPair.post == asset {
            ZStack {
                objectImage(flipPair.pre).modifier(
                    SteakObjectMotionModifier(
                        trigger: objectMotionTrigger,
                        motion: objectMotion,
                        midlineOpacity: { progress in progress < 0.5 ? 1 : 0 }
                    )
                )
                objectImage(flipPair.post).modifier(
                    SteakObjectMotionModifier(
                        trigger: objectMotionTrigger,
                        motion: objectMotion,
                        midlineOpacity: { progress in progress >= 0.5 ? 1 : 0 }
                    )
                )
            }
            .frame(
                width: size.width * 0.86,
                height: size.height * 0.52,
                alignment: objectAlignment
            )
            .frame(width: size.width, height: size.height, alignment: objectAlignment)
        } else {
            objectImage(asset)
                .modifier(
                    SteakObjectMotionModifier(
                        trigger: objectMotionTrigger,
                        motion: objectMotion,
                        midlineOpacity: nil
                    )
                )
                .frame(
                    width: size.width * 0.86,
                    height: size.height * 0.52,
                    alignment: objectAlignment
                )
                .frame(width: size.width, height: size.height, alignment: objectAlignment)
        }
    }

    private func objectImage(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .scaledToFit()
            .shadow(
                color: .black.opacity(0.34),
                radius: 16,
                y: 10
            )
    }

    private var objectAssetForOverlay: String? {
        guard presentation == .fullBleed else { return nil }
        return CookingStageArtwork.objectAsset(
            for: controller.session.phase,
            action: controller.guidance.currentAction
        )
    }

    private var objectAlignment: Alignment {
        switch controller.session.phase {
        case .finishing: .center
        default: .bottom
        }
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

// MARK: - Background response (restrained, never a full-photo flip)

private struct BackgroundPhotoResponseModifier: ViewModifier {
    let trigger: Int
    let motion: SignatureObjectMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: BackgroundResponseValues(),
            trigger: trigger
        ) { content, value in
            content
                .scaleEffect(value.scale)
                .brightness(value.brightness)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(peakScale, duration: MotionTiming.responsive)
                SpringKeyframe(1, duration: MotionTiming.emphasis, spring: .smooth)
            }
            KeyframeTrack(\.brightness) {
                CubicKeyframe(peakBrightness, duration: MotionTiming.responsive)
                LinearKeyframe(0, duration: MotionTiming.emphasis)
            }
        }
    }

    private var peakScale: CGFloat {
        switch motion {
        case .heroFlip: 1.006
        case .compactFlip: 1.004
        case .pull: 1.008
        case .attention: 1.004
        case .none: 1
        }
    }

    private var peakBrightness: Double {
        switch motion {
        case .attention: 0.018
        case .pull: -0.02
        default: 0
        }
    }
}

private struct BackgroundResponseValues {
    var scale: CGFloat = 1
    var brightness: Double = 0
}

// MARK: - Object layer motion (the steak itself moves, not the photo)

private struct SteakObjectMotionModifier: ViewModifier {
    let trigger: Int
    let motion: SignatureObjectMotion
    /// Per-frame opacity for the pre/post flip swap, nil for plain motion.
    let midlineOpacity: (@Sendable (Double) -> Double)?

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: SteakObjectMotionValues(),
            trigger: trigger
        ) { content, value in
            content
                .scaleEffect(x: value.scaleX, y: value.scaleY)
                .offset(y: value.verticalOffset)
                .rotation3DEffect(
                    .degrees(value.flipAngle),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.55
                )
                .opacity(midlineOpacity?(value.flipProgress) ?? value.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scaleY) {
                CubicKeyframe(midScaleY, duration: riseDuration)
                SpringKeyframe(1, duration: settleDuration, spring: .smooth)
            }
            KeyframeTrack(\.scaleX) {
                CubicKeyframe(midScaleX, duration: riseDuration)
                SpringKeyframe(1, duration: settleDuration, spring: .smooth)
            }
            KeyframeTrack(\.verticalOffset) {
                CubicKeyframe(peakLift, duration: riseDuration)
                if exitsScene {
                    LinearKeyframe(exitLift, duration: exitDuration)
                } else {
                    SpringKeyframe(0, duration: settleDuration, spring: .smooth)
                }
            }
            KeyframeTrack(\.flipAngle) {
                CubicKeyframe(flipArc, duration: riseDuration)
                if spins {
                    SpringKeyframe(360, duration: settleDuration, spring: .smooth)
                } else {
                    LinearKeyframe(flipArc, duration: settleDuration)
                }
            }
            KeyframeTrack(\.flipProgress) {
                LinearKeyframe(1, duration: riseDuration + settleDuration)
            }
            KeyframeTrack(\.opacity) {
                if exitsScene {
                    CubicKeyframe(1, duration: riseDuration)
                    LinearKeyframe(0, duration: exitDuration)
                } else {
                    LinearKeyframe(1, duration: riseDuration + settleDuration)
                }
            }
        }
    }

    private var spins: Bool {
        motion == .heroFlip || motion == .compactFlip
    }

    private var exitsScene: Bool {
        motion == .pull
    }

    private var riseDuration: TimeInterval {
        switch motion {
        case .none: MotionTiming.subtle
        case .attention: MotionTiming.responsive
        case .heroFlip: MotionTiming.flipLift + MotionTiming.flipRotate
        case .compactFlip: MotionTiming.compactFlipOut
        case .pull: MotionTiming.takeOutLift
        }
    }

    private var settleDuration: TimeInterval {
        switch motion {
        case .none, .attention: MotionTiming.responsive
        case .heroFlip: MotionTiming.flipLand + MotionTiming.flipSettle
        case .compactFlip: MotionTiming.compactFlipLand
        case .pull: MotionTiming.takeOutHold
        }
    }

    private var exitDuration: TimeInterval {
        MotionTiming.takeOutSettle
    }

    private var peakLift: CGFloat {
        switch motion {
        case .attention: -4
        case .heroFlip: -14
        case .compactFlip: -7
        case .pull: -22
        case .none: 0
        }
    }

    private var exitLift: CGFloat {
        -170
    }

    private var midScaleY: CGFloat {
        switch motion {
        case .heroFlip: 0.84
        case .compactFlip: 0.9
        case .pull: 1
        case .attention, .none: 1
        }
    }

    private var midScaleX: CGFloat {
        switch motion {
        case .heroFlip: 1.05
        case .compactFlip: 1.03
        case .pull: 1.04
        case .attention, .none: 1
        }
    }

    private var flipArc: Double {
        switch motion {
        case .heroFlip: 165
        case .compactFlip: 170
        default: 0
        }
    }
}

private struct SteakObjectMotionValues {
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var verticalOffset: CGFloat = 0
    var flipAngle: Double = 0
    var flipProgress: Double = 0
    var opacity: Double = 1
}
