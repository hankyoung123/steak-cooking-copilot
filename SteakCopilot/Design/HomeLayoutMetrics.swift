import SwiftUI

/// Stable identifiers for the setup screen's skeleton.
///
/// Only the bands that are neither a button nor already addressable need a new
/// name here; the interactive parts keep their existing identifiers
/// (`setup.primary`, `home.settings`, `home.history`, `home.previousCut`,
/// `home.nextCut`, `home.carousel`, `setup.cut.*`) so nothing that already
/// drives a test or the accessibility tree has to move.
enum HomeLayoutID {
    static let title = "home.title"
    static let planDoneness = "home.plan.doneness"
    static let planThickness = "home.plan.thickness"
    static let summary = "home.summary"
}

/// One device-independent description of the setup screen's vertical skeleton.
///
/// ## Why the setup screen gets the same treatment as the session
///
/// The three cuts have different name lengths in both languages — `RIBEYE` /
/// `STRIP` / `TENDERLOIN`, `肉眼牛排` / `纽约客牛排` / `菲力` — and the screen
/// was a plain `VStack` of intrinsically sized rows. Nothing pinned the title
/// band, the parameter row, the summary or the call to action, so any copy
/// change was free to reflow everything below it.
///
/// The slots are resolved from the container size alone; the selected cut is
/// not an input, so switching cuts cannot move anything:
///
///     topBar        history / settings
///     hero          steak artwork
///     navigation    previous cut · dots · next cut
///     title         TODAY’S CUT + cut name
///     plan          doneness | thickness
///     summary       duration + pull target
///     primaryAction Begin Cooking
///     secondary     fine-tune settings
///
/// The hero takes the height left over after the fixed slots
/// (`heightExcludingHero`), clamped. That is what keeps the page filling the
/// screen instead of leaving dead space at the bottom, and it keeps every other
/// slot's offset identical on one device.
///
/// These are UI layout constants. They are deliberately not in
/// `Config/production.yaml`: they are not cooking behaviour.
///
/// The setup screen uses fixed-size editorial type (`font(.system(size:))`,
/// which does not track Dynamic Type), so unlike the session skeleton these
/// slots are not text-scaled. The hero is the only flexible slot, so a larger
/// text size costs hero height rather than pushing the call to action away.
struct HomeLayoutMetrics: Equatable, Sendable {
    enum LayoutClass: String, Equatable, Sendable {
        case compact
        case regular
    }

    let layoutClass: LayoutClass

    // MARK: Horizontal rhythm

    /// Page inset for the top bar, parameter row, summary and actions.
    let screenInset: CGFloat

    // MARK: Fixed vertical slots

    let topBarHeight: CGFloat
    let heroHeight: CGFloat
    /// Width of one carousel card. The hero artwork is fitted inside it.
    let heroFrameWidth: CGFloat
    /// Breathing room between the card edge and the artwork itself. Kept small
    /// so the steak, not the frame, is what the eye measures.
    let heroImageInset: CGFloat
    let navigationHeight: CGFloat
    /// Fixed label width on both sides of the dots, so a longer neighbour name
    /// cannot widen one side and shift the dot group off centre.
    let navigationLabelWidth: CGFloat
    /// Cap on the navigation row. Without it the two labels sit at the page
    /// margins, ~80pt from the dots, and the row reads as three scattered parts;
    /// capping it pulls them in so the arrows, the labels and the dots form one
    /// control group while the dots stay centred.
    let navigationMaxWidth: CGFloat
    let titleHeight: CGFloat
    let planHeight: CGFloat
    let summaryHeight: CGFloat
    let primaryActionHeight: CGFloat
    let secondaryActionHeight: CGFloat

    // MARK: Spacing rhythm (the only vertical spacing on the screen)

    let heroToNavigation: CGFloat
    let navigationToTitle: CGFloat
    let titleToPlan: CGFloat
    let planToSummary: CGFloat
    let summaryToPrimary: CGFloat
    let primaryToSecondary: CGFloat

    /// Height of everything that is not the hero. `resolve` subtracts this from
    /// the container and gives the remainder to the hero.
    var heightExcludingHero: CGFloat {
        topBarHeight
            + heroToNavigation
            + navigationHeight
            + navigationToTitle
            + titleHeight
            + titleToPlan
            + planHeight
            + planToSummary
            + summaryHeight
            + summaryToPrimary
            + primaryActionHeight
            + primaryToSecondary
            + secondaryActionHeight
    }

    var totalHeight: CGFloat { heightExcludingHero + heroHeight }

