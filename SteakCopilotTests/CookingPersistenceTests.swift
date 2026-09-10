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

// MARK: - Tuning override schema migration

/// Adding `basteMultiplier` to `CutSpecTuning` changed a persisted model, so a
/// stored override written before that field existed must still be usable.
///
/// Both historical shapes are covered: the sparse `{schemaVersion, patch}`
/// document and the older full-`AppTuning` snapshot that the first version of
/// the store wrote under the same UserDefaults key.
@MainActor
final class TuningOverrideMigrationTests: XCTestCase {
    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "TuningOverrideMigrationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return (defaults, suite)
    }

    private static let overrideKey = "steak.tuning.override.v1"

    func testOverridePatchWithoutBasteMultiplierMergesOverProduction() throws {
        let (defaults, _) = makeDefaults()

        // A patch written before basteMultiplier existed.
        let legacyPatch: [String: Any] = [
            "schemaVersion": 1,
            "patch": [
                "cooking": ["baseCookingBudget": 480],
                "cuts": ["strip": ["needsFatCap": true, "fatCapDuration": 35]],
            ],
        ]
        defaults.set(
            try JSONSerialization.data(withJSONObject: legacyPatch),
            forKey: Self.overrideKey
        )

        let store = TuningStore(defaults: defaults)

        // The override still applies…
        XCTAssertTrue(store.hasOverride)
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 480)
        // …and the field added later keeps its production default.
        XCTAssertEqual(
            store.effective.cuts.strip.basteMultiplier,
            AppTuning.production.cuts.strip.basteMultiplier
        )
        XCTAssertEqual(
            store.effective.cuts.ribeye.basteMultiplier,
            AppTuning.production.cuts.ribeye.basteMultiplier
        )
    }

    func testLegacyFullSnapshotOverrideFallsBackInsteadOfBreaking() throws {
        let (defaults, _) = makeDefaults()

        // The oldest stored shape: a complete AppTuning snapshot, which cannot
        // satisfy the current model (it has no basteMultiplier, and the layout
        // has moved on). It must be ignored, not crash or half-apply.
        let legacySnapshot: [String: Any] = [
            "cooking": ["baseCookingBudget": 480, "referenceThickness": 2.5],
            "cuts": [
                "ribeye": ["cookingBudgetOffset": 12, "needsFatCap": false],
                "strip": ["cookingBudgetOffset": 0, "needsFatCap": true],
                "tenderloin": ["cookingBudgetOffset": -12, "needsFatCap": false],
            ],
            "doneness": [:],
            "calibration": [:],
            "finishing": [:],
            "notifications": [:],
            "motion": [:],
        ]
        defaults.set(
            try JSONSerialization.data(withJSONObject: legacySnapshot),
            forKey: Self.overrideKey
        )

        let store = TuningStore(defaults: defaults)

        // Undecodable legacy state is dropped, and the app runs production.
        XCTAssertFalse(store.hasOverride)
        XCTAssertEqual(store.effective, AppTuning.production)
    }

    /// An override that is merely missing the new field must survive a save
    /// round trip without acquiring a stale value.
    func testOverrideRoundTripPreservesTheNewFieldFromProduction() throws {
        let (defaults, _) = makeDefaults()
        let store = TuningStore(defaults: defaults)

        var tuned = store.effective
        tuned.calibration.crustStepSeconds = 15
        try store.applyValidatedAndSave(tuned)

        // Re-encode the patch and reload: the added field must still resolve to
        // the production default, not to nil or zero.
        let reloaded = TuningStore(defaults: defaults)
        XCTAssertEqual(reloaded.effective.calibration.crustStepSeconds, 15)
        for cut in SteakCut.allCases {
            XCTAssertEqual(
                reloaded.effective.cuts[cut].basteMultiplier,
                AppTuning.production.cuts[cut].basteMultiplier,
                "\(cut.rawValue).basteMultiplier must survive the round trip"
            )
        }
    }
}
