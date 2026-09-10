import Foundation

/// A JSON value, used to carry a sparse tuning patch.
///
/// The override is stored as JSON (never YAML). Keeping it as a real JSON value
/// tree — instead of a second full `AppTuning` snapshot — is what makes a
/// partial override possible: only the fields a developer touched are written
/// down, so adding a new field to `Config/production.yaml` later cannot be
/// masked by an old override.
enum TuningJSONValue: Codable, Equatable, Sendable {
    case object([String: TuningJSONValue])
    case array([TuningJSONValue])
    case number(Double)
    case string(String)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let value = try? container.decode([TuningJSONValue].self) {
            self = .array(value)
            return
        }
        if let value = try? container.decode([String: TuningJSONValue].self) {
            self = .object(value)
            return
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unsupported JSON value in tuning override"
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

extension TuningJSONValue {
    /// Encodes any `Encodable` into a JSON value tree.
    static func encoding(_ value: some Encodable) throws -> TuningJSONValue {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        return try decoder.decode(TuningJSONValue.self, from: encoder.encode(value))
    }

    /// Decodes this tree back into a model type.
    func decoding<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(self))
    }
}

/// A versioned, sparse override of the production tuning.
///
///     Production Defaults (production.yaml)
///             ↓  merge patch over production
///     Validated Local Override
///             ↓
///     Effective Tuning
///
/// `patch` contains only the leaves that differ from production. Merging is a
/// deep object merge, so:
///
///   * fields the patch does not mention keep the production value — an older
///     override cannot resurrect a stale default for a field added later;
///   * a field explicitly set to `null` (for example `fatCapDuration`) is
///     cleared rather than silently ignored;
///   * keys the current model no longer knows about are ignored by the decoder.
struct TuningOverride: Codable, Equatable, Sendable {
    /// Bumped when the patch layout itself changes. A patch written by a newer
    /// build is rejected rather than silently misinterpreted.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var patch: [String: TuningJSONValue]

    init(
        schemaVersion: Int = TuningOverride.currentSchemaVersion,
        patch: [String: TuningJSONValue]
    ) {
        self.schemaVersion = schemaVersion
        self.patch = patch
    }

    /// Number of leaves the override changes, for developer feedback.
    var leafCount: Int {
        Self.leafCount(of: patch)
    }

    var isEmpty: Bool { patch.isEmpty }

    /// Builds a patch describing how `effective` differs from `production`.
    /// Returns nil when nothing differs.
    static func make(
        production: AppTuning,
        effective: AppTuning
    ) throws -> TuningOverride? {
        guard production != effective else { return nil }
        let base = try TuningJSONValue.encoding(production)
        let target = try TuningJSONValue.encoding(effective)
        guard case let .object(baseObject) = base,
              case let .object(targetObject) = target
        else {
            throw TuningOverrideError.unexpectedShape
        }
        guard let patch = diff(base: baseObject, target: targetObject) else {
            return nil
        }
        return TuningOverride(patch: patch)
    }

    /// Deep-merges this patch over the given production tuning.
    func applied(to production: AppTuning) throws -> AppTuning {
        guard schemaVersion <= Self.currentSchemaVersion else {
            throw TuningOverrideError.unsupportedSchemaVersion(schemaVersion)
        }
        let base = try TuningJSONValue.encoding(production)
        let merged = Self.merge(base: base, patch: patch)
        return try merged.decoding(AppTuning.self)
    }

    // MARK: - Internals

    private static func diff(
        base: [String: TuningJSONValue],
        target: [String: TuningJSONValue]
    ) -> [String: TuningJSONValue]? {
        var patch: [String: TuningJSONValue] = [:]

        for (key, targetValue) in target {
            guard let baseValue = base[key] else {
                patch[key] = targetValue
                continue
            }
            if case let .object(baseObject) = baseValue,
               case let .object(targetObject) = targetValue {
                if let nested = diff(base: baseObject, target: targetObject) {
                    patch[key] = .object(nested)
                }
                continue
            }
            if baseValue != targetValue {
                patch[key] = targetValue
            }
        }

        // A key present in production but absent from the target is an explicit
        // removal (the encoder omits nil optionals), so record it as null.
        for key in base.keys where target[key] == nil {
            patch[key] = .null
        }

        return patch.isEmpty ? nil : patch
    }

    private static func merge(
        base: TuningJSONValue,
        patch: [String: TuningJSONValue]
    ) -> TuningJSONValue {
        guard case var .object(object) = base else {
            return .object(patch)
        }
        for (key, patchValue) in patch {
            if case let .object(nestedPatch) = patchValue,
               case let .object(nestedBase)? = object[key] {
                object[key] = merge(base: .object(nestedBase), patch: nestedPatch)
            } else {
                object[key] = patchValue
            }
        }
        return .object(object)
    }

    private static func leafCount(of patch: [String: TuningJSONValue]) -> Int {
        patch.values.reduce(into: 0) { count, value in
            if case let .object(nested) = value {
                count += leafCount(of: nested)
            } else {
                count += 1
            }
        }
    }
}

enum TuningOverrideError: Error, Equatable {
    case unexpectedShape
    case unsupportedSchemaVersion(Int)
}
