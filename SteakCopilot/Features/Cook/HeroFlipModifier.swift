import SwiftUI

struct HeroFlipModifier: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: HeroFlipValues(),
            trigger: trigger
        ) { content, value in
            content
                .scaleEffect(value.scale)
                .offset(y: value.verticalOffset)
                .rotation3DEffect(
                    .degrees(value.rotation),
                    axis: (x: 1, y: 0.08, z: 0)
                )
                .shadow(
                    color: .black.opacity(value.shadowOpacity),
                    radius: value.shadowRadius,
                    y: value.shadowY
                )
        } keyframes: { _ in
            KeyframeTrack(\.verticalOffset) {
                CubicKeyframe(-42, duration: MotionTiming.flipLift)
                CubicKeyframe(-58, duration: MotionTiming.flipRotate)
                CubicKeyframe(0, duration: MotionTiming.flipLand)
                SpringKeyframe(
                    0,
                    duration: MotionTiming.flipSettle,
                    spring: .bouncy
                )
            }
            KeyframeTrack(\.rotation) {
                CubicKeyframe(0, duration: MotionTiming.flipLift)
                CubicKeyframe(90, duration: MotionTiming.flipRotate)
                CubicKeyframe(180, duration: MotionTiming.flipLand)
                LinearKeyframe(180, duration: MotionTiming.flipSettle)
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.06, duration: MotionTiming.flipLift)
                CubicKeyframe(1.08, duration: MotionTiming.flipRotate)
                CubicKeyframe(0.98, duration: MotionTiming.flipLand)
                SpringKeyframe(
                    1,
                    duration: MotionTiming.flipSettle,
                    spring: .bouncy
                )
            }
            KeyframeTrack(\.shadowRadius) {
                LinearKeyframe(
                    26,
                    duration: MotionTiming.flipLift + MotionTiming.flipRotate
                )
                LinearKeyframe(8, duration: MotionTiming.flipLand)
                LinearKeyframe(16, duration: MotionTiming.flipSettle)
            }
            KeyframeTrack(\.shadowOpacity) {
                LinearKeyframe(
                    0.48,
                    duration: MotionTiming.flipLift + MotionTiming.flipRotate
                )
                LinearKeyframe(0.18, duration: MotionTiming.flipLand)
                LinearKeyframe(0.3, duration: MotionTiming.flipSettle)
            }
            KeyframeTrack(\.shadowY) {
                LinearKeyframe(
                    34,
                    duration: MotionTiming.flipLift + MotionTiming.flipRotate
                )
                LinearKeyframe(5, duration: MotionTiming.flipLand)
                LinearKeyframe(12, duration: MotionTiming.flipSettle)
            }
        }
    }
}

private struct HeroFlipValues {
    var verticalOffset: CGFloat = 0
    var rotation: Double = 0
    var scale: CGFloat = 1
    var shadowRadius: CGFloat = 16
    var shadowOpacity: Double = 0.3
    var shadowY: CGFloat = 12
}
