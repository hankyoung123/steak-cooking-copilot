# Steak Cooking Copilot V1 Implementation Plan

> **For Codex:** Use the executing-plans workflow to implement this plan task-by-task.

**Goal:** Build a complete, testable iOS 18 SwiftUI app that helps a user pan-sear one steak through setup, active cooking, resting, eating, and calibration feedback.

**Architecture:** A pure deterministic cooking engine derives guidance from configuration and absolute dates. A root `@Observable` controller owns the session and routes domain events into a presentation-only motion director; SwiftUI screens render state and never infer or advance cooking phases from animation callbacks.

**Tech Stack:** Swift 6, SwiftUI, Observation, UserNotifications, UIKit haptics, XCTest, Xcode 26.2, iOS 18+

---

### Task 1: Project scaffold

**Files:**
- Create: `SteakCopilot.xcodeproj/project.pbxproj`
- Create: `SteakCopilot/App/SteakCopilotApp.swift`
- Create: `SteakCopilot/Resources/Assets.xcassets/**`
- Create: `SteakCopilotTests/SteakCopilotTests.swift`

**Steps:**
1. Create an iOS application target and XCTest unit-test target with an iOS 18 deployment target.
2. Add a minimal app entry and smoke test.
3. Run `xcodebuild -project SteakCopilot.xcodeproj -scheme SteakCopilot -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`.
4. Confirm the app target compiles before adding features.

### Task 2: Domain and engine (TDD)

**Files:**
- Create: `SteakCopilot/Domain/Steak.swift`
- Create: `SteakCopilot/Domain/Doneness.swift`
- Create: `SteakCopilot/Domain/CookingPhase.swift`
- Create: `SteakCopilot/Domain/CookingSession.swift`
- Create: `SteakCopilot/Engine/CookingProfile.swift`
- Create: `SteakCopilot/Engine/CookingCalibration.swift`
- Create: `SteakCopilot/Engine/CookingEngine.swift`
- Test: `SteakCopilotTests/CookingEngineTests.swift`

**Steps:**
1. Write failing tests for duration scaling by thickness/doneness, next-action boundaries, date-derived remaining time, and pull temperature.
2. Run the focused tests and verify failures.
3. Implement immutable configuration/profile/guidance values and a deterministic engine.
4. Run tests and verify they pass.
5. Add event-boundary and first-versus-compact flip tests.

### Task 3: Session ownership, calibration, and storage

**Files:**
- Create: `SteakCopilot/App/CookingSessionController.swift`
- Create: `SteakCopilot/Persistence/CookingStore.swift`
- Test: `SteakCopilotTests/CookingSessionControllerTests.swift`
- Test: `SteakCopilotTests/CookingCalibrationTests.swift`

**Steps:**
1. Write failing tests proving background recovery is based on `Date` and feedback adjusts the next profile in the expected direction.
2. Implement a root `@Observable` controller that handles user intents and persists snapshots.
3. Ensure phase changes happen only in controller/domain methods, never motion callbacks.
4. Run focused tests, then all tests.

### Task 4: Motion, haptics, notification services

**Files:**
- Create: `SteakCopilot/Motion/MotionEvent.swift`
- Create: `SteakCopilot/Motion/MotionPreset.swift`
- Create: `SteakCopilot/Motion/MotionTiming.swift`
- Create: `SteakCopilot/Motion/MotionDirector.swift`
- Create: `SteakCopilot/Services/HapticService.swift`
- Create: `SteakCopilot/Services/NotificationService.swift`
- Create: `SteakCopilot/Motion/MotionQuality.md`
- Test: `SteakCopilotTests/MotionDirectorTests.swift`

**Steps:**
1. Test that each domain event maps to one presentation cue and haptic preset without mutating session state.
2. Implement centralized visual/haptic mappings and preference gates.
3. Schedule FLIP, ADD BUTTER, CHECK TEMP, TAKE IT OUT, and READY notifications from absolute dates.
4. Document the motion quality-gate fields for every animation.

### Task 5: Theme and reusable food visuals

**Files:**
- Create: `SteakCopilot/Design/AppTheme.swift`
- Create: `SteakCopilot/Design/SteakVisual.swift`
- Create: `SteakCopilot/Design/PanVisual.swift`
- Create: `SteakCopilot/Design/PrimaryActionButton.swift`

**Steps:**
1. Implement semantic cream/charcoal/heat/accent tokens and Dynamic Type-friendly typography.
2. Build a parameterized steak visual for cut, thickness, doneness, sear, and sliced state.
3. Build low-cost pan, heat, butter, and steam elements.
4. Add deterministic previews for representative light, cook, and ready states.

### Task 6: Complete product flow

**Files:**
- Create: `SteakCopilot/App/RootFlowView.swift`
- Create: `SteakCopilot/Features/Setup/SetupView.swift`
- Create: `SteakCopilot/Features/Prep/PrepView.swift`
- Create: `SteakCopilot/Features/Heat/HeatView.swift`
- Create: `SteakCopilot/Features/Cook/CookView.swift`
- Create: `SteakCopilot/Features/Finish/FinishView.swift`
- Create: `SteakCopilot/Features/Result/EatView.swift`
- Create: `SteakCopilot/Features/Result/FeedbackView.swift`

**Steps:**
1. Implement Setup controls with visual cut/thickness/doneness feedback.
2. Implement Prep and Heat without fake temperature countdowns.
3. Implement Cook as one stable screen for all internal cooking phases.
4. Implement Finish carryover visualization, Eat reward, and feedback capture.
5. Add accessibility labels, large hit targets, and concise action text.

### Task 7: Signature motion and Reduce Motion

**Files:**
- Modify: `SteakCopilot/Features/Cook/CookView.swift`
- Modify: `SteakCopilot/Features/Finish/FinishView.swift`
- Modify: `SteakCopilot/Design/SteakVisual.swift`

**Steps:**
1. Implement hero FLIP keyframes (lift, rotation, impact) and compact subsequent flips.
2. Implement TAKE IT OUT lift/exit plus charcoal-to-cream transition.
3. Implement READY pause, completion cue, and whole-to-sliced transition.
4. Add Reduce Motion crossfade/low-scale fallbacks without changing domain flow.
5. Confirm no animation completion handler mutates cooking state.

### Task 8: Verification and PRD audit

**Files:**
- Create: `docs/verification/2026-08-23-v1-checklist.md`

**Steps:**
1. Run `xcodebuild test` on an available iOS Simulator.
2. Run a clean app build and inspect all compiler warnings.
3. Launch the app in Simulator and smoke-test Setup → Feedback, including a shortened debug session.
4. Enable Reduce Motion and repeat FLIP, PULL, and READY transitions.
5. Record exact results against the V1 Definition of Done and note any simulator-only limitations.
