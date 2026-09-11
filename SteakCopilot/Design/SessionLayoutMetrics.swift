import SwiftUI

/// Stable accessibility identifiers for the session skeleton.
///
/// These names are part of the layout contract: the layout regression tests
/// read the frame of each one and assert that it does not move when the
/// cooking phase changes.
enum SessionLayoutID {
    /// The top navigation row (back / phase title / step + skip).
    static let topControls = "session.topControls"
    /// The hero band: countdown or headline.
    static let hero = "session.hero"
    /// The stage artwork band.
    static let scene = "session.scene"
    /// The instruction band (title + optional detail).
    static let instruction = "session.instruction"
    /// The progress rail.
    static let progress = "session.progress"
    /// The temperature telemetry row.
    static let telemetry = "session.telemetry"
    /// The primary call to action.
    static let primaryAction = "session.primaryAction"
}

/// Stable accessibility identifiers for the result screen's skeleton
/// (READY → EAT → FEEDBACK). Separate from `SessionLayoutID` so a shared slot
/// can still be told apart in a test failure message.
enum ResultLayoutID {
    /// The top navigation row (back / eyebrow / skip).
    static let topControls = "result.topControls"
    /// The doneness eyebrow + headline band.
    static let title = "result.title"
    /// The sliced-steak hero band.
    static let hero = "result.hero"
    /// The temperature / time summary band.
    static let summary = "result.summary"
    /// The primary call to action.
    static let primaryAction = "result.primaryAction"
}

/// Geometry anchors for the two decorative slots.
///
/// A photograph and a progress rail carry no accessibility content on
/// purpose, so making them permanently visible to VoiceOver just to be
/// measurable would be a regression for real users. They only materialise as
/// accessibility elements when the app is launched with `-layoutProbes`,
/// which is what the layout regression tests pass. Every other slot keeps its
/// identifier in production.
enum SessionLayoutProbes {
    static let launchArgument = "-layoutProbes"

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }
}

private struct SessionLayoutProbeModifier: ViewModifier {
    let identifier: String

