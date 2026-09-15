import Foundation

/// One entry in the list of adjustments the app has learned from feedback.
///
/// The calibration silently shapes cooking times and sear bias for a given cut,
/// thickness bucket and doneness. Settings shows these numbers so they stop being
/// invisible, and offers to clear them.
struct LearnedAdjustment: Identifiable, Equatable, Sendable {
    let key: CalibrationKey
    let calibration: CookingCalibration

    var id: CalibrationKey { key }

    /// Whether the entry changes anything at all. A neutral entry is noise in a
    /// list whose whole purpose is "what has this app changed about my cooking".
    var isEffective: Bool {
        calibration != .neutral
    }

    /// How much this entry moved the cooking time, in seconds.
    var cookingTimeAdjustment: TimeInterval { calibration.cookingTimeAdjustment }

    /// How much this entry moved the sear bias, in seconds.
    var searBiasAdjustment: TimeInterval { calibration.searBias }

    /// Total size of the change, for ordering. Magnitudes only: the list is
    /// sorted by "most influential", not by sign.
    var magnitude: TimeInterval {
        abs(cookingTimeAdjustment) + abs(searBiasAdjustment)
    }
}
