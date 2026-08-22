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

    init(configuration: SteakConfiguration) {
        self.init(
            cut: configuration.cut,
            thicknessBucket: configuration.thicknessBucket,
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

    func applying(
        doneness: DonenessFeedback,
        crust: CrustFeedback
    ) -> CookingCalibration {
        let cookingDelta = TimeInterval(-doneness.rawValue * 12)
        let searDelta = TimeInterval(-crust.rawValue * 8)
        return CookingCalibration(
            cookingTimeAdjustment: (
                cookingTimeAdjustment + cookingDelta
            ).clamped(to: -60...60),
            searBias: (searBias + searDelta).clamped(to: -24...24)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
