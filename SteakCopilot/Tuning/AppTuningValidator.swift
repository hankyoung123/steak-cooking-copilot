import Foundation

/// Semantic validation for tuning values, mirroring the checks in
/// `Scripts/generate_tuning.py`.
///
/// The generator validates `production.yaml`; this validates an override that
/// arrived at runtime (imported JSON or an in-app edit). Both must enforce the
/// same rules so a value that could never ship through the YAML cannot sneak in
/// through an override. `TuningConfigurationTests` asserts that every
/// production value passes this validator, which catches the two drifting apart.
///
/// Only *parameters* are validated here. Correctness rules (manual-temperature
/// priority, the no-thermometer rule, sear-boundary priority, phase transitions,
/// Reduce Motion, accessibility identifiers) are not configurable and therefore
/// have nothing to validate.
enum AppTuningValidator {
    struct Failure: Error, LocalizedError, Equatable {
        let issues: [String]

        var errorDescription: String? {
            issues.isEmpty ? nil : issues.joined(separator: "\n")
        }
    }

    /// Every problem found, in a stable order. Empty means valid.
    static func issues(in tuning: AppTuning) -> [String] {
        var issues: [String] = []

        func require(
            _ condition: Bool,
            _ message: String
        ) {
            if !condition { issues.append(message) }
        }

        // MARK: Cooking

        let cooking = tuning.cooking
        require(cooking.baseCookingBudget > 0, "cooking.baseCookingBudget must be > 0")
        require(cooking.referenceThickness > 0, "cooking.referenceThickness must be > 0")
        require(
            cooking.minThicknessFactor > 0 && cooking.minThicknessFactor <= 1,
            "cooking.minThicknessFactor must be in (0, 1]"
        )
        require(
            cooking.minCookingBudget > 0,
            "cooking.minCookingBudget must be > 0"
        )
        require(
            cooking.minCookingBudget < cooking.maxCookingBudget,
            "cooking.minCookingBudget must be below cooking.maxCookingBudget"
        )
        require(
            cooking.flipIntervalThin > 0
                && cooking.flipIntervalStandard > 0
                && cooking.flipIntervalThick > 0,
            "cooking flip intervals must be > 0"
        )
        require(
            cooking.flipIntervalThin <= cooking.flipIntervalStandard
                && cooking.flipIntervalStandard <= cooking.flipIntervalThick,
            "cooking flip intervals must be non-decreasing from thin to thick"
        )
        require(
            cooking.flipIntervalStandardMaxThickness > 0,
            "cooking.flipIntervalStandardMaxThickness must be > 0"
        )
        require(
            cooking.minFlipInterval > 0,
            "cooking.minFlipInterval must be > 0"
        )
        require(
            cooking.minBudgetInFlipIntervals >= 1,
            "cooking.minBudgetInFlipIntervals must be >= 1"
        )
        require(
            cooking.lateStageMinFlipIntervals >= 1,
            "cooking.lateStageMinFlipIntervals must be >= 1"
        )
        require(
            cooking.thinMaxThickness > 0,
            "cooking.thinMaxThickness must be > 0"
        )
        require(
            cooking.thinMaxThickness < cooking.standardMaxThickness,
            "cooking.thinMaxThickness must be below cooking.standardMaxThickness"
        )
        require(
            cooking.thinMaxThickness < cooking.flipIntervalStandardMaxThickness,
            "cooking.thinMaxThickness must be below "
                + "cooking.flipIntervalStandardMaxThickness"
        )
        require(
            cooking.lateStageRatio > 0 && cooking.lateStageRatio < 1,
            "cooking.lateStageRatio must be in (0, 1)"
        )
        require(
            cooking.basteRatio > 0 && cooking.basteRatio <= 1,
            "cooking.basteRatio must be in (0, 1]"
        )
        require(
            cooking.minBasteDuration > 0,
            "cooking.minBasteDuration must be > 0"
        )
        require(
            cooking.minBasteDuration < cooking.maxBasteDuration,
            "cooking.minBasteDuration must be below cooking.maxBasteDuration"
        )
        require(
            cooking.budgetFinishAdjustmentRatio >= 0
                && cooking.budgetFinishAdjustmentRatio <= 1,
            "cooking.budgetFinishAdjustmentRatio must be in [0, 1]"
        )
        require(
            cooking.budgetFinishAdjustmentMinSeconds
                < cooking.budgetFinishAdjustmentMaxSeconds,
            "cooking.budgetFinishAdjustmentMinSeconds must be below "
                + "cooking.budgetFinishAdjustmentMaxSeconds"
        )
        require(
            cooking.minFatCapDuration > 0,
            "cooking.minFatCapDuration must be > 0"
        )

        // MARK: Cuts

        for cut in SteakCut.allCases {
            let spec = tuning.cuts[cut]
            let path = "cuts.\(cut.rawValue)"
            require(
                spec.recommendedThickness >= 0.5 && spec.recommendedThickness <= 10,
                "\(path).recommendedThickness must be in [0.5, 10]"
            )
            switch (spec.needsFatCap, spec.fatCapDuration) {
            case (true, nil):
                issues.append("\(path).fatCapDuration is required when needsFatCap is true")
            case (false, .some):
                issues.append("\(path).fatCapDuration must be nil when needsFatCap is false")
            case let (true, .some(duration)):
                require(
                    duration > 0,
                    "\(path).fatCapDuration must be > 0"
                )
            case (false, nil):
                break
            }
        }

        // MARK: Doneness

        var previousTarget: Double?
        for doneness in Doneness.allCases {
            let spec = tuning.doneness[doneness]
            let path = "doneness.\(doneness.rawValue)"
            require(
                spec.targetTemperatureC >= 30 && spec.targetTemperatureC <= 100,
                "\(path).targetTemperatureC must be in [30, 100]"
            )
            require(
                spec.pullTemperatureC >= 20 && spec.pullTemperatureC <= 100,
                "\(path).pullTemperatureC must be in [20, 100]"
            )
            require(
                spec.pullTemperatureC < spec.targetTemperatureC,
                "\(path).pullTemperatureC must be below targetTemperatureC"
            )
            require(
                spec.cookingBudgetFactor > 0 && spec.cookingBudgetFactor <= 3,
                "\(path).cookingBudgetFactor must be in (0, 3]"
            )
            if let previousTarget, spec.targetTemperatureC <= previousTarget {
                issues.append(
                    "\(path).targetTemperatureC must increase with doneness"
                )
            }
            previousTarget = spec.targetTemperatureC
        }

        // MARK: Calibration

        let calibration = tuning.calibration
        require(
            calibration.donenessStepSeconds > 0,
            "calibration.donenessStepSeconds must be > 0"
        )
        require(
            calibration.crustStepSeconds > 0,
            "calibration.crustStepSeconds must be > 0"
        )
        require(
            calibration.maxCookingAdjustment > 0,
            "calibration.maxCookingAdjustment must be > 0"
        )
        require(
            calibration.maxSearAdjustment > 0,
            "calibration.maxSearAdjustment must be > 0"
        )

        // MARK: Finishing

        let finishing = tuning.finishing
        require(
            finishing.minLowerBoundSeconds > 0,
            "finishing.minLowerBoundSeconds must be > 0"
        )
        require(
            finishing.minLowerBoundSeconds < finishing.minUpperBoundSeconds,
            "finishing.minLowerBoundSeconds must be below minUpperBoundSeconds"
        )
        require(
            finishing.spreadSeconds > 0,
            "finishing.spreadSeconds must be > 0"
        )
        require(
            finishing.carryoverMinC <= finishing.carryoverMaxC,
            "finishing.carryoverMinC must be <= finishing.carryoverMaxC"
        )
        require(
            finishing.idleEstimateMinSeconds < finishing.idleEstimateMaxSeconds,
            "finishing.idleEstimateMinSeconds must be below idleEstimateMaxSeconds"
        )
        require(
            finishing.idleEstimateMinSeconds > 0,
            "finishing.idleEstimateMinSeconds must be > 0"
        )
        require(
            finishing.remainingRiseSecondsPerDegree >= 0,
            "finishing.remainingRiseSecondsPerDegree must be >= 0"
        )
        require(
            finishing.maxManualAdjustmentSeconds >= 0,
            "finishing.maxManualAdjustmentSeconds must be >= 0"
        )
        require(
            finishing.thicknessAdjustmentPerCM >= 0,
            "finishing.thicknessAdjustmentPerCM must be >= 0"
        )
        require(
            finishing.baseAdjustmentSeconds >= 0,
            "finishing.baseAdjustmentSeconds must be >= 0"
        )
        for doneness in Doneness.allCases {
            let adjustment = finishing.donenessAdjustment[doneness]
            require(
                adjustment >= 0,
                "finishing.donenessAdjustment.\(doneness.rawValue) must be >= 0"
            )
        }

        // MARK: Notifications

        let notifications = tuning.notifications
        require(
            notifications.approachingThresholdSeconds > 0
                && notifications.approachingThresholdSeconds <= 60,
            "notifications.approachingThresholdSeconds must be in (0, 60]"
        )
        require(
            notifications.urgentThresholdSeconds > 0
                && notifications.urgentThresholdSeconds <= 60,
            "notifications.urgentThresholdSeconds must be in (0, 60]"
        )
        require(
            notifications.hapticHeavySeconds < notifications.hapticLightSeconds,
            "notifications.hapticHeavySeconds must be below hapticLightSeconds"
        )
        require(
            notifications.hapticHeavySeconds >= 0,
            "notifications.hapticHeavySeconds must be >= 0"
        )
        require(
            notifications.staleDelaySeconds > 0,
            "notifications.staleDelaySeconds must be > 0"
        )
        require(
            notifications.finishedDismissalSeconds > 0,
            "notifications.finishedDismissalSeconds must be > 0"
        )
        require(
            notifications.cancelledDismissalSeconds > 0,
            "notifications.cancelledDismissalSeconds must be > 0"
        )

        // MARK: Motion

        for (name, value) in motionDurations(in: tuning.motion) {
            require(value >= 0, "motion.\(name) must be >= 0")
        }
        for (name, value) in motionBounces(in: tuning.motion) {
            require(
                value >= 0 && value <= 1,
                "motion.\(name) must be in [0, 1]"
            )
        }

        return issues
    }

