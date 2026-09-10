import XCTest
@testable import SteakCopilot

/// Cut-level behaviour: thickness stays the primary driver, doneness keeps a
/// single shared meaning, and a cut is only a secondary correction.
///
/// The cut parameters (`cookingBudgetOffset`, `basteMultiplier`,
/// `fatCapDuration`) are V1 empirical baselines from
/// `Config/production.yaml`, so these tests assert *relationships* and
/// *ordering* rather than pretending the numbers are exact predictions.
@MainActor
final class CutProfileTests: XCTestCase {
    private let engine = CookingEngine(tuning: .production)
    private let tuning = AppTuning.production

    private func configuration(
        _ cut: SteakCut,
        thicknessCM: Double,
        doneness: Doneness = .mediumRare
    ) -> SteakConfiguration {
        SteakConfiguration(cut: cut, thicknessCM: thicknessCM, doneness: doneness)
    }

    private func profile(
        _ cut: SteakCut,
        thicknessCM: Double,
        doneness: Doneness = .mediumRare
    ) -> CookingProfile {
        engine.profile(
            for: configuration(cut, thicknessCM: thicknessCM, doneness: doneness),
            calibration: .neutral
        )
    }

    // MARK: - Doneness is cut-independent

    /// Medium Rare means the same centre temperature for every cut. There is
    /// deliberately no `ribeye.mediumRareTarget`-style override.
    func testCutNeverChangesTargetOrPullTemperature() {
        let expected = tuning.doneness[.mediumRare]

        for cut in SteakCut.allCases {
            let cutProfile = profile(cut, thicknessCM: 3)

            XCTAssertEqual(
                cutProfile.targetTemperatureC,
                expected.targetTemperatureC,
                "\(cut.rawValue) must not change the target temperature"
            )
            XCTAssertEqual(
                cutProfile.pullTemperatureC,
                expected.pullTemperatureC,
                "\(cut.rawValue) must not change the pull temperature"
            )
        }
    }

    func testPullStaysBelowTargetForEveryCutAndDoneness() {
        for cut in SteakCut.allCases {
            for doneness in Doneness.allCases {
                let cutProfile = profile(cut, thicknessCM: 3, doneness: doneness)
                XCTAssertLessThan(
                    cutProfile.pullTemperatureC,
                    cutProfile.targetTemperatureC,
                    "\(cut.rawValue)/\(doneness.rawValue) broke pull < target"
                )
            }
        }
    }

    /// No cut-specific temperature table may creep into the configuration.
    ///
    /// Checked against configured KEYS: the YAML explains this rule in a
    /// comment, which mentions the very names a naive text search would flag.
    func testThereIsNoCutSpecificDonenessTemperature() throws {
        // Scope the check to the `cuts` section: that is where a per-cut
        // temperature would appear. The `doneness` section legitimately owns
        // targetTemperatureC / pullTemperatureC.
        let cutSection = try ProductionYAML.section("cuts")
        XCTAssertGreaterThan(cutSection.count, 0, "The cuts section must exist")

        for key in cutSection {
            XCTAssertFalse(
                key.lowercased().contains("temperature"),
                "\(key) is a temperature inside the cuts section"
            )
            XCTAssertFalse(
                key.lowercased().contains("pull"),
                "\(key) is a pull temperature inside the cuts section"
            )
        }

        // The doneness section is the only place a target (or pull) is set,
        // exactly once per level, and there are no extra temperature keys
        // anywhere outside it.
        XCTAssertEqual(
            try ProductionYAML.count(ofKey: "targetTemperatureC"),
            Doneness.allCases.count,
            "Expected exactly one target per doneness level"
        )
        XCTAssertEqual(
            try ProductionYAML.count(ofKey: "pullTemperatureC"),
            Doneness.allCases.count,
            "Expected exactly one pull per doneness level"
        )
        XCTAssertEqual(
            try ProductionYAML.count(ofKey: "cookingBudgetFactor"),
            Doneness.allCases.count,
            "cookingBudgetFactor also belongs to doneness only"
        )

        // Every temperature key lives under `doneness`.
        let donenessSection = try ProductionYAML.section("doneness")
        for key in ["targetTemperatureC", "pullTemperatureC"] {
            XCTAssertTrue(
                donenessSection.contains(key),
                "\(key) must be configured under doneness"
            )
        }
    }

