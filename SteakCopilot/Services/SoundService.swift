import AudioToolbox

@MainActor
final class SoundService {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func play(_ preset: SoundPreset) {
        guard isEnabled else { return }

        let soundID: SystemSoundID?
        switch preset {
        case .none: soundID = nil
        case .flip: soundID = 1104
        case .pull: soundID = 1151
        case .ready: soundID = 1114
        }

        if let soundID {
            AudioServicesPlaySystemSound(soundID)
        }
    }
}
