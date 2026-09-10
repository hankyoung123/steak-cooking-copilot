import XCTest
@testable import SteakCopilot

final class CookingPersistenceTests: XCTestCase {
    private func referenceDate(_ date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
    }

    func testLegacySessionJSONWithTemperatureCheckConfirmedAtStillDecodes() throws {
        let start = Date(timeIntervalSince1970: 10_000)
        let legacy: [String: Any] = [
            "id": UUID().uuidString,
            "configuration": [
                "cut": "ribeye",
                "thicknessCM": 3.0,
                "doneness": "mediumRare"
            ],
            "phase": "sear",
            "startedAt": referenceDate(start),
            "phaseStartedAt": referenceDate(start),
            "nextActionAt": referenceDate(start.addingTimeInterval(30)),
            "flipCount": 2,
            "lastManualTemperatureC": NSNull(),
            "lastManualTemperatureAt": NSNull(),
            "butterAddedAt": NSNull(),
            // Legacy key removed from the current model.
            "temperatureCheckConfirmedAt": referenceDate(start.addingTimeInterval(200)),
            "pulledAt": NSNull(),
            "finishedAt": NSNull()
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)

        let decoded = try JSONDecoder().decode(CookingSession.self, from: data)

        XCTAssertEqual(decoded.flipCount, 2)
        XCTAssertEqual(decoded.phase, .sear)
        XCTAssertEqual(decoded.nextActionAt, start.addingTimeInterval(30))
        XCTAssertNil(decoded.lastManualTemperatureC)
        XCTAssertNil(decoded.thermometerUnavailableAt)
    }

    func testLegacyPreferencesJSONWithStartingConditionStillDecodes() throws {
        let legacy: [String: Any] = [
            "configuration": [
                "cut": "strip",
                "thicknessCM": 4.5,
                "doneness": "medium"
            ],
            // Legacy key removed from the current model.
            "startingCondition": "fridge"
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)

        let decoded = try JSONDecoder().decode(SteakSetupPreferences.self, from: data)

        XCTAssertEqual(decoded.configuration.cut, .strip)
        XCTAssertEqual(decoded.configuration.thicknessCM, 4.5)
        XCTAssertEqual(decoded.configuration.doneness, .medium)
    }

    func testAbsoluteNextActionAtAndFallbackStateRoundTripThroughStore() throws {
        let suite = "CookingPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let start = Date(timeIntervalSince1970: 20_000)
        var session = CookingSession.fresh(at: start)
        session.configuration = SteakConfiguration(
            cut: .ribeye,
            thicknessCM: 3,
            doneness: .mediumRare
        )
        session.enter(.sear, at: start, nextActionAt: start.addingTimeInterval(120))
        session.startedAt = start
        session.thermometerUnavailableAt = start.addingTimeInterval(40)

        store.save(session: session)

        let restored = try XCTUnwrap(store.loadSession())
        XCTAssertEqual(restored.nextActionAt, start.addingTimeInterval(120))
        XCTAssertEqual(
            restored.thermometerUnavailableAt,
            start.addingTimeInterval(40)
        )
        XCTAssertNil(restored.lastManualTemperatureC)
    }

    func testStoredCalibrationsSurviveSessionReset() {
        let suite = "CookingPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let key = CalibrationKey(
            cut: .strip,
            thicknessBucket: .thick,
            doneness: .wellDone
        )
        let learned = CookingCalibration(cookingTimeAdjustment: -12, searBias: 16)

        store.save(calibration: learned, for: key)
        store.save(session: CookingSession.fresh())
        store.clearSession()

        XCTAssertEqual(store.loadCalibration(for: key), learned)
        XCTAssertNil(store.loadSession())
    }
}