    /// The scanner itself must work, otherwise the checks above could pass by
    /// finding nothing at all.
    func testProductionYAMLScannerFindsRealKeysAndIgnoresComments() throws {
        XCTAssertTrue(try ProductionYAML.hasKey("cooking"))
        XCTAssertTrue(try ProductionYAML.hasKey("basteMultiplier"))
        XCTAssertTrue(try ProductionYAML.hasKey("targetTemperatureC"))

        // A rule name that only appears in a comment must not be reported.
        XCTAssertFalse(try ProductionYAML.hasKey("reduceMotion"))
        XCTAssertFalse(
            try ProductionYAML.keys().contains { $0.contains("mediumRareTarget") },
            "Comment-only mentions must not register as keys"
        )
    }

    // MARK: - Cuts differ, but only slightly

    /// Same thickness + doneness: the three cuts may differ, but only a little.
    func testCutsProduceSmallDifferencesAtTheSameThickness() {
        let budgets = SteakCut.allCases.map { profile($0, thicknessCM: 3).estimatedCookingBudget }
        let spread = (budgets.max() ?? 0) - (budgets.min() ?? 0)
        let reference = tuning.cooking.baseCookingBudget

        XCTAssertGreaterThan(spread, 0, "The cuts should not be identical")
        XCTAssertLessThan(
            spread,
            reference * 0.15,
            "Cut differences must stay a secondary correction, got \(spread)s"
        )
    }

    /// The offset ordering is the documented one: ribeye above strip above
    /// tenderloin, and the values match the YAML baselines.
    func testCutOffsetsFollowTheDocumentedOrdering() {
        XCTAssertEqual(tuning.cuts.ribeye.cookingBudgetOffset, 5)
        XCTAssertEqual(tuning.cuts.strip.cookingBudgetOffset, 0)
        XCTAssertEqual(tuning.cuts.tenderloin.cookingBudgetOffset, -8)

        let ribeye = profile(.ribeye, thicknessCM: 3).estimatedCookingBudget
        let strip = profile(.strip, thicknessCM: 3).estimatedCookingBudget
        let tenderloin = profile(.tenderloin, thicknessCM: 3).estimatedCookingBudget

        XCTAssertGreaterThan(ribeye, strip)
        XCTAssertGreaterThan(strip, tenderloin)
    }

    // MARK: - Thickness dominates

    /// Thickness must stay the primary variable: a thicker tenderloin has to
    /// take longer than a thinner strip, despite its negative offset.
    func testThicknessOutweighsCutOffset() {
        let thickTenderloin = profile(.tenderloin, thicknessCM: 4).estimatedCookingBudget
        let thinStrip = profile(.strip, thicknessCM: 2.5).estimatedCookingBudget
        let thickStrip = profile(.strip, thicknessCM: 4).estimatedCookingBudget
        let thinTenderloin = profile(.tenderloin, thicknessCM: 2.5).estimatedCookingBudget

        // 4cm tenderloin is not faster than a much thinner steak…
        XCTAssertGreaterThan(
            thickTenderloin,
            thinStrip,
            "A thicker cut must not be outrun by the cut offset"
        )
        // …and thickness dominates within a single cut too.
        XCTAssertGreaterThan(thickStrip, thinStrip)
        XCTAssertGreaterThan(thickTenderloin, thinTenderloin)

        // The thickness effect must be far larger than the whole cut offset.
        let thicknessEffect = thickStrip - thinStrip
        let cutOffsetSpread = tuning.cuts.ribeye.cookingBudgetOffset
            - tuning.cuts.tenderloin.cookingBudgetOffset
        XCTAssertGreaterThan(thicknessEffect, cutOffsetSpread * 3)
    }

    func testThicknessRemainsMonotonicForEveryCut() {
        for cut in SteakCut.allCases {
            let thin = profile(cut, thicknessCM: 2.0).estimatedCookingBudget
            let standard = profile(cut, thicknessCM: 3.0).estimatedCookingBudget
            let thick = profile(cut, thicknessCM: 5.0).estimatedCookingBudget

            XCTAssertLessThan(thin, standard, "\(cut.rawValue): 2cm vs 3cm")
            XCTAssertLessThan(standard, thick, "\(cut.rawValue): 3cm vs 5cm")
        }
    }

    // MARK: - Fat cap

