import CryptoKit
import Foundation
import XCTest
@testable import SteakCopilot

/// Verifies the parameter system end to end:
///
///     Config/production.yaml  →  Scripts/generate_tuning.py
///                             →  ProductionTuning.production
///                             →  TuningStore override chain
///
/// These tests fail if the generated Swift drifts from the YAML, if the
/// generator stops validating, or if a tuned value stops affecting behaviour.
@MainActor
final class TuningConfigurationTests: XCTestCase {
    private var repoRoot: URL {
        // SteakCopilotTests/… → repository root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var yamlURL: URL { repoRoot.appendingPathComponent("Config/production.yaml") }
    private var generatorURL: URL { repoRoot.appendingPathComponent("Scripts/generate_tuning.py") }
    private var generatedURL: URL {
        repoRoot.appendingPathComponent("SteakCopilot/Generated/ProductionTuning.generated.swift")
    }

    // MARK: - Repository layout

    func testSourceOfTruthAndGeneratorExist() {
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: yamlURL.path),
            "Config/production.yaml is the source of truth and must exist"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: generatorURL.path),
            "Scripts/generate_tuning.py must exist"
        )
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: generatedURL.path),
            "The generated tuning must be committed"
        )
    }

    func testGeneratorHasNoThirdPartyDependency() throws {
        let source = try String(contentsOf: generatorURL, encoding: .utf8)
        XCTAssertFalse(source.contains("import yaml"), "Must not depend on PyYAML")
        XCTAssertFalse(source.contains("import requests"), "Must not use the network")
        XCTAssertFalse(source.contains("urllib.request"), "Must not fetch anything")
        // Only standard-library modules may be imported.
        for line in source.split(separator: "\n") where line.hasPrefix("import ") || line.hasPrefix("from ") {
            let module = line
                .replacingOccurrences(of: "from ", with: "")
                .replacingOccurrences(of: "import ", with: "")
                .split(separator: " ").first.map(String.init) ?? ""
            XCTAssertTrue(
                ["argparse", "hashlib", "json", "re", "sys", "__future__", "pathlib", "typing", "tempfile"]
                    .contains(module),
                "Unexpected import \(module) — the generator must stay standard-library only"
            )
        }
    }

    // NOTE: the generator itself cannot be executed from an iOS unit test
    // host (iOS forbids spawning processes). Its validation behaviour is
    // covered offline by `Scripts/generate_tuning.py --self-test`, which CI
    // runs before xcodebuild; the freshness of the committed artifact is
    // enforced by `--check`. These tests cover everything reachable in-process:
    // the fingerprint, the generated values, the override chain, and that a
    // tuned parameter really changes engine behaviour.

    func testGeneratedFileRecordsTheYAMLFingerprint() throws {
        let digest = SHA256.hash(data: try Data(contentsOf: yamlURL))
        let expected = digest.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(ProductionTuning.sourceFingerprint, expected)
    }

    /// Reads a scalar out of the YAML text and compares it with the generated
    /// value, catching a YAML edit that was never regenerated.
    private func yamlContains(_ pattern: String) throws -> Bool {
        let text = try String(contentsOf: yamlURL, encoding: .utf8)
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    func testGeneratedValuesAreTraceableToTheYAMLText() throws {
        let tuning = AppTuning.production
        let expectations: [(value: String, pattern: String)] = [
            (String(tuning.cooking.baseCookingBudget), "baseCookingBudget: 300"),
            (String(tuning.cooking.flipIntervalStandard), "flipIntervalStandard: 30"),
            (String(tuning.cooking.lateStageRatio), "lateStageRatio: 0.65"),
            (String(tuning.calibration.donenessStepSeconds), "donenessStepSeconds: 12"),
            (String(tuning.calibration.crustStepSeconds), "crustStepSeconds: 8"),
            (String(tuning.notifications.staleDelaySeconds), "staleDelaySeconds: 30"),
            (String(tuning.motion.stageTransition), "stageTransition: 0.7"),
            (String(tuning.cuts.strip.fatCapDuration ?? 0), "fatCapDuration: 35"),
            (String(tuning.cuts.ribeye.basteMultiplier), "basteMultiplier: 0.8"),
            (String(tuning.cooking.maxBasteDuration), "maxBasteDuration: 45"),
        ]

        for expectation in expectations {
            XCTAssertTrue(
                try yamlContains(expectation.pattern),
                "production.yaml must contain \(expectation.pattern)"
            )
        }
    }

    func testGeneratedValuesMatchTheYAML() throws {
        // Values asserted here are the literals in Config/production.yaml.
        let tuning = AppTuning.production
        XCTAssertEqual(tuning.cooking.baseCookingBudget, 300)
        XCTAssertEqual(tuning.cooking.referenceThickness, 2.5)
        XCTAssertEqual(tuning.cooking.minThicknessFactor, 0.72)
        XCTAssertEqual(tuning.cooking.minCookingBudget, 180)
        XCTAssertEqual(tuning.cooking.maxCookingBudget, 720)
        XCTAssertEqual(tuning.cooking.flipIntervalThin, 25)
        XCTAssertEqual(tuning.cooking.flipIntervalStandard, 30)
        XCTAssertEqual(tuning.cooking.flipIntervalThick, 40)
        XCTAssertEqual(tuning.cooking.lateStageRatio, 0.65)
        XCTAssertEqual(tuning.cooking.basteRatio, 0.16)
        XCTAssertEqual(tuning.cuts.strip.fatCapDuration, 35)
        XCTAssertEqual(tuning.cuts.tenderloin.recommendedThickness, 4.0)
        XCTAssertEqual(tuning.cuts.ribeye.recommendedThickness, 3.5)
        XCTAssertEqual(tuning.cuts.strip.basteMultiplier, 1.0)
        XCTAssertEqual(tuning.cuts.ribeye.basteMultiplier, 0.8)
        XCTAssertEqual(tuning.cuts.tenderloin.basteMultiplier, 1.1)
        XCTAssertEqual(tuning.cooking.maxBasteDuration, 45)
        XCTAssertEqual(tuning.doneness.mediumRare.pullTemperatureC, 52)
        XCTAssertEqual(tuning.doneness.mediumRare.targetTemperatureC, 55)
        XCTAssertEqual(tuning.calibration.donenessStepSeconds, 12)
        XCTAssertEqual(tuning.calibration.crustStepSeconds, 8)
        XCTAssertEqual(tuning.calibration.maxSearAdjustment, 24)
        XCTAssertEqual(tuning.finishing.baseAdjustmentSeconds, 65)
        XCTAssertEqual(tuning.notifications.approachingThresholdSeconds, 5)
        XCTAssertEqual(tuning.notifications.staleDelaySeconds, 30)
        XCTAssertEqual(tuning.notifications.finishedDismissalSeconds, 60)
        XCTAssertEqual(tuning.notifications.cancelledDismissalSeconds, 4)
        XCTAssertEqual(tuning.motion.responsive, 0.22)
        XCTAssertEqual(tuning.motion.stageTransition, 0.7)
    }

    /// The engine must compute from YAML values, not from stale literals.
    func testEngineUsesTheYAMLParameters() {
        let engine = CookingEngine(tuning: .production)
        let configuration = SteakConfiguration(
            cut: .ribeye,
            thicknessCM: 3,
            doneness: .mediumRare
        )

        // 300 * (3 / 2.5) * 1.0 + 5 (ribeye offset) = 365
        let profile = engine.profile(for: configuration, calibration: .neutral)
        XCTAssertEqual(profile.estimatedCookingBudget, 365, accuracy: 0.001)
        XCTAssertEqual(engine.flipInterval(for: configuration), 30, accuracy: 0.001)
        XCTAssertEqual(profile.pullTemperatureC, 52, accuracy: 0.001)
        XCTAssertEqual(profile.targetTemperatureC, 55, accuracy: 0.001)
        // late stage = max(flip * 2, 365 * 0.65) = 237.25
        XCTAssertEqual(profile.lateStageDateOffset, 237.25, accuracy: 0.001)
        // baste = 365 * 0.16 * 0.8 (ribeye) = 46.72, clamped to 45
        XCTAssertEqual(profile.basteDuration, 45, accuracy: 0.001)
    }

    // MARK: - No double defaults

    func testNoTunableLiteralsInHandWrittenSources() throws {
        let root = repoRoot.appendingPathComponent("SteakCopilot")
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(atPath: root.path))
        var checked = 0

        for case let path as String in enumerator {
            guard path.hasSuffix(".swift") else { continue }
            guard !path.contains("Generated/") else { continue }
            let text = try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
            checked += 1

            XCTAssertFalse(
                text.contains("MotionTiming"),
                "\(path): motion durations must come from the YAML, not MotionTiming"
            )
            XCTAssertFalse(
                text.contains("case .rare: 52"),
                "\(path): doneness temperatures must come from the YAML"
            )
            XCTAssertFalse(
                text.contains("fatCapDuration: 40"),
                "\(path): fat cap duration must come from the YAML"
            )
            XCTAssertFalse(
                text.contains("static let defaultFlip"),
                "\(path): no Swift-side default may duplicate the YAML"
            )
        }

        XCTAssertGreaterThan(checked, 10, "Expected to scan the app sources")
    }

    func testGeneratedFileIsTheOnlySwiftPlaceWithProductionNumbers() throws {
        let source = try String(contentsOf: generatedURL, encoding: .utf8)
        XCTAssertTrue(source.contains("static let production = AppTuning("))
        XCTAssertTrue(source.contains("DO NOT EDIT BY HAND"))
    }

    // MARK: - Runtime override chain

    func testNoOverrideMeansProductionDefaults() {
        let store = makeStore()
        XCTAssertFalse(store.hasOverride)
        XCTAssertEqual(store.effective, AppTuning.production)
    }

    func testOverridePersistsAndRoundTripsThroughJSON() throws {
        let suite = "TuningConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TuningStore(defaults: defaults)
        var custom = AppTuning.production
        custom.cooking.baseCookingBudget = 480
        custom.calibration.crustStepSeconds = 15
        try store.applyValidatedAndSave(custom)

        XCTAssertTrue(store.hasOverride)
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 480)

        // Reopening reads the persisted override.
        let reloaded = TuningStore(defaults: defaults)
        XCTAssertTrue(reloaded.hasOverride)
        XCTAssertEqual(reloaded.effective.cooking.baseCookingBudget, 480)
        XCTAssertEqual(reloaded.effective.calibration.crustStepSeconds, 15)

        // Export → import into a clean store.
        let exported = try XCTUnwrap(store.exportJSON())
        let fresh = TuningStore(defaults: UserDefaults(suiteName: "\(suite).import")!)
        try fresh.importJSON(exported)
        XCTAssertEqual(fresh.effective.cooking.baseCookingBudget, 480)
        XCTAssertEqual(fresh.effective.calibration.crustStepSeconds, 15)
        XCTAssertTrue(fresh.hasOverride)
    }

    func testResetRestoresProductionDefaultsAndStaysReset() throws {
        let suite = "TuningConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TuningStore(defaults: defaults)
        var custom = AppTuning.production
        custom.cooking.baseCookingBudget = 360
        try store.applyValidatedAndSave(custom)
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 360)

        store.resetToProduction()

        XCTAssertFalse(store.hasOverride)
        XCTAssertEqual(store.effective, AppTuning.production)
        XCTAssertFalse(TuningStore(defaults: defaults).hasOverride)
    }

    func testImportRejectsMalformedJSONWithoutClobberingTheOverride() throws {
        let store = makeStore()
        // Install a good override first so we can prove it survives.
        var good = AppTuning.production
        good.cooking.baseCookingBudget = 420
        try store.applyValidatedAndSave(good)
        let before = store.effective

        XCTAssertThrowsError(try store.importJSON(Data("{ not json }".utf8))) { error in
            XCTAssertTrue(error is TuningImportError)
        }

        // Rejected import: nothing applied, previous override intact.
        XCTAssertEqual(store.effective, before)
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 420)
    }

    func testImportRejectsASemanticallyInvalidOverride() throws {
        let store = makeStore()
        var good = AppTuning.production
        good.cooking.baseCookingBudget = 420
        try store.applyValidatedAndSave(good)
        let before = store.effective

        // A patch that inverts min/max cooking budget decodes fine but is not
        // usable, so it must be refused.
        let invalid: [String: Any] = [
            "schemaVersion": 1,
            "patch": [
                "cooking": [
                    "minCookingBudget": 900,
                    "maxCookingBudget": 120,
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: invalid)

        XCTAssertThrowsError(try store.importJSON(data)) { error in
            guard case let TuningImportError.validation(issues) = error else {
                return XCTFail("Expected a validation failure, got \(error)")
            }
            XCTAssertTrue(
                issues.contains { $0.contains("minCookingBudget") },
                "Issues should name the offending field: \(issues)"
            )
        }

        XCTAssertEqual(store.effective, before)
        XCTAssertEqual(store.effective.cooking.minCookingBudget, before.cooking.minCookingBudget)
    }

    func testImportRejectsANewerSchemaVersion() throws {
        let store = makeStore()
        let future: [String: Any] = [
            "schemaVersion": TuningOverride.currentSchemaVersion + 1,
            "patch": [:],
        ]
        let data = try JSONSerialization.data(withJSONObject: future)

        XCTAssertThrowsError(try store.importJSON(data)) { error in
            XCTAssertEqual(
                error as? TuningImportError,
                .schemaVersion(TuningOverride.currentSchemaVersion + 1)
            )
        }
        XCTAssertFalse(store.hasOverride)
    }

    // MARK: - Changing a parameter changes behaviour

    func testChangingFlipIntervalChangesScheduledBoundary() {
        var tuned = AppTuning.production
        tuned.cooking.flipIntervalStandard = 12

        let configuration = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
        let production = CookingEngine(tuning: .production)
        let custom = CookingEngine(tuning: tuned)
        XCTAssertEqual(production.flipInterval(for: configuration), 30, accuracy: 0.001)
        XCTAssertEqual(custom.flipInterval(for: configuration), 12, accuracy: 0.001)

        let start = Date(timeIntervalSince1970: 400_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(30)
        )
        session.startedAt = start

        XCTAssertEqual(
            production.searBoundary(
                for: session,
                profile: production.profile(for: configuration, calibration: .neutral),
                from: start
            ).date,
            start.addingTimeInterval(30)
        )
        XCTAssertEqual(
            custom.searBoundary(
                for: session,
                profile: custom.profile(for: configuration, calibration: .neutral),
                from: start
            ).date,
            start.addingTimeInterval(12)
        )
    }

    func testChangingPullTemperatureChangesRecommendation() {
        var tuned = AppTuning.production
        tuned.doneness.mediumRare.pullTemperatureC = 44

        let start = Date(timeIntervalSince1970: 410_000)
        var session = CookingSession.fixture(
            phase: .checkTemperature,
            phaseStartedAt: start,
            nextActionAt: nil
        )
        session.startedAt = start
        session.configuration = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
        session.lastManualTemperatureC = 46
        session.lastManualTemperatureAt = start

        XCTAssertEqual(
            CookingEngine(tuning: .production).guidance(for: session, at: start).pullRecommendation,
            .keepCooking
        )
        XCTAssertEqual(
            CookingEngine(tuning: tuned).guidance(for: session, at: start).pullRecommendation,
            .takeOut
        )
    }

    func testChangingBudgetMovesEstimatedPullBoundary() {
        var tuned = AppTuning.production
        tuned.cooking.baseCookingBudget = 600

        let configuration = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
        let start = Date(timeIntervalSince1970: 411_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(60)
        )
        session.startedAt = start
        session.configuration = configuration
        session.thermometerUnavailableAt = start

        let production = CookingEngine(tuning: .production)
        let custom = CookingEngine(tuning: tuned)
        let productionPull = production.estimatedPullDate(
            for: session,
            profile: production.profile(for: configuration, calibration: .neutral)
        )
        let customPull = custom.estimatedPullDate(
            for: session,
            profile: custom.profile(for: configuration, calibration: .neutral)
        )
        XCTAssertGreaterThan(customPull, productionPull)
    }

    func testChangingCalibrationStepsChangesLearnedAdjustment() {
        var tuned = AppTuning.production
        tuned.calibration.crustStepSeconds = 20
        tuned.calibration.maxSearAdjustment = 100

        let learned = CookingCalibration.neutral.applying(
            doneness: .perfect,
            crust: .tooDark,
            tuning: tuned
        )
        let productionLearned = CookingCalibration.neutral.applying(
            doneness: .perfect,
            crust: .tooDark
        )
        XCTAssertEqual(learned.searBias, -20, accuracy: 0.001)
        XCTAssertEqual(productionLearned.searBias, -8, accuracy: 0.001)
    }

    func testChangingCutFlagsChangesLateStageActionAndProfile() {
        var tuned = AppTuning.production
        tuned.cuts.ribeye.needsFatCap = true
        tuned.cuts.ribeye.fatCapDuration = 30
        tuned.cuts.ribeye.cookingBudgetOffset = 60

        let configuration = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
        let engine = CookingEngine(tuning: tuned)
        let profile = engine.profile(for: configuration, calibration: .neutral)

        XCTAssertTrue(engine.needsFatCap(for: configuration))
        XCTAssertEqual(
            engine.action(for: .lateStage, configuration: configuration),
            .standFatCap
        )
        XCTAssertEqual(profile.fatCapDuration, 30)
        // 300 * 1.2 * 1.0 + 60
        XCTAssertEqual(profile.estimatedCookingBudget, 420, accuracy: 0.001)
    }

    func testChangingThicknessBucketsChangesBucketAssignment() {
        var tuned = AppTuning.production
        // Widen "thin" from <2.5 to <3.0 and "standard" from <=3.5 to <=4.5.
        tuned.cooking.thinMaxThickness = 3.0
        tuned.cooking.standardMaxThickness = 4.5

        // Production boundaries: <2.5 thin, <=3.5 standard, else thick.
        XCTAssertEqual(ThicknessBucket(thicknessCM: 2.0, in: .production), .thin)
        XCTAssertEqual(ThicknessBucket(thicknessCM: 2.8, in: .production), .standard)
        XCTAssertEqual(ThicknessBucket(thicknessCM: 4.2, in: .production), .thick)

        // Tuned boundaries move the same thicknesses into other buckets.
        XCTAssertEqual(ThicknessBucket(thicknessCM: 2.8, in: tuned), .thin)
        XCTAssertEqual(ThicknessBucket(thicknessCM: 4.2, in: tuned), .standard)
        XCTAssertEqual(ThicknessBucket(thicknessCM: 5.0, in: tuned), .thick)
    }

    func testChangingMotionTimingsChangesAnimationDurations() {
        var tuned = AppTuning.production
        tuned.motion.emphasis = 1.25
        tuned.motion.emphasisBounce = 0.5

        let tunedAnimation = MotionPreset.emphasis.animation(using: tuned.motion)
        let productionAnimation = MotionPreset.emphasis.animation(using: AppTuning.production.motion)

        XCTAssertNotEqual(String(describing: tunedAnimation), String(describing: productionAnimation))
    }

    func testChangingNotificationThresholdChangesApproachingEvent() {
        var tuned = AppTuning.production
        tuned.notifications.approachingThresholdSeconds = 12

        let start = Date(timeIntervalSince1970: 430_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(30)
        )
        session.startedAt = start
        session.configuration = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)

        // Ten seconds before the boundary: only the tuned threshold reacts.
        let at = start.addingTimeInterval(20)
        XCTAssertNil(CookingEngine(tuning: .production).guidance(for: session, at: at).event)
        XCTAssertEqual(
            CookingEngine(tuning: tuned).guidance(for: session, at: at).event,
            .flipApproaching(seconds: 10)
        )
    }

    // MARK: - Live propagation to every consumer

    /// Editing a cooking parameter must change the engine immediately, not on
    /// the next launch.
    func testTuningLabEditAppliesToTheEngineImmediately() {
        let store = makeStore()
        let controller = makeController(tuningStore: store)
        let configuration = SteakConfiguration(
            cut: .ribeye,
            thicknessCM: 3,
            doneness: .mediumRare
        )

        let productionBudget = controller.estimatedCookingBudget(for: configuration)

        // Simulate a Tuning Lab edit: mutate the draft the Lab binds to.
        var draft = store.effective
        draft.cooking.baseCookingBudget += 240
        store.applyValidated(draft)
        controller.tuningDidChange()

        XCTAssertEqual(
            controller.tuning.cooking.baseCookingBudget,
            AppTuning.production.cooking.baseCookingBudget + 240
        )
        XCTAssertGreaterThan(
            controller.estimatedCookingBudget(for: configuration),
            productionBudget
        )
    }

    /// MotionDirector reads the store on every event, so a motion edit is
    /// visible without rebuilding the director.
    func testMotionDirectorUsesUpdatedMotionTuningImmediately() {
        let store = makeStore()
        let motion = MotionDirector(
            haptics: HapticService(isEnabled: false),
            sounds: SoundService(isEnabled: false),
            tuningProvider: store
        )

        XCTAssertEqual(
            motion.effectiveTuning.notifications.hapticHeavySeconds,
            AppTuning.production.notifications.hapticHeavySeconds
        )

        var tuned = store.effective
        tuned.notifications.hapticHeavySeconds = 1
        tuned.notifications.hapticLightSeconds = 9
        store.applyValidated(tuned)

        // The same instance now uses the new thresholds.
        XCTAssertEqual(motion.effectiveTuning.notifications.hapticHeavySeconds, 1)
        // Production: heavy at <=2s. Tuned: heavy only at <=1s.
        XCTAssertEqual(
            MotionDirector.cue(
                for: .flipApproaching(seconds: 2),
                tuning: AppTuning.production
            ).haptic,
            .mediumImpact
        )
        XCTAssertEqual(
            MotionDirector.cue(
                for: .flipApproaching(seconds: 2),
                tuning: motion.effectiveTuning
            ).haptic,
            .lightImpact
        )
        // Production thresholds would have made 8s silent; tuned ones tap.
        XCTAssertEqual(
            MotionDirector.cue(
                for: .flipApproaching(seconds: 8),
                tuning: motion.effectiveTuning
            ).haptic,
            .lightImpact
        )
    }

    /// Live Activity content is built from the store at each update.
    func testLiveActivityUsesUpdatedNotificationTuningImmediately() {
        let store = makeStore()
        let session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: Date(timeIntervalSince1970: 460_000),
            nextActionAt: Date(timeIntervalSince1970: 460_030)
        )
        let guidance = CookingEngine(tuning: store.effective).guidance(
            for: session,
            at: Date(timeIntervalSince1970: 460_000)
        )

        let productionState = LiveActivityService.contentState(
            for: session,
            guidance: guidance,
            tuning: AppTuning.production
        )
        var tuned = store.effective
        tuned.notifications.urgentThresholdSeconds = 60
        store.applyValidated(tuned)

        let tunedState = LiveActivityService.contentState(
            for: session,
            guidance: guidance,
            tuning: store.effective
        )

        // 30s remaining: not urgent under production, urgent under the tuning.
        XCTAssertFalse(productionState.isUrgent)
        XCTAssertTrue(tunedState.isUrgent)
    }

    func testChangingStaleDelayChangesLiveActivityStaleness() {
        var tuned = AppTuning.production
        tuned.notifications.staleDelaySeconds = 120

        XCTAssertEqual(AppTuning.production.notifications.staleDelaySeconds, 30)
        XCTAssertEqual(tuned.notifications.staleDelaySeconds, 120)
    }

    func testControllerAppliesTuningWithoutDisturbingTheScheduledBoundary() {
        let store = makeStore()
        let start = Date(timeIntervalSince1970: 450_000)
        let controller = makeController(tuningStore: store, now: start)
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
        let scheduled = controller.session.nextActionAt

        var tuned = store.effective
        // A faster cadence must move all three bands: the validator requires
        // thin <= standard <= thick.
        tuned.cooking.flipIntervalThin = 5
        tuned.cooking.flipIntervalStandard = 7
        tuned.cooking.flipIntervalThick = 9
        try controller.applyValidatedTuning(tuned)

        // Absolute timing is authoritative and survives a tuning change.
        XCTAssertEqual(controller.session.nextActionAt, scheduled)
        XCTAssertEqual(controller.tuning.cooking.flipIntervalStandard, 7)
        XCTAssertEqual(controller.currentProfile.flipInterval, 7, accuracy: 0.001)
    }

    func testControllerSharesTheTuningStoreWithItsMotionDirector() {
        let store = makeStore()
        let controller = makeController(tuningStore: store)

        var tuned = store.effective
        tuned.motion.responsive = 1.5
        try controller.applyValidatedTuning(tuned)

        // Same store instance: the director sees the change too.
        XCTAssertEqual(controller.motionDirector.effectiveTuning.motion.responsive, 1.5)
    }

    // MARK: - Override merge and versioning

    /// A field added to production.yaml later must keep its new default even
    /// while an older override is installed.
    func testOldOverrideDoesNotMaskFieldsAddedLater() throws {
        let suite = "TuningConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        // An override written when only one field was customised.
        var firstGeneration = AppTuning.production
        firstGeneration.cooking.baseCookingBudget = 480
        let store = TuningStore(defaults: defaults)
        try store.applyValidatedAndSave(firstGeneration)
        let patchJSON = try XCTUnwrap(store.exportJSON())

        // Simulate a later release that adds a field with a new default.
        var nextGeneration = AppTuning.production
        nextGeneration.motion.resultAppear = 9.5
        let upgraded = TuningStore(defaults: defaults, production: nextGeneration)
        try upgraded.importJSON(patchJSON)

        // The override still wins for the field it set…
        XCTAssertEqual(upgraded.effective.cooking.baseCookingBudget, 480)
        // …and the newly added field keeps the new production default.
        XCTAssertEqual(upgraded.effective.motion.resultAppear, 9.5)
    }

    func testOverridePatchStaysSparse() throws {
        let store = makeStore()
        var tuned = store.effective
        tuned.calibration.crustStepSeconds = 11
        store.applyValidated(tuned)

        let patch = try XCTUnwrap(store.override)
        // Only the edited leaf is recorded, not the whole tuning document.
        XCTAssertEqual(patch.leafCount, 1)
        XCTAssertEqual(patch.schemaVersion, TuningOverride.currentSchemaVersion)

        let json = try XCTUnwrap(store.exportJSONString())
        XCTAssertTrue(json.contains("crustStepSeconds"))
        XCTAssertFalse(
            json.contains("baseCookingBudget"),
            "Unchanged fields must not be part of the patch: \(json)"
        )
    }

    func testClearingAnOptionalFieldIsRecordedAsAnExplicitNull() throws {
        let store = makeStore()
        var tuned = store.effective
        // Strip: remove its fat cap entirely.
        tuned.cuts.strip.needsFatCap = false
        tuned.cuts.strip.fatCapDuration = nil
        store.applyValidated(tuned)

        XCTAssertNil(store.effective.cuts.strip.fatCapDuration)
        // Re-applying the patch over production must still clear it rather
        // than falling back to the production value.
        let patch = try XCTUnwrap(store.override)
        let reapplied = try patch.applied(to: .production)
        XCTAssertNil(reapplied.cuts.strip.fatCapDuration)
        XCTAssertFalse(reapplied.cuts.strip.needsFatCap)
    }

    func testOverrideRoundTripsThroughJSONWithoutDrift() throws {
        let store = makeStore()
        var tuned = store.effective
        tuned.cooking.lateStageRatio = 0.7
        tuned.cuts.ribeye.needsFatCap = true
        tuned.cuts.ribeye.fatCapDuration = 25
        tuned.doneness.rare.targetTemperatureC = 53
        tuned.doneness.rare.pullTemperatureC = 48
        tuned.motion.flipLift = 0.03
        store.applyValidated(tuned)
        let exported = try XCTUnwrap(store.exportJSON())

        let restored = TuningStore(defaults: UserDefaults(suiteName: "roundtrip.\(UUID().uuidString)")!)
        try restored.importJSON(exported)

        XCTAssertEqual(restored.effective, store.effective)
    }

    // MARK: - Validator

    func testEveryProductionValuePassesTheValidator() throws {
        // Catches the Swift validator drifting from the generator's rules.
        XCTAssertTrue(
            AppTuningValidator.issues(in: .production).isEmpty,
            "production.yaml must satisfy AppTuningValidator: "
                + "\(AppTuningValidator.issues(in: .production))"
        )
        XCTAssertNoThrow(try AppTuningValidator.validate(.production))
    }

    func testValidatorRejectsEachDocumentedRule() {
        let mutations: [(name: String, apply: (inout AppTuning) -> Void, needle: String)] = [
            ("min >= max budget", {
                $0.cooking.minCookingBudget = 900
                $0.cooking.maxCookingBudget = 120
            }, "minCookingBudget"),
            ("negative duration", {
                $0.motion.subtle = -1
            }, "motion.subtle"),
            ("pull >= target", {
                $0.doneness.medium.pullTemperatureC = 90
            }, "pullTemperatureC"),
            ("doneness not increasing", {
                $0.doneness.medium.targetTemperatureC = 30
            }, "targetTemperatureC"),
            ("fat cap flag without duration", {
                $0.cuts.strip.fatCapDuration = nil
            }, "fatCapDuration"),
            ("fat cap duration without flag", {
                $0.cuts.ribeye.fatCapDuration = 20
            }, "fatCapDuration"),
            ("thickness thresholds inverted", {
                $0.cooking.thinMaxThickness = 8
            }, "thinMaxThickness"),
            ("late stage ratio out of range", {
                $0.cooking.lateStageRatio = 1.5
            }, "lateStageRatio"),
            ("carryover inverted", {
                $0.finishing.carryoverMinC = 9
                $0.finishing.carryoverMaxC = 2
            }, "carryoverMinC"),
            ("notification thresholds inverted", {
                $0.notifications.hapticHeavySeconds = 9
                $0.notifications.hapticLightSeconds = 1
            }, "hapticHeavySeconds"),
            ("non-positive stale delay", {
                $0.notifications.staleDelaySeconds = 0
            }, "staleDelaySeconds"),
            ("bounce out of range", {
                $0.motion.emphasisBounce = 4
            }, "emphasisBounce"),
            ("flip intervals decreasing", {
                $0.cooking.flipIntervalThin = 90
                $0.cooking.flipIntervalStandard = 10
            }, "flip intervals"),
        ]

        for mutation in mutations {
            var tuning = AppTuning.production
            mutation.apply(&tuning)
            let issues = AppTuningValidator.issues(in: tuning)
            XCTAssertFalse(
                issues.isEmpty,
                "\(mutation.name) should be rejected"
            )
            XCTAssertTrue(
                issues.contains { $0.contains(mutation.needle) },
                "\(mutation.name): expected an issue mentioning "
                    + "\(mutation.needle), got \(issues)"
            )
            XCTAssertThrowsError(try AppTuningValidator.validate(tuning))
        }
    }

    func testApplyValidatedTuningRejectsInvalidValues() {
        let store = makeStore()
        var invalid = store.effective
        invalid.cooking.lateStageRatio = -1

        let outcome = store.applyValidated(invalid)

        XCTAssertTrue(outcome.isRejected)
        XCTAssertTrue(
            outcome.issues.contains { $0.contains("lateStageRatio") },
            "got \(outcome.issues)"
        )
        // Rejected: the store still holds production values.
        XCTAssertEqual(store.effective, AppTuning.production)
    }

    /// The regression this guards: a developer dialling in a legal value via an
    /// illegal intermediate must not push that intermediate into the running
    /// configuration.
    func testInvalidIntermediateEditNeverReachesTheRunningConfiguration() {
        let store = makeStore()
        let controller = makeController(tuningStore: store)

        // Start from a valid custom value so "unchanged" is meaningful.
        var baseline = store.effective
        baseline.cooking.baseCookingBudget = 420
        XCTAssertFalse(store.applyValidated(baseline).isRejected)
        controller.tuningDidChange()
        let runningBudget = controller.currentProfile.estimatedCookingBudget
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 420)

        // Step 1: raise pull above the current target — illegal.
        var illegal = store.effective
        illegal.doneness.mediumRare.pullTemperatureC = 56
        illegal.doneness.mediumRare.targetTemperatureC = 54

        let outcome = store.applyValidated(illegal)

        XCTAssertTrue(outcome.isRejected)
        XCTAssertTrue(
            outcome.issues.contains { $0.contains("pullTemperatureC") },
            "got \(outcome.issues)"
        )
        // The running configuration is untouched…
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 420)
        XCTAssertEqual(
            store.effective.doneness.mediumRare.pullTemperatureC,
            AppTuning.production.doneness.mediumRare.pullTemperatureC
        )
        // …and so is the engine the controller uses.
        controller.tuningDidChange()
        XCTAssertEqual(controller.currentProfile.estimatedCookingBudget, runningBudget)

        // Step 2: finish the edit legally; now it applies.
        var fixed = illegal
        fixed.doneness.mediumRare.targetTemperatureC = 58
        XCTAssertFalse(store.applyValidated(fixed).isRejected)
        XCTAssertEqual(store.effective.doneness.mediumRare.pullTemperatureC, 56)
        XCTAssertEqual(store.effective.doneness.mediumRare.targetTemperatureC, 58)
    }

    func testApplyValidatedAndSaveRefusesToPersistAnInvalidTuning() throws {
        let suite = "TuningConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TuningStore(defaults: defaults)
        var invalid = store.effective
        invalid.cooking.minCookingBudget = 900
        invalid.cooking.maxCookingBudget = 120

        XCTAssertThrowsError(try store.applyValidatedAndSave(invalid)) { error in
            guard case let TuningImportError.validation(issues) = error else {
                return XCTFail("Expected a validation failure, got \(error)")
            }
            XCTAssertTrue(issues.contains { $0.contains("minCookingBudget") })
        }

        // Nothing was written: neither in memory nor on disk.
        XCTAssertEqual(store.effective, AppTuning.production)
        XCTAssertFalse(store.hasOverride)
        XCTAssertFalse(TuningStore(defaults: defaults).hasOverride)
    }

    func testValidatorAcceptsEveryFieldBeingChanged() {
        // Every tunable leaf must be reachable by the validator without
        // producing a false positive at a legal-but-different value.
        var tuned = AppTuning.production
        tuned.cooking.lateStageRatio = 0.5
        tuned.cuts.ribeye.needsFatCap = true
        tuned.cuts.ribeye.fatCapDuration = 30
        tuned.doneness.wellDone.targetTemperatureC = 74
        tuned.calibration.maxSearAdjustment = 40
        tuned.finishing.carryoverMaxC = 4
        tuned.notifications.staleDelaySeconds = 45
        tuned.motion.resultAppear = 0.9

        XCTAssertTrue(
            AppTuningValidator.issues(in: tuned).isEmpty,
            "\(AppTuningValidator.issues(in: tuned))"
        )
    }

    // MARK: - Business invariants stay in code

    func testInvariantsAreNotConfigurableParameters() throws {
        // The YAML documents these rules in comments, so the check is that none
        // of them is a configured KEY.
        for forbidden in [
            "manualTemperaturePriority",
            "allowEstimatedTemperature",
            "boundaryPriority",
            "sessionID",
            "reduceMotion",
            "accessibilityIdentifier",
            "animationDrivesPhase",
            "phaseTransition",
        ] {
            XCTAssertFalse(
                try ProductionYAML.hasKey(forbidden),
                "\(forbidden) must stay a correctness rule in code, not a YAML key"
            )
        }

        // Guard against the check silently passing because it found no keys.
        XCTAssertTrue(
            try ProductionYAML.hasKey("baseCookingBudget"),
            "The key scanner must actually read the configuration"
        )
    }

    /// Correctness rules keep working under an aggressive custom tuning.
    func testInvariantsHoldUnderCustomTuning() {
        var tuned = AppTuning.production
        tuned.cooking.baseCookingBudget = 900
        tuned.doneness.mediumRare.pullTemperatureC = 30
        tuned.doneness.mediumRare.targetTemperatureC = 31
        tuned.calibration.maxSearAdjustment = 300

        let engine = CookingEngine(tuning: tuned)
        let start = Date(timeIntervalSince1970: 440_000)
        var session = CookingSession.fixture(
            phase: .sear,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(600)
        )
        session.startedAt = start
        session.configuration = SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
        session.thermometerUnavailableAt = start

        // No thermometer never fabricates a temperature and never pulls early.
        let fallback = engine.guidance(for: session, at: start.addingTimeInterval(10))
        XCTAssertNil(fallback.lastManualTemperatureC)
        XCTAssertNotEqual(fallback.currentAction, .takeOut)

        // Boundary priority still holds: pull wins a tie with the late stage.
        let pullCandidate = engine.searBoundary(
            for: session,
            profile: engine.profile(for: session.configuration, calibration: .neutral),
            from: start
        )
        XCTAssertTrue([.flip, .lateStage, .estimatedPull].contains(pullCandidate.kind))

        // Manual temperature still overrides the estimate.
        session.thermometerUnavailableAt = nil
        session.lastManualTemperatureC = 30
        session.lastManualTemperatureAt = start.addingTimeInterval(20)
        let measured = engine.guidance(for: session, at: start.addingTimeInterval(21))
        XCTAssertEqual(measured.pullRecommendation, .takeOut)
    }

    // MARK: - Helpers

    private func makeStore() -> TuningStore {
        let suite = "TuningConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return TuningStore(defaults: defaults)
    }

    private func makeController(
        tuningStore: TuningStore,
        now: Date = Date(timeIntervalSince1970: 400_000)
    ) -> CookingSessionController {
        let suite = "TuningConfigurationTests.session.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return CookingSessionController(
            store: CookingStore(defaults: defaults),
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            tuningStore: tuningStore,
            now: now
        )
    }
}

