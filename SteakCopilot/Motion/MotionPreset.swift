import SwiftUI

enum MotionPreset: Equatable, Sendable {
    case subtle
    case responsive
    case emphasis
    case action
    case cinematic

    /// Animation curves are built from tunable durations; the mapping from
    /// preset to curve is not a tunable parameter.
    func animation(using motion: MotionTuning) -> Animation {
        switch self {
        case .subtle: .easeOut(duration: motion.subtle)
        case .responsive: .snappy(duration: motion.responsive)
        case .emphasis: .spring(duration: motion.emphasis, bounce: motion.emphasisBounce)
        case .action: .spring(duration: motion.action, bounce: motion.actionBounce)
        case .cinematic: .easeInOut(duration: motion.cinematic)
        }
    }
}