    func body(content: Content) -> some View {
        if SessionLayoutProbes.isEnabled {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

extension View {
    /// Marks a decorative fixed slot as a measurable geometry anchor for the
    /// layout regression tests. Inert unless `-layoutProbes` is passed.
    func sessionLayoutProbe(_ identifier: String) -> some View {
        modifier(SessionLayoutProbeModifier(identifier: identifier))
    }
}

/// One device-independent description of the session screen's vertical
/// skeleton.
///
/// ## Why this exists
///
/// The session screen used to be a `ScrollView` around a `VStack` of
/// intrinsically sized rows. Almost every phase changed the intrinsic height
/// of at least one row:
///
/// * the hero alternated between a 78pt countdown and a 40pt sentence,
///   and relied on `minHeight`, which does not stop a taller line from
///   pushing everything below it down;
/// * the instruction kept or dropped its detail line
///   (`minHeight: 52` vs `minHeight: 34`);
/// * CHECK TEMP inserted a temperature control *into the middle* of the
///   column, so the progress rail, the telemetry and the button all moved;
/// * FINISHING replaced the rail + telemetry with a taller card;
/// * PREP and HEAT ended with a different number of controls than the cook
///   phases, so the bottom of the page had no stable baseline at all.
///
/// Every one of those rows reflowed the rows after it. The elements
/// themselves were fine; their *positions* moved.
///
/// The fix is not per-phase padding. It is a fixed set of semantic slots
/// whose geometry depends only on the container size and the Dynamic Type
/// size, never on the phase, and whose *content* is what changes:
///
///     topControls    back / phase title / step + skip
///     hero           countdown or headline
///     scene          stage artwork
///     instruction    instruction title + optional detail
///     status         progress rail + telemetry / finishing card / reading entry
///     bottomAction   contextual secondary control + primary CTA
///
/// A phase may leave a slot empty or swap what is inside it; it may never
/// resize a slot. `resolve(for:dynamicTypeSize:)` is a pure function of its
/// arguments, so within one device and one text size every phase resolves to
/// identical geometry.
///
/// These are UI layout constants and are deliberately **not** in
/// `Config/production.yaml`: they are not cooking behaviour and must never be
/// tuned by a cooking parameter override.
struct SessionLayoutMetrics: Equatable, Sendable {
    enum LayoutClass: String, Equatable, Sendable {
        /// iPhone SE and the 12/13 mini, where the regular rhythm leaves no
        /// usable scene.
        case compact
        case regular
    }

    let layoutClass: LayoutClass

    // MARK: Horizontal rhythm

    /// Top navigation row inset.
    let screenInset: CGFloat
    /// Instruction / status / action inset.
    let contentInset: CGFloat
    /// Hero and scene inset.
    let sceneInset: CGFloat

    // MARK: Fixed vertical slots

    let topControlHeight: CGFloat
    let headerHeight: CGFloat
    let sceneHeight: CGFloat
    let instructionHeight: CGFloat
    let statusHeight: CGFloat

    // MARK: Fixed spacing between slots

    let headerSpacing: CGFloat
    let sceneSpacing: CGFloat
    let instructionSpacing: CGFloat
    let statusSpacing: CGFloat
    let bottomActionSpacing: CGFloat

    // MARK: Slot internals

    let progressRailHeight: CGFloat
    let statusContentSpacing: CGFloat
    let bottomPrimaryHeight: CGFloat
    let bottomSecondaryHeight: CGFloat
    let bottomSecondarySpacing: CGFloat

    /// The bottom area holds two fixed rows: the contextual secondary control
    /// (prep toggles, "no thermometer") and the primary call to action. The
    /// primary row is bottom aligned, so the CTA has one screen position in
    /// every phase — including the phases where the secondary row is empty.
    var bottomActionHeight: CGFloat {
        bottomSecondaryHeight + bottomSecondarySpacing + bottomPrimaryHeight
    }

    /// Height consumed by everything that is not the scene.
    var heightExcludingScene: CGFloat {
        topControlHeight
            + headerSpacing
            + headerHeight
            + sceneSpacing
            + instructionSpacing
            + instructionHeight
            + statusSpacing
            + statusHeight
            + bottomActionSpacing
            + bottomActionHeight
    }

    /// Height of the whole skeleton for this device.
    var totalHeight: CGFloat { heightExcludingScene + sceneHeight }
}

extension SessionLayoutMetrics {
    /// Below this container height the regular rhythm cannot fit a usable
    /// scene, so the compact rhythm is used instead.
    static let compactHeightThreshold: CGFloat = 700
    /// The scene never disappears entirely; below this the skeleton scrolls.
    static let sceneFloor: CGFloat = 150
    /// The scene never grows past this, so tablet-sized containers do not turn
    /// the hero photograph into the whole screen.
    static let sceneCeiling: CGFloat = 340

    static let regular = SessionLayoutMetrics(
        layoutClass: .regular,
        screenInset: 18,
        contentInset: 26,
        sceneInset: 22,
        topControlHeight: 42,
        headerHeight: 96,
        sceneHeight: 0,
        instructionHeight: 58,
        statusHeight: 112,
        headerSpacing: 10,
        sceneSpacing: 6,
        instructionSpacing: 14,
        statusSpacing: 14,
        bottomActionSpacing: 12,
        progressRailHeight: 12,
        statusContentSpacing: 10,
        bottomPrimaryHeight: 56,
        bottomSecondaryHeight: 46,
        bottomSecondarySpacing: 8
    )

    static let compact = SessionLayoutMetrics(
        layoutClass: .compact,
        screenInset: 18,
        contentInset: 24,
        sceneInset: 20,
        topControlHeight: 42,
        headerHeight: 80,
        sceneHeight: 0,
        instructionHeight: 58,
        statusHeight: 112,
        headerSpacing: 8,
        sceneSpacing: 4,
        instructionSpacing: 12,
        statusSpacing: 12,
        bottomActionSpacing: 10,
        progressRailHeight: 12,
        statusContentSpacing: 8,
        bottomPrimaryHeight: 56,
        bottomSecondaryHeight: 46,
        bottomSecondarySpacing: 8
    )

    /// Resolves the skeleton for a container. Pure: the phase is not an input,
    /// which is precisely why no phase can move a slot.
    static func resolve(
        for size: CGSize,
        dynamicTypeSize: DynamicTypeSize = .large
    ) -> SessionLayoutMetrics {
        let scale = textScale(for: dynamicTypeSize)
        let base = size.height < compactHeightThreshold ? compact : regular
        let scaled = base.scalingTextSlots(by: scale)
        // Even at the largest text sizes the scene keeps a floor; past that the
        // outer scroll view takes over rather than the slots overlapping.
        let floor = max(120, sceneFloor / scale)
        let available = max(size.height, 1) - scaled.heightExcludingScene
        return scaled.withSceneHeight(min(max(available, floor), sceneCeiling))
    }

    /// Slot heights grow with Dynamic Type, but the spacings are optical
    /// rhythm and stay put. Growth is capped so a huge text size shrinks the
    /// scene instead of pushing the CTA off screen.
    static func textScale(for size: DynamicTypeSize) -> CGFloat {
        let table: [(DynamicTypeSize, CGFloat)] = [
            (.xSmall, 0.94),
            (.small, 0.96),
            (.medium, 0.98),
            (.large, 1),
            (.xLarge, 1.07),
            (.xxLarge, 1.14),
            (.xxxLarge, 1.21),
            (.accessibility1, 1.30),
            (.accessibility2, 1.38),
            (.accessibility3, 1.46),
            (.accessibility4, 1.54),
            (.accessibility5, 1.62)
        ]
        var scale: CGFloat = 1
        for (candidate, value) in table where size >= candidate {
            scale = value
        }
        return scale
    }

    private func scalingTextSlots(by scale: CGFloat) -> SessionLayoutMetrics {
        guard scale != 1 else { return self }
        return SessionLayoutMetrics(
            layoutClass: layoutClass,
            screenInset: screenInset,
            contentInset: contentInset,
            sceneInset: sceneInset,
            topControlHeight: topControlHeight * scale,
            headerHeight: headerHeight * scale,
            sceneHeight: sceneHeight,
            instructionHeight: instructionHeight * scale,
            statusHeight: statusHeight * scale,
            headerSpacing: headerSpacing,
            sceneSpacing: sceneSpacing,
            instructionSpacing: instructionSpacing,
            statusSpacing: statusSpacing,
            bottomActionSpacing: bottomActionSpacing,
            progressRailHeight: progressRailHeight,
            statusContentSpacing: statusContentSpacing,
            bottomPrimaryHeight: bottomPrimaryHeight * scale,
            bottomSecondaryHeight: bottomSecondaryHeight * scale,
            bottomSecondarySpacing: bottomSecondarySpacing
        )
    }

    private func withSceneHeight(_ height: CGFloat) -> SessionLayoutMetrics {
        SessionLayoutMetrics(
            layoutClass: layoutClass,
            screenInset: screenInset,
            contentInset: contentInset,
            sceneInset: sceneInset,
            topControlHeight: topControlHeight,
            headerHeight: headerHeight,
            sceneHeight: height,
            instructionHeight: instructionHeight,
            statusHeight: statusHeight,
            headerSpacing: headerSpacing,
            sceneSpacing: sceneSpacing,
            instructionSpacing: instructionSpacing,
            statusSpacing: statusSpacing,
            bottomActionSpacing: bottomActionSpacing,
            progressRailHeight: progressRailHeight,
            statusContentSpacing: statusContentSpacing,
            bottomPrimaryHeight: bottomPrimaryHeight,
            bottomSecondaryHeight: bottomSecondaryHeight,
            bottomSecondarySpacing: bottomSecondarySpacing
        )
    }
}

extension SessionLayoutMetrics {
    /// The READY → EAT → FEEDBACK screen's skeleton.
    ///
    /// It deliberately reuses the session's top rule (control band, title band,
    /// insets, bottom action row) instead of inventing its own, so the top
    /// navigation and the bottom CTA keep one position across the whole flow.
    /// The upper bands are fixed; only the middle band changes content between
    /// the "how it went" note and the feedback form, and it scrolls inside
    /// itself rather than pushing the hero or the summary card.
    struct Result: Equatable, Sendable {
        let layoutClass: SessionLayoutMetrics.LayoutClass
        let screenInset: CGFloat
        let contentInset: CGFloat
        let sceneInset: CGFloat
        let topControlHeight: CGFloat
        let controlsSpacing: CGFloat
        let titleHeight: CGFloat
        let titleSpacing: CGFloat
        let heroHeight: CGFloat
        let heroSpacing: CGFloat
        let summaryHeight: CGFloat
        let summarySpacing: CGFloat
        let middleHeight: CGFloat
        let bottomActionSpacing: CGFloat
        let bottomSecondaryHeight: CGFloat
        let bottomPrimarySpacing: CGFloat
        let bottomPrimaryHeight: CGFloat

        var bottomActionHeight: CGFloat {
            bottomSecondaryHeight + bottomPrimarySpacing + bottomPrimaryHeight
        }

        var heightExcludingHero: CGFloat {
            topControlHeight
                + controlsSpacing
                + titleHeight
                + titleSpacing
                + heroSpacing
                + summaryHeight
                + summarySpacing
                + middleHeight
                + bottomActionSpacing
                + bottomActionHeight
        }

        var totalHeight: CGFloat { heightExcludingHero + heroHeight }

        fileprivate func withHeroHeight(_ height: CGFloat) -> Result {
            Result(
                layoutClass: layoutClass,
                screenInset: screenInset,
                contentInset: contentInset,
                sceneInset: sceneInset,
                topControlHeight: topControlHeight,
                controlsSpacing: controlsSpacing,
                titleHeight: titleHeight,
                titleSpacing: titleSpacing,
                heroHeight: height,
                heroSpacing: heroSpacing,
                summaryHeight: summaryHeight,
                summarySpacing: summarySpacing,
                middleHeight: middleHeight,
                bottomActionSpacing: bottomActionSpacing,
                bottomSecondaryHeight: bottomSecondaryHeight,
                bottomPrimarySpacing: bottomPrimarySpacing,
                bottomPrimaryHeight: bottomPrimaryHeight
            )
        }

        static func resolve(
            for size: CGSize,
            dynamicTypeSize: DynamicTypeSize = .large
        ) -> Result {
            let shared = SessionLayoutMetrics.resolve(
                for: size,
                dynamicTypeSize: dynamicTypeSize
            )
            let isCompact = shared.layoutClass == .compact
            let base = Result(
                layoutClass: shared.layoutClass,
                screenInset: shared.screenInset,
                contentInset: shared.contentInset,
                sceneInset: shared.sceneInset,
                topControlHeight: shared.topControlHeight,
                controlsSpacing: shared.headerSpacing,
                titleHeight: shared.headerHeight,
                titleSpacing: isCompact ? 10 : 14,
                heroHeight: 0,
                heroSpacing: isCompact ? 10 : 14,
                summaryHeight: isCompact ? 76 : 82,
                summarySpacing: isCompact ? 10 : 14,
                // Reserved for the feedback form, which is the tallest content
                // this band ever has to hold (~167pt at every text size, since
                // the form uses fixed editorial type).
                middleHeight: isCompact ? 168 : 190,
                bottomActionSpacing: shared.bottomActionSpacing,
                bottomSecondaryHeight: shared.bottomSecondaryHeight,
                bottomPrimarySpacing: shared.bottomSecondarySpacing,
                bottomPrimaryHeight: shared.bottomPrimaryHeight
            )
            let floor: CGFloat = isCompact ? 120 : 110
            let ceiling: CGFloat = 306
            let hero = min(max(size.height - base.heightExcludingHero, floor), ceiling)
            return base.withHeroHeight(hero)
        }
    }
}
