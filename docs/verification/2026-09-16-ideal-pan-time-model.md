# Ideal in-pan time: the linear exposure model

Verified on 2026-09-16 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2. Deployment target remains iOS 18.0.

## What changed

Three things, all about *time*:

1. The pan-time model is now a **line through the empirical Medium-Rare
   baseline** — 2.0cm ≈ 120s and +60s per additional 0.5cm — instead of a
   proportional scale from a reference thickness. It describes the **ideal
   in-pan heat exposure** and contains no allowance for how long the user takes
   to react.
2. The late stage (`FAT CAP`, `ADD BUTTER` → `BASTE`) runs on the plan's
   **absolute** timeline, so a step taken late compresses what follows it
   instead of pushing `TAKE IT OUT` later.
3. A flip that would land within `cooking.minSecondsAfterFlipBeforePull` (10s) of
   the estimated pull is **not scheduled at all** in the timing fallback: the
   plan waits the remaining seconds out.

## 1. The model

```
exposure(t)  = baseCookingBudget + thicknessSecondsPerCM · (t − referenceThickness)
budget(t,d)  = clamp(exposure(t) · donenessFactor[d] + cutOffset, min, max)

baseCookingBudget    = 180     # seconds, for the 2.5cm Medium-Rare reference
referenceThickness   = 2.5     # cm
thicknessSecondsPerCM= 120     # +60s per +0.5cm
minCookingBudget     = 90      # only binds below ~1.7cm
maxCookingBudget     = 720
```

| Thickness | Exposure | Pan time (strip, Medium Rare) |
| --- | --- | --- |
| 2.0cm | 120s | **2:00** |
| 2.5cm | 180s | **3:00** |
| 3.0cm | 240s | **4:00** |
| 3.5cm | 300s | **5:00** |

`cuts.cookingBudgetOffset` (+5 ribeye, 0 strip, −8 tenderloin) and the learned
calibration still apply on top; nothing else does.

### Why the old shape could not express that baseline

The old model was `base × (t / reference)` — a line through the origin. It cannot
pass through (2.0cm, 120s) *and* (3.5cm, 300s): those points have different
slopes (60 s/cm vs 85.7 s/cm), so it produced 240s at 2.0cm and 420s at 3.5cm
with the old `baseCookingBudget: 300`. Reaching 120s at 2.0cm therefore forced
`baseCookingBudget` down, which then made thick steaks too fast.

The baseline is genuinely linear, so the shape is now linear with a non-zero
intercept. This is also what `testEveryHalfCentimetreAddsSixtySeconds` pins: the
*step* is constant at every thickness, which is the property the old shape broke.

Two knobs changed meaning:

- `cooking.minThicknessFactor` is **removed**. It existed to stop a proportional
  model from starving thin steaks (`0.72` floor). The linear model has no such
  failure mode, and the absolute `minCookingBudget` already covers it.
- `cooking.minCookingBudget` moved `180 → 90`. At 180s it would have clamped the
  2.0cm baseline from 120s up to 180s — a 50% overrun on exactly the steak the
  baseline is calibrated on. 90s now only binds below ~1.7cm
  (`testTheBudgetFloorDoesNotClampTheThinBaseline`).

### No operating margin

The number *is* the pan time. A real user needs a few seconds to notice a
reminder, pick up tongs, flip and tap confirm; that delay is **not** added back
here, because it would be counted twice — once as slack in the parameters and
again as the delay that actually happens. `testTheBaselineIsTheWholePanTimeWithNoOperatingAllowance`
asserts the Medium-Rare strip budget equals the exposure time exactly.

## 2. Lateness is absorbed, never compensated

`CookingEngine` now exposes the late stage as a **plan** rather than a set of
durations:

| Method | Meaning |
| --- | --- |
| `estimatedPullDate` | cook start + budget — the absolute pull anchor |
| `fallbackPullDate` | the above, *only* when the timing fallback decides the pull |
| `fatCapEndDate` | plan's late-stage start + fat-cap duration, capped by the anchor |
| `basteEndDate` | plan's fat-cap end + baste duration, capped by the anchor |

`CookingSessionController` uses `fatCapEndDate` / `basteEndDate` instead of
`now + duration`, which is the whole fix: the window ends when the **plan** says
it ends, so acting 8s late leaves an 8s shorter window.
`testALateAddButterShrinksTheBasteWindow` drives the controller, adds the butter
8s late, and asserts the baste window is `basteDuration − 8`; the engine-level
`testLateButterShortensTheBasteByExactlyTheLateness` pins the same arithmetic and
that the planned end does not depend on the tap at all.

Because every boundary is an absolute date, the searing loop was already immune:
flipping late makes the *next* boundary the calibrated late stage, never a
stretched one. `testLateActionsCompressLaterStagesAndNeverMoveThePullDeadline`
walks a whole strip cook confirming **every** action 12s late and asserts that no
boundary the plan hands out ever falls past the pull anchor — the only thing that
lands after it is the user's own final tap.

### The pull anchor is fallback-only

`fallbackPullDate` returns `nil` when a probe reading is in play, because then the
pull follows a measurement that has not happened yet. The windows still follow the
plan (a late step still compresses what follows), but nothing is capped by a
timing estimate that is not allowed to make the pull decision. This keeps the
"a reading always wins" rule and the "the estimate is display-only" rule intact.

### No flip, then immediately TAKE IT OUT

At a sear boundary the engine skips the flip candidate when
`pullAt − flipDate < minSecondsAfterFlipBeforePull`. The remaining candidates are
the late stage and the pull, so the boundary becomes `TAKE IT OUT` and the
announced action follows it (`testNoFlipIsScheduledInsideTheGuardWindowBeforeThePull`).

Two consequences worth recording:

