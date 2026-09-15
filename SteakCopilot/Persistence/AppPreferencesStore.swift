import Foundation

/// Persistence for the app-wide preferences.
///
/// Mirrors `CookingStore`'s `UserDefaults` + JSON shape but stays separate,
/// because these are app settings rather than cooking data: clearing a session
/// or a calibration must never disturb them, and vice versa.
struct AppPreferencesStore {
    private enum Key {
        static let preferences = "steak.preferences.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppPreferences {
        guard let data = defaults.data(forKey: Key.preferences),
              let stored = try? decoder.decode(AppPreferences.self, from: data)
        else { return .standard }
        return stored
    }

    func save(_ preferences: AppPreferences) {
        guard let data = try? encoder.encode(preferences) else { return }
        defaults.set(data, forKey: Key.preferences)
    }

    func reset() {
        defaults.removeObject(forKey: Key.preferences)
    }
}
