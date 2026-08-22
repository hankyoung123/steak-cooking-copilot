import Foundation

struct CookingCalibration: Codable, Equatable, Sendable {
    var durationAdjustment: TimeInterval
    var searAdjustment: TimeInterval

    static let neutral = CookingCalibration(
        durationAdjustment: 0,
        searAdjustment: 0
    )

    func applying(
        doneness: DonenessFeedback,
        crust: CrustFeedback
    ) -> CookingCalibration {
        let durationDelta = TimeInterval(-doneness.rawValue * 12)
        let searDelta = TimeInterval(-crust.rawValue * 8)
        return CookingCalibration(
            durationAdjustment: (durationAdjustment + durationDelta).clamped(to: -60...60),
            searAdjustment: (searAdjustment + searDelta).clamped(to: -24...24)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
