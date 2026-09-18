# The session progress rail no longer steps backwards

Verified on 2026-09-16 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2.

## The defect

The rail in the session header is the second view of the same walk the `05 / 07`
counter shows — and the two disagreed. `CookingSessionView.overallProgress` was
mapped **per phase**:

```swift
case .sear, .fatCap: 0.12 + controller.guidance.estimatedProgress * 0.48
case .baste: 0.62
```

`.baste` was a fixed constant while `.sear` was a fraction of the cooking budget,
and the no-thermometer fallback legitimately **re-enters the searing loop after
BASTE**: `confirmCurrentAction(.flip)` goes back to `.sear` when the tail of the
cook still has room for a flip. For the default configuration (ribeye, 3cm,
Medium Rare) that produced:

| Moment | Phase | Rail |
| --- | --- | --- |
| 159.25s — late stage starts | sear | 0.432 |
| 159.25s — ADD BUTTER | baste | **0.620** |
| 190.61s — baste window ends, FLIP offered | baste | 0.620 |
| the user flips → loop re-enters | sear | **0.493** ← backwards |
| 245s — TAKE IT OUT | finishing | 0.900 |

`0.12 + 0.48 × 190.61 / 245 = 0.4934`.

Three things are worth recording about it:

- **The counter was right.** `CookingJourney`'s milestone is a high-water mark
  (`advanced(from:with:)` can only move forward), so `05 / 06` never went back.
  The rail was the only thing that disagreed with it.
- **It was not new.** With the previous pan-time parameters (budget 365s, baste
  clamped to 45s → 282.25s) the same mapping gave
  `0.12 + 0.48 × 0.773 = 0.491 < 0.62`, so the step back existed before the
  empirical pan-time model landed. The pan-time change only altered how often
  the last flip is offered at all.
- **The other bar was fine.** The `FINISHING` "Finishing heat" bar is
  `1 − remaining / total` against a `nextActionAt` that is fixed when the phase
  starts, so it is monotonic.

## The fix

`SessionProgressRail` (new, `Domain/`) derives the rail from the same monotonic
milestone the counter uses, as the maximum of two non-decreasing terms clamped to
the current step's segment:

```
floor   = 0.12 + 0.74 × (position(milestone) − 1) / totalSteps
ceiling = 0.12 + 0.74 ×  position(milestone)      / totalSteps
timed   = 0.12 + 0.48 × estimatedProgress
rail    = min(max(floor, timed), ceiling)
```

- `floor` only advances, because the milestone is a high-water mark.
- `timed` (`elapsed ÷ estimated budget`) only advances within a session.
- `ceiling` is the next step's floor, so it only advances too.
- `min`/`max` of non-decreasing values is non-decreasing, so the rail is
  **monotonic by construction** — no high-water mark stored in the view, and
  nothing to reset when the view is rebuilt.

The time term is kept (with the same `0.48` span) so the searing loop still
creeps rather than sitting still, and the clamp means the rail can never run
*ahead* of the counter either. The band is unchanged (`prep` 0.04, `heat` 0.08,
cook 0.12…0.86, `finishing` 0.92, done 1.0), so the rail still reaches the same
places at the same phases.

Same walk after the fix, for the default configuration:

| Moment | Phase | Milestone | Rail |
| --- | --- | --- | --- |
| seam of first flip | sear | flip | 0.268 |
| late stage | sear | flip | 0.416 (clamped to the step) |
| ADD BUTTER prompt | sear | addButter | 0.432 |
| butter added | baste | baste | 0.564 |
| baste ends, flip re-enters the loop | **sear** | baste | **0.564 (held)** |
| TAKE IT OUT | sear | takeOut | 0.712 |
| resting | finishing | takeOut | 0.920 |

The rail now advances in the same discrete steps the counter displays, with the
time term smoothing the first part of the searing loop.

## Tests

New `SessionProgressRailTests` (5 cases):

- `testTheBasteToSearReEntryDoesNotStepTheRailBack` — the exact defect, asserted
  at the exact moment (0.620 → 0.564 today; 0.620 → 0.493 before).
- `testAControllerWalkNeverMovesTheRailBackwards` — drives a real controller
  through the whole fallback cook, samples the rail at every boundary and after
  every confirmation, and asserts it never decreases. It also **requires** that
  the walk performed the BASTE → SEAR re-entry, so the regression cannot become
  untested if the route changes.
- `testTheRailIsNonDecreasingInBothOfItsInputs` — the invariant behind the
  guarantee: a later milestone, or more elapsed time, can never lower the value.
  Checked for both route shapes (5 steps and 6).
- `testTheRailStaysInsideTheCurrentStepsSegment` — the rail and the `05 / 07`
  counter can never disagree by more than the step being displayed.
- `testTheRailIsOrderedAcrossTheNonCookPhases` — setup < prep < heat < cook <
  finishing < done.

The first draft of the route test failed, and it is worth recording why: it fed
milestones out of route order (`.addButter` before `.fatCap` on a strip), which
is a sequence the app cannot produce. The invariant test above replaced it,
because the guarantee is about the rail's *inputs* being monotone, not about an
enumeration of phase/step pairs.

## Automated results

- Unit tests: **276/276 passed** (5 new).
- UI tests: **20/20 passed** (full suite, one device).
- Generator unchanged: `--self-test` 22 cases, `--check` clean.

## Constraints honoured

The `05 / 07` counter, `CookingJourney`, the phase machine, the engine's boundary
priority, the session layout slots and the `FINISHING` bar are untouched: this
change is confined to how one value is derived for display. `SessionProgressRail`
is a pure function of `(phase, milestone, journey, estimatedProgress)`, so it is
unit-testable without a view, which is what let the defect be asserted directly
instead of through a screenshot.
