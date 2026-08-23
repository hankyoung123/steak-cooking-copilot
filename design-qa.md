# Design QA — Prototype-led cooking flow redesign

## Inputs

- Reference: `/Users/hankyoung/Downloads/ChatGPT Image 2026年8月23日 12_35_58.png` (1024 × 1536 composite)
- Runtime: iPhone 17 Simulator on iOS 26.2
- Native captures: 1206 × 2622 test attachments, plus a 368 × 800 optimized Cook capture
- Combined comparison canvases:
  - `.derivedData/PrototypeDesignQA-20260823/compare-setup-prep-heat.png`
  - `.derivedData/PrototypeDesignQA-20260823/compare-cook-flip-final.png`
  - `.derivedData/PrototypeDesignQA-20260823/compare-finish-eat-feedback.png`

The reference is a framed nine-screen composition rather than raw device screenshots. Comparisons therefore use app-owned content, hierarchy, spacing rhythm, color, imagery, and matching flow states; the simulator status bar and safe areas remain native.

## Required surfaces

| Surface | Evidence | Result |
| --- | --- | --- |
| Setup | English and Simplified Chinese five-doneness setup captures | Passed |
| Prep | `stage-controls-prep` capture | Passed |
| Heat | `prototype-heat` capture | Passed |
| Cook | final 368 × 800 Cook capture and combined Flip comparison | Passed |
| Finish | estimated-finish and stage-flow captures | Passed |
| Ready / Eat | `prototype-ready` and `prototype-eat` captures | Passed |
| Feedback | `prototype-feedback` capture | Passed |
| Exit / Skip | every non-Setup stage plus return-to-Setup UI test | Passed |
| English / Simplified Chinese | locale-specific UI tests and screenshots | Passed |

## Iterations

### Iteration 1

- P1: Cook temperature rail text and primary action extended beyond the horizontal safe margin.
- Fix: constrained Cook content to the available geometry and applied explicit 16-point horizontal margins.
- Verification: final Cook captures show complete values, rail, and rounded action button inside the viewport.

### Iteration 2

- P2: the animated whole-steak layer read too tall compared with the reference's pan perspective.
- Fix: constrained and compressed the runtime steak layer vertically while preserving the existing event-driven flip motion.
- Verification: final combined Cook comparison shows a low, horizontal steak silhouette centered in the pan with no clipping.

### Iteration 3

- P1: Setup originally exposed only three doneness levels and reused synthetic image variants.
- Fix: expanded the shared domain model to five ordered levels and installed the five supplied transparent steak cross-section assets from Rare through Well Done.
- Verification: English and Simplified Chinese iPhone 17 captures show all five assets, readable two-line labels, correct red-to-brown progression, and working selection outlines without clipping the primary action.

### Deliberate product differences

- Finish displays an explicitly labeled estimate when no thermometer reading exists. It does not copy the reference's precise live temperature, because the Cooking Engine has no sensor measurement to support that claim.
- Setup now exposes five doneness levels, and Feedback uses the same five supplied assets for its relative calibration scale.
- Seven progress marks represent the app's real Setup → Prep → Heat → Cook → Finish → Eat → Feedback flow.

## Final audit

- No unresolved P0, P1, or P2 visual defects.
- No cropped imagery, broken safe-area layout, inaccessible primary actions, or dead core controls observed.
- Food remains the dominant visual element; Cook uses the requested focused dark mode and the other stages return to warm porcelain.
- Final automated result: 36 passed, 0 failed, 0 skipped.

Final result: passed
