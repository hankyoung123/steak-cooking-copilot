import Foundation

/// App-wide preferences, as opposed to the per-cook setup held in
/// `SteakSetupPreferences`.
///
/// Only one preference exists so far — which cuts appear on the setup screen —
/// but sound, haptics and notifications will land here too.
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

    static let standard = AppPreferences()

    init(hiddenCuts: Set<SteakCut> = []) {
        self.hiddenCuts = Self.sanitised(hiddenCuts)
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

    /// Encoded as a bare set, so the stored document stays readable.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(hiddenCuts: try container.decode(Set<SteakCut>.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hiddenCuts)
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
