# Five-Level Doneness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the existing doneness artwork with the five user-provided assets and expand the cooking configuration from three to five doneness levels.

**Architecture:** Keep `Doneness` as the single source of truth for labels, target temperature, pull temperature, cooking-budget scaling, and asset identity. Setup, result imagery, feedback imagery, persistence, and the Cooking Engine continue consuming that enum without introducing a second UI-only model. Existing raw values remain unchanged so saved sessions remain decodable.

**Tech Stack:** Swift 6, SwiftUI, XCTest/XCUITest, Xcode asset catalogs, String Catalogs.

---

### Task 1: Lock the five-level domain contract

**Files:**
- Modify: `SteakCopilot/Domain/Doneness.swift`
- Modify: `SteakCopilotTests/CookingEngineTests.swift`

**Step 1: Write the failing tests**

Add assertions that `Doneness.allCases` contains five values in display order, all target and pull temperatures increase monotonically, every target remains above its pull temperature, and cooking-budget factors increase monotonically.

**Step 2: Run the focused tests and verify failure**

Run the `CookingEngineTests` target. Expected: failure because only three cases exist.

**Step 3: Implement the minimal model expansion**

Add `mediumWell` and `wellDone` while preserving the current three raw values. Use these domain values:

| Doneness | Target | Pull | Budget factor |
| --- | ---: | ---: | ---: |
| Rare | 52°C | 49°C | 0.88 |
| Medium Rare | 54°C | 52°C | 1.00 |
| Medium | 60°C | 57°C | 1.14 |
| Medium Well | 65°C | 62°C | 1.28 |
| Well Done | 71°C | 68°C | 1.42 |

**Step 4: Run the focused tests and verify pass**

Expected: all `CookingEngineTests` pass.

### Task 2: Install the five exact visual assets

**Files:**
- Replace: `SteakCopilot/Resources/Assets.xcassets/DonenessRare.imageset/doneness-rare.png`
- Replace: `SteakCopilot/Resources/Assets.xcassets/DonenessMediumRare.imageset/doneness-medium-rare.png`
- Replace: `SteakCopilot/Resources/Assets.xcassets/DonenessMedium.imageset/doneness-medium.png`
- Create: `SteakCopilot/Resources/Assets.xcassets/DonenessMediumWell.imageset/`
- Create: `SteakCopilot/Resources/Assets.xcassets/DonenessWellDone.imageset/`

**Step 1: Map assets by visible center color**

- `11_46_27` → Rare
- `11_46_31` → Medium Rare
- `11_46_35` → Medium
- `11_46_39` → Medium Well
- `11_46_45` → Well Done

**Step 2: Preserve transparency and fit**

Convert each source to a 1000 × 1000 transparent PNG. Keep the full steak inside the square and use universal asset-catalog entries.

**Step 3: Validate assets**

Use `sips` to verify dimensions and alpha. Expected: five 1000 × 1000 PNGs with alpha.

### Task 3: Use one asset mapping across the product

**Files:**
- Modify: `SteakCopilot/Domain/Doneness.swift`
- Modify: `SteakCopilot/Design/SteakVisual.swift`
- Modify: `SteakCopilot/Features/Setup/SetupView.swift`
- Modify: `SteakCopilot/Features/Result/FeedbackView.swift`

**Step 1: Add a stable asset name to `Doneness`**

Expose an `assetName` computed property so Setup and result views cannot drift into different switch mappings.

**Step 2: Update Setup selection**

Render all five `Doneness.allCases` in a horizontally scrollable picker with compact cards, selected outline, accessibility identifiers, and enough bottom spacing for two-line labels.

**Step 3: Update result and feedback imagery**

Use the selected doneness asset for sliced result imagery. Map the five relative feedback choices from Rare through Well Done, removing synthetic brightness changes.

**Step 4: Build and inspect the Setup screen**

Expected: all five cards are usable on iPhone 17 without shrinking labels beyond legibility or clipping the primary action.

### Task 4: Complete localization and regression coverage

**Files:**
- Modify: `SteakCopilot/Localizable.xcstrings`
- Modify: `SteakCopilotTests/LocalizationTests.swift`
- Modify: `SteakCopilotUITests/SteakCopilotUITests.swift`

**Step 1: Add translations**

Add `Medium Well` → `七分熟` and `Well Done` → `全熟`. Keep English as the development language.

**Step 2: Extend UI tests**

Assert that the two new Setup buttons exist and can be selected. Add a cooking-flow launch using Well Done to prove the new value reaches the engine.

**Step 3: Verify catalogs**

Run `xcstringstool sync` with stale marking disabled, validate JSON, and assert all Simplified Chinese units are translated.

### Task 5: Final verification and commit

**Files:**
- Update: `design-qa.md`

**Step 1: Run focused tests**

Run domain, localization, and five-level Setup UI tests.

**Step 2: Run full verification**

Run the full test suite plus Debug and Release simulator builds.

**Step 3: Visual QA**

Capture English and Simplified Chinese Setup states on iPhone 17. Verify the five assets progress from red to brown, scrolling/selection works, labels are readable, and no action is clipped.

**Step 4: Commit**

Commit the complete change with `feat: expand doneness to five levels`.
