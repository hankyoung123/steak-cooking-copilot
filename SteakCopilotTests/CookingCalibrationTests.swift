import XCTest
@testable import SteakCopilot

final class CookingCalibrationTests: XCTestCase {
    func testRareFeedbackAddsCookingTime() {
        let updated = CookingCalibration.neutral.applying(
            doneness: .tooRare,
            crust: .perfect
        )

        XCTAssertGreaterThan(updated.durationAdjustment, 0)
    }

    func testOverdoneFeedbackRemovesCookingTime() {
        let updated = CookingCalibration.neutral.applying(
            doneness: .tooDone,
            crust: .perfect
        )

        XCTAssertLessThan(updated.durationAdjustment, 0)
    }

    func testLightCrustIncreasesInitialSearWithoutChangingTotalDonenessAdjustment() {
        let updated = CookingCalibration.neutral.applying(
            doneness: .perfect,
            crust: .tooLight
        )

        XCTAssertGreaterThan(updated.searAdjustment, 0)
        XCTAssertEqual(updated.durationAdjustment, 0)
    }
}
