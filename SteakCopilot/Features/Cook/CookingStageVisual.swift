import SwiftUI

struct CookingStageVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let configuration: SteakConfiguration
    let cookedProgress: Double
    let showsButter: Bool
    let action: CookingAction
    let motion: MotionDirector
    let butterColor: Color
    @State private var heroFlipTrigger = 0
    @State private var compactFlipTrigger = 0
    @State private var takeOutTrigger = 0

    var body: some View {
        ZStack {
            Image(action == .baste ? "BasteScene" : "CookPan")
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [.black.opacity(0.22), .clear, .black.opacity(0.45)],
                startPoint: .top,
                endPoint: .bottom
            )

            if action != .baste {
                animatedSteak
                    .frame(width: 225, height: 154)
                    .scaleEffect(x: 1.08, y: 0.68)
                    .rotationEffect(.degrees(-6))
                    .offset(y: 78)
            }

            CookingAccent(action: action, butterColor: butterColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onChange(of: motion.sequence, handleMotionCue)
    }

    @ViewBuilder
    private var animatedSteak: some View {
        let steak = SteakVisual(
            configuration: configuration,
            cookedProgress: cookedProgress,
            showButter: showsButter
        )

        if reduceMotion {
            steak.contentTransition(.opacity)
        } else {
            steak
                .modifier(HeroFlipModifier(trigger: heroFlipTrigger))
                .modifier(CompactFlipModifier(trigger: compactFlipTrigger))
                .modifier(TakeOutModifier(trigger: takeOutTrigger))
        }
    }

    private func handleMotionCue() {
        switch motion.cue.visual {
        case .heroFlip: heroFlipTrigger += 1
        case .compactFlip: compactFlipTrigger += 1
        case .pull: takeOutTrigger += 1
        default: break
        }
    }
}

private struct CookingAccent: View {
    let action: CookingAction
    let butterColor: Color

    var body: some View {
        ZStack {
            if action == .addButter {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .stroke(butterColor.opacity(0.52), lineWidth: 2)
                        .frame(width: 10 + CGFloat(index % 3) * 5)
                        .offset(
                            x: CGFloat((index * 43) % 150) - 74,
                            y: CGFloat((index * 31) % 86) - 28
                        )
                }
            }
        }
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}