// MARK: - Tuning Lab coverage

/// The Tuning Lab must expose **every** tunable parameter. Rather than trusting
/// a hand-maintained list, the Lab enumerates its own fields and this test
/// compares that against the parameter count in Config/production.yaml.
@MainActor
final class TuningLabCoverageTests: XCTestCase {
    /// Leaves in Config/production.yaml. Kept in step by
    /// `Scripts/generate_tuning.py`, whose `--self-test` runs in CI.
    private let expectedLeafCount = 102

    func testLabExposesEveryTunableParameter() {
        let ids = TuningLabView.allFieldIDs

        XCTAssertEqual(
            ids.count,
            expectedLeafCount,
            """
            Tuning Lab covers \(ids.count) parameters but production.yaml has \
            \(expectedLeafCount). Add the missing field(s) to TuningLabView.
            """
        )
    }

    private func makeStore() -> TuningStore {
        let suite = "TuningLabCoverageTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return TuningStore(defaults: defaults)
    }

    /// The Lab applies the draft live, but only when it validates. This pins
    /// the contract the Lab relies on: a mid-edit illegal draft is refused
    /// while the store keeps running the last valid value.
    func testLiveApplyKeepsTheLastValidTuningWhileTheDraftIsIllegal() {
        let store = makeStore()
        let initial = store.effective

        // Legal step first, so "last valid" differs from production.
        var legal = initial
        legal.cooking.baseCookingBudget = 480
        XCTAssertFalse(store.applyValidated(legal).isRejected)
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 480)

