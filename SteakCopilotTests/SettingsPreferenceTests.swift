import XCTest
@testable import SteakCopilot

/// The sound and haptic switches in Settings.
///
/// `MotionDirector` reads the preference on every event rather than capturing it
/// at launch, so these tests flip the switch between two cues and check the second
/// one is already affected.
@MainActor
final class FeedbackPreferenceTests: XCTestCase {
    @MainActor
    private final class SpyHaptics: HapticServing {
        private(set) var fired: [HapticPreset] = []
        func fire(_ preset: HapticPreset) { fired.append(preset) }
    }

    @MainActor
    private final class SpySounds: SoundServing {
        private(set) var played: [SoundPreset] = []
        func play(_ preset: SoundPreset) { played.append(preset) }
    }

    @MainActor
    private final class MutableProvider: AppPreferencesProviding {
        var preferences: AppPreferences
        init(_ preferences: AppPreferences = .standard) {
            self.preferences = preferences
        }
    }

    private func makeDirector(
        _ preferences: AppPreferences = .standard
    ) -> (director: MotionDirector, haptics: SpyHaptics, sounds: SpySounds) {
        let haptics = SpyHaptics()
        let sounds = SpySounds()
        let director = MotionDirector(
            haptics: haptics,
            sounds: sounds,
            tuning: .production,
            preferencesProvider: StaticAppPreferencesProvider(preferences)
        )
        return (director, haptics, sounds)
    }

    func testBothCuesFireWhenBothSwitchesAreOn() {
        let fixture = makeDirector()

        fixture.director.handle(.pullNow)

        XCTAssertEqual(fixture.haptics.fired, [.heavyImpact])
        XCTAssertEqual(fixture.sounds.played, [.pull])
    }

    /// The two switches are independent: turning one off must not silence the
    /// other.
    func testHapticsCanBeTurnedOffWithoutSilencingSound() {
        let fixture = makeDirector(AppPreferences(isHapticsEnabled: false))

        fixture.director.handle(.pullNow)

        XCTAssertTrue(fixture.haptics.fired.isEmpty)
        XCTAssertEqual(fixture.sounds.played, [.pull])
    }

    func testSoundCanBeTurnedOffWithoutDisablingHaptics() {
        let fixture = makeDirector(AppPreferences(isSoundEnabled: false))

        fixture.director.handle(.pullNow)

        XCTAssertEqual(fixture.haptics.fired, [.heavyImpact])
        XCTAssertTrue(fixture.sounds.played.isEmpty)
    }

    /// The visual cue is not a preference: it is how the app communicates, so it
    /// is still delivered with both switches off.
    func testTheVisualCueIsStillDeliveredWithBothSwitchesOff() {
        let fixture = makeDirector(
            AppPreferences(isSoundEnabled: false, isHapticsEnabled: false)
        )

        fixture.director.handle(.pullNow)

        XCTAssertEqual(fixture.director.cue.visual, .pull)
        XCTAssertEqual(fixture.director.sequence, 1)
        XCTAssertTrue(fixture.haptics.fired.isEmpty)
        XCTAssertTrue(fixture.sounds.played.isEmpty)
    }

    /// The whole point of reading the preference live: a switch flipped in
    /// Settings is felt on the very next cue, not at the next launch.
    func testASwitchFlipTakesEffectOnTheNextCue() {
        let provider = MutableProvider()
        let haptics = SpyHaptics()
        let sounds = SpySounds()
        let director = MotionDirector(
            haptics: haptics,
            sounds: sounds,
            tuning: .production,
            preferencesProvider: provider
        )

        director.handle(.pullNow)
        XCTAssertEqual(haptics.fired.count, 1)

        provider.preferences.isHapticsEnabled = false
        provider.preferences.isSoundEnabled = false
        director.handle(.pullNow)

        XCTAssertEqual(
            haptics.fired.count,
            1,
            "the second cue must already see the new preference"
        )
        XCTAssertEqual(sounds.played.count, 1)
    }
}

