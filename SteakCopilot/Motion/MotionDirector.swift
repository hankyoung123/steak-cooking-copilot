import Foundation
import Observation

@MainActor
@Observable
final class MotionDirector {
    private let haptics: HapticService
    private let sounds: SoundService
    private let tuning: AppTuning

    private(set) var cue = MotionCue(
        visual: .none,
        preset: .subtle,
        haptic: .none,
        sound: .none
    )
    private(set) var sequence = 0

    init(
        haptics: HapticService = HapticService(),
        sounds: SoundService = SoundService(),
        tuning: AppTuning = .production
    ) {
        self.haptics = haptics
        self.sounds = sounds
        self.tuning = tuning
    }

    func handle(_ event: CookingEvent) {
        cue = Self.cue(for: event, tuning: tuning)
        sequence += 1
        haptics.fire(cue.haptic)
        sounds.play(cue.sound)
    }

    func resetTransientState() {
        cue = MotionCue(
            visual: .none,
            preset: .subtle,
            haptic: .none,
            sound: .none
        )
        sequence += 1
    }

    static func cue(
        for event: CookingEvent,
        tuning: AppTuning = .production
    ) -> MotionCue {
        switch event {
        case let .flipApproaching(seconds):
            let thresholds = tuning.notifications
            let heavy = Int(thresholds.hapticHeavySeconds)
            let light = Int(thresholds.hapticLightSeconds)
            let haptic: HapticPreset = seconds <= heavy
                ? .mediumImpact
                : (seconds <= light ? .lightImpact : .none)
            return MotionCue(
                visual: .attention(seconds: seconds),
                preset: .emphasis,
                haptic: haptic,
                sound: .none
            )
        case let .flipNow(style):
            return MotionCue(
                visual: style == .hero ? .heroFlip : .compactFlip,
                preset: style == .hero ? .action : .emphasis,
                haptic: .heavyImpact,
                sound: style == .hero ? .flip : .none
            )
        case .standFatCap:
            return MotionCue(visual: .standFatCap, preset: .emphasis, haptic: .mediumImpact, sound: .none)
        case .addButter:
            return MotionCue(visual: .addButter, preset: .emphasis, haptic: .mediumImpact, sound: .none)
        case .baste:
            return MotionCue(visual: .baste, preset: .emphasis, haptic: .lightImpact, sound: .none)
        case .checkTemperature:
            return MotionCue(visual: .checkTemperature, preset: .emphasis, haptic: .mediumImpact, sound: .none)
        case .pullNow:
            return MotionCue(visual: .pull, preset: .action, haptic: .heavyImpact, sound: .pull)
        case .ready:
            return MotionCue(visual: .ready, preset: .cinematic, haptic: .success, sound: .ready)
        }
    }
}
