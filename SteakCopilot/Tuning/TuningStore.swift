import Foundation
import Observation

/// Anything that can hand out the currently effective tuning.
///
/// Consumers (motion, Live Activity) hold a *provider*, never an `AppTuning`
/// snapshot, so a change made in the Tuning Lab is picked up on the next read
/// instead of requiring every service to be rebuilt.
@MainActor
protocol TuningProviding: AnyObject {
    var effective: AppTuning { get }
}

/// A fixed provider, for tests and for consumers built before a live store
/// exists.
@MainActor
final class StaticTuningProvider: TuningProviding {
    var tuning: AppTuning

    init(tuning: AppTuning = .production) {
        self.tuning = tuning
    }

    var effective: AppTuning { tuning }
}

/// Result of attempting to apply an edited tuning.
///
/// A rejected apply is an expected outcome while a developer is mid-edit (for
/// example raising `pullTemperatureC` before lowering `targetTemperatureC`),
/// so it is a value rather than an error: the previous effective tuning stays
/// in force and the issues are surfaced in the UI.
enum TuningApplyOutcome: Equatable {
    case applied
    case rejected([String])

    var isRejected: Bool {
        if case .rejected = self { return true }
        return false
    }

    var issues: [String] {
        if case let .rejected(issues) = self { return issues }
        return []
    }
}

/// Reasons an imported override can be rejected.
enum TuningImportError: LocalizedError, Equatable {
    case malformedJSON(String)
    case schemaVersion(Int)
    case validation([String])

    var errorDescription: String? {
        switch self {
        case let .malformedJSON(detail):
            "The JSON could not be read as a tuning override: \(detail)"
        case let .schemaVersion(version):
            "This override was written by a newer build (schema \(version))."
        case let .validation(issues):
            "The override is not valid:\n" + issues.joined(separator: "\n")
        }
    }

    var issues: [String] {
        switch self {
        case let .validation(issues): issues
        case let .malformedJSON(detail): [detail]
        case let .schemaVersion(version): ["unsupported schema version \(version)"]
        }
    }
}

/// The runtime override chain for production parameters.
///
///     ProductionTuning.production     (generated from Config/production.yaml)
///                 ↓
///     validated, versioned override   sparse patch, JSON, development only
///                 ↓
///     effective                       what the app actually runs on
///
/// The override is a `TuningOverride` patch, not a second full snapshot, so a
/// field added to `production.yaml` later keeps its new default even when an
/// older override is still installed. Every path that changes the override
/// validates first; a rejected override leaves the previous one untouched.
@MainActor
@Observable
final class TuningStore: TuningProviding {
    private enum Key {
        static let override = "steak.tuning.override.v1"
    }

    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    /// Generated production defaults. Never edited in Swift.
    let production: AppTuning
    /// Sparse, validated override, or nil when running production values.
    private(set) var override: TuningOverride?
    /// The tuning every consumer actually reads.
    private(set) var effective: AppTuning
    /// True when the current override is the one persisted on disk.
    private(set) var isPersisted = false

    init(
        defaults: UserDefaults = .standard,
        production: AppTuning = .production
    ) {
        self.defaults = defaults
        self.production = production
        self.effective = production
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder

        if let data = defaults.data(forKey: Key.override) {
            // A stored override that no longer validates (or was written by a
            // newer schema) is ignored rather than breaking the app.
            if let restored = try? Self.restore(
                data: data,
                production: production
            ) {
                override = restored
                effective = (try? restored.applied(to: production)) ?? production
                isPersisted = true
            }
        }
    }

    // MARK: - State

    var hasOverride: Bool { override?.isEmpty == false }

    /// How many leaves the override changes, for developer feedback.
    var overriddenFieldCount: Int { override?.leafCount ?? 0 }

    var stateDescription: String {
        guard hasOverride else { return "production" }
        return isPersisted ? "override (saved)" : "override (unsaved)"
    }

    // MARK: - Mutation

    /// Validates then applies a tuning in memory (does not persist).
    ///
    /// Every write into the store goes through here, so an unusable tuning can
    /// never become the effective one. On rejection nothing changes and the
    /// issues are returned for the caller to display.
    @discardableResult
    func applyValidated(_ tuning: AppTuning) -> TuningApplyOutcome {
        let issues = AppTuningValidator.issues(in: tuning)
        guard issues.isEmpty else {
            return .rejected(issues)
        }
        set(tuning)
        return .applied
    }