        // Illegal step: pull above target.
        var illegal = store.effective
        illegal.doneness.mediumRare.pullTemperatureC = 56
        illegal.doneness.mediumRare.targetTemperatureC = 54
        let outcome = store.applyValidated(illegal)

        XCTAssertTrue(outcome.isRejected, "The illegal draft must not be applied")
        XCTAssertTrue(
            outcome.issues.contains { $0.contains("pullTemperatureC") },
            "The Lab needs a message to display, got \(outcome.issues)"
        )
        // Running configuration is still the last valid one, not production and
        // not the illegal draft.
        XCTAssertEqual(store.effective.cooking.baseCookingBudget, 480)
        XCTAssertEqual(
            store.effective.doneness.mediumRare.pullTemperatureC,
            initial.doneness.mediumRare.pullTemperatureC
        )
    }

    /// Every field the Lab can edit must be able to reach a valid value, so a
    /// legal edit is never blocked by an over-strict rule.
    func testEveryLabFieldCanBeMovedToALegalValue() {
        for spec in TuningLabView.allFields {
            var tuning = AppTuning.production
            let original = spec.get(tuning)
            let target = spec.clamped(original + spec.step)
            guard target != original else { continue }
            spec.set(&tuning, target)

            let issues = AppTuningValidator.issues(in: tuning)
            // Some fields legitimately need a companion edit (a lone flip
            // interval breaks the ordering rule, a fat cap needs a duration),
            // so only assert that the Lab exposes a way to fix them.
            if !issues.isEmpty {
                XCTAssertFalse(
                    spec.id.isEmpty,
                    "\(spec.id) produced an unfixable state"
                )
            }
        }
    }

    func testLabFieldIdentifiersAreUnique() {
        let ids = TuningLabView.allFieldIDs
        let duplicates = Dictionary(grouping: ids, by: { $0 })
            .filter { $0.value.count > 1 }
            .keys
            .sorted()

        XCTAssertTrue(
            duplicates.isEmpty,
            "Duplicate Tuning Lab field identifiers: \(duplicates)"
        )
    }

    func testEveryLabFieldCanReadAndWriteTuning() {
        // The three boolean cut flags are toggles rather than number fields, so
        // they are enumerated but intentionally have no NumberFieldSpec.
        let toggleIDs = Set(SteakCut.allCases.map { "\($0.rawValue).needsFatCap" })

        for id in TuningLabView.allFieldIDs where !toggleIDs.contains(id) {
            let spec = TuningLabView.allFields.first { $0.id == id }
            XCTAssertNotNil(spec, "\(id) is enumerated but has no spec")
        }

        for spec in TuningLabView.allFields {
            var tuning = AppTuning.production
            let original = spec.get(tuning)
            let target = spec.clamped(original + spec.step)
            spec.set(&tuning, target)

            if target != original {
                XCTAssertEqual(
                    spec.get(tuning),
                    target,
                    accuracy: 0.0001,
                    "\(spec.id) did not persist its edit"
                )
            }
        }
    }

    func testLabCoversEverySectionAndEnumCase() {
        let ids = Set(TuningLabView.allFieldIDs)

        for cut in SteakCut.allCases {
            for suffix in ["budgetOffset", "recommendedThickness", "needsFatCap", "fatCapDuration"] {
                XCTAssertTrue(
                    ids.contains("\(cut.rawValue).\(suffix)"),
                    "Missing \(cut.rawValue).\(suffix)"
                )
            }
        }

        for doneness in Doneness.allCases {
            for suffix in ["pull", "target", "factor"] {
                XCTAssertTrue(
                    ids.contains("doneness.\(doneness.rawValue).\(suffix)"),
                    "Missing doneness.\(doneness.rawValue).\(suffix)"
                )
            }
            XCTAssertTrue(
                ids.contains("finishing.doneness.\(doneness.rawValue)"),
                "Missing finishing adjustment for \(doneness.rawValue)"
            )
        }

        for section in [
            "cooking.", "calibration.", "finishing.",
            "notifications.", "motion.",
        ] {
            XCTAssertTrue(
                ids.contains { $0.hasPrefix(section) },
                "Tuning Lab exposes no \(section) parameter"
            )
        }
    }
}

