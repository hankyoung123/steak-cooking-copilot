import UIKit

/// Seam for `MotionDirector`, so a test can observe which cues were fired —
/// which is the only way to prove a preference actually silences one.
@MainActor
protocol HapticServing: AnyObject {
    func fire(_ preset: HapticPreset)
}

@MainActor
final class HapticService: HapticServing {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func fire(_ preset: HapticPreset) {
        guard isEnabled else { return }

        switch preset {
        case .none:
            break
        case .lightImpact:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .mediumImpact:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavyImpact:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
