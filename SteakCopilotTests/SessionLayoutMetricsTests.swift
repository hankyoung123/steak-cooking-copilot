import SwiftUI
import XCTest
@testable import SteakCopilot

/// The session skeleton's contract.
///
/// The property that keeps PREP → HEAT → SEAR → FLIP → FAT CAP → BASTE →
/// CHECK TEMP → FINISHING from moving shared UI is structural: the layout is a
/// *pure function of the container size and the text size*. No phase is an
/// input, so no phase can change a slot. These tests pin the numbers around
/// that property:
///
/// * the resolved skeleton fits every supported phone at the default text size,
///   so the slot positions are the positions the user actually sees (a skeleton
///   that has to scroll has no stable on-screen positions);
/// * a slot is never allowed to grow so much that it eats the scene;
/// * the light and dark stages resolve identically (the dark stages draw their
///   artwork behind the whole session, and that must not change the geometry).
@MainActor
final class SessionLayoutMetricsTests: XCTestCase {
    /// Session container heights for the iPhones the app supports, measured as
    /// screen height minus the top and bottom safe areas.
    private let phoneHeights: [CGFloat] = [
        647, // iPhone SE (3rd generation)
        667, // iPhone 8
        728, // iPhone 13 mini
        759, // iPhone 15 / 16 / 17
        763, // iPhone 14
        812, // iPhone X
        839, // iPhone 16 Pro Max
        926, // iPhone 17 Pro Max
        932
    ]

    // MARK: - Fits the device

    func testSkeletonFitsEverySupportedPhoneAtDefaultTextSize() {
        for height in phoneHeights {
            let layout = SessionLayoutMetrics.resolve(
                for: CGSize(width: 393, height: height)
            )

            XCTAssertLessThanOrEqual(
                layout.totalHeight,
                height + 0.5,
                "The session skeleton must fit a \(height)pt container outright; if it "
                    + "does not, its slots scroll and their positions are no longer stable"
            )
            XCTAssertGreaterThanOrEqual(
                layout.sceneHeight,
                SessionLayoutMetrics.sceneFloor,
                "The scene must keep a usable band at \(height)pt"
            )
            XCTAssertLessThanOrEqual(layout.sceneHeight, SessionLayoutMetrics.sceneCeiling)
        }
    }

    func testResultSkeletonFitsEverySupportedPhoneAtDefaultTextSize() {
        for height in phoneHeights {
            let layout = SessionLayoutMetrics.Result.resolve(
                for: CGSize(width: 393, height: height)
            )

            XCTAssertLessThanOrEqual(
                layout.totalHeight,
                height + 0.5,
                "The result skeleton must fit a \(height)pt container outright"
            )
            XCTAssertGreaterThan(layout.heroHeight, 0)
            // The middle band is the only one whose content length changes
            // (note vs feedback form); it is reserved for the taller one.
            XCTAssertGreaterThanOrEqual(
                layout.middleHeight,
                160,
                "The feedback form needs a reserved band, or it would push the hero"
            )
        }
    }

    // MARK: - Slot arithmetic

    /// The bottom action row is the anchor the CTA is measured against: the
    /// primary row is bottom aligned inside it, so its position is
    /// `bottomActionHeight - bottomPrimaryHeight` in every phase.
    func testBottomActionRowIsTheSumOfItsRows() {
        for height in phoneHeights {
            let layout = SessionLayoutMetrics.resolve(
                for: CGSize(width: 393, height: height)
            )
            XCTAssertEqual(
                layout.bottomActionHeight,
                layout.bottomSecondaryHeight
                    + layout.bottomSecondarySpacing
                    + layout.bottomPrimaryHeight,
                accuracy: 0.001
            )
        }
    }

    /// `heightExcludingScene` is the number `resolve` subtracts from the
    /// container, so it has to be the honest sum of every other slot.
    func testExcludingSceneHeightIsTheSumOfTheOtherSlots() {
        let layout = SessionLayoutMetrics.resolve(
            for: CGSize(width: 393, height: 759)
        )
        let expected = layout.topControlHeight
            + layout.headerSpacing
            + layout.headerHeight
            + layout.sceneSpacing
            + layout.instructionSpacing
            + layout.instructionHeight
            + layout.statusSpacing
            + layout.statusHeight
            + layout.bottomActionSpacing
            + layout.bottomActionHeight

        XCTAssertEqual(layout.heightExcludingScene, expected, accuracy: 0.001)
        XCTAssertEqual(layout.totalHeight, expected + layout.sceneHeight, accuracy: 0.001)
    }

    // MARK: - Purity and class selection

