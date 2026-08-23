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
            ),
            startingCondition: .room
        )

        store.save(setupPreferences: preferences)

        XCTAssertEqual(store.loadSetupPreferences(for: .strip), preferences)
        XCTAssertEqual(
            store.loadSetupPreferences(for: .ribeye),
            .recommended(for: .ribeye)
        )
    }
}
