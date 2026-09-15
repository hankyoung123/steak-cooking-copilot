import Foundation

/// Whether the app offers a probe-reading entry point.
///
/// This is a product switch, not a cooking parameter, so it lives in code
/// rather than in `Config/production.yaml`.
///
/// Turning it off **hides the entry point only**. The engine keeps the whole
/// reading capability — a reading still overrides the time estimate, the
/// priority rules are untouched, and `recordManualTemperature` still works —
/// and so do its tests. What changes is that no screen asks for a reading, so
/// the cook runs on the timing estimate and the in-pan journey has no CHECK TEMP
/// step. Flipping this back to `true` restores the step in the journey; the
/// reading control itself is in git history.
enum ProbeReading {
    static let isOffered = false
}

/// One milestone in the in-pan cooking journey.
///
/// This is the only thing the flow counter in the top-right corner counts. It is
/// deliberately **not** `CookingPhase`: the phase machine is the engine's
/// business (searing is one cyclic `.sear` phase that can be re-entered from the
/// baste or check-temperature stages), while the journey is a linear route a
/// person walks once.
///
/// The declaration order *is* the route order; `rank` is the source of the
/// comparisons that keep the counter monotonic.
enum CookingJourneyStep: String, Codable, CaseIterable, Comparable, Sendable {
    case sear
    case flip
    case fatCap
    case addButter
    case baste
    case checkTemperature
    case takeOut

    /// Canonical order, independent of `allCases` so a future case cannot
    /// silently reorder the route.
    static let route: [CookingJourneyStep] = [
        .sear, .flip, .fatCap, .addButter, .baste, .checkTemperature, .takeOut
    ]

