import Foundation
import Observation

@MainActor
@Observable
final class CookingSessionController {
    private let engine: CookingEngine
    private let store: CookingStore
    private let timeScale: Double
    private let notificationService: any CookingNotificationServing
    private let liveActivityService: any CookingLiveActivityServing
    private var lastMotionToken: String?

    private(set) var session: CookingSession
    private(set) var guidance: CookingGuidance
    private(set) var calibrations: [CalibrationKey: CookingCalibration]
    let motionDirector: MotionDirector

    var flowStage: CookingFlowStage { session.phase.flowStage }

    init(
        engine: CookingEngine = CookingEngine(),
        store: CookingStore = CookingStore(),
        motionDirector: MotionDirector = MotionDirector(),
        notificationService: any CookingNotificationServing = NotificationService(),
        liveActivityService: any CookingLiveActivityServing = LiveActivityService(),
        timeScale: Double = 1,
        now: Date = .now
    ) {
        self.engine = engine
        self.store = store
        self.motionDirector = motionDirector
        self.notificationService = notificationService
        self.liveActivityService = liveActivityService
        self.timeScale = timeScale
        let restoredCalibrations = store.loadCalibrations()
        calibrations = restoredCalibrations
        let restored = store.loadSession() ?? CookingSession.fresh(at: now)
        session = restored
        let restoredCalibration = restoredCalibrations[
            CalibrationKey(configuration: restored.configuration)
        ] ?? .neutral
        guidance = engine.guidance(
            for: restored,
            at: now,
            calibration: restoredCalibration,
            timeScale: timeScale
        )
        if restored.phase.flowStage == .cook || restored.phase == .finishing {
            Task {
                await liveActivityService.recover(
                    for: restored,
                    guidance: guidance
                )
            }
        }
    }

    func updateConfiguration(_ configuration: SteakConfiguration) {
        guard session.phase == .setup else { return }
        session.configuration = configuration
        persistAndRefresh(at: .now)
    }

    func setupPreferences(for cut: SteakCut) -> SteakSetupPreferences {
        store.loadSetupPreferences(for: cut)
    }

    func updateSetupPreferences(_ preferences: SteakSetupPreferences) {
        guard session.phase == .setup else { return }
        session.configuration = preferences.configuration
        store.save(setupPreferences: preferences)
        persistAndRefresh(at: .now)
    }

    var cookHistory: [FeedbackRecord] {
        store.loadFeedback().sorted { $0.date > $1.date }
    }

    /// Pure estimate for a draft configuration, used by the advanced
    /// settings sheet without mutating the active session.
    func estimatedCookingBudget(for configuration: SteakConfiguration) -> TimeInterval {
        engine.profile(
            for: configuration,
            calibration: calibrations[CalibrationKey(configuration: configuration)] ?? .neutral,
            timeScale: timeScale
        ).estimatedCookingBudget
    }

    func finishSetup(at date: Date = .now) {
        session.enter(.prep, at: date)
        persistAndRefresh(at: date)
    }

    func finishPrep(at date: Date = .now) {
        session.enter(.heat, at: date)
        persistAndRefresh(at: date)
    }

    func panIsReady(at date: Date = .now) {
        session.startedAt = date
        session.enter(
            .sear,
            at: date,
            nextActionAt: nextSearBoundary(from: date)
        )
        persistAndRefresh(at: date)
        Task {
            _ = await notificationService.requestAuthorization()
            await notificationService.scheduleNextAction(guidance: guidance)
            await liveActivityService.start(for: session, guidance: guidance)
        }
    }

    func refresh(at date: Date = .now) {
        guidance = makeGuidance(at: date)

        if session.phase == .finishing,
           session.remaining(at: date) <= 0 {
            completeFinishing(at: date)
            return
        }

        dispatchMotionEventIfNeeded()
    }

    func confirmCurrentAction(at date: Date = .now) {
        switch guidance.currentAction {
        case .flip:
            guard session.remaining(at: date) <= 0 else { return }
            session.flipCount += 1
            session.lastFlipAt = date
            let nextBoundary = nextSearBoundary(from: date)
            if session.phase == .sear {
                session.nextActionAt = nextBoundary
            } else {
                // A flip can follow the baste stage in the no-thermometer
                // fallback; return to the sear loop with the next boundary.
                session.enter(.sear, at: date, nextActionAt: nextBoundary)
            }
            persistAndRefresh(at: date)
        case .standFatCap:
            guard session.phase == .sear else { return }
            let duration = currentProfile.fatCapDuration ?? 0
            session.enter(
                .fatCap,
                at: date,
                nextActionAt: date.addingTimeInterval(duration)
            )
            persistAndRefresh(at: date)
        case .addButter:
            session.butterAddedAt = date
            session.enter(
                .baste,
                at: date,
                nextActionAt: date.addingTimeInterval(currentProfile.basteDuration)
            )
            persistAndRefresh(at: date)
        case .checkTemperature:
            session.enter(.checkTemperature, at: date)
            persistAndRefresh(at: date)
        case .takeOut:
            beginFinishing(at: date)
        case .eat:
            if session.phase == .ready {
                session.enter(.eat, at: date)
                persistAndRefresh(at: date)
            } else if session.phase == .eat {
                session.enter(.feedback, at: date)
                persistAndRefresh(at: date)
            }
        case .wait, .baste, .waitForFinish:
            break
        }
    }

    /// Explicit no-thermometer choice. Switches to the estimated-timing
    /// fallback WITHOUT creating a temperature value and WITHOUT claiming
    /// pull temperature was reached.
    func continueWithoutThermometer(at date: Date = .now) {
        guard session.phase.flowStage == .cook else { return }
        session.thermometerUnavailableAt = date
        session.enter(
            .sear,
            at: date,
            nextActionAt: nextSearBoundary(from: date)
        )
        persistAndRefresh(at: date)
    }

