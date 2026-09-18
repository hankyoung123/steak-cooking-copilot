import Foundation

/// The session's progress rail.
///
/// The rail is a second view of the same walk the `05 / 07` counter shows, so it
/// is derived from the same **monotonic milestone** rather than from
/// `CookingPhase`.
///
/// It used to be mapped per phase, and that is what made it step **backwards**:
/// `.baste` held a fixed `0.62` while `.sear` was a fraction of the cooking
/// budget, and the no-thermometer fallback legitimately re-enters the searing
/// loop after BASTE. At the end of the baste the elapsed-time fraction is only
/// `0.12 + 0.48 × (159.25 + 31.36) / 245 = 0.493`, so the rail fell from `0.62`
/// back to `0.49` in the default configuration (ribeye, 3cm, medium rare).
/// A low probe reading did the same thing before the probe entry point was
/// hidden, and the old budget made it happen too.
///
/// The rail is therefore the **maximum of two non-decreasing terms**:
///
///   * `floor` — how far along the route the milestone is. `CookingJourney`'s
///     high-water mark only ever advances, so this term only ever advances.
///   * `timed` — elapsed ÷ estimated cooking budget, which only ever advances
///     within a session.
///
/// The maximum of two non-decreasing functions cannot decrease, so the rail is
/// monotonic by construction rather than by remembering a maximum in the view.
///
/// The result is then clamped to the current step's own segment. That segment
/// end only ever moves forward too (it is the next step's floor), so the clamp
/// cannot reintroduce a backward step — and it keeps the rail from ever running
/// ahead of the `05 / 07` counter, which the raw time fraction could do when the
/// user confirms actions slowly.
enum SessionProgressRail {
    /// Before the pan is on the heat.
    static let setupProgress = 0.0
    static let prepProgress = 0.04
    static let heatProgress = 0.08

    /// The band the in-pan route occupies. `cookCeiling` is the floor of the
    /// route's last step, so resting (below) is always further along.
    static let cookFloor = 0.12
    static let cookCeiling = 0.86

    /// How much of the rail the cooking budget fills. Chosen so the searing loop
    /// keeps the creep it had before this was made monotonic.
    static let cookTimeSpan = 0.48

    /// Resting and serving are not cook steps, so they sit past the route.
    static let finishingProgress = 0.92
    static let doneProgress = 1.0

    static func progress(
        phase: CookingPhase,
        milestone: CookingJourneyStep?,
        journey: CookingJourney,
        estimatedProgress: Double
    ) -> Double {
        switch phase {
        case .setup:
            return setupProgress
        case .prep:
            return prepProgress
        case .heat:
            return heatProgress
        case .sear, .fatCap, .baste, .checkTemperature:
            let step = journey.clamped(milestone ?? .sear)
            let position = journey.position(of: step) ?? 1
            let steps = max(1, journey.totalSteps)
            let span = cookCeiling - cookFloor
            let floor = cookFloor + span * Double(position - 1) / Double(steps)
            let ceiling = cookFloor + span * Double(position) / Double(steps)
            let timed = cookFloor
                + cookTimeSpan * min(max(estimatedProgress, 0), 1)
            return min(max(floor, timed), ceiling)
        case .finishing:
            return finishingProgress
        case .ready, .eat, .feedback:
            return doneProgress
        }
    }
}
