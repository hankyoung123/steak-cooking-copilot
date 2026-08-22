import SwiftUI

struct TakeOutModifier: ViewModifier {
    let trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(
            initialValue: TakeOutValues(),
            trigger: trigger
        ) { content, value in
            content
                .offset(y: value.verticalOffset)
                .scaleEffect(value.scale)
                .shadow(
                    color: .black.opacity(value.shadowOpacity),
                    radius: value.shadowRadius,
                    y: value.shadowY
                )
        } keyframes: { _ in
            KeyframeTrack(\.verticalOffset) {
                CubicKeyframe(-22, duration: MotionTiming.takeOutLift)
                CubicKeyframe(-34, duration: MotionTiming.takeOutHold)
                SpringKeyframe(
                    0,
                    duration: MotionTiming.takeOutSettle,
                    spring: .smooth
                )
            }
            KeyframeTrack(\.scale) {
                CubicKeyframe(1.06, duration: MotionTiming.takeOutLift)
                CubicKeyframe(1.09, duration: MotionTiming.takeOutHold)
                SpringKeyframe(
                    1,
                    duration: MotionTiming.takeOutSettle,
                    spring: .smooth
                )
            }
            KeyframeTrack(\.shadowRadius) {
                CubicKeyframe(28, duration: MotionTiming.takeOutLift)
                LinearKeyframe(30, duration: MotionTiming.takeOutHold)
                LinearKeyframe(16, duration: MotionTiming.takeOutSettle)
            }
            KeyframeTrack(\.shadowOpacity) {
                CubicKeyframe(0.5, duration: MotionTiming.takeOutLift)
                LinearKeyframe(0.54, duration: MotionTiming.takeOutHold)
                LinearKeyframe(0.3, duration: MotionTiming.takeOutSettle)
            }
            KeyframeTrack(\.shadowY) {
                CubicKeyframe(36, duration: MotionTiming.takeOutLift)
                LinearKeyframe(40, duration: MotionTiming.takeOutHold)
                LinearKeyframe(12, duration: MotionTiming.takeOutSettle)
            }
        }
    }
}

private struct TakeOutValues {
    var verticalOffset: CGFloat = 0
    var scale: CGFloat = 1
    var shadowRadius: CGFloat = 16
    var shadowOpacity: Double = 0.3
    var shadowY: CGFloat = 12
}
