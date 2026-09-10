import Foundation

struct CalibrationKey: Codable, Hashable, Sendable {
    let cut: SteakCut
    let thicknessBucket: ThicknessBucket
    let doneness: Doneness

    init(
        cut: SteakCut,
        thicknessBucket: ThicknessBucket,
        doneness: Doneness
    ) {
        self.cut = cut
        self.thicknessBucket = thicknessBucket
        self.doneness = doneness
    }

    init(configuration: SteakConfiguration, tuning: AppTuning = .production) {
        self.init(
            cut: configuration.cut,
            thicknessBucket: configuration.thicknessBucket(in: tuning),
            doneness: configuration.doneness
        )
    }
}

struct CookingCalibration: Codable, Equatable, Sendable {
    var cookingTimeAdjustment: TimeInterval
    var searBias: TimeInterval

    static let neutral = CookingCalibration(
        cookingTimeAdjustment: 0,
        searBias: 0
    )

    /// Learns from feedback. Step sizes and clamps are tunable; the rule that
    /// doneness feedback moves the budget and crust feedback moves the sear
    /// bias is a product invariant and stays here.
    func applying(
        doneness: DonenessFeedback,
        crust: CrustFeedback,
        tuning: AppTuning = .production
    ) -> CookingCalibration {
        let calibration = tuning.calibration
        let cookingDelta = TimeInterval(
            -Double(doneness.rawValue) * calibration.donenessStepSeconds
        )
        let searDelta = TimeInterval(
            -Double(crust.rawValue) * calibration.crustStepSeconds
        )
        return CookingCalibration(
            cookingTimeAdjustment: (
                cookingTimeAdjustment + cookingDelta
            ).clamped(
                to: -calibration.maxCookingAdjustment...calibration.maxCookingAdjustment
            ),
            searBias: (searBias + searDelta).clamped(
                to: -calibration.maxSearAdjustment...calibration.maxSearAdjustment
            )
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
