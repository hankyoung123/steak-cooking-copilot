# Steak Cooking Copilot V1 Verification

Verified on 2026-08-23 with Xcode 26.2, Swift 6.2, and an iPhone 17 simulator running iOS 26.2. The deployment target remains iOS 18.0.

## Automated results

- Full suite: **27/27 passed** in 173.225 seconds.
- Unit and integration tests: **24/24 passed** across `CookingEngine`, `CookingSessionController`, calibration, motion mapping, and application loading.
- End-to-end XCUITests: **3/3 passed**.
  - Case A: 3 cm Ribeye, Medium Rare, no thermometer; repeated flips, butter, take-out, honest estimated finish, Ready, Eat, Feedback, and fresh Setup.
  - Case B: 4 cm Strip, Medium Rare, manual thermometer; repeated flips, fat cap, butter/baste, temperature entry, and take-out.
  - Case C: 3 cm Tenderloin, Medium; repeated flips, no fat-cap step, butter, and finish.
- Debug simulator build: **passed**.
- Release simulator build: **passed**. Xcode emitted only the expected signed Live Activity extension stripping note.
- `git diff --check`: **passed**.
- Source audit found no legacy first/second sear phases, decrementing authoritative timer, 10 Hz refresh loop, animation-driven phase mutation, or generated live temperature.

## First-principles cooking model

- [x] `searFirst` and `searSecond` are deleted; searing is one cyclic `.sear` state.
- [x] A confirmed flip increments `flipCount`, remains in `.sear`, and schedules the next absolute action date.
- [x] `CookingSession` stores facts and absolute `nextActionAt`; remaining time is derived from `Date`.
- [x] Cut affects the path: Strip/Ribeye can request fat-cap work, while Tenderloin skips it.
- [x] Butter is a confirmed event timestamp, not a fake top-level cooking phase.
- [x] Pull is a recommendation and confirmed action, not a timer-owned phase.
- [x] A manual temperature immediately recalculates guidance; a low reading returns to the sear cycle and a threshold reading requests take-out.
- [x] Target and pull temperatures are separate domain values.
- [x] Finish duration is a bounded estimate derived from profile and optional manual reading, not a fixed 240-second timer.
- [x] Without a thermometer, the app never invents a temperature and labels finish timing as estimated.
- [x] Calibration is keyed by cut, thickness bucket, and doneness; crust bias and cooking-time adjustment remain separate.
- [x] Start Over clears notifications, ends the current Live Activity, resets transient motion, and persists a fresh session.
- [x] Background recovery recomputes guidance from absolute dates.
- [x] Notifications and Live Activity consume Engine guidance rather than reconstructing UI timing.

## V1 Definition of Done

- [x] Complete Setup → Prep → Heat → Cook → Finish → Ready → Eat → Feedback session.
- [x] Cooking Engine and UI are decoupled: the Engine consumes domain facts and returns `CookingGuidance`.
- [x] Motion System and Cooking Engine are decoupled: `MotionDirector` translates domain events into visual, haptic, and optional sound cues.
- [x] FLIP signature motion has T−5 attention, centralized countdown feedback, one hero keyframe flip, and compact later flips.
- [x] TAKE IT OUT signature motion has urgent event-driven feedback and a Reduce Motion fade fallback.
- [x] READY signature motion has distinct completion feedback and a whole-to-sliced reveal.
- [x] Motion and haptic use the same domain event source.
- [x] Cooking timing is date-based and independent of animation refresh.
- [x] The app schedules the next background action from Engine-owned `nextActionAt`.
- [x] Live Activity recovery rebinds an existing matching activity or starts a new one.
- [x] Reduce Motion preserves the full business flow while simplifying FLIP, TAKE IT OUT, READY, and ambience.
- [x] Motion never owns or mutates phase, remaining time, target temperature, or next action.
- [x] Feedback calibrates the next matching steak configuration locally without ML or cloud infrastructure.
- [x] No game engine, Metal renderer, backend, generalized food model, or pre-rendered animation-frame stack was introduced.

## Motion and performance audit

- Signature timings live in `MotionTiming`; keyframe closures contain transforms only.
- Cook uses a one-second `TimelineView` for display and refreshes the controller only at meaningful action boundaries (T−5, T−3, T−2, and T−0).
- Authoritative time is always recomputed from absolute dates; animation completion never advances cooking.
- Ambient effects are bounded, low-contrast SwiftUI transforms with Reduce Motion fallbacks.
- No per-frame persistence, engine recomputation, I/O, large live blur, unbounded particles, or repeated image allocation was found.
- All three simulator flows completed without crash or interaction stall.

## Visual evidence

- [Case A estimated Finish screen](screenshots/case-a-estimated-finish.png): inspected after layout correction; no overlap and no fabricated live temperature.
- Setup, Cook, and Ready were also inspected interactively on the iPhone 17 simulator.
- Runtime visuals use one photographic steak surface masked by SwiftUI shape plus three doneness cross-section assets; motion remains runtime-driven.

## Physical-device checks before App Store submission

Simulator automation cannot establish these hardware qualities:

- Verify actual haptic intensity and the three restrained sounds in a noisy kitchen.
- Verify notification delivery while suspended and locked.
- Verify Lock Screen and Dynamic Island Live Activity presentation on supported hardware.
- Profile FLIP and TAKE IT OUT on the oldest supported physical device with Instruments/ETTrace.
- Add final App Store icon artwork and production signing/team configuration.