/// The learned adjustments listed in Settings.
@MainActor
final class LearnedAdjustmentTests: XCTestCase {
    /// The controller loads the calibrations it owns at init, so anything that
    /// should be visible has to be in the store first.
    private func makeFixture(
        seeding: (CookingStore) -> Void = { _ in }
    ) -> (CookingSessionController, CookingStore) {
        let suite = "LearnedAdjustmentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        seeding(store)
        let controller = CookingSessionController(
            store: store,
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false)
        )
        return (controller, store)
    }

    private func key(_ cut: SteakCut, doneness: Doneness = .mediumRare) -> CalibrationKey {
        CalibrationKey(
            configuration: SteakConfiguration(
                cut: cut,
                thicknessCM: 3,
                doneness: doneness
            )
        )
    }

    func testNothingIsListedBeforeAnyFeedback() {
        let (controller, _) = makeFixture()

        XCTAssertTrue(controller.learnedAdjustments.isEmpty)
    }

    /// Neutral entries answer nothing: the list is "what has this app changed
    /// about my cooking", so they stay out.
    func testNeutralEntriesAreNotListed() {
        let stripped = key(.strip)
        let (controller, store) = makeFixture { store in
            store.save(calibration: .neutral, for: stripped)
        }

        XCTAssertFalse(
            store.loadCalibrations().isEmpty,
            "the neutral entry is stored"
        )
        XCTAssertTrue(
            controller.learnedAdjustments.isEmpty,
            "but it changes nothing, so it is not listed"
        )
    }

    func testStoredAdjustmentsAreListedMostInfluentialFirst() {
        let minor = key(.ribeye)
        let major = key(.strip)
        let (controller, _) = makeFixture { store in
            store.save(
                calibration: CookingCalibration(cookingTimeAdjustment: 5, searBias: 0),
                for: minor
            )
            store.save(
                calibration: CookingCalibration(cookingTimeAdjustment: 30, searBias: -5),
                for: major
            )
        }

        XCTAssertEqual(
            controller.learnedAdjustments.map(\.key),
            [major, minor],
            "the biggest change to the cooking should be the easiest to find"
        )
        XCTAssertEqual(
            controller.learnedAdjustments.first?.magnitude,
            35
        )
    }

    func testResetForgetsEveryAdjustment() {
        let stripped = key(.strip)
        let (controller, store) = makeFixture { store in
            store.save(
                calibration: CookingCalibration(cookingTimeAdjustment: 30, searBias: -5),
                for: stripped
            )
        }
        XCTAssertFalse(controller.learnedAdjustments.isEmpty)

        controller.resetLearnedAdjustments()

        XCTAssertTrue(controller.learnedAdjustments.isEmpty)
        XCTAssertTrue(store.loadCalibrations().isEmpty)
    }

    /// The reset is deliberately narrow. Saved setup preferences, cook history and
    /// app preferences are different stores and must survive it.
    func testResetKeepsSavedSettingsHistoryAndPreferences() {
        let suite = "LearnedAdjustmentTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let store = CookingStore(defaults: defaults)
        let preferencesStore = AppPreferencesStore(defaults: defaults)

        let saved = SteakSetupPreferences(
            configuration: SteakConfiguration(
                cut: .strip,
                thicknessCM: 4.5,
                doneness: .medium
            )
        )
        store.save(setupPreferences: saved)
        store.append(
            feedback: FeedbackRecord(
                id: UUID(),
                date: Date(timeIntervalSince1970: 0),
                configuration: saved.configuration,
                doneness: .tooDone,
                crust: .perfect
            )
        )
        store.save(
            calibration: CookingCalibration(cookingTimeAdjustment: 30, searBias: 0),
            for: key(.strip)
        )
        var preferences = AppPreferences()
        preferences.setCut(.tenderloin, visible: false)
        preferencesStore.update(preferences)

        let controller = CookingSessionController(
            store: store,
            notificationService: NotificationService(isEnabled: false),
            liveActivityService: LiveActivityService(isEnabled: false),
            tuningStore: TuningStore(defaults: defaults)
        )
        controller.resetLearnedAdjustments()

        XCTAssertTrue(store.loadCalibrations().isEmpty)
        XCTAssertEqual(store.loadSetupPreferences(for: .strip), saved)
        XCTAssertEqual(store.loadFeedback().count, 1)
        XCTAssertEqual(
            AppPreferencesStore(defaults: defaults).preferences,
            preferences
        )
    }

    /// Feedback actually taught something: the deltas that come out of a real cook
    /// are the ones the screen has to show.
    func testOvershootingACookProducesAListedAdjustment() {
        let (controller, store) = makeFixture()
        controller.updateConfiguration(
            SteakConfiguration(cut: .ribeye, thicknessCM: 3, doneness: .mediumRare)
        )
        controller.submitFeedback(doneness: .tooDone, crust: .perfect)

        let listed = controller.learnedAdjustments
        XCTAssertEqual(listed.count, 1, "a two-step overshoot should be remembered")
        XCTAssertLessThan(
            listed[0].cookingTimeAdjustment,
            0,
            "cooking it too long should shorten the next attempt"
        )
        XCTAssertFalse(store.loadCalibrations().isEmpty)
    }
}

/// The reminder switch.
@MainActor
final class ReminderPreferenceTests: XCTestCase {
    /// With reminders switched off the app must not even ask for permission.
    /// `requestAuthorization` returns before touching `UNUserNotificationCenter`,
    /// which is what makes this safe to assert in a unit test.
    func testPermissionIsNotRequestedWhenRemindersAreOff() async {
        let service = NotificationService(
            isEnabled: true,
            preferencesProvider: StaticAppPreferencesProvider(
                AppPreferences(isNotificationsEnabled: false)
            )
        )

        let granted = await service.requestAuthorization()

        XCTAssertFalse(granted)
    }

    /// The launch-argument kill switch still wins over the user's preference, so
    /// the UI test runs stay silent and prompt-free.
    func testTheServiceKillSwitchStillWins() async {
        let service = NotificationService(
            isEnabled: false,
            preferencesProvider: StaticAppPreferencesProvider(
                AppPreferences(isNotificationsEnabled: true)
            )
        )

        let granted = await service.requestAuthorization()

        XCTAssertFalse(granted)
    }
}
