import SwiftUI

enum MotionPreset: Equatable, Sendable {
    case subtle
    case responsive
    case emphasis
    case action
    case cinematic

    var animation: Animation {
        switch self {
        case .subtle: .easeOut(duration: MotionTiming.subtle)
        case .responsive: .snappy(duration: MotionTiming.responsive)
        case .emphasis: .spring(duration: MotionTiming.emphasis, bounce: 0.16)
        case .action: .spring(duration: MotionTiming.action, bounce: 0.22)
        case .cinematic: .easeInOut(duration: MotionTiming.cinematic)
        }
    }
}