    func testOnlyStripNeedsAFatCapAndItMatchesTheBaseline() {
        for cut in SteakCut.allCases {
            let spec = tuning.cuts[cut]

            switch cut {
            case .strip:
                XCTAssertTrue(spec.needsFatCap, "strip keeps its fat cap stage")
                XCTAssertEqual(spec.fatCapDuration, 35)
                XCTAssertNotNil(
                    profile(cut, thicknessCM: 3).fatCapDuration,
                    "strip profile must carry a fat cap duration"
                )
            case .ribeye, .tenderloin:
                XCTAssertFalse(
                    spec.needsFatCap,
                    "\(cut.rawValue) must not gain a fat cap stage"
                )
                XCTAssertNil(spec.fatCapDuration)
                XCTAssertNil(
                    profile(cut, thicknessCM: 3).fatCapDuration,
                    "\(cut.rawValue) profile must not carry a fat cap duration"
                )
            }
        }
    }

    /// The state machine only enters FAT CAP for a cut that needs it.
    func testFatCapStageIsOnlyReachedByStrip() {
        let start = Date(timeIntervalSince1970: 600_000)

        for cut in SteakCut.allCases {
            let configuration = configuration(cut, thicknessCM: 3)
            let cutProfile = engine.profile(for: configuration, calibration: .neutral)
            var session = CookingSession.fixture(
                phase: .sear,
                phaseStartedAt: start,
                nextActionAt: start.addingTimeInterval(
                    cutProfile.lateStageDateOffset
                )
            )
            session.startedAt = start
            session.configuration = configuration

            let guidance = engine.guidance(for: session, at: start.addingTimeInterval(
                cutProfile.lateStageDateOffset
            ))

            if cut == .strip {
                XCTAssertEqual(
                    guidance.currentAction,
                    .standFatCap,
                    "strip should enter the fat cap stage"
                )
            } else {
                XCTAssertEqual(
                    guidance.currentAction,
                    .addButter,
                    "\(cut.rawValue) should skip straight to butter"
                )
            }
        }
    }

    // MARK: - Baste multiplier

    func testBasteMultiplierOrderingMatchesTheBaselines() {
        XCTAssertLessThan(
            tuning.cuts.ribeye.basteMultiplier,
            tuning.cuts.strip.basteMultiplier,
            "ribeye leans shorter than the baseline"
        )
        XCTAssertLessThan(
            tuning.cuts.strip.basteMultiplier,
            tuning.cuts.tenderloin.basteMultiplier,
            "tenderloin leans longer than the baseline"
        )
        XCTAssertEqual(tuning.cuts.strip.basteMultiplier, 1.0)
    }

    /// The multiplier must actually reach `basteDuration`, at a thickness where
    /// the clamp is not flattening every cut to the same value.
    func testBasteMultiplierChangesTheEngineBasteDuration() {
        // Thin steaks keep the raw budget low enough to stay under the clamp.
        let ribeye = profile(.ribeye, thicknessCM: 2).basteDuration
        let strip = profile(.strip, thicknessCM: 2).basteDuration
        let tenderloin = profile(.tenderloin, thicknessCM: 2).basteDuration

        XCTAssertLessThan(ribeye, strip)
        XCTAssertLessThan(strip, tenderloin)

        // Ribeye 0.8x must be strictly below the shared baseline ratio applied
        // to the same raw budget.
        let ribeyeRaw = profile(.ribeye, thicknessCM: 2).estimatedCookingBudget
        XCTAssertLessThan(ribeye, ribeyeRaw * tuning.cooking.basteRatio)
    }

    /// Editing the multiplier changes the engine's output — the parameter is
    /// wired through, not decorative.
    func testChangingBasteMultiplierChangesBasteDuration() {
        var tuned = AppTuning.production
        tuned.cuts.strip.basteMultiplier = 2.0

        let custom = CookingEngine(tuning: tuned)
        let configuration = configuration(.strip, thicknessCM: 2)
        let production = engine.profile(for: configuration, calibration: .neutral)
        let edited = custom.profile(for: configuration, calibration: .neutral)

        XCTAssertGreaterThan(edited.basteDuration, production.basteDuration)
    }

