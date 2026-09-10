import SwiftUI

/// Explicit artwork policy for the cooking stage.
///
/// The repository holds two INCOMPATIBLE artwork families:
///
/// 1. `Cook*Background` — opaque photographs that already contain the pan,
///    the steak and the steam. They are a *complete composition*.
/// 2. `*Cutout` (SearCutout, FlipCutout, …) — transparent object layers
///    (verified alpha channel) meant to be the single food layer on a plain
///    canvas.
///
/// Drawing a complete composition and an object cutout at the same time
/// renders two steaks, which is exactly the overlap this type prevents: the
/// view no longer guesses, it asks for the policy and renders what it says.
struct CookingStageArtwork: Equatable, Sendable {
    /// Opaque complete photograph, drawn full-bleed. Never combined with an
    /// object layer.
    let backgroundAsset: String?
    /// Transparent single object layer, used only when the stage has no
    /// complete photograph behind it.
    let objectAsset: String?

    /// True for stages whose artwork is a complete composition: render the
    /// photograph and nothing else.
    var usesBackgroundOnly: Bool { backgroundAsset != nil }

    /// True only for stages with no complete photograph, where the single
    /// transparent object layer *is* the picture.
    var showsObjectOverlay: Bool {
        backgroundAsset == nil && objectAsset != nil
    }

    /// A steak cutout may be layered only when there is no complete
    /// composition behind it. This is the invariant that was violated.
    var allowsSteakCutout: Bool { !usesBackgroundOnly }

    /// The single image this stage draws. Exactly one layer, always.
    var asset: String {
        backgroundAsset ?? objectAsset ?? "CookSearBackground"
    }

    /// Resolves the artwork for a stage. The artwork family is a property of
    /// the stage, not of the presentation, so a stage can never end up
    /// layered differently depending on where it is rendered.
    static func resolve(
        for phase: CookingPhase,
        action: CookingAction,
        prepIsDry: Bool = true
    ) -> CookingStageArtwork {
        switch phase {
        case .prep:
            // No background photo for prep: the transparent cutout is the
            // single layer on the light canvas.
            return CookingStageArtwork(
                backgroundAsset: nil,
                objectAsset: prepIsDry ? "PrepSaltCutout" : "PrepDryCutout"
            )
        case .heat:
            return CookingStageArtwork(
                backgroundAsset: nil,
                objectAsset: "HotPanCutout"
            )
        case .sear, .fatCap:
            switch action {
            case .flip, .standFatCap:
                return backgroundOnly("CookFlipBackground")
            case .addButter, .baste:
                return backgroundOnly("CookBasteBackground")
            case .checkTemperature, .takeOut:
                return backgroundOnly("CookCheckBackground")
            default:
                return backgroundOnly("CookSearBackground")
            }
        case .baste:
            return [.checkTemperature, .takeOut].contains(action)
                ? backgroundOnly("CookCheckBackground")
                : backgroundOnly("CookBasteBackground")
        case .checkTemperature:
            return backgroundOnly("CookCheckBackground")
        case .finishing:
            return backgroundOnly("CookRestBackground")
        case .setup, .ready, .eat, .feedback:
            return CookingStageArtwork(backgroundAsset: nil, objectAsset: nil)
        }
    }

    /// Convenience for the five supplied full-bleed compositions.
    private static func backgroundOnly(_ asset: String) -> CookingStageArtwork {
        CookingStageArtwork(backgroundAsset: asset, objectAsset: nil)
    }
}

/// Pure mapping from a motion cue to the stage's whole-frame motion response.
/// Kept value-level so it is testable without rendering; `reduceMotion`
/// disables everything.
///
/// The cook stages are complete photographs, so the response stays a subtle
/// scale / brightness pulse: no layer is spun or swapped, because there is no
/// separate object layer to animate.
enum StageMotionResponse: Equatable, Sendable {
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
    @State private var motion = StageMotionResponse.none
    @State private var motionTrigger = 0

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
            reduceMotion
                ? nil
                : .easeInOut(duration: controller.tuning.motion.stageSceneCrossfade),
            value: sceneAsset
        )
        .onChange(of: controller.motionDirector.sequence) { _, _ in
            let response = StageMotionResponse(
                visual: controller.motionDirector.cue.visual,
                reduceMotion: reduceMotion
            )
            guard response != .none else { return }
            motion = response
            motionTrigger += 1
        }
        .accessibilityHidden(true)
    }

    /// Inline presentation for stages without a photograph (prep, heat): the
    /// transparent cutout is the one and only layer.
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

    /// Full-bleed presentation for the cook and finishing stages.
    ///
    /// These stages use a complete composition that already contains the pan
    /// and the steak, so this renders ONE layer: the photograph. Adding an
    /// object cutout here would duplicate the steak.
    private func fullBleedScene(in size: CGSize) -> some View {
        ZStack {
            // The photograph stays essentially still; only a subtle
            // brightness / micro-scale response so motion never reads as
            // camera shake and never as a second layer.
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
                    StageCompositionResponseModifier(
                        trigger: motionTrigger,
                        response: motion,
                        timing: controller.tuning.motion
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

    /// The resolved artwork policy for the current stage.
    private var artwork: CookingStageArtwork {
        CookingStageArtwork.resolve(
            for: controller.session.phase,
            action: controller.guidance.currentAction,
            prepIsDry: prepIsDry
        )
    }

    /// Identity of the single rendered layer, used for the crossfade between
    /// stage compositions.
    private var sceneAsset: String { artwork.asset }

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

// MARK: - Whole-frame response (no separate object layer)

private struct StageCompositionResponseModifier: ViewModifier {
    let trigger: Int
    let response: StageMotionResponse
    let timing: MotionTuning

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: StageCompositionResponseValues(),
            trigger: trigger
        ) { content, value in
            content
                .scaleEffect(value.scale)
                .brightness(value.brightness)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(peakScale, duration: timing.responsive)
                SpringKeyframe(1, duration: timing.emphasis, spring: .smooth)
            }
            KeyframeTrack(\.brightness) {
                CubicKeyframe(peakBrightness, duration: timing.responsive)
                LinearKeyframe(0, duration: timing.emphasis)
            }
        }
    }

    private var peakScale: CGFloat {
        switch response {
        case .heroFlip: 1.006
        case .compactFlip: 1.004
        case .pull: 1.008
        case .attention: 1.004
        case .none: 1
        }
    }

    private var peakBrightness: Double {
        switch response {
        case .attention: 0.018
        case .pull: -0.02
        default: 0
        }
    }
}

private struct StageCompositionResponseValues {
    var scale: CGFloat = 1
    var brightness: Double = 0
}
