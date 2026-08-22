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
        static let calibration = "steak.calibration.v1"
        static let feedback = "steak.feedback.v1"
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

    func loadCalibration() -> CookingCalibration {
        decode(CookingCalibration.self, forKey: Key.calibration) ?? .neutral
    }

    func save(calibration: CookingCalibration) {
        encode(calibration, forKey: Key.calibration)
    }

    func loadFeedback() -> [FeedbackRecord] {
        decode([FeedbackRecord].self, forKey: Key.feedback) ?? []
    }

    func append(feedback: FeedbackRecord) {
        var records = loadFeedback()
        records.append(feedback)
        encode(records, forKey: Key.feedback)
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