    /// The upper clamp works: a large multiplier cannot exceed maxBasteDuration.
    func testBasteDurationIsClampedToTheConfiguredMaximum() {
        XCTAssertEqual(
            tuning.cooking.maxBasteDuration,
            45,
            "the V1 baste ceiling is 45s, not 75s"
        )

        // Thick cuts produce a large raw budget, so the clamp is what applies.
        for cut in SteakCut.allCases {
            let cutProfile = profile(cut, thicknessCM: 5)
            XCTAssertLessThanOrEqual(
                cutProfile.basteDuration,
                tuning.cooking.maxBasteDuration + 0.001,
                "\(cut.rawValue) exceeded the baste ceiling"
            )
        }

        // Strip at a typical budget is the documented clamp case:
        // 300 * 0.16 * 1.0 = 48 -> 45.
        let strip = profile(.strip, thicknessCM: 2.5)
        XCTAssertEqual(strip.estimatedCookingBudget, 300, accuracy: 0.001)
        XCTAssertEqual(strip.basteDuration, 45, accuracy: 0.001)

        // A large multiplier still cannot break the ceiling.
        var tuned = AppTuning.production
        tuned.cuts.ribeye.basteMultiplier = 2.0
        let clamped = CookingEngine(tuning: tuned).profile(
            for: configuration(.ribeye, thicknessCM: 5),
            calibration: .neutral
        )
        XCTAssertEqual(clamped.basteDuration, 45, accuracy: 0.001)
    }

    func testBasteDurationNeverDropsBelowTheMinimum() {
        for cut in SteakCut.allCases {
            // A tiny budget would otherwise produce a sub-second baste.
            let tiny = engine.profile(
                for: configuration(cut, thicknessCM: 0.5),
                calibration: .neutral
            )
            XCTAssertGreaterThanOrEqual(
                tiny.basteDuration,
                tuning.cooking.minBasteDuration
            )
        }
    }

    /// Characterisation test for a real interaction between two requested
    /// values: at the recommended thicknesses (3.0-4.0 cm) the raw baste is
    /// 58-75s, so `maxBasteDuration` (45s) binds for *every* cut and
    /// `basteMultiplier` has no visible effect there.
    ///
    /// The multiplier only differentiates thinner steaks. This is recorded
    /// deliberately: if someone raises the cap or the ratio, this test fails
    /// and forces a conscious decision instead of silently changing the
    /// intended "ribeye shorter, tenderloin longer" behaviour.
    func testBasteMultiplierIsAbsorbedByTheClampAtRecommendedThickness() {
        let cap = tuning.cooking.maxBasteDuration

        for cut in SteakCut.allCases {
            let recommended = tuning.cuts[cut].recommendedThickness
            let cutProfile = profile(cut, thicknessCM: recommended)
            let rawBaste = cutProfile.estimatedCookingBudget
                * tuning.cooking.basteRatio
                * tuning.cuts[cut].basteMultiplier

            XCTAssertGreaterThan(
                rawBaste,
                cap,
                """
                \(cut.rawValue) at its recommended \(recommended)cm no longer \
                exceeds the \(cap)s baste cap. The cut multipliers now differ \
                in the default configuration - update this expectation and the \
                comments in Config/production.yaml.
                """
            )
            XCTAssertEqual(
                cutProfile.basteDuration,
                cap,
                accuracy: 0.001,
                "\(cut.rawValue) should be clamped at the recommended thickness"
            )
        }
    }

    /// The multiplier still differentiates cuts where the clamp does not bind,
    /// which is what makes it a working parameter rather than decoration.
    func testBasteMultiplierDifferentiatesThinCuts() {
        let thin = 2.0
        let ribeye = profile(.ribeye, thicknessCM: thin).basteDuration
        let strip = profile(.strip, thicknessCM: thin).basteDuration
        let tenderloin = profile(.tenderloin, thicknessCM: thin).basteDuration
        let cap = tuning.cooking.maxBasteDuration

        XCTAssertLessThan(ribeye, cap)
        XCTAssertLessThan(strip, cap)
        XCTAssertLessThan(tenderloin, cap)
        XCTAssertLessThan(ribeye, strip)
        XCTAssertLessThan(strip, tenderloin)
    }

    // MARK: - Calibration isolation is untouched

