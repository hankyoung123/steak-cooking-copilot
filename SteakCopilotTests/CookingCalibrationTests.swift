import XCTest
@testable import SteakCopilot

final class CookingCalibrationTests: XCTestCase {
    func testRareFeedbackAddsCookingBudget() {
        let updated = CookingCalibration.neutral.applying(
            doneness: .tooRare,
            crust: .perfect
        )

        XCTAssertGreaterThan(updated.cookingTimeAdjustment, 0)
    }

    func testOverdoneFeedbackRemovesCookingBudget() {
        let updated = CookingCalibration.neutral.applying(
            doneness: .tooDone,
            crust: .perfect
        )

        XCTAssertLessThan(updated.cookingTimeAdjustment, 0)
    }

    func testLightCrustChangesSearBiasWithoutChangingCookingBudget() {
        let updated = CookingCalibration.neutral.applying(
            doneness: .perfect,
            crust: .tooLight
        )

        XCTAssertGreaterThan(updated.searBias, 0)
        XCTAssertEqual(updated.cookingTimeAdjustment, 0)
    }

    func testDifferentProfilesDoNotShareCalibration() {
        let suite = "CookingCalibrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let strip = CalibrationKey(
            cut: .strip,
            thicknessBucket: .standard,
            doneness: .mediumRare
        )
        let tenderloin = CalibrationKey(
            cut: .tenderloin,
            thicknessBucket: .standard,
            doneness: .mediumRare
        )
        let thickStrip = CalibrationKey(
            cut: .strip,
            thicknessBucket: .thick,
            doneness: .mediumRare
        )
        let mediumStrip = CalibrationKey(
            cut: .strip,
            thicknessBucket: .standard,
            doneness: .medium
        )
        let learned = CookingCalibration(
            cookingTimeAdjustment: 24,
            searBias: 8
        )

        store.save(calibration: learned, for: strip)

        XCTAssertEqual(store.loadCalibration(for: strip), learned)
        XCTAssertEqual(store.loadCalibration(for: tenderloin), .neutral)
        XCTAssertEqual(store.loadCalibration(for: thickStrip), .neutral)
        XCTAssertEqual(store.loadCalibration(for: mediumStrip), .neutral)
    }

    func testCrustFeedbackChangesSearBiasByObservableSteps() {
        var calibration = CookingCalibration.neutral

        for _ in 0..<3 {
            calibration = calibration.applying(doneness: .perfect, crust: .tooLight)
        }
        XCTAssertEqual(calibration.searBias, 24)
        XCTAssertEqual(calibration.cookingTimeAdjustment, 0)

        for _ in 0..<6 {
            calibration = calibration.applying(doneness: .perfect, crust: .tooDark)
        }
        XCTAssertEqual(calibration.searBias, -24)
    }

    func testSearBiasMovesLateStageDateOffset() {
        let engine = CookingEngine()
        let configuration = SteakConfiguration(
            cut: .strip,
            thicknessCM: 3,
            doneness: .mediumRare
        )
        let neutral = engine.profile(for: configuration, calibration: .neutral)
        let light = engine.profile(
            for: configuration,
            calibration: CookingCalibration(cookingTimeAdjustment: 0, searBias: 8)
        )
        let dark = engine.profile(
            for: configuration,
            calibration: CookingCalibration(cookingTimeAdjustment: 0, searBias: -8)
        )

        XCTAssertGreaterThan(light.lateStageDateOffset, neutral.lateStageDateOffset)
        XCTAssertLessThan(dark.lateStageDateOffset, neutral.lateStageDateOffset)
    }
}
