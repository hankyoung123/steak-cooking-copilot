import Foundation

/// Strongly typed production tuning.
///
/// `Config/production.yaml` is the single source of truth: the build-time
/// generator (`Scripts/generate_tuning.py`) validates it and emits
/// `ProductionTuning.production`, which is the only place these defaults are
/// written down in Swift. Business code reads `AppTuning` and never touches
/// dictionaries or string keys.
///
/// Runtime override chain:
///
///     ProductionTuning.production   (generated from production.yaml)
///                 ↓
///     TuningStore.override          (local JSON, development only)
///                 ↓
///     TuningStore.effective         (what the app actually runs on)
///
/// What is deliberately NOT configurable: manual-temperature priority, the
/// no-thermometer rule that no temperature may be invented, sear-boundary
/// priority, nextAction/nextActionAt agreement, session identity, legal phase
/// transitions, animation never driving business state, Reduce Motion and
/// accessibility identifiers. Those are correctness rules, not parameters.
struct AppTuning: Codable, Equatable, Sendable {
    var cooking: CookingTuning
    var cuts: CutTuning
    var doneness: DonenessTuning
    var calibration: CalibrationTuning
    var finishing: FinishingTuning
    var notifications: NotificationTuning
    var motion: MotionTuning

    /// Production defaults, generated from Config/production.yaml.
    static var production: AppTuning { ProductionTuning.production }
}

// MARK: - Cooking

struct CookingTuning: Codable, Equatable, Sendable {
    var baseCookingBudget: TimeInterval
    var referenceThickness: Double
    var minThicknessFactor: Double
    var minCookingBudget: TimeInterval
    var maxCookingBudget: TimeInterval
    var flipIntervalThin: TimeInterval
    var flipIntervalStandard: TimeInterval
    var flipIntervalThick: TimeInterval
    var flipIntervalStandardMaxThickness: Double
    var minFlipInterval: TimeInterval
    var minBudgetInFlipIntervals: Double
    var thinMaxThickness: Double
    var standardMaxThickness: Double
    var lateStageRatio: Double
    var lateStageMinFlipIntervals: Double
    var basteRatio: Double
    var minBasteDuration: TimeInterval
    var maxBasteDuration: TimeInterval
    var budgetFinishAdjustmentRatio: Double
    var budgetFinishAdjustmentMinSeconds: TimeInterval
    var budgetFinishAdjustmentMaxSeconds: TimeInterval
    var minFatCapDuration: TimeInterval

    /// Frequent-flip cadence for a thickness, before time scaling.
    func flipInterval(thicknessCM: Double) -> TimeInterval {
        if thicknessCM < thinMaxThickness { return flipIntervalThin }
        if thicknessCM <= flipIntervalStandardMaxThickness { return flipIntervalStandard }
        return flipIntervalThick
    }

    /// Thickness bucket boundaries, in centimetres.
    func thicknessBucket(thicknessCM: Double) -> ThicknessBucket {
        if thicknessCM < thinMaxThickness { return .thin }
        if thicknessCM <= standardMaxThickness { return .standard }
        return .thick
    }
}

// MARK: - Cuts

struct CutSpecTuning: Codable, Equatable, Sendable {
    var cookingBudgetOffset: TimeInterval
    var needsFatCap: Bool
    var fatCapDuration: TimeInterval?
    var recommendedThickness: Double

    var profile: SteakCutProfile {
        SteakCutProfile(
            needsFatCap: needsFatCap,
            fatCapDuration: fatCapDuration
        )
    }
}

struct CutTuning: Codable, Equatable, Sendable {
    var ribeye: CutSpecTuning
    var strip: CutSpecTuning
    var tenderloin: CutSpecTuning

    subscript(cut: SteakCut) -> CutSpecTuning {
        switch cut {
        case .ribeye: ribeye
        case .strip: strip
        case .tenderloin: tenderloin
        }
    }
}

// MARK: - Doneness

