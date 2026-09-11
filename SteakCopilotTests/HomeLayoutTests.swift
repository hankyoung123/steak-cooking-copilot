import CoreGraphics
import SwiftUI
import UIKit
import XCTest
@testable import SteakCopilot

/// The setup screen skeleton's contract.
///
/// As with the session skeleton, the anti-drift property is structural: the
/// layout is a pure function of the container size, so the selected cut is not
/// an input and cannot move a band. These tests pin the arithmetic around that:
/// the resolved skeleton fills every supported phone, the hero absorbs the
/// leftover height, and the spacing tokens are the only vertical rhythm.
@MainActor
final class HomeLayoutTests: XCTestCase {
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

    func testSkeletonFillsEverySupportedPhoneWithoutScrolling() {
        for height in phoneHeights {
            let layout = HomeLayoutMetrics.resolve(
                for: CGSize(width: 393, height: height)
            )

            XCTAssertLessThanOrEqual(
                layout.totalHeight,
                height + 0.5,
                "The setup skeleton must fit a \(height)pt container"
            )
            XCTAssertGreaterThanOrEqual(
                layout.heroImageSide,
                150,
                "The artwork must stay the primary subject at \(height)pt"
            )
        }
    }

    /// The hero is the flexible slot: on a phone it must take exactly the height
    /// the fixed bands leave over, which is what keeps the call to action at one
    /// offset instead of leaving dead space at the bottom of the page.
    func testHeroAbsorbsTheLeftoverHeightExactly() {
        for height in phoneHeights {
            let layout = HomeLayoutMetrics.resolve(
                for: CGSize(width: 393, height: height)
            )
            let leftover = height - layout.heightExcludingHero
            let floor = layout.layoutClass == .compact
                ? HomeLayoutMetrics.compactHeroFloor
                : HomeLayoutMetrics.regularHeroFloor

            if leftover >= floor, leftover <= HomeLayoutMetrics.heroCeiling {
                XCTAssertEqual(
                    layout.heroHeight,
                    leftover,
                    accuracy: 0.001,
                    "At \(height)pt the hero should fill the leftover space exactly"
                )
                XCTAssertEqual(layout.totalHeight, height, accuracy: 0.001)
            } else {
                // Clamped: the hero has hit its floor or ceiling and the page no
                // longer fills the screen exactly.
                XCTAssertTrue(
                    layout.heroHeight == floor
                        || layout.heroHeight == HomeLayoutMetrics.heroCeiling,
                    """
                    At \(height)pt the hero was neither the leftover (\(leftover)) \
                    nor a clamp (floor \(floor), ceiling \
                    \(HomeLayoutMetrics.heroCeiling)): got \(layout.heroHeight)
                    """
                )
            }
        }
    }

    // MARK: - Purity

    /// The real guarantee: identical inputs give identical geometry, and the
    /// selected cut is not an input at all.
    func testResolutionIsDeterministicAndCutIndependent() {
        for height in phoneHeights {
            let size = CGSize(width: 393, height: height)
            XCTAssertEqual(
                HomeLayoutMetrics.resolve(for: size),
                HomeLayoutMetrics.resolve(for: size)
            )
        }

        // Nothing about the cut can reach the resolver: it takes only a size.
        let tall = HomeLayoutMetrics.resolve(for: CGSize(width: 393, height: 759))
        let short = HomeLayoutMetrics.resolve(for: CGSize(width: 393, height: 647))
        XCTAssertEqual(short.layoutClass, .compact)
        XCTAssertEqual(tall.layoutClass, .regular)
    }

    func testExcludingHeroHeightIsTheSumOfTheFixedBands() {
        let layout = HomeLayoutMetrics.resolve(for: CGSize(width: 393, height: 759))
        let expected = layout.topBarHeight
            + layout.heroToNavigation
            + layout.navigationHeight
            + layout.navigationToTitle
            + layout.titleHeight
            + layout.titleToPlan
            + layout.planHeight
            + layout.planToSummary
            + layout.summaryHeight
            + layout.summaryToPrimary
            + layout.primaryActionHeight
            + layout.primaryToSecondary
            + layout.secondaryActionHeight

        XCTAssertEqual(layout.heightExcludingHero, expected, accuracy: 0.001)
        XCTAssertEqual(
            layout.totalHeight,
            expected + layout.heroHeight,
            accuracy: 0.001
        )
    }

    /// The rhythm is deliberately grouped rather than uniform: the hero and the
    /// title form one composition, the parameter row and the summary form a
    /// second, and the call to action is set apart from both.
    func testVerticalRhythmGroupsTheCompositionAndSetsTheCTAApart() {
        for height in phoneHeights {
            let layout = HomeLayoutMetrics.resolve(
                for: CGSize(width: 393, height: height)
            )
            let gaps = [
                layout.heroToNavigation,
                layout.navigationToTitle,
                layout.titleToPlan,
                layout.planToSummary,
                layout.summaryToPrimary,
                layout.primaryToSecondary
            ]

            for gap in gaps {
                XCTAssertGreaterThanOrEqual(gap, 0, "Spacing cannot be negative")
            }

            // Hero → title is the tight end of the page.
            XCTAssertLessThanOrEqual(
                layout.heroToNavigation + layout.navigationToTitle,
                layout.titleToPlan,
                "The artwork and the title must read as one composition at \(height)pt"
            )

            // The parameter row and the summary are one group: the gap inside it
            // is tighter than the gap that separates the group from the CTA.
            XCTAssertLessThanOrEqual(
                layout.planToSummary,
                layout.summaryToPrimary,
                "The summary belongs with the parameters, not with the CTA"
            )

            // The CTA is the single strongest action and gets the most air.
            XCTAssertGreaterThanOrEqual(
                layout.summaryToPrimary,
                layout.navigationToTitle,
                "The CTA needs more air above it than the title does"
            )
        }
    }

