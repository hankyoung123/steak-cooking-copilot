import Foundation

struct FeedbackRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let configuration: SteakConfiguration
    let doneness: DonenessFeedback
    let crust: CrustFeedback
}

struct CookingStore {
    private enum Key {
        static let session = "steak.session.v1"
        static let calibrations = "steak.calibrations.v2"
        static let feedback = "steak.feedback.v1"
        static let setupPreferences = "steak.setup.preferences.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSession() -> CookingSession? {
        decode(CookingSession.self, forKey: Key.session)
    }

    func save(session: CookingSession) {
        encode(session, forKey: Key.session)
    }

    func clearSession() {
        defaults.removeObject(forKey: Key.session)
    }

    func loadCalibrations() -> [CalibrationKey: CookingCalibration] {
        decode(
            [CalibrationKey: CookingCalibration].self,
            forKey: Key.calibrations
        ) ?? [:]
    }

    func loadCalibration(for key: CalibrationKey) -> CookingCalibration {
        loadCalibrations()[key] ?? .neutral
    }

    func save(calibration: CookingCalibration, for key: CalibrationKey) {
        var calibrations = loadCalibrations()
        calibrations[key] = calibration
        encode(calibrations, forKey: Key.calibrations)
    }

    func loadFeedback() -> [FeedbackRecord] {
        decode([FeedbackRecord].self, forKey: Key.feedback) ?? []
    }

    func append(feedback: FeedbackRecord) {
        var records = loadFeedback()
        records.append(feedback)
        encode(records, forKey: Key.feedback)
    }

    /// Falls back to the recommended setup for the cut, whose thickness comes
    /// from production tuning.
    func loadSetupPreferences(
        for cut: SteakCut,
        tuning: AppTuning = .production
    ) -> SteakSetupPreferences {
        let saved = decode(
            [SteakCut: SteakSetupPreferences].self,
            forKey: Key.setupPreferences
        ) ?? [:]
        return saved[cut] ?? .recommended(for: cut, tuning: tuning)
    }

    func save(setupPreferences: SteakSetupPreferences) {
        var saved = decode(
            [SteakCut: SteakSetupPreferences].self,
            forKey: Key.setupPreferences
        ) ?? [:]
        saved[setupPreferences.configuration.cut] = setupPreferences
        encode(saved, forKey: Key.setupPreferences)
    }

    private func encode<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private func decode<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