    /// Rendered side of the square hero artwork.
    ///
    /// `scaledToFit` on a square asset inside the card fits the *smaller* of the
    /// two available dimensions, and the optical correction is expressed as a
    /// fraction of this length so it stays correct on every device instead of
    /// being a hardcoded number of points.
    var heroImageSide: CGFloat {
        max(
            0,
            min(
                heroFrameWidth - heroImageInset * 2,
                heroHeight - heroImageInset * 2
            )
        )
    }
}

extension HomeLayoutMetrics {
    /// Below this container height the compact rhythm is used.
    static let compactHeightThreshold: CGFloat = 700
    /// The artwork never disappears entirely, and never takes over the screen.
    static let regularHeroFloor: CGFloat = 240
    static let compactHeroFloor: CGFloat = 200
    static let heroCeiling: CGFloat = 380

    static let regular = HomeLayoutMetrics(
        layoutClass: .regular,
        screenInset: 28,
        topBarHeight: 44,
        heroHeight: 0,
        heroFrameWidth: 0,
        heroImageInset: 14,
        navigationHeight: 44,
        // Wide enough for the longest neighbour name in either language
        // ("NEW YORK STRIP" / "纽约客牛排") to fit without truncating. The
        // slot is fixed on both sides, so the dot group cannot drift when the
        // neighbour changes.
        navigationLabelWidth: 92,
        navigationMaxWidth: 302,
        titleHeight: 70,
        planHeight: 76,
        summaryHeight: 44,
        primaryActionHeight: 56,
        secondaryActionHeight: 44,
        heroToNavigation: 0,
        navigationToTitle: 10,
        titleToPlan: 22,
        planToSummary: 16,
        summaryToPrimary: 22,
        primaryToSecondary: 8
    )

    static let compact = HomeLayoutMetrics(
        layoutClass: .compact,
        screenInset: 24,
        topBarHeight: 42,
        heroHeight: 0,
        heroFrameWidth: 0,
        heroImageInset: 12,
        navigationHeight: 44,
        navigationLabelWidth: 86,
        navigationMaxWidth: 286,
        titleHeight: 66,
        planHeight: 72,
        summaryHeight: 42,
        primaryActionHeight: 56,
        secondaryActionHeight: 42,
        heroToNavigation: 0,
        navigationToTitle: 8,
        titleToPlan: 18,
        planToSummary: 14,
        summaryToPrimary: 18,
        primaryToSecondary: 6
    )

    /// Resolves the skeleton for a container. Pure: the selected cut is not an
    /// input, which is precisely why changing it cannot move a slot.
    static func resolve(for size: CGSize) -> HomeLayoutMetrics {
        let base = size.height < compactHeightThreshold ? compact : regular
        let floor = base.layoutClass == .compact
            ? compactHeroFloor
            : regularHeroFloor
        let available = max(size.height, 1) - base.heightExcludingHero
        let hero = min(max(available, floor), heroCeiling)
        return base
            .withHeroHeight(hero)
            .withHeroFrameWidth(max(268, size.width - 86))
    }

    /// Horizontal margin on the carousel that centres one card: with a card of
    /// `width - 86` the two margins are 43 each.
    static let carouselContentMargin: CGFloat = 43

    private func withHeroHeight(_ height: CGFloat) -> HomeLayoutMetrics {
        copy(heroHeight: height)
    }

    private func withHeroFrameWidth(_ width: CGFloat) -> HomeLayoutMetrics {
        copy(heroFrameWidth: width)
    }

    private func copy(
        heroHeight: CGFloat? = nil,
        heroFrameWidth: CGFloat? = nil
    ) -> HomeLayoutMetrics {
        HomeLayoutMetrics(
            layoutClass: layoutClass,
            screenInset: screenInset,
            topBarHeight: topBarHeight,
            heroHeight: heroHeight ?? self.heroHeight,
            heroFrameWidth: heroFrameWidth ?? self.heroFrameWidth,
            heroImageInset: heroImageInset,
            navigationHeight: navigationHeight,
            navigationLabelWidth: navigationLabelWidth,
            navigationMaxWidth: navigationMaxWidth,
            titleHeight: titleHeight,
            planHeight: planHeight,
            summaryHeight: summaryHeight,
            primaryActionHeight: primaryActionHeight,
            secondaryActionHeight: secondaryActionHeight,
            heroToNavigation: heroToNavigation,
            navigationToTitle: navigationToTitle,
            titleToPlan: titleToPlan,
            planToSummary: planToSummary,
            summaryToPrimary: summaryToPrimary,
            primaryToSecondary: primaryToSecondary
        )
    }
}
