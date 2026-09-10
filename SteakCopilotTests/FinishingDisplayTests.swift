import XCTest
@testable import SteakCopilot

/// FINISHING must never look like a precise measurement: the presentation is
/// a minute range, not a ticking second countdown.
final class FinishingDisplayTests: XCTestCase {
    /// Extracts the numeric bounds from a rendered range such as
    /// “2–4 min” / “2–4 分钟”, so assertions stay locale-independent.
    private func bounds(in text: String) -> [Int] {
        text
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }

    func testTwoToFourMinutesRendersAsA2To4MinuteRange() {
        XCTAssertEqual(bounds(in: FinishingDisplay.rangeText(for: 120...225)), [2, 4])
    }

    func testRangeTextNeverLooksLikeASecondCountdown() {
        let estimates: [ClosedRange<TimeInterval>] = [
            120...225,
            90...180,
            150...255,
            1...2,
            240...380
        ]

        for estimate in estimates {
            let text = FinishingDisplay.rangeText(for: estimate)
            XCTAssertFalse(
                text.contains(":"),
                "Finishing must not present a m:ss countdown, got \(text)"
            )
            XCTAssertEqual(
                bounds(in: text).count,
                2,
                "Finishing must present a two-bound range, got \(text)"
            )
        }
    }

    func testRangeIsAlwaysOrderedAndPositive() {
        let estimates: [ClosedRange<TimeInterval>] = [
            0...0,
            1...2,
            30...30,
            120...225
        ]

        for estimate in estimates {
            let text = FinishingDisplay.rangeText(for: estimate)
            let values = bounds(in: text)
            XCTAssertEqual(values.count, 2, "Expected two bounds in \(text)")
            XCTAssertLessThan(values[0], values[1], "Range must be ordered: \(text)")
            XCTAssertGreaterThan(values[0], 0, "Range must be positive: \(text)")
        }
    }

    func testGuidanceFinishingEstimateRendersAsARange() {
        let start = Date(timeIntervalSince1970: 300_000)
        let session = CookingSession.fixture(
            phase: .finishing,
            phaseStartedAt: start,
            nextActionAt: start.addingTimeInterval(200)
        )
        let guidance = CookingEngine().guidance(for: session, at: start)

        let text = FinishingDisplay.rangeText(for: guidance.finishingEstimate)
        let values = bounds(in: text)

        XCTAssertEqual(values.count, 2)
        XCTAssertFalse(text.contains(":"))
    }

    func testLongerCarryoverEstimateProducesALaterRange() {
        let short = FinishingDisplay.rangeText(for: 120...225)
        let long = FinishingDisplay.rangeText(for: 240...420)

        XCTAssertGreaterThan(bounds(in: long)[0], bounds(in: short)[0])
    }
}
