import Foundation

enum MotionVisual: Equatable, Sendable {
    case none
    case attention(seconds: Int)
    case heroFlip
    case compactFlip
    case standFatCap
    case addButter
    case baste
    case checkTemperature
    case pull
    case ready
}

enum HapticPreset: Equatable, Sendable {
    case none
    case lightImpact
    case mediumImpact
    case heavyImpact
    case success
}

enum SoundPreset: Equatable, Sendable {
    case none
    case flip
    case pull
    case ready
}

struct MotionCue: Equatable, Sendable {
    let visual: MotionVisual
    let preset: MotionPreset
    let haptic: HapticPreset
    let sound: SoundPreset
}
