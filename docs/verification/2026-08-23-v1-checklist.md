# Steak Cooking Copilot V1 Verification

Verified on 2026-08-23 with Xcode 26.2, Swift 6.2, and an iPhone 17 simulator running iOS 26.2. The deployment target is iOS 18.0.

## Automated results

- App + embedded Live Activity: `xcodebuild ... build` — **passed**
- Unit/integration suite: 13 tests — **passed**
- End-to-end XCUITest: Setup → Prep → Heat → all seven Cook actions → Finish → Ready → Eat → Feedback → fresh Setup — **passed** in 50.684 seconds with the debug time scale.
- Visual captures inspected: Setup, Flip attention during Cook, and Ready.
- Final build-for-testing: **passed** with no source warnings. Xcode emits only its benign “No AppIntents.framework dependency found” metadata note for the UI-test bundle.

## V1 Definition of Done

- [x] Complete Cooking Session: the automated UI test returns from Feedback to a fresh Setup.
- [x] Cooking Engine and UI are decoupled: `CookingEngine` consumes domain values and `Date`, and returns `CookingGuidance`.
- [x] Motion System and Cooking Engine are decoupled: `MotionDirector` translates `CookingEvent` to a visual/haptic/sound cue.
- [x] FLIP signature motion: T−5 attention, numeric emphasis, centralized haptics, hero `KeyframeAnimator`, and compact later flips.
- [x] TAKE IT OUT signature motion: urgent text/haptic/sound cue and state-driven pan-to-warm Finish transition.
- [x] READY signature motion: distinct success feedback, warm completion screen, and whole-to-sliced transition.
- [x] Motion and haptic share one event source through `MotionDirector`.
- [x] Background timer is date-based: remaining time is `phaseDuration - now.timeIntervalSince(phaseStartedAt)` and recovery has a dedicated test.
- [x] Background flip alert: `NotificationService` schedules the next event from the absolute phase end date.
- [x] Live Activity: embedded ActivityKit/WidgetKit extension shows only phase, next action, and absolute-date countdown.
- [x] Reduce Motion: hero flip becomes a crossfade, pull becomes the state-driven fade, Ready uses opacity without spatial scaling, heat/rest ambience is removed.
- [x] Motion does not control business state: no animation completion handlers exist; a dedicated test proves a motion event leaves the session unchanged.
- [x] Feedback calibrates the next cook: doneness adjusts total duration and crust adjusts initial sear, with directional tests.
- [x] Local persistence restores active session, calibration, and feedback history.
- [x] Manual temperature input can trigger an early pull recommendation.
- [x] No unnecessary renderer/game stack or pre-rendered animation frames were introduced.

## Motion and performance audit

- Keyframe animation closures contain transforms only; no engine, storage, notification, or I/O calls.
- Timeline refresh and authoritative cooking time are independent.
- Ambient effects use fixed-count shapes and simple opacity/offset transforms.
- No per-frame database work, large live blur, unbounded particles, image allocation, or infinite basting animation.
- The full simulator flow completed without a crash, timeout, or observed interaction stall.

## Physical-device checks before App Store submission

These cannot be meaningfully proven by Simulator automation and should be included in release QA:

- Verify actual haptic intensity and the three restrained system sounds in a noisy kitchen.
- Verify notification delivery while the app is suspended and the phone is locked.
- Verify Lock Screen/Dynamic Island Live Activity presentation on supported hardware.
- Run Instruments/ETTrace on the oldest supported physical device during hero FLIP and TAKE IT OUT.
- Add final App Store icon artwork and signing/team configuration.
