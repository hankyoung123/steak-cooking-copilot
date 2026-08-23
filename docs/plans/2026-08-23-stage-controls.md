# Stage Exit and Skip Controls Implementation Plan

**Goal:** Give every active cooking-stage screen a consistent, confirmed way to exit the session or skip to the next flow stage.

**Architecture:** `RootFlowView` owns one small confirmation enum and renders a shared `SessionStageControls` top inset for every stage except Setup, which is the safe exit destination. `CookingSessionController` remains the sole owner of stage transitions, cleanup, persistence, notifications, and Live Activity lifecycle.

**Tech Stack:** Swift 6.2, SwiftUI, Observation, XCTest, XCUITest, String Catalogs.

---

### Task 1: Define and test skip transitions

**Files:**
- Modify: `SteakCopilotTests/CookingSessionControllerTests.swift`
- Modify: `SteakCopilot/App/CookingSessionController.swift`

**Steps:**
1. Add a failing test that skips Prep → Heat → Cook → Finish → Ready → Eat → Feedback → Setup.
2. Extract shared finishing and ready transitions so normal and skipped paths use the same lifecycle work.
3. Implement `skipCurrentStage(at:)` and verify the controller test passes.

### Task 2: Add shared stage controls

**Files:**
- Create: `SteakCopilot/App/SessionStageControls.swift`
- Modify: `SteakCopilot/App/RootFlowView.swift`

**Steps:**
1. Add one UI-owned confirmation enum instead of separate Boolean flags.
2. Render Exit and Skip controls through a top safe-area inset on Prep through Feedback.
3. Confirm Exit before calling `startOver`; confirm Skip before calling the controller transition.
4. Give both controls stable accessibility identifiers.

### Task 3: Localize control and safety copy

**Files:**
- Modify: `SteakCopilot/Localizable.xcstrings`

**Steps:**
1. Add English-source keys and Simplified Chinese translations for controls, confirmations, and stage-specific safety messages.
2. Keep Setup as the English-default fallback destination.
3. Validate every Catalog entry has a Simplified Chinese translation.

### Task 4: Verify every stage

**Files:**
- Modify: `SteakCopilotUITests/SteakCopilotUITests.swift`

**Steps:**
1. Add an end-to-end UI test that uses Skip on every active stage and returns to Setup.
2. Verify Exit clears an active session and returns to Setup.
3. Capture and inspect representative light and dark stage screenshots.
4. Run the full suite, Debug and Release builds, Catalog audit, and `git diff --check`.