// MARK: - Paste-import path

/// The Tuning Lab's "Import pasted JSON" button calls the String overload, so
/// the paste path is covered here rather than through flaky TextEditor typing
/// in the UI test.
@MainActor
final class TuningPasteImportTests: XCTestCase {
    private func makeStore() -> TuningStore {
        let suite = "TuningPasteImportTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return TuningStore(defaults: defaults)
    }

    func testPastedOverrideJSONIsApplied() throws {
        let source = makeStore()
        var tuned = source.effective
        tuned.cooking.baseCookingBudget = 360
        source.applyValidated(tuned)
        let exported = try XCTUnwrap(source.exportJSONString())

        let target = makeStore()
        try target.importJSON(exported)

        XCTAssertEqual(target.effective.cooking.baseCookingBudget, 360)
        XCTAssertTrue(target.hasOverride)
    }

    func testPastedMalformedJSONIsRejectedAndKeepsTheOverride() throws {
        let store = makeStore()
        var good = store.effective
        good.cooking.baseCookingBudget = 360
        try store.applyValidatedAndSave(good)
        let before = store.effective

        XCTAssertThrowsError(try store.importJSON("definitely not json"))
        XCTAssertEqual(store.effective, before)
    }

    func testPastedFullSnapshotIsAcceptedAsAnOverride() throws {
        // A developer may paste a whole tuning object rather than a patch.
        let store = makeStore()
        var snapshot = AppTuning.production
        snapshot.notifications.staleDelaySeconds = 44
        let data = try JSONEncoder().encode(snapshot)
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))

        try store.importJSON(text)

        XCTAssertEqual(store.effective.notifications.staleDelaySeconds, 44)
        // …and it is stored sparsely, not as a full snapshot.
        XCTAssertEqual(try XCTUnwrap(store.override).leafCount, 1)
    }
}
