import XCTest
@testable import SteakCopilot

/// Which cuts the setup screen shows.
///
/// Hiding a cut is a display filter, so the two properties that matter are that
/// the screen can never end up empty and that hiding destroys nothing.
@MainActor
final class AppPreferencesTests: XCTestCase {

    // MARK: - Defaults

    func testEverythingIsVisibleByDefault() {
        let preferences = AppPreferences()

        XCTAssertEqual(preferences.visibleCuts, SteakCut.allCases)
        XCTAssertTrue(preferences.hiddenCuts.isEmpty)
        for cut in SteakCut.allCases {
            XCTAssertTrue(preferences.isVisible(cut))
        }
    }

    /// Storing the *hidden* set is what gives a new cut a visible default: an
    /// untouched install shows it without any migration.
    func testAnUnseenCutWouldBeVisible() {
        let preferences = AppPreferences(hiddenCuts: [.strip])

        XCTAssertTrue(preferences.isVisible(.ribeye))
        XCTAssertTrue(preferences.isVisible(.tenderloin))
        XCTAssertFalse(preferences.isVisible(.strip))
    }

    // MARK: - Hiding

    func testHidingRemovesOnlyThatCut() {
        var preferences = AppPreferences()

        XCTAssertTrue(preferences.setCut(.strip, visible: false))
        XCTAssertEqual(preferences.visibleCuts, [.ribeye, .tenderloin])
    }

    func testShowingACutBringsItBack() {
        var preferences = AppPreferences(hiddenCuts: [.strip])

        XCTAssertTrue(preferences.setCut(.strip, visible: true))
        XCTAssertEqual(preferences.visibleCuts, SteakCut.allCases)
    }

    /// The screen must always have something to show.
    func testTheLastVisibleCutCannotBeHidden() {
        var preferences = AppPreferences()
        XCTAssertTrue(preferences.setCut(.strip, visible: false))
        XCTAssertTrue(preferences.setCut(.tenderloin, visible: false))

        XCTAssertFalse(
            preferences.setCut(.ribeye, visible: false),
            "hiding the last visible cut must be refused"
        )
        XCTAssertEqual(preferences.visibleCuts, [.ribeye])
        XCTAssertFalse(preferences.canHide(.ribeye))
    }

    /// Hiding something already hidden is a no-op rather than a failure, so a
    /// repeated toggle cannot report a confusing rejection.
    func testHidingAnAlreadyHiddenCutSucceeds() {
        var preferences = AppPreferences(hiddenCuts: [.strip])

        XCTAssertTrue(preferences.setCut(.strip, visible: false))
        XCTAssertTrue(preferences.canHide(.strip))
    }

    /// A hand-edited or corrupted store must not leave the setup screen empty.
    func testADamagedStoredValueStillLeavesSomethingVisible() {
        let preferences = AppPreferences(hiddenCuts: Set(SteakCut.allCases))

        XCTAssertFalse(preferences.visibleCuts.isEmpty)
        XCTAssertEqual(preferences.visibleCuts.count, 1)
    }

    // MARK: - Selection

    func testSelectionStaysPutWhenTheCutIsStillVisible() {
        let preferences = AppPreferences(hiddenCuts: [.strip])

        XCTAssertEqual(preferences.selection(startingFrom: .tenderloin), .tenderloin)
    }

    /// Hiding the cut you are looking at moves you to the nearest one you still
    /// have, and the answer is deterministic so a relaunch cannot land elsewhere.
    func testSelectionMovesToTheNearestVisibleCut() {
        // Something still visible after it: take that one.
        let middle = AppPreferences(hiddenCuts: [.strip])
        XCTAssertEqual(middle.selection(startingFrom: .strip), .tenderloin)

        // Nothing after it: fall back to the nearest one before it rather than
        // wrapping to the far end of the list.
        let tail = AppPreferences(hiddenCuts: [.tenderloin])
        XCTAssertEqual(tail.selection(startingFrom: .tenderloin), .strip)
    }

    func testSelectionIsStableAcrossRepeatedResolution() {
        let preferences = AppPreferences(hiddenCuts: [.strip])

        let first = preferences.selection(startingFrom: .ribeye)
        XCTAssertEqual(first, .ribeye)
        XCTAssertEqual(preferences.selection(startingFrom: first), first)
    }

    // MARK: - Toggles

    func testEverySwitchStartsOn() {
        let preferences = AppPreferences()

        XCTAssertTrue(preferences.isNotificationsEnabled)
        XCTAssertTrue(preferences.isSoundEnabled)
        XCTAssertTrue(preferences.isHapticsEnabled)
    }

    func testTogglesSurviveCoding() throws {
        let preferences = AppPreferences(
            hiddenCuts: [.strip],
            isNotificationsEnabled: false,
            isSoundEnabled: false,
            isHapticsEnabled: true
        )

        let decoded = try JSONDecoder().decode(
            AppPreferences.self,
            from: JSONEncoder().encode(preferences)
        )

        XCTAssertEqual(decoded, preferences)
    }

    // MARK: - Coding

    func testRoundTripsThroughCoding() throws {
        let preferences = AppPreferences(hiddenCuts: [.strip, .tenderloin])

        let data = try JSONEncoder().encode(preferences)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertEqual(decoded, preferences)
        XCTAssertEqual(decoded.visibleCuts, [.ribeye])
    }

