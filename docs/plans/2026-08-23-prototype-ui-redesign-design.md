# Prototype-led UI/UX Redesign

## Goal

Rebuild the existing SteakCopilot flow around the supplied nine-screen iPhone prototype while preserving the tested Cooking Engine, session persistence, localization, motion cues, notifications, Live Activity behavior, accessibility identifiers, and explicit Exit/Skip escape routes.

## Direction

Three implementation depths were considered:

1. **Cosmetic reskin:** recolor the existing screens and keep their layouts. Lowest risk, but it would miss the prototype's information hierarchy and card-led UX.
2. **Faithful shell redesign (selected):** retain the domain/controller layer and rebuild every SwiftUI screen plus the shared navigation shell. This captures the prototype while limiting risk to presentation code.
3. **Full product rearchitecture:** replace the stage model and merge Ready/Eat/Feedback. This could match the mock literally but would discard verified cooking behavior and make Live Activity recovery riskier.

The selected direction treats the prototype as the visual source of truth and maps it onto the existing seven flow stages.

## Visual system

- Light stages use a warm porcelain background, near-black type, soft neutral cards, 16–20 pt radii, restrained shadows, and a rust-red brand accent.
- Cook uses a near-black photographic stage, high-contrast white type, compact amber/rust status pills, and translucent controls.
- Typography stays on semantic SF Pro styles for Dynamic Type. Oversized cooking countdowns retain monospaced rounded numerals.
- SF Symbols provide all interface icons. Photographic food and cookware remain raster assets.
- The prototype's centered stage title and progress dots become a shared `StageHeader`; Exit and Skip stay accessible through compact controls without dominating the content.

## Flow mapping

| Existing stage | Prototype treatment | Primary interaction |
| --- | --- | --- |
| Setup | Raw steak hero, thickness control, doneness cards, cooking-method row | Start Cooking |
| Prep | Two large visual task cards plus optional dry-brine note | Mark Dry and Salt, then continue |
| Heat | Large overhead hot-pan hero and concise water-drop test | Pan is ready |
| Cook | Dark immersive pan scene, action badge, timer/action readout, temperature rail | Confirm engine-requested action |
| Finish | Finish estimate/last reading, carryover progress visualization, rest note | Automatic boundary |
| Ready/Eat | Sliced steak hero and concise result summary | Continue to eat / feedback |
| Feedback | Compact visual choice grids for doneness and crust | Save |

## State and interaction

`CookingSessionController` remains the only phase-transition owner. Views keep only local presentation state, such as Setup selections, Prep checkmarks, and Feedback selections. The shared root presents destructive confirmation for Exit and safety-aware confirmation for Skip. No image, animation, timer, or view callback owns a business transition.

## Responsive and accessible behavior

Each stage is built in a vertical `ScrollView` or flexible stack with a bottom safe-area action, avoiding fixed full-screen pixel layouts. Cards use semantic type, minimum 44 pt controls, VoiceOver identifiers, selected traits, and Reduce Motion fallbacks. The iPhone 17 portrait viewport is the visual QA baseline; smaller supported phones must remain scrollable rather than clipped.

## Verification

- Preserve and update the existing 33-test baseline.
- Add assertions for redesigned shared stage controls and all primary flow identifiers.
- Capture Setup, Prep, Heat, Cook, Finish, Ready, and Feedback on the same iPhone 17 simulator.
- Compare implementation captures with the supplied prototype in a design QA report and fix all P0–P2 differences.
- Pass localization Catalog audits plus Debug and Release simulator builds.