    /// Throws the full list of problems when the tuning is not usable.
    static func validate(_ tuning: AppTuning) throws {
        let issues = issues(in: tuning)
        guard issues.isEmpty else {
            throw Failure(issues: issues)
        }
    }

    /// Duration-valued motion parameters, by name.
    static func motionDurations(in motion: MotionTuning) -> [(String, Double)] {
        [
            ("subtle", motion.subtle),
            ("responsive", motion.responsive),
            ("emphasis", motion.emphasis),
            ("action", motion.action),
            ("cinematic", motion.cinematic),
            ("stageTransition", motion.stageTransition),
            ("flipLift", motion.flipLift),
            ("flipRotate", motion.flipRotate),
            ("flipLand", motion.flipLand),
            ("flipSettle", motion.flipSettle),
            ("compactFlipOut", motion.compactFlipOut),
            ("compactFlipLand", motion.compactFlipLand),
            ("takeOutLift", motion.takeOutLift),
            ("takeOutHold", motion.takeOutHold),
            ("takeOutSettle", motion.takeOutSettle),
            ("readyRevealDelay", motion.readyRevealDelay),
            ("stageSceneCrossfade", motion.stageSceneCrossfade),
            ("sessionPhaseChange", motion.sessionPhaseChange),
            ("progressRailSpring", motion.progressRailSpring),
            ("resultAppear", motion.resultAppear),
        ]
    }

    /// Bounce-valued motion parameters, by name.
    static func motionBounces(in motion: MotionTuning) -> [(String, Double)] {
        [
            ("emphasisBounce", motion.emphasisBounce),
            ("actionBounce", motion.actionBounce),
            ("progressRailBounce", motion.progressRailBounce),
        ]
    }
}