    /// Cut feedback must stay isolated: the calibration key still includes the
    /// cut, the thickness bucket and the doneness.
    func testCalibrationStaysScopedByCutThicknessBucketAndDoneness() {
        let ribeye = CalibrationKey(
            cut: .ribeye,
            thicknessBucket: .standard,
            doneness: .mediumRare
        )
        let tenderloin = CalibrationKey(
            cut: .tenderloin,
            thicknessBucket: .standard,
            doneness: .mediumRare
        )
        let thickRibeye = CalibrationKey(
            cut: .ribeye,
            thicknessBucket: .thick,
            doneness: .mediumRare
        )
        let mediumRibeye = CalibrationKey(
            cut: .ribeye,
            thicknessBucket: .standard,
            doneness: .medium
        )

        XCTAssertNotEqual(ribeye, tenderloin)
        XCTAssertNotEqual(ribeye, thickRibeye)
        XCTAssertNotEqual(ribeye, mediumRibeye)

        // Learned feedback does not leak across cuts.
        let learned = CookingCalibration(cookingTimeAdjustment: 24, searBias: 8)
        let applied = engine.profile(
            for: configuration(.ribeye, thicknessCM: 3),
            calibration: learned
        )
        let untouched = engine.profile(
            for: configuration(.tenderloin, thicknessCM: 3),
            calibration: .neutral
        )

        XCTAssertGreaterThan(
            applied.estimatedCookingBudget,
            engine.profile(
                for: configuration(.ribeye, thicknessCM: 3),
                calibration: .neutral
            ).estimatedCookingBudget
        )
        XCTAssertEqual(
            untouched.estimatedCookingBudget,
            engine.profile(
                for: configuration(.tenderloin, thicknessCM: 3),
                calibration: .neutral
            ).estimatedCookingBudget
        )
    }

    // MARK: - Recommended thickness

    func testRecommendedThicknessMatchesTheBaselines() {
        XCTAssertEqual(
            SteakSetupPreferences.recommended(for: .ribeye, tuning: tuning)
                .configuration.thicknessCM,
            3.5
        )
        XCTAssertEqual(
            SteakSetupPreferences.recommended(for: .strip, tuning: tuning)
                .configuration.thicknessCM,
            3.0
        )
        // The leanest cut is recommended thicker, which is why its negative
        // offset does not make it the fastest steak.
        XCTAssertEqual(
            SteakSetupPreferences.recommended(for: .tenderloin, tuning: tuning)
                .configuration.thicknessCM,
            4.0
        )
    }

    func testRecommendedTenderloinIsNotFasterThanRecommendedStrip() {
        let tenderloin = SteakSetupPreferences.recommended(for: .tenderloin, tuning: tuning)
        let strip = SteakSetupPreferences.recommended(for: .strip, tuning: tuning)

        let tenderloinBudget = engine.profile(
            for: tenderloin.configuration,
            calibration: .neutral
        ).estimatedCookingBudget
        let stripBudget = engine.profile(
            for: strip.configuration,
            calibration: .neutral
        ).estimatedCookingBudget

        XCTAssertGreaterThan(
            tenderloinBudget,
            stripBudget,
            "The recommended filet (4cm) must not cook faster than a 3cm strip"
        )
    }

    // MARK: - Validator / generator agreement

    func testValidatorEnforcesTheSameBasteMultiplierBoundsAsTheGenerator() {
        XCTAssertTrue(AppTuningValidator.issues(in: .production).isEmpty)

        for invalid in [0.0, -0.5, 2.5, 10] {
            var tuned = AppTuning.production
            tuned.cuts.strip.basteMultiplier = invalid
            let issues = AppTuningValidator.issues(in: tuned)
            XCTAssertTrue(
                issues.contains { $0.contains("basteMultiplier") },
                "\(invalid) should be rejected, got \(issues)"
            )
        }

        // The inclusive upper bound is legal on both sides.
        for valid in [0.05, 1.0, 2.0] {
            var tuned = AppTuning.production
            tuned.cuts.strip.basteMultiplier = valid
            XCTAssertTrue(
                AppTuningValidator.issues(in: tuned).isEmpty,
                "\(valid) should be accepted"
            )
        }
    }

    func testOverrideRejectsAnOutOfRangeBasteMultiplier() throws {
        let suite = "CutProfileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TuningStore(defaults: defaults)

        var invalid = store.effective
        invalid.cuts.ribeye.basteMultiplier = 3
        let outcome = store.applyValidated(invalid)

        XCTAssertTrue(outcome.isRejected)
        XCTAssertEqual(store.effective, AppTuning.production)
    }

    func testBasteMultiplierIsExposedInTheTuningLab() {
        let ids = Set(TuningLabView.allFieldIDs)
        for cut in SteakCut.allCases {
            XCTAssertTrue(
                ids.contains("\(cut.rawValue).basteMultiplier"),
                "\(cut.rawValue).basteMultiplier needs a Tuning Lab control"
            )
        }
        // And it must be editable, not just listed.
        XCTAssertNotNil(
            TuningLabView.allFields.first { $0.id == "strip.basteMultiplier" }
        )
    }
}
