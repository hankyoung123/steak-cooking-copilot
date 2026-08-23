# Editorial Cooking Experience Design

## Outcome

Steak Copilot becomes a three-act experience: a warm editorial home, a near-black unified cooking instrument, and a warm completion/result surface. A user can identify the selected steak and configuration within one second, swipe between Ribeye, Filet, and Strip, begin with one dominant action, and read the current cooking instruction within two seconds.

## Chosen approach

Three approaches were considered:

1. Incrementally restyle the seven existing screens. This is the smallest code diff, but it preserves the fragmented flow and cannot satisfy the single-session-shell requirement.
2. Keep `CookingSessionController`, `CookingEngine`, and the persisted session as the source of truth, while replacing the presentation below `RootFlowView` with Home, Settings Sheet, Cooking Session, Result, and Cook Log surfaces. This is the selected approach because it changes the product experience without duplicating or rewriting cooking logic.
3. Replace the domain flow with a new navigation/state model. This would make the new IA direct, but it violates the requirement to preserve stage progression, algorithms, timer behavior, session state, and persistence.

## Architecture

`RootFlowView` remains the only router. Setup renders `CookingHomeView`; Prep, Heat, Cook, and Finish all render one `CookingSessionView`; Ready, Eat, and Feedback render one `CookingResultView`. Sheets are local, item-driven presentation surfaces for advanced settings, cook history, and feedback where appropriate.

The controller remains the source of truth for the active `CookingSession`. Small presentation-facing controller APIs expose read-only cook history and saved per-cut setup preferences. These additions do not change the engine's profiles, temperatures, timers, action sequencing, or calibration behavior.

## Visual system

- Canvas: warm ivory `#F3EFE7` outside cooking, near-black `#12110F` during the active session.
- Accent: warm gold `#B79866` for progress and quiet emphasis; steak red `#7C3028` for selected doneness and destructive/culinary emphasis.
- Rhythm: 8, 16, 28, 48, and 72 point tokens.
- Type: 11–12 point eyebrow, 13–14 supporting, 16–17 body, 24–28 section, 48–64 cut name, 72–96 timer.
- Food imagery carries visual weight. UI cards, blur, glow, gradients, and capsule decoration are removed unless required for a real control or photographic legibility.

## Core surfaces

### Home

A native paging carousel occupies roughly the upper half of the screen. It uses three supplied transparent raw-steak assets, allows a hint of adjacent cuts, scales and fades non-selected cuts, and emits selection haptics. Below it, a concise summary shows cut, doneness, thickness, starting condition, pull target, and estimated duration. `Begin Cooking →` is the only dominant action. `Fine-tune settings` opens one advanced settings sheet; a quiet history icon opens Cook Log.

### Advanced settings

The sheet is one scrollable surface with typographic sections and separators: five doneness options with supplied cross-section imagery, thickness presets plus fine adjustment, fridge/room starting condition, and read-only pull target and estimated time. `Save & Close` persists the selected cut's last-used setup.

### Cooking session

One dark shell renders all active phases. The header contains phase and minimal progress; the body contains a hero timer/readout, a large phase-specific photographic scene, and one instruction; telemetry and the single phase action sit at the bottom. Preheat, sear, flip, butter, baste, check, and rest are differentiated by real photography/assets and short 0.35–0.6 second transitions. Pan Ready, Flip, and Remove receive the strongest motion emphasis. Exit and Skip remain available in every active phase.

### Result and Cook Log

The result returns to warm ivory and leads with sliced steak imagery, completion copy, final reading/estimate, duration, and doneness. `Cook Again` returns to setup; `View Cook Log` opens a custom history surface. Cook Log reads existing persisted feedback records and uses custom rows rather than `List`.

## Accessibility, localization, and verification

All controls retain stable accessibility identifiers and selected traits. English is the development/default language and every new user-facing string has Simplified Chinese. Layouts must remain complete on compact iPhone heights and with larger Dynamic Type. Verification includes unit tests, UI flow tests, English/Chinese captures, compact/standard simulator captures, and a source-vs-implementation Design QA report.
