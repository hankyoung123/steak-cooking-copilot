# Steak Cooking Copilot First-Principles Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the two-sided page timer with one fact-based cooking session that drives cyclic guidance, honest finish estimates, scoped calibration, and state-owned motion.

**Architecture:** `CookingSession` is the only runtime source of truth. `CookingEngine` derives a `CookingGuidance` from the session, profile, scoped calibration, and current date; the controller records confirmed facts, while UI, notifications, Live Activity, and Motion only consume guidance.

**Tech Stack:** Swift 6, SwiftUI, Observation, ActivityKit, UserNotifications, XCTest, XCUITest.

---

### Task 1: Simplify the domain and make time absolute

**Files:**
- Modify: `SteakCopilot/Domain/CookingPhase.swift`
- Modify: `SteakCopilot/Domain/CookingSession.swift`
- Modify: `SteakCopilot/Domain/Doneness.swift`
- Modify: `SteakCopilot/Domain/Steak.swift`
- Test: `SteakCopilotTests/CookingEngineTests.swift`

**Steps:**
1. Add failing tests that require a single `.sear`, separate target/pull temperatures, cut-specific fat-cap strategy, and `nextActionAt` countdown behavior.
2. Run the focused test target and confirm the old phase/session model fails to compile against those requirements.
3. Replace `.searFirst/.searSecond/.butter/.pull/.resting` with `.sear/.finishing`; add factual session dates and confirmations only.
4. Add `SteakCutProfile`, `ThicknessBucket`, and the target/pull temperature definitions to their existing domain owners.
5. Run the focused tests and commit the domain change.

### Task 2: Rebuild guidance around cyclic cooking

**Files:**
- Modify: `SteakCopilot/Engine/CookingProfile.swift`
- Modify: `SteakCopilot/Engine/CookingEngine.swift`
- Test: `SteakCopilotTests/CookingEngineTests.swift`

**Steps:**
1. Add failing tests for ~30-second flips, remaining in `.sear` after a flip, tenderloin skipping fat cap, manual temperature producing `.takeOut`, and no generated temperature without a reading.
2. Replace fixed first/second sear durations with `flipInterval` and `estimatedCookingBudget`.
3. Make guidance expose current/next action, absolute next-action date, estimated progress, pull recommendation, finishing range, and an optional engine event.
4. Derive late-stage transitions from confirmed actions, cut strategy, budget progress, and manual temperature without claiming measured doneness.
5. Run engine tests and commit.

### Task 3: Record only confirmed actions in the controller

**Files:**
- Modify: `SteakCopilot/App/CookingSessionController.swift`
- Test: `SteakCopilotTests/CookingSessionControllerTests.swift`

**Steps:**
1. Add failing controller tests for cyclic flips, fat-cap branching, butter confirmation inside `.baste`, pull-to-finishing, absolute-date recovery, and full flow completion.
2. Replace phase-based button routing with guidance-action confirmation.
3. Recompute guidance only on real state changes, lifecycle restoration, user actions, and absolute time boundaries.
4. Ensure every user action updates factual session fields before persistence.
5. Run controller tests and commit.

### Task 4: Scope calibration to similar steaks

**Files:**
- Modify: `SteakCopilot/Engine/CookingCalibration.swift`
- Modify: `SteakCopilot/Persistence/CookingStore.swift`
- Modify: `SteakCopilot/App/CookingSessionController.swift`
- Test: `SteakCopilotTests/CookingCalibrationTests.swift`

**Steps:**
1. Add a failing store test proving different cut/thickness/doneness keys do not share calibration.
2. Add `CalibrationKey` and persist a dictionary of calibration values with a migration-safe default.
3. Apply doneness feedback to cooking budget and crust feedback to sear bias for only the active key.
4. Run calibration/controller tests and commit.

### Task 5: Make runtime services consumers of guidance

**Files:**
- Modify: `SteakCopilot/Services/NotificationService.swift`
- Modify: `SteakCopilot/Services/LiveActivityService.swift`
- Modify: `SteakCopilot/App/CookingSessionController.swift`
- Test: `SteakCopilotTests/CookingSessionControllerTests.swift`

**Steps:**
1. Add test seams and failing lifecycle tests for Start Over notification cleanup and Live Activity termination.
2. Schedule notifications only from `guidance.nextAction` and `guidance.nextActionAt`.
3. Rebind to matching ActivityKit activities on app restoration; create one only when needed.
4. Make `startOver()` clear pending notifications, end activity, reset transient motion, and persist a fresh session.
5. Run lifecycle tests and commit.

### Task 6: Make UI an honest projection

**Files:**
- Modify: `SteakCopilot/Features/Cook/CookView.swift`
- Modify: `SteakCopilot/Features/Finish/FinishView.swift`
- Modify: `SteakCopilot/Features/Setup/SetupView.swift`
- Modify: `SteakCopilot/App/RootFlowView.swift`
- Modify: `SteakCopilot/Motion/MotionTiming.swift`

**Steps:**
1. Split Cook visuals into `CookingStageVisual`, `CookingActionReadout`, `ManualTemperatureControl`, `HeroFlipModifier`, and `CompactFlipModifier` without introducing a ViewModel.
2. Use `TimelineView` only to derive countdown display from an absolute date; remove 10 Hz controller refresh.
3. Replace Finish's fabricated live temperature and exact rest countdown with an estimated range and an explicitly labeled last manual reading/carryover estimate.
4. Replace doneness color dots with cross-section visual assets and move signature motion durations to timing tokens.
5. Build and visually inspect setup, cyclic cooking, finishing, and ready states; commit.

### Task 7: Verify the three required scenarios

**Files:**
- Modify: `SteakCopilotUITests/SteakCopilotUITests.swift`
- Modify: `docs/verification/2026-08-23-v1-checklist.md`

**Steps:**
1. Update UI automation so it follows engine actions instead of tapping a fixed seven-phase sequence.
2. Run Case A: 3 cm ribeye, medium rare, no thermometer; prove repeated flips, late guidance, take-out, estimated finishing, and ready.
3. Run Case B: 4 cm strip, medium rare, manual thermometer; prove fat cap, baste, temperature-driven recalculation, and take-out.
4. Run Case C: 3 cm tenderloin, medium; prove fat cap is skipped.
5. Run all unit tests, UI tests, Debug build, and Release build; inspect the rendered screens.
6. Audit every Definition of Done item against source/test/runtime evidence, then commit and push.

