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

    func testCookingStagesUseTheFiveSuppliedFullBleedBackgrounds() {
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
        XCTAssertNil(
            CookingStageArtwork.resolve(for: .prep, action: .wait).backgroundAsset
        )
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
                    let artwork = CookingStageArtwork.resolve(
                        for: phase,
                        action: action,
                        prepIsDry: prepIsDry
                    )

                    XCTAssertFalse(
                        artwork.backgroundAsset != nil && artwork.objectAsset != nil,
                        "\(phase)/\(action) would draw two food layers"
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

    func testCompleteCompositionsNeverAllowACutout() {
        // Prepare, heat and every cook/finishing stage: the five supplied
        // cooking photographs contain the pan and the steak.
        let composedPhases: [CookingPhase] = [
            .sear, .fatCap, .baste, .checkTemperature, .finishing
        ]

        for phase in composedPhases {
            let artwork = CookingStageArtwork.resolve(
                for: phase,
                action: .wait
            )
            XCTAssertTrue(
                artwork.usesBackgroundOnly,
                "\(phase) should render a complete composition"
            )
            XCTAssertFalse(
                artwork.allowsSteakCutout,
                "\(phase) must not overlay a steak cutout on the photograph"
            )
            XCTAssertNil(artwork.objectAsset)
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
