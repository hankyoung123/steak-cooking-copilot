import SwiftUI

struct CompactFlipModifier: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: CompactFlipValues(),
            trigger: trigger
        ) { content, value in
            content
                .rotationEffect(.degrees(value.rotation))
                .scaleEffect(value.scale)
        } keyframes: { _ in
            KeyframeTrack(\.rotation) {
                CubicKeyframe(-7, duration: MotionTiming.compactFlipOut)
                SpringKeyframe(
                    0,
                    duration: MotionTiming.compactFlipLand,
                    spring: .bouncy
                )
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.035, duration: MotionTiming.compactFlipOut)
                SpringKeyframe(
                    1,
                    duration: MotionTiming.compactFlipLand,
                    spring: .bouncy
                )
            }
        }
    }
}

private struct CompactFlipValues {
    var rotation: Double = 0
    var scale: CGFloat = 1
}
