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
            PanVisual(isCooking: true)
                .frame(width: 315)

            animatedSteak
                .frame(width: 235)
                .offset(y: 10)

            CookingAccent(action: action, butterColor: butterColor)
        }
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

            if action == .baste {
                BasteAccent()
            }
        }
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}

private struct BasteAccent: View {
    var body: some View {
        ZStack {
            ArcShape()
                .stroke(
                    .white.opacity(0.6),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 130, height: 90)
                .rotationEffect(.degrees(-18))
                .offset(x: 44, y: -42)
            Capsule()
                .fill(.white.opacity(0.7))
                .frame(width: 90, height: 10)
                .rotationEffect(.degrees(-35))
                .offset(x: 82, y: -78)
        }
    }
}

private struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY * 0.58),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return path
    }
}