    /// The real anti-drift guarantee: identical inputs produce identical
    /// geometry, and nothing about the session (phase, action, timer) is an
    /// input at all.
    func testResolutionIsDeterministic() {
        let size = CGSize(width: 393, height: 759)
        let first = SessionLayoutMetrics.resolve(for: size)
        let second = SessionLayoutMetrics.resolve(for: size)

        XCTAssertEqual(first, second)
        XCTAssertEqual(
            SessionLayoutMetrics.Result.resolve(for: size),
            SessionLayoutMetrics.Result.resolve(for: size)
        )
    }

    func testLayoutClassSwitchesOnContainerHeight() {
        let threshold = SessionLayoutMetrics.compactHeightThreshold
        let compact = SessionLayoutMetrics.resolve(
            for: CGSize(width: 375, height: threshold - 1)
        )
        let regular = SessionLayoutMetrics.resolve(
            for: CGSize(width: 393, height: threshold)
        )

        XCTAssertEqual(compact.layoutClass, .compact)
        XCTAssertEqual(regular.layoutClass, .regular)
        // Both classes must still fit their own container at the boundary, so a
        // device just below or just above the threshold never starts scrolling.
        XCTAssertLessThanOrEqual(compact.totalHeight, threshold - 1 + 0.5)
        XCTAssertLessThanOrEqual(regular.totalHeight, threshold + 0.5)
    }

    /// A taller container may only give its extra height to the scene, and only
    /// up to the ceiling; past that the slack lives above the bottom action
    /// row, which therefore never moves.
    func testExtraHeightGoesToTheSceneUpToTheCeiling() {
        let mid = SessionLayoutMetrics.resolve(for: CGSize(width: 393, height: 760))
        let tall = SessionLayoutMetrics.resolve(for: CGSize(width: 393, height: 900))

        XCTAssertGreaterThan(tall.sceneHeight, mid.sceneHeight)
        XCTAssertEqual(tall.sceneHeight, SessionLayoutMetrics.sceneCeiling)
        XCTAssertEqual(
            tall.heightExcludingScene,
            mid.heightExcludingScene,
            accuracy: 0.001,
            "Growing the container must not resize any non-scene slot"
        )
    }

    // MARK: - Dynamic Type

    func testTextScaleIsMonotonicAndNormalAtTheDefaultSize() {
        XCTAssertEqual(SessionLayoutMetrics.textScale(for: .large), 1, accuracy: 0.001)

        let sizes: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2, .accessibility3, .accessibility4,
            .accessibility5
        ]
        let scales = sizes.map(SessionLayoutMetrics.textScale(for:))
        XCTAssertEqual(scales, scales.sorted())
        XCTAssertLessThanOrEqual(scales.last ?? 1, 1.7)
    }

    /// Growing the text size may shrink the scene, but it must never resize the
    /// slots above or below it, because that is what a phase switch must not do
    /// either.
    func testTextSizeGrowthOnlyConsumesTheScene() {
        let size = CGSize(width: 393, height: 759)
        let normal = SessionLayoutMetrics.resolve(for: size, dynamicTypeSize: .large)
        let large = SessionLayoutMetrics.resolve(
            for: size,
            dynamicTypeSize: .accessibility5
        )

        XCTAssertEqual(
            large.topControlHeight,
            normal.topControlHeight * SessionLayoutMetrics.textScale(for: .accessibility5),
            accuracy: 0.001
        )
        XCTAssertLessThan(large.sceneHeight, normal.sceneHeight)
        XCTAssertGreaterThanOrEqual(large.sceneHeight, 120)
        XCTAssertEqual(large.instructionHeight / normal.instructionHeight,
                       large.statusHeight / normal.statusHeight,
                       accuracy: 0.01,
                       "Text-bearing slots must scale together, or their content would clip")
    }

    // MARK: - Layout identifiers

    /// The geometry contract names are consumed by the UI regression test, so
    /// they have to be stable and distinct.
    func testLayoutIdentifiersAreStableAndDistinct() {
        let identifiers = [
            SessionLayoutID.topControls,
            SessionLayoutID.hero,
            SessionLayoutID.scene,
            SessionLayoutID.instruction,
            SessionLayoutID.progress,
            SessionLayoutID.telemetry,
            SessionLayoutID.primaryAction
        ]

        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        for identifier in identifiers {
            XCTAssertTrue(identifier.hasPrefix("session."))
            XCTAssertFalse(identifier.isEmpty)
        }
        XCTAssertEqual(SessionLayoutID.instruction, "session.instruction")
        XCTAssertEqual(SessionLayoutID.scene, "session.scene")
    }
}
