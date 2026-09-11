import Foundation

struct SteakCutProfile: Equatable, Sendable {
    let needsFatCap: Bool
    let fatCapDuration: TimeInterval?
}

enum SteakCut: String, Codable, CaseIterable, Identifiable, Sendable {
    case ribeye
    case strip
    case tenderloin

    var id: Self { self }

    var title: String {
        switch self {
        case .ribeye: String(localized: "Ribeye")
        case .strip: String(localized: "New York Strip")
        case .tenderloin: String(localized: "Filet")
        }
    }

    /// Behaviour parameters for this cut, from the production tuning
    /// generated from `Config/production.yaml`.
    func spec(in tuning: AppTuning) -> CutSpecTuning {
        tuning.cuts[self]
    }

    /// Asset name for the setup carousel. Artwork identity is not a tunable
    /// parameter, so it stays in code.
    var heroAssetName: String {
        switch self {
        case .ribeye: "RawRibeye"
        case .strip: "RawStrip"
        case .tenderloin: "RawFilet"
        }
    }

    /// Optical-centring correction for the hero artwork, as a fraction of the
    /// rendered image side. Negative shifts the artwork left.
    ///
    /// All three source images are 1254 × 1254 PNGs whose subject sits slightly
    /// **right** of the geometric centre, so a purely geometric centring reads
    /// as the steak drifting right. Measured as the alpha-weighted centroid of
    /// each asset, relative to the frame centre:
    ///
    ///     ribeye  +0.93%   (bbox centre +0.40%)
    ///     strip   +0.73%   (bbox centre −0.04%)
    ///     filet   +2.06%   (bbox centre +1.28%)
    ///
    /// These are the negated centroid offsets, so the weighted centre lands on
    /// the frame centre. `SessionAssetOpticalTests` reads the alpha channel of
    /// the shipped assets and fails if these constants stop matching them, which
    /// is what keeps them a measurement rather than a nudge.
    ///
    /// Filet genuinely differs from the other two (about 2.2×), which is why the
    /// correction is per cut instead of one shared value.
    var heroOpticalOffset: CGFloat {
        switch self {
        case .ribeye: -0.0093
        case .strip: -0.0073
        case .tenderloin: -0.0206
        }
    }
}

enum ThicknessBucket: String, Codable, Hashable, Sendable {
    case thin
    case standard
    case thick

    /// Bucket boundaries are tunable, so the tuning must be supplied.
    init(thicknessCM: Double, in tuning: AppTuning) {
        self = tuning.cooking.thicknessBucket(thicknessCM: thicknessCM)
    }
}

struct SteakConfiguration: Codable, Equatable, Sendable {
    var cut: SteakCut
    var thicknessCM: Double
    var doneness: Doneness

    init(
        cut: SteakCut = .ribeye,
        thicknessCM: Double = 3,
        doneness: Doneness = .mediumRare
    ) {
        self.cut = cut
        self.thicknessCM = thicknessCM
        self.doneness = doneness
    }

    func thicknessBucket(in tuning: AppTuning) -> ThicknessBucket {
        ThicknessBucket(thicknessCM: thicknessCM, in: tuning)
    }
}

struct SteakSetupPreferences: Codable, Equatable, Sendable {
    var configuration: SteakConfiguration

    /// Recommended starting configuration for a cut, using the recommended
    /// thickness from production tuning.
    static func recommended(
        for cut: SteakCut,
        tuning: AppTuning = .production
    ) -> SteakSetupPreferences {
        SteakSetupPreferences(
            configuration: SteakConfiguration(
                cut: cut,
                thicknessCM: cut.spec(in: tuning).recommendedThickness,
                doneness: .mediumRare
            )
        )
    }
}