    /// The first release stored the hidden set on its own, before the switches
    /// existed. An install that predates them must keep its hidden cuts and pick
    /// up the defaults for everything else, with no migration step.
    func testDecodesTheEarlierShapeAndKeepsTheHiddenCuts() throws {
        let legacy = try JSONEncoder().encode(Set([SteakCut.strip]))

        let decoded = try JSONDecoder().decode(AppPreferences.self, from: legacy)

        XCTAssertFalse(decoded.isVisible(.strip))
        XCTAssertTrue(decoded.isVisible(.ribeye))
        XCTAssertTrue(decoded.isNotificationsEnabled)
        XCTAssertTrue(decoded.isSoundEnabled)
        XCTAssertTrue(decoded.isHapticsEnabled)
    }

    func testDecodingRepairsAValueThatHidesEverything() throws {
        let data = try JSONEncoder().encode(Set(SteakCut.allCases))

        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)

        XCTAssertFalse(decoded.visibleCuts.isEmpty)
    }
}

/// Persistence for the app-wide preferences.
@MainActor
final class AppPreferencesStoreTests: XCTestCase {
    private func makeDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "AppPreferencesStoreTests.\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    func testDefaultsToEverythingVisible() {
        XCTAssertEqual(AppPreferencesStore(defaults: makeDefaults()).preferences, .standard)
    }

    func testRoundTripsThroughTheStore() {
        let defaults = makeDefaults()
        let store = AppPreferencesStore(defaults: defaults)

        var preferences = AppPreferences()
        preferences.setCut(.tenderloin, visible: false)
        store.update(preferences)

        XCTAssertEqual(AppPreferencesStore(defaults: defaults).preferences, preferences)
    }

    func testResetRestoresTheDefault() {
        let defaults = makeDefaults()
        let store = AppPreferencesStore(defaults: defaults)
        var preferences = AppPreferences()
        preferences.setCut(.strip, visible: false)
        store.update(preferences)

        store.reset()

        XCTAssertEqual(store.preferences, .standard)
    }

    /// A value written by the previous release, sitting in `UserDefaults`, is
    /// read back with its hidden cuts intact.
    func testLoadsAPreviouslyStoredShape() throws {
        let defaults = makeDefaults()
        defaults.set(
            try JSONEncoder().encode(Set([SteakCut.tenderloin])),
            forKey: "steak.preferences.v1"
        )

        let loaded = AppPreferencesStore(defaults: defaults).preferences

        XCTAssertFalse(loaded.isVisible(.tenderloin))
        XCTAssertTrue(loaded.isNotificationsEnabled)
    }

    func testTogglesRoundTripThroughTheStore() {
        let defaults = makeDefaults()
        let store = AppPreferencesStore(defaults: defaults)
        var preferences = store.preferences
        preferences.isSoundEnabled = false
        preferences.isNotificationsEnabled = false
        store.update(preferences)

        let reloaded = AppPreferencesStore(defaults: defaults).preferences

        XCTAssertFalse(reloaded.isSoundEnabled)
        XCTAssertFalse(reloaded.isNotificationsEnabled)
        XCTAssertTrue(reloaded.isHapticsEnabled)
    }

    func testStorePublishesTheValueItWasGiven() {
        let store = AppPreferencesStore(defaults: makeDefaults())
        var preferences = store.preferences
        preferences.setCut(.strip, visible: false)

        store.update(preferences)

        XCTAssertEqual(store.preferences, preferences)
        XCTAssertFalse(store.preferences.isVisible(.strip))
    }

    func testGarbageInTheStoreFallsBackToTheDefault() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "steak.preferences.v1")

        XCTAssertEqual(AppPreferencesStore(defaults: defaults).preferences, .standard)
    }

    /// The promise the settings screen makes in its footnote: hiding is not
    /// deleting. Settings and learned adjustments live in a different store and
    /// must survive untouched, and reappear when the cut does.
    func testHidingACutKeepsItsSettingsAndLearnedAdjustments() {
        let defaults = makeDefaults()
        let cooking = CookingStore(defaults: defaults)
        let store = AppPreferencesStore(defaults: defaults)

        let configuration = SteakConfiguration(
            cut: .strip,
            thicknessCM: 4.5,
            doneness: .medium
        )
        let saved = SteakSetupPreferences(configuration: configuration)
        cooking.save(setupPreferences: saved)

        let key = CalibrationKey(configuration: configuration)
        let learned = CookingCalibration(
            cookingTimeAdjustment: 30,
            searBias: -5
        )
        cooking.save(calibration: learned, for: key)

        var preferences = AppPreferences()
        preferences.setCut(.strip, visible: false)
        store.update(preferences)
        XCTAssertFalse(store.preferences.isVisible(.strip))

        XCTAssertEqual(cooking.loadSetupPreferences(for: .strip), saved)
        XCTAssertEqual(cooking.loadCalibration(for: key), learned)

        // Showing it again restores it with nothing lost.
        preferences.setCut(.strip, visible: true)
        store.update(preferences)

        XCTAssertTrue(store.preferences.isVisible(.strip))
        XCTAssertEqual(cooking.loadSetupPreferences(for: .strip), saved)
        XCTAssertEqual(cooking.loadCalibration(for: key), learned)
    }

    /// Clearing a session must not disturb the app preferences, and vice versa.
    func testClearingASessionLeavesThePreferencesAlone() {
        let defaults = makeDefaults()
        let cooking = CookingStore(defaults: defaults)
        let store = AppPreferencesStore(defaults: defaults)

        var preferences = AppPreferences()
        preferences.setCut(.strip, visible: false)
        store.update(preferences)
        cooking.save(session: .fresh(at: Date(timeIntervalSince1970: 0)))

        cooking.clearSession()

        XCTAssertEqual(
            AppPreferencesStore(defaults: defaults).preferences,
            preferences,
            "session data and app preferences are separate concerns"
        )
    }
}
