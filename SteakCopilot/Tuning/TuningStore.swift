import Foundation
import Observation

/// The runtime override chain for production parameters.
///
///     ProductionTuning.production     (generated from Config/production.yaml)
///                 ↓
///     local override (Codable JSON)   development only, never shipped
///                 ↓
///     effective                       what the app actually runs on
///
/// The override is stored as JSON (never YAML) and only ever replaces fields
/// the developer changed: `resetToProduction()` simply drops it, so the
/// generated production values remain the single source of defaults.
@MainActor
@Observable
final class TuningStore {
    private enum Key {
        static let override = "steak.tuning.override.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Generated production defaults. Never edited in Swift.
    let production: AppTuning
    /// Local development override, or nil when running production values.
    private(set) var override: AppTuning?

    init(
        defaults: UserDefaults = .standard,
        production: AppTuning = .production
    ) {
        self.defaults = defaults
        self.production = production
        self.override = Self.decodeOverride(
            defaults.data(forKey: Key.override),
            decoder: JSONDecoder()
        )
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    /// Effective tuning used by the engine.
    var effective: AppTuning { override ?? production }

    /// True while a local override is active.
    var hasOverride: Bool { override != nil }

    /// Applies an override in memory (does not persist).
    func apply(_ tuning: AppTuning) {
        override = tuning
    }

    /// Persists the current override.
    func save() {
        guard let override else {
            defaults.removeObject(forKey: Key.override)
            return
        }
        guard let data = try? encoder.encode(override) else { return }
        defaults.set(data, forKey: Key.override)
    }

    /// Applies and persists in one step.
    func applyAndSave(_ tuning: AppTuning) {
        override = tuning
        save()
    }

    /// Drops the override and returns to the generated production defaults.
    func resetToProduction() {
        override = nil
        defaults.removeObject(forKey: Key.override)
    }

    /// Exports the current override as JSON for sharing/inspection.
    func exportJSON() -> Data? {
        try? encoder.encode(effective)
    }

    /// Imports an override from JSON. Returns false when the payload does not
    /// decode as a complete tuning document.
    @discardableResult
    func importJSON(_ data: Data) -> Bool {
        guard let decoded = Self.decodeOverride(data, decoder: decoder) else {
            return false
        }
        override = decoded
        return true
    }

    private static func decodeOverride(
        _ data: Data?,
        decoder: JSONDecoder
    ) -> AppTuning? {
        guard let data else { return nil }
        return try? decoder.decode(AppTuning.self, from: data)
    }
}
