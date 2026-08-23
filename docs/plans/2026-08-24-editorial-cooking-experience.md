# Editorial Cooking Experience Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild Steak Copilot's presentation layer as a warm editorial home, unified dark cooking session, and warm result/history experience while preserving the existing cooking engine and session behavior.

**Architecture:** `RootFlowView` continues to route from the controller's persisted phase. New SwiftUI views collapse the existing page-per-stage presentation into Home, Cooking Session, and Result surfaces; the controller only gains narrow presentation-facing persistence accessors.

**Tech Stack:** Swift 6, SwiftUI, Observation, XCTest/XCUITest, Asset Catalogs, Xcode 26.

---

### Task 1: Lock the new design system and persistence seams

**Files:**
- Modify: `SteakCopilot/Design/AppTheme.swift`
- Modify: `SteakCopilot/Domain/Steak.swift`
- Modify: `SteakCopilot/Persistence/CookingStore.swift`
- Modify: `SteakCopilot/App/CookingSessionController.swift`
- Test: `SteakCopilotTests/SteakCopilotTests.swift`

**Steps:**
1. Write tests for cut asset mapping, per-cut saved configuration, and history ordering.
2. Run the focused tests and confirm they fail.
3. Add spacing/color/type tokens and narrow preference/history store APIs.
4. Run the focused tests and confirm they pass.
5. Commit the foundation.

### Task 2: Build Home and Advanced Settings Sheet

**Files:**
- Create: `SteakCopilot/Features/Home/CookingHomeView.swift`
- Create: `SteakCopilot/Features/Home/SteakHeroCarousel.swift`
- Create: `SteakCopilot/Features/Home/AdvancedSettingsSheet.swift`
- Add: `SteakCopilot/Resources/Assets.xcassets/RawRibeye.imageset`
- Add: `SteakCopilot/Resources/Assets.xcassets/RawFilet.imageset`
- Add: `SteakCopilot/Resources/Assets.xcassets/RawStrip.imageset`
- Modify: `SteakCopilot/App/RootFlowView.swift`
- Test: `SteakCopilotUITests/SteakCopilotUITests.swift`

**Steps:**
1. Add failing UI assertions for the carousel, summary, Begin Cooking action, and settings sheet.
2. Install the supplied transparent steak assets.
3. Implement the paging carousel, summary, primary CTA, and item-driven settings sheet.
4. Verify carousel selection, saved per-cut setup, and compact-height scrolling.
5. Commit Home and Settings.

### Task 3: Build the unified Cooking Session shell

**Files:**
- Create: `SteakCopilot/Features/Session/CookingSessionView.swift`
- Create: `SteakCopilot/Features/Session/CookingStageScene.swift`
- Modify: `SteakCopilot/App/RootFlowView.swift`
- Modify: `SteakCopilot/App/SessionStageControls.swift`
- Test: `SteakCopilotUITests/SteakCopilotUITests.swift`

**Steps:**
1. Add failing UI assertions proving Prep, Heat, Cook, and Finish share one session shell.
2. Implement the dark shell with phase header, hero readout, stage media, one instruction, telemetry, and one primary action.
3. Map existing controller phases/actions to differentiated Prep, Preheat, Sear/Flip, Butter/Baste, Check, and Rest scenes.
4. Preserve all existing controller action calls and Exit/Skip behavior.
5. Verify phase transitions, manual-temperature entry, reduced motion, and compact height.
6. Commit the session shell.

### Task 4: Build Result and Cook Log

**Files:**
- Create: `SteakCopilot/Features/Result/CookingResultView.swift`
- Create: `SteakCopilot/Features/History/CookLogView.swift`
- Modify: `SteakCopilot/App/RootFlowView.swift`
- Test: `SteakCopilotUITests/SteakCopilotUITests.swift`

**Steps:**
1. Add failing tests for completion metrics, Cook Again, Cook Log, and feedback save.
2. Implement one warm result surface for ready/eat/feedback phases.
3. Implement custom history rows backed by existing feedback records.
4. Verify empty and populated history states and return-to-home behavior.
5. Commit Result and Cook Log.

### Task 5: Localize, visually compare, and ship

**Files:**
- Modify: `SteakCopilot/Localizable.xcstrings`
- Modify: `SteakCopilotUITests/SteakCopilotUITests.swift`
- Modify: `design-qa.md`
- Add: `docs/verification/screenshots/*`

**Steps:**
1. Add Simplified Chinese translations for every new string and confirm English remains default.
2. Run unit tests and the complete UI flow in English and Simplified Chinese.
3. Build Debug and Release for simulator.
4. Capture Home, Settings, key Cooking phases, Result, History, and compact-height states.
5. Compare the implementation and source prototype together, fix all P0/P1/P2 findings, and record `final result: passed`.
6. Commit, push `main`, and verify local HEAD equals `origin/main`.
