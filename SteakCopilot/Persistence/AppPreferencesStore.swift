import Foundation
import Observation

/// Persistence for the app-wide preferences.
///
/// Mirrors `CookingStore`'s `UserDefaults` + JSON shape but stays separate,
/// because these are app settings rather than cooking data: clearing a session
/// or a calibration must never disturb them, and vice versa.
///
/// Observable, and a `AppPreferencesProviding`, so the settings screen, the
/// feedback services and the notification service all read one live value
/// instead of three snapshots taken at launch.
@MainActor
@Observable
final class AppPreferencesStore: AppPreferencesProviding {
    private enum Key {
        static let preferences = "steak.preferences.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var preferences: AppPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preferences = Self.load(from: defaults)
    }

    func update(_ newValue: AppPreferences) {
        preferences = newValue
        guard let data = try? encoder.encode(newValue) else { return }
        defaults.set(data, forKey: Key.preferences)
    }

    func reset() {
        defaults.removeObject(forKey: Key.preferences)
        preferences = .standard
    }

    private static func load(from defaults: UserDefaults) -> AppPreferences {
        guard let data = defaults.data(forKey: Key.preferences),
              let stored = try? JSONDecoder().decode(AppPreferences.self, from: data)
        else { return .standard }
        return stored
    }
}