    /// Position in the full route, used for comparisons only. Steps missing from
    /// a particular cut's route keep their rank here and are filtered by
    /// `CookingJourney` instead.
    var rank: Int {
        Self.route.firstIndex(of: self) ?? 0
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// What the session has actually done, as inputs to the journey.
///
/// Every date here is a recorded fact. `pendingAction` is the one live input: it
/// exists because "the app is asking for butter" has no recorded fact of its own
/// (`butterAddedAt` is only set once the user confirms). It is used as evidence
/// for which milestone has been reached, never as the milestone itself — the
/// displayed number comes from the monotonic high-water mark, so a change of
/// action can never walk the counter backwards.
struct CookingJourneyFacts: Equatable, Sendable {
    var needsFatCap: Bool
    var flipCount: Int
    var phase: CookingPhase
    var butterAddedAt: Date?
    var lastManualTemperatureAt: Date?
    var pulledAt: Date?
    var pendingAction: CookingAction

    init(
        needsFatCap: Bool,
        flipCount: Int,
        phase: CookingPhase,
        butterAddedAt: Date? = nil,
        lastManualTemperatureAt: Date? = nil,
        pulledAt: Date? = nil,
        pendingAction: CookingAction
    ) {
        self.needsFatCap = needsFatCap
        self.flipCount = flipCount
        self.phase = phase
        self.butterAddedAt = butterAddedAt
        self.lastManualTemperatureAt = lastManualTemperatureAt
        self.pulledAt = pulledAt
        self.pendingAction = pendingAction
    }

    init(
        session: CookingSession,
        needsFatCap: Bool,
        pendingAction: CookingAction
    ) {
        self.init(
            needsFatCap: needsFatCap,
            flipCount: session.flipCount,
            phase: session.phase,
            butterAddedAt: session.butterAddedAt,
            lastManualTemperatureAt: session.lastManualTemperatureAt,
            pulledAt: session.pulledAt,
            pendingAction: pendingAction
        )
    }
}

/// The counter the setup/session chrome displays: `currentStep / totalSteps`.
///
/// A plain value so the view never has to know what a journey is.
struct CookingProgress: Equatable, Sendable {
    let currentStep: Int
    let totalSteps: Int

    /// `01 / 07`, `00 / 06`, …
    var label: String {
        String(format: "%02d / %02d", currentStep, totalSteps)
    }
}

/// The route a particular steak actually walks, derived from its configuration.
///
/// Fat cap is optional, so the total is 7 for a cut that needs one and 6 for a
/// cut that does not. The route is contiguous in both cases: there is no empty
/// slot where the fat cap would have been, so a strip reads 01…07 and a ribeye
/// reads 01…06 with no gap.
struct CookingJourney: Equatable, Sendable {
    let steps: [CookingJourneyStep]

    init(needsFatCap: Bool, includesTemperatureCheck: Bool = ProbeReading.isOffered) {
        var steps: [CookingJourneyStep] = [.sear, .flip]
        if needsFatCap {
            steps.append(.fatCap)
        }
        steps.append(contentsOf: [.addButter, .baste])
        if includesTemperatureCheck {
            steps.append(.checkTemperature)
        }
        steps.append(.takeOut)
        self.steps = steps
    }

    init(
        configuration: SteakConfiguration,
        tuning: AppTuning = .production,
        includesTemperatureCheck: Bool = ProbeReading.isOffered
    ) {
        self.init(
            needsFatCap: configuration.cut.spec(in: tuning).needsFatCap,
            includesTemperatureCheck: includesTemperatureCheck
        )
    }

    var totalSteps: Int { steps.count }

    /// The last step of the in-pan journey. Nothing may be counted after it.
    var finalStep: CookingJourneyStep { steps[steps.count - 1] }

    func contains(_ step: CookingJourneyStep) -> Bool {
        steps.contains(step)
    }

    /// 1-based position on this route, or `nil` when the step is not on it.
    func position(of step: CookingJourneyStep) -> Int? {
        steps.firstIndex(of: step).map { $0 + 1 }
    }

    /// The furthest step on this route that is not past `step`. Used when a
    /// milestone was recorded for a route that no longer applies (a cut without
    /// a fat cap, say), so the counter can still be resolved instead of
    /// producing a gap.
    func clamped(_ step: CookingJourneyStep) -> CookingJourneyStep {
        steps.last { $0 <= step } ?? steps[0]
    }

    /// The milestone the recorded facts point at, with no memory.
    ///
    /// Every satisfied predicate is considered and the furthest wins, so the
    /// result does not depend on the order the evidence is written in, and a
    /// session that has both added butter and stood the fat cap resolves to the
    /// later of the two.
    func candidate(for facts: CookingJourneyFacts) -> CookingJourneyStep {
        var reached: [CookingJourneyStep] = [.sear]

        // Sticky facts: each of these is written once and never cleared, which is
        // what lets a route that re-enters the sear loop still resolve forward.
        if facts.pulledAt != nil {
            reached.append(.takeOut)
        }
        if facts.phase == .checkTemperature || facts.lastManualTemperatureAt != nil {
            reached.append(.checkTemperature)
        }
        if facts.butterAddedAt != nil {
            reached.append(.baste)
        }

        // Prompts with no recorded fact of their own. Each of these is the moment
        // the app asks for the action, which is the moment the user is on that
        // step; every one of them is followed by a sticky fact for the same
        // milestone or a later one (butter added, steak out), so reaching a step
        // here cannot leave the counter stranded.
        if facts.pendingAction == .addButter {
            reached.append(.addButter)
        }
        if facts.pendingAction == .checkTemperature {
            // Being asked to probe the steak *is* the check-temperature step: the
            // baste timer has already run out by the time the prompt appears.
            reached.append(.checkTemperature)
        }
        if facts.pendingAction == .takeOut {
            reached.append(.takeOut)
        }
        if facts.needsFatCap,
           facts.phase == .fatCap || facts.pendingAction == .standFatCap {
            reached.append(.fatCap)
        }

        // Repeated flipping is one milestone: the count is only tested for
        // "has flipped at all", so frequent flips cannot advance the route.
        if facts.flipCount >= 1 {
            reached.append(.flip)
        }

        let furthest = reached.max() ?? .sear
        return clamped(furthest)
    }

    /// Advances a stored milestone by one observation. Monotonic by
    /// construction: the result is never behind `previous`.
    func advanced(
        from previous: CookingJourneyStep?,
        with candidate: CookingJourneyStep
    ) -> CookingJourneyStep {
        let next = clamped(candidate)
        guard let previous else { return next }
        let current = clamped(previous)
        return max(current, next)
    }

    /// The counter for a phase, or `nil` when there is nothing to count.
    ///
    /// Resting and serving are not cook steps, so they get no counter at all
    /// rather than being numbered on the end of the route. Before the pan is on
    /// the heat the journey has not started, so it shows `00 / total`.
    func progress(
        for phase: CookingPhase,
        milestone: CookingJourneyStep?
    ) -> CookingProgress? {
        switch phase {
        case .setup, .prep, .heat:
            return CookingProgress(currentStep: 0, totalSteps: totalSteps)
        case .sear, .fatCap, .baste, .checkTemperature:
            let step = clamped(milestone ?? .sear)
            return CookingProgress(
                currentStep: position(of: step) ?? 1,
                totalSteps: totalSteps
            )
        case .finishing, .ready, .eat, .feedback:
            // TAKE OUT completed: the in-pan journey is over. FINISHING is a
            // rest, not the next cook step, so it must not be numbered.
            return nil
        }
    }
}