- `currentAction` returns `WAIT` rather than `FLIP` when the pending moment is
  inside the guard window, so the app does not *offer* a flip it will not
  schedule (`testThePlanWaitsRatherThanOfferAPointlessFlip`).
- `scheduledSearBoundaryKind` also checks the guard, so a flip boundary the user
  never confirmed cannot be announced as `FLIP` after it has drifted into the
  guard window.

The guard is deliberately fallback-only; with a probe the timing estimate is not
a decision, so a flip near it is still scheduled
(`testTheGuardDoesNotApplyWhenAProbeIsInPlay`).

The guard is also **scaled with the time scale**, like every other duration in
`CookingProfile`. An unscaled 10s guard is longer than a `-fastCook` steak
(~8s), which would have suppressed *every* flip and turned the route into
SEAR → FAT CAP with no flipping — a trap the UI walks would not have caught,
because they never assert a flip count.
`testTheGuardScalesWithTheTestTimeScale` and
`testTheFastCookScaleStillWalksTheFlipRoute` (which drives a real controller at
`timeScale: 0.035` and requires the flips and the closing `TAKE IT OUT`) both
pin this.

## 3. What the plan looks like now

Strip, Medium Rare, seconds from pan-on:

| Thickness | Flips | Late stage | Fat cap | Baste | Free sear before TAKE OUT |
| --- | --- | --- | --- | --- | --- |
| 2.0cm | 25, 50, 75 | 78 | → 113 | 113 → 120 | 0s |
| 2.5cm | 30, 60, 90 | 117 | → 152 | 152 → 180 | 0s |
| 3.0cm | 30, 60, 90, 120, 150 | 156 | → 191 | 191 → 229.4 | 10.6s |
| 3.5cm | 30, 60, 90, 120, 150, 180 | 195 | → 230 | 230 → 275 | 25s |

For 2.0cm and 2.5cm the fat cap and baste now fill the rest of the budget, which
is the compression rule working in the default configuration: the 35s fat cap is
a large share of a 120s steak, and the baste is capped by the pull anchor rather
than running a full 19.2s past it.

## 4. Unchanged

The canonical rules were not touched: boundary priority
(`estimatedPull` > `lateStage` > `flip`), the "never fabricate a temperature"
rule, manual-reading priority, `nextAction` / `nextActionAt` agreement, the phase
machine, session identity, animation never advancing a phase, Reduce Motion and
accessibility identifiers. The estimated centre temperature is still display-only
and still anchored so it reaches the suggested pull temperature at the estimated
pull — it moved with the budget, it did not influence it.

The interaction layer is unchanged and remains where lateness is handled: the
"approaching" reminder fires at 5s before a boundary, haptics at 3s/2s, and both
the notification and the Live Activity publish the **absolute** boundary date.

## Automated results

- Unit tests: **271/271 passed**, including 17 new in `PanTimingModelTests`
  (baseline, lateness absorption, guard, guard scaling, floor, doneness scaling).
- UI tests: **20/20 passed**, full suite on the one device (iPhone 17). The two
  that walk the cook are the ones that matter here: the pan is now ~33% shorter
  at every time scale, and both the phase walk
  (`testPrototypeVisualStatesUseStageSpecificArtwork`, at `-visualCook`) and the
  slot-stability walk (`testSessionSkeletonSlotsDoNotMoveBetweenCookingPhases`,
  at `-fastCook`) still reach every phase they assert. `make test-ui-layout`
  (3/3) was also run on its own as the cheap layout regression.
- Generator: `--self-test` **22 cases passed**, `--check` clean. Two validation
  cases were added (non-positive thickness slope, negative flip guard) and one
  re-anchored (the illegal-range case needed a `maxCookingBudget` below the new
  90s floor).
- Tuning Lab coverage: expected leaf count **104 → 105**
  (−`minThicknessFactor`, +`thicknessSecondsPerCM`, +`minSecondsAfterFlipBeforePull`).

Five absolute-value expectations were updated rather than worked around, and each
is recorded because it is a real consequence of the shorter budgets:
- `TuningConfigurationTests.testEngineUsesTheYAMLParameters`: ribeye 3cm is
  245s (was 365s), the late stage 159.25s (was 237.25s), and the baste is
  31.36s instead of hitting the 45s cap.
- `TuningConfigurationTests.testChangingCutFlagsChangesLateStageActionAndProfile`:
  the +60s offset case is 300s (was 420s).
- `CutProfileTests.testBasteDurationIsClampedToTheConfiguredMaximum`: the cap now
  first binds at 3.5cm (300 × 0.16 = 48 → 45), not 2.5cm (180 × 0.16 = 28.8).
- `CutProfileTests.testBasteCapBindsOnlyForTheThickestRecommendation` (renamed
  from `...IsAbsorbedByTheClampAtRecommendedThickness`): the 45s cap used to bind
  for every cut at its recommended thickness; now only the 4.0cm tenderloin
  (352 × 0.16 × 1.1 = 61.95) still reaches it, and every cut still saturates the
  cap at 5cm. Recorded so raising the cap or the ratio fails loudly.
- `CookingSessionControllerTests.testNoThermometerFallbackContinuesFlipCycleUntilEstimatedPullBoundary`
  confirms three flips instead of four: the 60s→late-stage window is shorter.
  It now also asserts the loop ends on the plan's absolute late stage.

## Constraints honoured

`Config/production.yaml` remains the single source of truth — no Swift copy of
any default, and the generated artifact is regenerated and `--check` clean.
Layout constants were not touched. No new dependency, no 3D/RealityKit. The
`minThicknessFactor` removal is reflected in the generator schema, the runtime
validator, the Tuning Lab and the leaf count together, so the four cannot drift.
