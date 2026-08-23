# System Language Localization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make all user-facing copy follow the system language in English or Simplified Chinese, with English as the development language and fallback.

**Architecture:** Add target-scoped String Catalogs with English source strings and Simplified Chinese translations. Keep domain state language-neutral, but localize computed presentation strings at their existing presentation boundaries so SwiftUI, notifications, accessibility, and Live Activity all receive localized values.

**Tech Stack:** Swift 6.2, SwiftUI, Foundation localization, String Catalogs, XCTest, XCUITest.

---

### Task 1: Add localization regression tests

**Files:**
- Create: `SteakCopilotTests/LocalizationTests.swift`
- Modify: `SteakCopilotUITests/SteakCopilotUITests.swift`

**Steps:**
1. Add a unit test asserting English is the development language and Simplified Chinese resources exist.
2. Add UI smoke tests that launch in `zh-Hans` and an unsupported language.
3. Verify the tests fail before localization resources exist.

### Task 2: Add target-scoped String Catalogs

**Files:**
- Create: `SteakCopilot/Localizable.xcstrings`
- Create: `SteakCopilotLiveActivity/Localizable.xcstrings`
- Modify: `SteakCopilot.xcodeproj/project.pbxproj`

**Steps:**
1. Keep `developmentRegion = en` and add `zh-Hans` to known regions.
2. Add complete English and Simplified Chinese entries for app, notification, accessibility, and widget copy.
3. Validate both catalogs as JSON and build both targets.

### Task 3: Localize runtime-computed copy

**Files:**
- Modify: domain title helpers, Cook/Finish/Result views, notification service, Live Activity service, and steak accessibility copy.

**Steps:**
1. Replace verbatim computed strings with `String(localized:)` at presentation boundaries.
2. Use localized format strings for values and ranges.
3. Preserve accessibility identifiers and business-state raw values unchanged.

### Task 4: Verify both languages

**Files:**
- Test: `SteakCopilotTests/LocalizationTests.swift`
- Test: `SteakCopilotUITests/SteakCopilotUITests.swift`

**Steps:**
1. Run localization unit tests.
2. Run English fallback and Simplified Chinese UI smoke tests.
3. Run the full test suite plus Debug and Release builds.
4. Inspect representative English and Chinese simulator screenshots and run `git diff --check`.
