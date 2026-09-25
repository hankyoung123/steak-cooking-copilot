import XCTest
@testable import SteakCopilot

final class SteakCopilotTests: XCTestCase {
    func testApplicationTargetLoads() {
        XCTAssertTrue(true)
    }

    func testEveryCutHasAUniqueHeroAsset() {
        XCTAssertEqual(Set(SteakCut.allCases.map(\.heroAssetName)).count, 3)
    }

    func testSetupPreferencesPersistPerCut() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = CookingStore(defaults: defaults)
        let preferences = SteakSetupPreferences(
            configuration: SteakConfiguration(
                cut: .strip,
                thicknessCM: 4.5,
                doneness: .medium
            )
        )

        store.save(setupPreferences: preferences)

        XCTAssertEqual(store.loadSetupPreferences(for: .strip), preferences)
        XCTAssertEqual(
            store.loadSetupPreferences(for: .ribeye),
            .recommended(for: .ribeye)
        )
    }

    func testCookingStagesUseTheSixSuppliedFullBleedBackgrounds() {
        XCTAssertEqual(
            CookingStageArtwork.resolve(for: .sear, action: .wait).backgroundAsset,
            "CookSearBackground"
        )
        XCTAssertEqual(
            CookingStageArtwork.resolve(for: .sear, action: .flip).backgroundAsset,
            "CookFlipBackground"
        )
        XCTAssertEqual(
            CookingStageArtwork.resolve(for: .baste, action: .baste).backgroundAsset,
            "CookBasteBackground"
        )
        XCTAssertEqual(
            CookingStageArtwork.resolve(
                for: .checkTemperature,
                action: .checkTemperature
            ).backgroundAsset,
            "CookCheckBackground"
        )
        XCTAssertEqual(
            CookingStageArtwork.resolve(
                for: .finishing,
                action: .waitForFinish
            ).backgroundAsset,
            "CookRestBackground"
        )
        // The seared composition is the one that is only reachable after the
        // first flip.
        XCTAssertEqual(
            CookingStageArtwork.resolve(
                for: .sear,
                action: .wait,
                flipCount: 1
            ).backgroundAsset,
            "CookSearedBackground"
        )
        XCTAssertNil(
            CookingStageArtwork.resolve(for: .prep, action: .wait).backgroundAsset
        )
    }

    /// The reported defect: after the first flip the steak has been seared on
    /// both faces, so the **searing wait** must show the seared steak rather
    /// than going back to the raw one.
    ///
    /// The action prompts are a different question — what is the app asking
    /// for — so the tongs photograph stays at every flip, which is why this
    /// test separates the two instead of sweeping them together.
    func testBothSidesSearedArtworkAfterTheFirstFlip() {
        for flipCount in 1...6 {
            for phase: CookingPhase in [.sear, .fatCap] {
                let waiting = CookingStageArtwork.resolve(
                    for: phase,
                    action: .wait,
                    flipCount: flipCount
                )
                XCTAssertEqual(
                    waiting.backgroundAsset,
                    "CookSearedBackground",
                    """
                    \(phase) after \(flipCount) flip(s) must show the seared \
                    steak, not \(waiting.asset)
                    """
                )
            }
        }

        // The raw searing wait is only reachable *before* the first flip.
        let before = CookingStageArtwork.resolve(
            for: .sear,
            action: .wait,
            flipCount: 0
        )
        XCTAssertEqual(before.backgroundAsset, "CookSearBackground")
    }

    /// The flip / fat-cap prompt keeps its own photograph at every flip: it is
    /// an instruction, not a statement about the steak's state, so it must not
    /// follow `flipCount`.
    func testTheFlipPromptKeepsTheTongsAtEveryFlip() {
        for flipCount in 0...6 {
            for phase: CookingPhase in [.sear, .fatCap] {
                for action: CookingAction in [.flip, .standFatCap] {
                    XCTAssertEqual(
                        CookingStageArtwork.resolve(
                            for: phase,
                            action: action,
                            flipCount: flipCount
                        ).backgroundAsset,
                        "CookFlipBackground",
                        "\(phase)/\(action) at flip \(flipCount)"
                    )
                }
            }
        }
    }

    /// Regression: a stage must never render a complete composition *and* an
    /// object cutout, which drew two steaks on top of each other.
    func testNoStageCombinesACompleteCompositionWithAnObjectCutout() {
        let actions: [CookingAction] = [
            .wait, .flip, .standFatCap, .addButter, .baste,
            .checkTemperature, .takeOut, .waitForFinish, .eat
        ]
        let phases: [CookingPhase] = [
            .setup, .prep, .heat, .sear, .fatCap, .baste,
            .checkTemperature, .finishing, .ready, .eat, .feedback
        ]

        for phase in phases {
            for action in actions {
                for prepIsDry in [true, false] {
                    for flipCount in [0, 1, 4] {
                        let artwork = CookingStageArtwork.resolve(
                            for: phase,
                            action: action,
                            prepIsDry: prepIsDry,
                            flipCount: flipCount
                        )

                        XCTAssertFalse(
                            artwork.backgroundAsset != nil && artwork.objectAsset != nil,
                            "\(phase)/\(action)/\(flipCount) would draw two food layers"
                        )
                        XCTAssertEqual(
                            artwork.allowsSteakCutout,
                            artwork.backgroundAsset == nil,
                            "\(phase)/\(action) cutout policy must follow the composition"
                        )
                        XCTAssertTrue(
                            artwork.usesBackgroundOnly || artwork.showsObjectOverlay
                                || artwork.asset.isEmpty == false,
                            "\(phase)/\(action) must resolve to exactly one layer"
                        )
                    }
                }
            }
        }
    }

    func testCompleteCompositionsNeverAllowACutout() {
        // Prepare, heat and every cook/finishing stage: the six supplied
        // cooking photographs contain the pan and the steak.
        let composedPhases: [CookingPhase] = [
            .sear, .fatCap, .baste, .checkTemperature, .finishing
        ]

        for phase in composedPhases {
            for flipCount in [0, 1, 4] {
                let artwork = CookingStageArtwork.resolve(
                    for: phase,
                    action: .wait,
                    flipCount: flipCount
                )
                XCTAssertTrue(
                    artwork.usesBackgroundOnly,
                    "\(phase)/\(flipCount) should render a complete composition"
                )
                XCTAssertFalse(
                    artwork.allowsSteakCutout,
                    "\(phase) must not overlay a steak cutout on the photograph"
                )
                XCTAssertNil(artwork.objectAsset)
            }
        }
    }

    func testOnlyStagesWithoutAPhotographUseACutout() {
        // Prep and heat have no photograph, so their transparent cutout is
        // the single layer and is allowed.
        let prep = CookingStageArtwork.resolve(for: .prep, action: .wait)
        XCTAssertTrue(prep.showsObjectOverlay)
        XCTAssertTrue(prep.allowsSteakCutout)
        XCTAssertEqual(prep.objectAsset, "PrepSaltCutout")
        XCTAssertEqual(
            CookingStageArtwork.resolve(
                for: .prep,
                action: .wait,
                prepIsDry: false
            ).objectAsset,
            "PrepDryCutout"
        )

        let heat = CookingStageArtwork.resolve(for: .heat, action: .wait)
        XCTAssertTrue(heat.showsObjectOverlay)
        XCTAssertEqual(heat.objectAsset, "HotPanCutout")
    }

    func testResolvedAssetIsAlwaysASingleLayer() {
        // The view renders `artwork.asset` only, so it must never be empty
        // for a cooking stage.
        for phase: CookingPhase in [.prep, .heat, .sear, .baste, .checkTemperature, .finishing] {
            let artwork = CookingStageArtwork.resolve(for: phase, action: .wait)
            XCTAssertFalse(artwork.asset.isEmpty, "\(phase) has no artwork")
        }
    }
}