    /// Validates, applies and persists in one step. Throws on rejection so a
    /// caller cannot accidentally store an invalid configuration.
    func applyValidatedAndSave(_ tuning: AppTuning) throws {
        let issues = AppTuningValidator.issues(in: tuning)
        guard issues.isEmpty else {
            throw TuningImportError.validation(issues)
        }
        set(tuning)
        save()
    }

    /// Persists the current override.
    func save() {
        guard let override, !override.isEmpty else {
            defaults.removeObject(forKey: Key.override)
            isPersisted = false
            return
        }
        guard let data = try? encoder.encode(override) else { return }
        defaults.set(data, forKey: Key.override)
        isPersisted = true
    }

    /// The one place `effective` is written. Private because callers must go
    /// through a validating entry point.
    private func set(_ tuning: AppTuning) {
        guard let patch = try? TuningOverride.make(
            production: production,
            effective: tuning
        ) else {
            // No difference from production: an empty override and production
            // are the same thing.
            override = nil
            effective = production
            isPersisted = false
            return
        }
        override = patch
        effective = tuning
        // Editing a saved override makes it unsaved again; only a patch that
        // matches what is on disk counts as persisted.
        isPersisted = persistedOverride == patch
    }

    /// Drops the override and returns to the generated production defaults.
    func resetToProduction() {
        override = nil
        effective = production
        isPersisted = false
        defaults.removeObject(forKey: Key.override)
    }

    // MARK: - Import / export

    /// Exports the active override as a versioned patch document. An empty
    /// patch is exported as an empty document so the shape is discoverable.
    func exportJSON() -> Data? {
        let document = override ?? TuningOverride(patch: [:])
        return try? encoder.encode(document)
    }

    func exportJSONString() -> String? {
        exportJSON().flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Imports an override document (or a full tuning snapshot).
    ///
    /// The candidate is merged over production and validated. On any failure
    /// the existing override is left untouched and the error is returned.
    func importJSON(_ data: Data) throws {
        let candidate = try Self.decodeCandidate(data, production: production)
        let merged = try candidate.applied(to: production)
        // Same validated write path as every other mutation, so an imported
        // document cannot bypass the checks.
        let outcome = applyValidated(merged)
        guard !outcome.isRejected else {
            throw TuningImportError.validation(outcome.issues)
        }
        // Keep the imported patch shape rather than re-deriving it.
        override = candidate
        isPersisted = false
    }

    func importJSON(_ text: String) throws {
        guard let data = text.data(using: .utf8) else {
            throw TuningImportError.malformedJSON("not valid UTF-8")
        }
        try importJSON(data)
    }

    // MARK: - Internals

    private var persistedOverride: TuningOverride? {
        guard let data = defaults.data(forKey: Key.override) else { return nil }
        return try? decoder.decode(TuningOverride.self, from: data)
    }

    /// Accepts either a versioned patch document or a full `AppTuning`
    /// snapshot (in which case the patch is derived by diffing).
    private static func decodeCandidate(
        _ data: Data,
        production: AppTuning
    ) throws -> TuningOverride {
        let decoder = JSONDecoder()
        if let document = try? decoder.decode(TuningOverride.self, from: data) {
            guard document.schemaVersion <= TuningOverride.currentSchemaVersion else {
                throw TuningImportError.schemaVersion(document.schemaVersion)
            }
            return document
        }
        if let snapshot = try? decoder.decode(AppTuning.self, from: data) {
            return try TuningOverride.make(
                production: production,
                effective: snapshot
            ) ?? TuningOverride(patch: [:])
        }
        throw TuningImportError.malformedJSON(
            "expected a {schemaVersion, patch} document or a full tuning object"
        )
    }

    private static func restore(
        data: Data,
        production: AppTuning
    ) throws -> TuningOverride {
        let document = try JSONDecoder().decode(TuningOverride.self, from: data)
        guard document.schemaVersion <= TuningOverride.currentSchemaVersion else {
            throw TuningOverrideError.unsupportedSchemaVersion(
                document.schemaVersion
            )
        }
        let merged = try document.applied(to: production)
        // A corrupt or outdated stored override falls back to production.
        try AppTuningValidator.validate(merged)
        return document
    }
}
