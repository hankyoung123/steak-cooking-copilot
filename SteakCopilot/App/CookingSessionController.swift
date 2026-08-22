import Foundation
import Observation

@MainActor
@Observable
final class CookingSessionController {
    private let engine: CookingEngine
    private let store: CookingStore
    private let timeScale: Double
    private let notificationService: NotificationService
    private let liveActivityService: LiveActivityService
    private var lastMotionToken: String?

    private(set) var session: CookingSession
    private(set) var guidance: CookingGuidance
    private(set) var calibration: CookingCalibration
    let motionDirector: MotionDirector

    var flowStage: CookingFlowStage { session.phase.flowStage }

    init(
        engine: CookingEngine = CookingEngine(),
        store: CookingStore = CookingStore(),
        motionDirector: MotionDirector = MotionDirector(),
        notificationService: NotificationService = NotificationService(),
        liveActivityService: LiveActivityService = LiveActivityService(),
        timeScale: Double = 1,
        now: Date = .now
    ) {
        self.engine = engine
        self.store = store
        self.motionDirector = motionDirector
        self.notificationService = notificationService
        self.liveActivityService = liveActivityService
        self.timeScale = timeScale
        let restoredCalibration = store.loadCalibration()
        calibration = restoredCalibration
        let restored = store.loadSession() ?? CookingSession.fresh(at: now)
        session = restored
        guidance = engine.guidance(
            for: restored,
            at: now,
            calibration: restoredCalibration,
            timeScale: timeScale
        )
    }

    func updateConfiguration(_ configuration: SteakConfiguration) {
        guard session.phase == .setup else { return }
        session.configuration = configuration
        persistAndRefresh(at: .now)
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
            nextActionAt: date.addingTimeInterval(currentProfile.flipInterval)
        )
        persistAndRefresh(at: date)
        Task {
            _ = await notificationService.requestAuthorization()
            await notificationService.scheduleNextAction(for: session, guidance: guidance)
            await liveActivityService.start(for: session, guidance: guidance)
        }
    }

    func refresh(at date: Date = .now) {
        guidance = makeGuidance(at: date)

        if session.phase == .finishing,
           session.remaining(at: date) <= 0 {
            session.finishedAt = date
            session.enter(.ready, at: date)
            store.save(session: session)
            guidance = makeGuidance(at: date)
            Task {
                await liveActivityService.end(for: session, guidance: guidance)
            }
        }

        dispatchMotionEventIfNeeded()
    }

    func confirmCurrentAction(at date: Date = .now) {
        switch guidance.currentAction {
        case .flip:
            guard session.remaining(at: date) <= 0 else { return }
            session.flipCount += 1
            session.lastFlipAt = date
            session.nextActionAt = date.addingTimeInterval(currentProfile.flipInterval)
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
            session.temperatureCheckConfirmedAt = date
            persistAndRefresh(at: date)
        case .takeOut:
            session.pulledAt = date
            let estimate = engine.guidance(
                for: session,
                at: date,
                calibration: calibration,
                timeScale: timeScale
            ).finishingEstimate
            session.enter(
                .finishing,
                at: date,
                nextActionAt: date.addingTimeInterval(estimate.upperBound)
            )
            persistAndRefresh(at: date)
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

    func recordManualTemperature(_ temperatureC: Double, at date: Date = .now) {
        guard session.phase.flowStage == .cook else { return }
        session.enter(.checkTemperature, at: date)
        session.lastManualTemperatureC = temperatureC
        session.lastManualTemperatureAt = date
        session.temperatureCheckConfirmedAt = date

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
        calibration = calibration.applying(doneness: doneness, crust: crust)
        store.save(calibration: calibration)
        session = CookingSession.fresh(at: date)
        store.save(session: session)
        notificationService.clearCookingNotifications()
        Task {
            await liveActivityService.end(for: session, guidance: guidance)
        }
        refresh(at: date)
    }

    func startOver(at date: Date = .now) {
        session = CookingSession.fresh(at: date)
        store.save(session: session)
        refresh(at: date)
    }

    var currentProfile: CookingProfile {
        engine.profile(
            for: session.configuration,
            calibration: calibration,
            timeScale: timeScale
        )
    }

    private func makeGuidance(at date: Date) -> CookingGuidance {
        engine.guidance(
            for: session,
            at: date,
            calibration: calibration,
            timeScale: timeScale
        )
    }

    private func persistAndRefresh(at date: Date) {
        store.save(session: session)
        refresh(at: date)
        Task {
            await notificationService.scheduleNextAction(for: session, guidance: guidance)
            await liveActivityService.update(for: session, guidance: guidance)
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
