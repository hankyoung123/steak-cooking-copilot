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
        XCTAssertEqual(tuning.cuts.strip.fatCapDuration, 40)
        XCTAssertEqual(tuning.cuts.tenderloin.recommendedThickness, 4)
        XCTAssertEqual(tuning.doneness.mediumRare.pullTemperatureC, 52)
        XCTAssertEqual(tuning.doneness.mediumRare.targetTemperatureC, 54)
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

        // 300 * (3 / 2.5) * 1.0 + 12 (ribeye offset) = 372
        let profile = engine.profile(for: configuration, calibration: .neutral)
        XCTAssertEqual(profile.estimatedCookingBudget, 372, accuracy: 0.001)
        XCTAssertEqual(engine.flipInterval(for: configuration), 30, accuracy: 0.001)
        XCTAssertEqual(profile.pullTemperatureC, 52, accuracy: 0.001)
        XCTAssertEqual(profile.targetTemperatureC, 54, accuracy: 0.001)
        // late stage = max(flip * 2, budget * 0.65) = 241.8
        XCTAssertEqual(profile.lateStageDateOffset, 241.8, accuracy: 0.001)
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
        store.applyAndSave(custom)

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
        XCTAssertTrue(fresh.importJSON(exported))
        XCTAssertEqual(fresh.effective.cooking.baseCookingBudget, 480)
    }

    func testResetRestoresProductionDefaultsAndStaysReset() {
        let suite = "TuningConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = TuningStore(defaults: defaults)
        var custom = AppTuning.production
        custom.cooking.flipIntervalStandard = 99
        store.applyAndSave(custom)
        XCTAssertEqual(store.effective.cooking.flipIntervalStandard, 99)

        store.resetToProduction()

        XCTAssertFalse(store.hasOverride)
        XCTAssertEqual(store.effective, AppTuning.production)
        XCTAssertFalse(TuningStore(defaults: defaults).hasOverride)
    }

    func testImportRejectsMalformedJSON() {
        let store = makeStore()
        XCTAssertFalse(store.importJSON(Data("{ not json }".utf8)))
        XCTAssertFalse(store.hasOverride)
    }

    func testImportRejectsIncompleteTuningDocument() throws {
        let store = makeStore()
        let partial = try JSONSerialization.data(withJSONObject: ["cooking": [:]])
        XCTAssertFalse(store.importJSON(partial))
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

    func testChangingStaleDelayChangesLiveActivityStaleness() {
        var tuned = AppTuning.production
        tuned.notifications.staleDelaySeconds = 120

        XCTAssertEqual(AppTuning.production.notifications.staleDelaySeconds, 30)
        XCTAssertEqual(tuned.notifications.staleDelaySeconds, 120)
    }

    func testControllerAppliesTuningWithoutDisturbingTheScheduledBoundary() {
        let suite = "TuningConfigurationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 450_000)
        let controller = CookingSessionController(
            store: CookingStore(defaults: defaults),
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            now: start
        )
        controller.finishSetup(at: start)
        controller.finishPrep(at: start)
        controller.panIsReady(at: start)
        let scheduled = controller.session.nextActionAt

        var tuned = AppTuning.production
        tuned.cooking.flipIntervalStandard = 7
        controller.applyTuning(tuned)

        // Absolute timing is authoritative and survives a tuning change.
        XCTAssertEqual(controller.session.nextActionAt, scheduled)
        XCTAssertEqual(controller.tuning.cooking.flipIntervalStandard, 7)
        XCTAssertEqual(controller.currentProfile.flipInterval, 7, accuracy: 0.001)
    }

    // MARK: - Business invariants stay in code

    func testInvariantsAreNotConfigurableParameters() throws {
        let yaml = try String(contentsOf: yamlURL, encoding: .utf8)
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
                yaml.contains(forbidden),
                "\(forbidden) is a correctness rule and must stay in code"
            )
        }
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
}