struct DonenessSpecTuning: Codable, Equatable, Sendable {
    var targetTemperatureC: Double
    var pullTemperatureC: Double
    var cookingBudgetFactor: Double
}

struct DonenessTuning: Codable, Equatable, Sendable {
    var rare: DonenessSpecTuning
    var mediumRare: DonenessSpecTuning
    var medium: DonenessSpecTuning
    var mediumWell: DonenessSpecTuning
    var wellDone: DonenessSpecTuning

    subscript(doneness: Doneness) -> DonenessSpecTuning {
        switch doneness {
        case .rare: rare
        case .mediumRare: mediumRare
        case .medium: medium
        case .mediumWell: mediumWell
        case .wellDone: wellDone
        }
    }
}

// MARK: - Calibration

struct CalibrationTuning: Codable, Equatable, Sendable {
    var donenessStepSeconds: TimeInterval
    var crustStepSeconds: TimeInterval
    var maxCookingAdjustment: TimeInterval
    var maxSearAdjustment: TimeInterval
}

// MARK: - Finishing

struct DonenessAdjustmentTuning: Codable, Equatable, Sendable {
    var rare: TimeInterval
    var mediumRare: TimeInterval
    var medium: TimeInterval
    var mediumWell: TimeInterval
    var wellDone: TimeInterval

    subscript(doneness: Doneness) -> TimeInterval {
        switch doneness {
        case .rare: rare
        case .mediumRare: mediumRare
        case .medium: medium
        case .mediumWell: mediumWell
        case .wellDone: wellDone
        }
    }
}

struct FinishingTuning: Codable, Equatable, Sendable {
    var baseAdjustmentSeconds: TimeInterval
    var thicknessAdjustmentPerCM: TimeInterval
    var donenessAdjustment: DonenessAdjustmentTuning
    var spreadSeconds: TimeInterval
    var minLowerBoundSeconds: TimeInterval
    var minUpperBoundSeconds: TimeInterval
    var carryoverMinC: Double
    var carryoverMaxC: Double
    var remainingRiseSecondsPerDegree: TimeInterval
    var maxManualAdjustmentSeconds: TimeInterval
    var idleEstimateMinSeconds: TimeInterval
    var idleEstimateMaxSeconds: TimeInterval

    /// Carryover range shown while finishing, in degrees Celsius.
    var carryoverRange: ClosedRange<Double> { carryoverMinC...carryoverMaxC }

    /// Idle estimate used before a session starts.
    var idleEstimate: ClosedRange<TimeInterval> {
        idleEstimateMinSeconds...idleEstimateMaxSeconds
    }
}

// MARK: - Notifications

struct NotificationTuning: Codable, Equatable, Sendable {
    var approachingThresholdSeconds: TimeInterval
    var urgentThresholdSeconds: TimeInterval
    var hapticLightSeconds: TimeInterval
    var hapticHeavySeconds: TimeInterval
    var staleDelaySeconds: TimeInterval
    var finishedDismissalSeconds: TimeInterval
    var cancelledDismissalSeconds: TimeInterval
}

// MARK: - Motion

struct MotionTuning: Codable, Equatable, Sendable {
    var subtle: TimeInterval
    var responsive: TimeInterval
    var emphasis: TimeInterval
    var action: TimeInterval
    var cinematic: TimeInterval
    var stageTransition: TimeInterval
    var flipLift: TimeInterval
    var flipRotate: TimeInterval
    var flipLand: TimeInterval
    var flipSettle: TimeInterval
    var compactFlipOut: TimeInterval
    var compactFlipLand: TimeInterval
    var takeOutLift: TimeInterval
    var takeOutHold: TimeInterval
    var takeOutSettle: TimeInterval
    var readyRevealDelay: TimeInterval
    var emphasisBounce: Double
    var actionBounce: Double
    var stageSceneCrossfade: TimeInterval
    var sessionPhaseChange: TimeInterval
    var progressRailSpring: TimeInterval
    var progressRailBounce: Double
    var resultAppear: TimeInterval
}