    func testHeroImageSideAccountsForTheInset() {
        let layout = HomeLayoutMetrics.resolve(for: CGSize(width: 393, height: 759))
        XCTAssertEqual(
            layout.heroImageSide,
            min(
                layout.heroFrameWidth - layout.heroImageInset * 2,
                layout.heroHeight - layout.heroImageInset * 2
            ),
            accuracy: 0.001
        )
        XCTAssertGreaterThan(layout.heroImageSide, 0)
    }

    func testLayoutIdentifiersAreStableAndDistinct() {
        let identifiers = [
            HomeLayoutID.title,
            HomeLayoutID.planDoneness,
            HomeLayoutID.planThickness,
            HomeLayoutID.summary
        ]
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        for identifier in identifiers {
            XCTAssertTrue(identifier.hasPrefix("home."))
        }
        XCTAssertEqual(HomeLayoutID.title, "home.title")
        XCTAssertEqual(HomeLayoutID.planDoneness, "home.plan.doneness")
    }
}

/// The hero artwork's optical centring.
///
/// These are the tests that keep `SteakCut.heroOpticalOffset` a measurement
/// rather than a nudge: they read the alpha channel of the shipped assets and
/// fail if the constants stop describing them.
@MainActor
final class SessionAssetOpticalTests: XCTestCase {
    /// The alpha-weighted centroid of an asset, as a fraction of its width.
    private func centroidX(of assetName: String) throws -> CGFloat {
        let image = try XCTUnwrap(
            UIImage(named: assetName),
            "missing asset \(assetName)"
        )
        let cgImage = try XCTUnwrap(image.cgImage, "\(assetName) has no bitmap")
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let alphaInfo = cgImage.alphaInfo

        let data = try XCTUnwrap(
            cgImage.dataProvider?.data as Data?,
            "\(assetName) has no pixel data"
        )

        // Alpha is the last byte for `.last` / `.premultipliedLast` and the first
        // for `.first` / `.premultipliedFirst`. Anything else is a layout this
        // test does not know how to read, and silently assuming would make the
        // measurement meaningless, so it fails loudly.
        let alphaOffset: Int
        switch alphaInfo {
        case .premultipliedLast, .last: alphaOffset = bytesPerPixel - 1
        case .premultipliedFirst, .first: alphaOffset = 0
        default:
            XCTFail("\(assetName) has unsupported alpha layout \(alphaInfo.rawValue)")
            return 0.5
        }

        var weighted = 0.0
        var total = 0.0
        for y in 0..<height {
            let row = y * cgImage.bytesPerRow
            for x in 0..<width {
                let alpha = Double(data[row + x * bytesPerPixel + alphaOffset])
                guard alpha > 0 else { continue }
                weighted += Double(x) * alpha
                total += alpha
            }
        }

        XCTAssertGreaterThan(total, 0, "\(assetName) is fully transparent")
        return CGFloat(weighted / total / Double(width))
    }

    /// Every hero asset carries its weight to the right of centre, which is what
    /// justifies a leftward correction at all.
    func testHeroArtworkWeightSitsRightOfGeometricCentre() throws {
        for cut in SteakCut.allCases {
            let centroid = try centroidX(of: cut.heroAssetName)
            XCTAssertGreaterThan(
                centroid,
                0.5,
                """
                \(cut.rawValue) (\(cut.heroAssetName)) no longer sits right of \
                centre (measured \(centroid)); the optical offset may be stale
                """
            )
            XCTAssertLessThan(
                centroid,
                0.54,
                "\(cut.rawValue) is much further off centre than expected"
            )
        }
    }

    /// The declared correction must equal the negated measured offset, so the
    /// artwork actually ends up optically centred on screen.
    func testDeclaredOpticalOffsetMatchesTheMeasuredAssets() throws {
        for cut in SteakCut.allCases {
            let centroid = try centroidX(of: cut.heroAssetName)
            XCTAssertEqual(
                Double(cut.heroOpticalOffset),
                Double(0.5 - centroid),
                accuracy: 0.004,
                """
                \(cut.rawValue) declares \(cut.heroOpticalOffset) but the asset \
                measures \(0.5 - centroid)
                """
            )
        }
    }

    /// And the correction must stay an optical nudge: a few points on a phone,
    /// never a repositioning of the artwork.
    func testOpticalCorrectionStaysWithinAFewPoints() {
        let layout = HomeLayoutMetrics.resolve(for: CGSize(width: 393, height: 759))

        for cut in SteakCut.allCases {
            let points = abs(layout.heroImageSide * cut.heroOpticalOffset)
            XCTAssertLessThanOrEqual(
                points,
                8,
                "\(cut.rawValue) shifts \(points)pt, which is no longer optical"
            )
        }
    }

    /// Filet genuinely differs from the other two, which is the stated reason the
    /// correction is per cut rather than one shared value. If a future asset
    /// makes them equivalent, this fails and the table can be collapsed.
    func testFiletIsTheOnlyAssetThatNeedsADistinctCorrection() {
        XCTAssertGreaterThan(
            abs(SteakCut.tenderloin.heroOpticalOffset),
            abs(SteakCut.ribeye.heroOpticalOffset) * 1.5
        )
        XCTAssertLessThan(
            abs(SteakCut.tenderloin.heroOpticalOffset),
            abs(SteakCut.strip.heroOpticalOffset) * 4
        )
    }
}
