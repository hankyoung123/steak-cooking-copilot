import Foundation

/// App-wide preferences, as opposed to the per-cook setup held in
/// `SteakSetupPreferences`.
///
/// ## Why the hidden set, not the visible one
///
/// Storing what is **hidden** rather than what is **shown** is deliberate:
///
/// * an empty set means "everything visible", so a fresh install and every
///   existing user get today's behaviour with no migration at all;
/// * a cut added to the app in a later release is visible by default, instead of
///   being invisible to everyone who ever opened this screen.
///
/// ## Hiding is not deleting
///
/// Hiding a cut is a display filter. Its saved doneness/thickness, the
/// adjustments it has learned, and its cook history all stay exactly where they
/// are, and reappear untouched when it is shown again.
struct AppPreferences: Codable, Equatable, Sendable {
    /// Cuts the user has chosen not to see on the setup screen.
    private(set) var hiddenCuts: Set<SteakCut>

    /// Whether the app may schedule cooking reminders.
    var isNotificationsEnabled: Bool
    /// Whether the app plays its cooking cues.
    var isSoundEnabled: Bool
    /// Whether the app produces haptic feedback.
    var isHapticsEnabled: Bool

    static let standard = AppPreferences()

    init(
        hiddenCuts: Set<SteakCut> = [],
        isNotificationsEnabled: Bool = true,
        isSoundEnabled: Bool = true,
        isHapticsEnabled: Bool = true
    ) {
        self.hiddenCuts = Self.sanitised(hiddenCuts)
        self.isNotificationsEnabled = isNotificationsEnabled
        self.isSoundEnabled = isSoundEnabled
        self.isHapticsEnabled = isHapticsEnabled
    }

    // MARK: - Reading

    /// The cuts to show, in canonical order. Never empty: the setup screen must
    /// always have something to display, even if the stored value is damaged.
    var visibleCuts: [SteakCut] {
        let visible = SteakCut.allCases.filter { !hiddenCuts.contains($0) }
        return visible.isEmpty ? SteakCut.allCases : visible
    }

    func isVisible(_ cut: SteakCut) -> Bool {
        !hiddenCuts.contains(cut)
    }

    // MARK: - Writing

    /// Whether this cut may be hidden without emptying the setup screen.
    ///
    /// Hiding an already-hidden cut is always allowed — it is a no-op rather
    /// than a rejected action, so a repeated toggle cannot fail confusingly.
    func canHide(_ cut: SteakCut) -> Bool {
        guard isVisible(cut) else { return true }
        return visibleCuts.count > 1
    }

    /// Shows or hides a cut. Returns `false` when the change was refused because
    /// it would hide the last visible cut.
    @discardableResult
    mutating func setCut(_ cut: SteakCut, visible: Bool) -> Bool {
        if visible {
            hiddenCuts.remove(cut)
        } else {
            guard canHide(cut) else { return false }
            hiddenCuts.insert(cut)
        }
        hiddenCuts = Self.sanitised(hiddenCuts)
        return true
    }

    // MARK: - Selection

    /// Where the setup screen's selection should land when `cut` is no longer on
    /// screen: the nearest visible cut at or after it in the canonical order,
    /// otherwise the last visible one.
    ///
    /// Deterministic on purpose — "whichever the set happened to yield" would
    /// make the screen land somewhere different on each launch, and the home
    /// layout regression test depends on this being reproducible.
    func selection(startingFrom cut: SteakCut) -> SteakCut {
        let visible = visibleCuts
        guard !visible.contains(cut) else { return cut }

        let order = SteakCut.allCases
        guard let index = order.firstIndex(of: cut) else { return visible[0] }
        return visible.first { candidate in
            (order.firstIndex(of: candidate) ?? 0) >= index
        } ?? visible[visible.count - 1]
    }

    // MARK: - Coding

    private enum CodingKeys: String, CodingKey {
        case hiddenCuts
        case isNotificationsEnabled
        case isSoundEnabled
        case isHapticsEnabled
    }

    /// Decodes both shapes this type has had.
    ///
    /// The first release stored the hidden set on its own; the toggles turned it
    /// into an object. Reading the bare set first means an install that predates
    /// the toggles keeps its hidden cuts and simply gains the defaults for
    /// everything else, with no migration step and no second storage key.
    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let legacyHiddenCuts = try? single.decode(Set<SteakCut>.self) {
            self.init(hiddenCuts: legacyHiddenCuts)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            hiddenCuts: try container.decodeIfPresent(
                Set<SteakCut>.self,
                forKey: .hiddenCuts
            ) ?? [],
            isNotificationsEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isNotificationsEnabled
            ) ?? true,
            isSoundEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isSoundEnabled
            ) ?? true,
            isHapticsEnabled: try container.decodeIfPresent(
                Bool.self,
                forKey: .isHapticsEnabled
            ) ?? true
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hiddenCuts, forKey: .hiddenCuts)
        try container.encode(isNotificationsEnabled, forKey: .isNotificationsEnabled)
        try container.encode(isSoundEnabled, forKey: .isSoundEnabled)
        try container.encode(isHapticsEnabled, forKey: .isHapticsEnabled)
    }

    /// Refuses to persist a set that would hide every cut.
    private static func sanitised(_ hidden: Set<SteakCut>) -> Set<SteakCut> {
        var value = hidden.filter { SteakCut.allCases.contains($0) }
        if value.count >= SteakCut.allCases.count, let keep = SteakCut.allCases.first {
            value.remove(keep)
        }
        return value
    }
}

/// Live access to the app-wide preferences.
///
/// Mirrors `TuningProviding`: the feedback and notification services read this on
/// every use rather than capturing a snapshot, so a switch flipped in Settings
/// takes effect on the very next cue instead of at the next launch.
@MainActor
protocol AppPreferencesProviding: AnyObject {
    var preferences: AppPreferences { get }
}

/// Fixed preferences, for tests and previews.
@MainActor
final class StaticAppPreferencesProvider: AppPreferencesProviding {
    let preferences: AppPreferences

    init(_ preferences: AppPreferences = .standard) {
        self.preferences = preferences
    }
}
