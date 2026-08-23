# Design QA — Editorial cooking experience

## Inputs

- Visual source of truth: `/Users/hankyoung/Downloads/ChatGPT Image 2026年8月23日 12_35_58.png` (1024 × 1536 composite)
- Runtime: iPhone 17 Simulator, iOS 26.2
- Primary native viewport: 402 × 874 points (1206 × 2622 screenshot at 3×)
- Compact viewport: iPhone 16e, 390 × 844 points (1170 × 2532 screenshot at 3×)
- Same-input comparison canvas: `docs/verification/screenshots/editorial/reference-comparison.png`

The supplied reference is a nine-screen presentation board rather than raw device captures. The comparison canvas places that board beside six native captures at the same visual scale, covering Home, settings, Prep, Cook, Result, and Feedback. Native status bars and safe areas intentionally remain system-owned.

## Required surfaces

| Surface | Evidence | Result |
| --- | --- | --- |
| Home | `home-en.png`, `home-compact-en.png` | Passed |
| Advanced settings | `advanced-settings.png` | Passed |
| Cook Log | `cook-log.png` | Passed |
| Prep / Heat | `session-prep-final.png`, `session-preheat-final.png` | Passed |
| Sear / Baste / Rest | `session-sear-final.png`, `session-rest-final.png` and full stage UI test | Passed |
| Result / Feedback | `result-ready-final.png`, `result-feedback-final.png` | Passed |
| Exit / Skip | every active stage plus return-to-Home UI test | Passed |
| English / Simplified Chinese | locale-specific localization and UI tests | Passed |

## Interaction audit

- Native steak carousel pages between Ribeye, Strip, and Filet, keeps adjacent content visible, updates the plan, and provides selection haptics.
- One settings sheet owns doneness, thickness, starting temperature, and cooking estimate inputs; preferences persist independently per cut.
- The cooking journey remains one view shell whose visual state changes across Prep, Heat, Sear, Flip, Baste, Check, and Rest.
- Every active phase exposes Exit and Skip. Both destructive exits and stage skips require confirmation.
- Result actions support feedback, save-and-cook-again, cook again, and Cook Log navigation.
- UI automation exercised all primary controls. Simulator/XCTest logs showed no app crash or layout failure.

## Visual iterations

1. The first unified-session pass allowed content to extend beyond the horizontal viewport. The shell now constrains and clips its visual layers to the available geometry; all controls remain inside safe margins.
2. The Cook scene initially showed an empty pan, then an obviously rectangular texture crop. The final scene masks a high-resolution cooked surface with the selected cut's transparent silhouette and sizes it to the pan perspective.
3. Result originally risked presenting a target as a measured final temperature. It now labels unmeasured values as `TARGET TEMP`; `FINAL TEMP` appears only when an actual reading exists.
4. Compact-device capture verified that the Home summary and primary action remain visible without shrinking the food hero or creating nested cards.

## Final audit

- Warm ivory Preparation/Result surfaces and near-black Cooking surfaces match the source's two-mode visual language.
- Food remains the dominant visual element; typography, spacing, red action color, warm gold telemetry, and sparse controls are consistent across the journey.
- No unresolved P0, P1, or P2 defects, cropped primary actions, broken safe areas, placeholder imagery, or dead core controls remain.
- Five supplied doneness assets are used consistently in settings and feedback.
- Release simulator build succeeded and the current full automated suite passes.

Final result: passed
