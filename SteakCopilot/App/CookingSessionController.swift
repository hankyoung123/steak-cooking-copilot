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
        guidance = engine.guidance(for: restored, at: now, calibration: restoredCalibration)
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
        let profile = currentProfile
        session.startedAt = date
        session.enter(.searFirst, at: date, duration: profile.firstSearDuration)
        persistAndRefresh(at: date)
        Task {
            _ = await notificationService.requestAuthorization()
            await notificationService.scheduleNextAction(for: session, guidance: guidance)
            await liveActivityService.start(for: session, guidance: guidance)
        }
    }

    func refresh(at date: Date = .now) {
        guidance = engine.guidance(for: session, at: date, calibration: calibration)

        if session.phase == .resting, guidance.remainingTime <= 0 {
            session.enter(.ready, at: date)
            store.save(session: session)
            guidance = engine.guidance(for: session, at: date, calibration: calibration)
            Task {
                await liveActivityService.end(for: session, guidance: guidance)
            }
        }

        dispatchMotionEventIfNeeded()
    }

    func confirmCurrentAction(at date: Date = .now) {
        switch session.phase {
        case .searFirst:
            session.flipCount += 1
            enter(.searSecond, at: date)
        case .searSecond:
            session.flipCount += 1
            enter(.fatCap, at: date)
        case .fatCap:
            enter(.butter, at: date)
        case .butter:
            enter(.baste, at: date)
        case .baste:
            enter(.checkTemperature, at: date)
        case .checkTemperature:
            enter(.pull, at: date)
        case .pull:
            enter(.resting, at: date)
        case .ready:
            enter(.eat, at: date)
        case .eat:
            enter(.feedback, at: date)
        default:
            break
        }
    }

    func recordManualTemperature(_ temperatureC: Double, at date: Date = .now) {
        session.manualTemperatureC = temperatureC
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

    private var currentProfile: CookingProfile {
        engine.profile(
            for: session.configuration,
            calibration: calibration,
            timeScale: timeScale
        )
    }

    private func enter(_ phase: CookingPhase, at date: Date) {
        session.enter(phase, at: date, duration: currentProfile.duration(for: phase))
        persistAndRefresh(at: date)
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

        let token = "\(session.phase.rawValue)|\(String(describing: event))"
        guard token != lastMotionToken else { return }
        lastMotionToken = token
        motionDirector.handle(event)
    }
}