    func skipCurrentStage(at date: Date = .now) async {
        switch session.phase {
        case .prep:
            finishPrep(at: date)
        case .heat:
            panIsReady(at: date)
        case .sear, .fatCap, .baste, .checkTemperature:
            beginFinishing(at: date)
        case .finishing:
            completeFinishing(at: date)
        case .ready, .eat:
            confirmCurrentAction(at: date)
        case .feedback:
            await startOver(at: date)
        case .setup:
            break
        }
    }

    func recordManualTemperature(_ temperatureC: Double, at date: Date = .now) {
        guard session.phase.flowStage == .cook else { return }
        // A real reading overrides the estimated-timing fallback.
        session.thermometerUnavailableAt = nil
        session.enter(.checkTemperature, at: date)
        session.lastManualTemperatureC = temperatureC
        session.lastManualTemperatureAt = date

        let measuredGuidance = makeGuidance(at: date)
        if measuredGuidance.pullRecommendation == .keepCooking {
            session.enter(
                .sear,
                at: date,
                nextActionAt: date.addingTimeInterval(currentProfile.flipInterval)
            )
        }
        persistAndRefresh(at: date)
    }

    func submitFeedback(
        doneness: DonenessFeedback,
        crust: CrustFeedback,
        at date: Date = .now
    ) {
        let record = FeedbackRecord(
            id: UUID(),
            date: date,
            configuration: session.configuration,
            doneness: doneness,
            crust: crust
        )
        store.append(feedback: record)
        store.save(
            setupPreferences: SteakSetupPreferences(
                configuration: session.configuration
            )
        )
        let calibrationKey = CalibrationKey(configuration: session.configuration)
        let updatedCalibration = currentCalibration.applying(
            doneness: doneness,
            crust: crust
        )
        calibrations[calibrationKey] = updatedCalibration
        store.save(calibration: updatedCalibration, for: calibrationKey)
        let previousSession = session
        let previousGuidance = guidance
        session = CookingSession.fresh(at: date)
        store.save(session: session)
        notificationService.clearCookingNotifications()
        motionDirector.resetTransientState()
        lastMotionToken = nil
        Task {
            await liveActivityService.end(
                for: previousSession,
                guidance: previousGuidance,
                reason: .cancelled
            )
        }
        refresh(at: date)
    }

    func startOver(at date: Date = .now) async {
        let previousSession = session
        let previousGuidance = guidance
        notificationService.clearCookingNotifications()
        motionDirector.resetTransientState()
        lastMotionToken = nil
        await liveActivityService.end(
            for: previousSession,
            guidance: previousGuidance,
            reason: .cancelled
        )
        session = CookingSession.fresh(at: date)
        store.save(session: session)
        refresh(at: date)
    }

    var currentProfile: CookingProfile {
        engine.profile(
            for: session.configuration,
            calibration: currentCalibration,
            timeScale: timeScale
        )
    }

    /// Absolute boundary for the next sear-stage action. Always the
    /// earliest of the next flip, the calibrated late-stage date, and —
    /// in the no-thermometer fallback — the estimated pull date, so a
    /// small searBias or a near pull boundary never waits out a full
    /// extra flip interval.
    func nextSearBoundary(from date: Date) -> Date {
        let profile = currentProfile
        var candidates = [date.addingTimeInterval(profile.flipInterval)]
        if session.butterAddedAt == nil {
            candidates.append(
                engine.lateStageDate(for: session, profile: profile)
            )
        }
        if session.thermometerUnavailableAt != nil {
            candidates.append(
                engine.estimatedPullDate(for: session, profile: profile)
            )
        }
        return candidates.min() ?? date
    }

    private func makeGuidance(at date: Date) -> CookingGuidance {
        engine.guidance(
            for: session,
            at: date,
            calibration: currentCalibration,
            timeScale: timeScale
        )
    }

    private var currentCalibration: CookingCalibration {
        calibrations[
            CalibrationKey(configuration: session.configuration)
        ] ?? .neutral
    }

    private func persistAndRefresh(at date: Date) {
        store.save(session: session)
        refresh(at: date)
        Task {
            await notificationService.scheduleNextAction(guidance: guidance)
            await liveActivityService.update(for: session, guidance: guidance)
        }
    }

    private func beginFinishing(at date: Date) {
        session.pulledAt = date
        let estimate = engine.guidance(
            for: session,
            at: date,
            calibration: currentCalibration,
            timeScale: timeScale
        ).finishingEstimate
        session.enter(
            .finishing,
            at: date,
            nextActionAt: date.addingTimeInterval(estimate.upperBound)
        )
        persistAndRefresh(at: date)
    }

    private func completeFinishing(at date: Date) {
        session.nextActionAt = date
        guidance = makeGuidance(at: date)
        dispatchMotionEventIfNeeded()
        session.finishedAt = date
        session.enter(.ready, at: date)
        store.save(session: session)
        notificationService.clearCookingNotifications()
        guidance = makeGuidance(at: date)
        Task {
            await liveActivityService.end(
                for: session,
                guidance: guidance,
                reason: .finished
            )
        }
    }

    private func dispatchMotionEventIfNeeded() {
        guard let event = guidance.event else {
            lastMotionToken = nil
            return
        }

        let actionDate = session.nextActionAt?.timeIntervalSinceReferenceDate ?? 0
        let token = "\(session.phase.rawValue)|\(session.flipCount)|\(actionDate)|\(String(describing: event))"
        guard token != lastMotionToken else { return }
        lastMotionToken = token
        motionDirector.handle(event)
    }
}
