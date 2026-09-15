import Foundation
import Observation

@MainActor
@Observable
final class MotionDirector {
    private let haptics: any HapticServing
    private let sounds: any SoundServing
    /// Read on every event, so a tuning change takes effect immediately
    /// instead of being frozen into an `AppTuning` snapshot at init.
    private let tuningProvider: any TuningProviding
    /// Also read on every event, so flipping a switch in Settings is felt on the
    /// very next cue rather than at the next launch.
    private let preferencesProvider: any AppPreferencesProviding

    private(set) var cue = MotionCue(
        visual: .none,
        preset: .subtle,
        haptic: .none,
        sound: .none
    )
    private(set) var sequence = 0

    init(
        haptics: any HapticServing = HapticService(),
        sounds: any SoundServing = SoundService(),
        tuningProvider: any TuningProviding = StaticTuningProvider(),
        preferencesProvider: any AppPreferencesProviding = StaticAppPreferencesProvider()
    ) {
        self.haptics = haptics
        self.sounds = sounds
        self.tuningProvider = tuningProvider
        self.preferencesProvider = preferencesProvider
    }

    /// Convenience for a fixed tuning (tests, previews).
    convenience init(
        haptics: any HapticServing = HapticService(),
        sounds: any SoundServing = SoundService(),
        tuning: AppTuning,
        preferencesProvider: any AppPreferencesProviding = StaticAppPreferencesProvider()
    ) {
        self.init(
            haptics: haptics,
            sounds: sounds,
            tuningProvider: StaticTuningProvider(tuning: tuning),
            preferencesProvider: preferencesProvider
        )
    }

    /// The tuning in force right now.
    var effectiveTuning: AppTuning { tuningProvider.effective }

    func handle(_ event: CookingEvent) {
        cue = Self.cue(for: event, tuning: tuningProvider.effective)
        sequence += 1

        // The services keep their own launch-argument kill switch; these are the
        // user's preferences on top of it, so a disabled cue is never fired and
        // the visual cue still is.
        let preferences = preferencesProvider.preferences
        if preferences.isHapticsEnabled {
            haptics.fire(cue.haptic)
        }
        if preferences.isSoundEnabled {
            sounds.play(cue.sound)
        }
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
