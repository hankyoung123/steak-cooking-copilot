# Steak Cooking Copilot V1 Design

## Product boundary

The app guides one pan-seared steak from setup through feedback. It is not a recipe browser, connected-device controller, or precision thermometer. The primary interface is the steak and its current physical state; chrome and controls stay quiet until the user must act.

The experience follows one stable screen hierarchy: Setup → Prep → Heat → Cook → Finish → Eat → Feedback. Sear, flip, fat-cap, butter, baste, temperature check, and pull are states inside the Cook screen rather than destinations. The emotional palette moves from warm cream, through charcoal during active cooking, back to warm cream for resting and eating.

## Architecture

Domain values (`Steak`, `Doneness`, `CookingPhase`, `CookingSession`) contain no SwiftUI code. `CookingEngine` is a deterministic value type: configuration, calibration, and the current date produce a `CookingGuidance` value containing phase, action, remaining time, progress, and emitted events. Time is derived from absolute dates (`phaseStartedAt` and `phaseDuration`), never decremented counters.

`CookingSessionController` is the root-owned `@Observable` coordinator. It advances business state in response to user intent and authoritative time, asks the engine for guidance, persists resumable state, and hands domain events to `MotionDirector`. The controller never waits for animation completion. Returning from the background simply recomputes guidance from the current date.

`MotionDirector` owns only transient presentation state. One `MotionEvent` maps to a visual preset, a centralized haptic, and an optional restrained sound. First flip uses the hero keyframe treatment; later flips use the compact treatment. Pull and Ready are cinematic only at those moments. Reduce Motion swaps spatial movement for short opacity/scale transitions while preserving identical domain transitions.

## UI composition

`RootFlowView` keeps a stable root and switches the content surface by high-level flow stage. Setup uses a food-first steak illustration with cut geometry, thickness scale, and smoothly changing doneness center. Prep is a small checklist with single-run dry and salt feedback. Heat shows a pan whose heat ambience builds without claiming a measured temperature. Cook uses a timeline-driven refresh solely to render derived time; the screen shows the steak, action, next-action time, and necessary temperature. Finish visualizes carryover as a slowly extending curve. Eat provides the reward moment and enters feedback.

The visual steak is a reusable SwiftUI shape/composition rather than dozens of frames. Ambient movement is deliberately sparse and inexpensive: gradients, a few bubbles, and opacity/offset changes. Signature movement uses `KeyframeAnimator`, and expensive calculations remain outside animation closures.

## Persistence, background behavior, and errors

V1 stores the active session, feedback history, and calibration in `UserDefaults` through a small `CookingStore`; this is local, deterministic, and adequate for the limited data shape. Notification authorization is requested at the point the user starts a cook, and actionable events are scheduled from absolute dates. If permission is denied, the in-app flow remains complete and the Heat screen explains that alerts are unavailable without blocking cooking.

Malformed persisted data is discarded safely and starts a fresh setup. A restored completed session opens at the appropriate Finish/Eat state. Haptic and notification failures are non-fatal. Manual temperature input is optional; the engine continues with its time estimate when absent.

## Testing and quality gates

Unit tests cover profile calculation, date-derived remaining time, event boundaries, first-versus-later flip behavior, background recovery, and calibration direction. UI logic uses deterministic fixtures and previews for representative states. The project must compile and unit tests must pass on an available iOS Simulator.

Every motion has a documented trigger, purpose, owner, duration, interruptibility, Reduce Motion fallback, and performance risk in `MotionQuality.md`. Final review checks that animation never mutates cooking phase, Cook remains one screen, timers derive from dates, all critical instructions are also textual, and Dynamic Type/VoiceOver labels are present.
