# The in-pan cooking journey and the flow counter

Verified on 2026-09-11 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2. Deployment target remains iOS 18.0.

## What was wrong

The counter in the top-right corner was a `switch` on `guidance.currentAction`
inside the view, with a hardcoded `/ 07`:

```swift
case .flip: step = 2
case .standFatCap: step = 3
case .addButter, .baste: step = 4
case .checkTemperature, .takeOut: step = 5
default: step = 1
```

That was wrong in four separate ways, and only the first is cosmetic:

1. **Every cut was shown seven steps**, but fat cap is optional. A ribeye walked
   01…06 and then displayed a seventh step it never performed.
2. **ADD BUTTER and BASTE shared one number** (`step = 4`), so the route the user
   was actually walking had a hidden step — and the fat-cap step was skipped
   entirely for cuts that have one (`standFatCap` = 3 but `baste` = 4, so a strip
   went 02 → 04 from the user's point of view).
3. **The number was a function of the current action**, so it was not monotonic.
   Repeated flips re-counted, and the no-thermometer fallback — which sends the
   session back into the searing loop after BASTE and CHECK TEMP — walked the
   counter backwards.
4. **FINISHING and READY were numbered on the end of the route** (06 and 07),
   claiming that resting and serving are cook steps.

## The model

`SteakCopilot/Domain/CookingJourney.swift`:

```
CookingJourneyStep   sear · flip · fatCap · addButter · baste · checkTemperature · takeOut
CookingJourney       the route for one steak, derived from needsFatCap
CookingJourneyFacts  what the session has actually done
CookingProgress      currentStep / totalSteps, the only thing the chrome sees
```

The route is built from the configuration, so the fat cap is a real optional
milestone rather than a gap:

| Cut | Route | Total |
| --- | --- | --- |
| Strip | SEAR → FLIP → **FAT CAP** → ADD BUTTER → BASTE → CHECK TEMP → TAKE OUT | 7 |
| Ribeye | SEAR → FLIP → ADD BUTTER → BASTE → CHECK TEMP → TAKE OUT | 6 |
| Tenderloin | SEAR → FLIP → ADD BUTTER → BASTE → CHECK TEMP → TAKE OUT | 6 |

Positions are contiguous in both cases: a ribeye reads 01…06 with no hole where
the fat cap would have been.

### Where the milestone comes from

Derived from recorded facts, never from `currentAction` as the answer — the
action is only evidence that a *prompt* is on screen for a step that has no
recorded fact of its own (`butterAddedAt` is written when the user confirms, so
"the app is asking for butter" needs the action to be visible at all).

| Evidence | Milestone | Sticky? |
| --- | --- | --- |
| `pulledAt` | TAKE OUT | yes |
| `phase == .checkTemperature` or `lastManualTemperatureAt` | CHECK TEMP | reading is |
| `butterAddedAt` | BASTE | yes |
| prompt `.addButter` | ADD BUTTER | superseded by the above |
| prompt `.checkTemperature` | CHECK TEMP | superseded by a reading |
| prompt `.takeOut` | TAKE OUT | superseded by `pulledAt` |
| `phase == .fatCap` or prompt `.standFatCap` | FAT CAP | superseded by butter |
| `flipCount >= 1` | FLIP | yes |
| otherwise | SEAR | — |

Every satisfied predicate is considered and the furthest one wins, so the result
does not depend on the order of the checks. `flipCount` is only tested for *has
flipped at all*, which is what makes frequent flipping one milestone.

### Why a stored high-water mark

The route legitimately returns to the searing loop: a reading below the pull
target, or the no-thermometer fallback after BASTE or CHECK TEMP. A purely
derived value would walk the counter backwards there, so the session stores the
furthest milestone reached and `CookingJourney.advanced(from:with:)` can only
move it forward.

It is a high-water mark *of the facts*, not a second source of truth: it is never
written anywhere except that one clamped advance, and it is persisted so the
stored value and the displayed one cannot drift apart between a refresh and the
next confirmed action.

### The chrome

`SessionStageControls` now takes a `CookingProgress?` and renders the pair of
numbers; the view's `stepLabel` switch is deleted, so the chrome has no idea what
a fat cap or a baste is. `nil` hides the counter.

Resting and serving pass `nil`: FINISHING is a rest, not the next cook step, so it
shows no number rather than 07. The counter's row is *reserved* even when hidden,
because collapsing it moved the skip control and changed the nav row's bounds —
caught by the session layout regression test, which failed on
`session.topControls` the first time.

Before the journey starts (PREP and HEAT) the counter shows `00 / total`, so the
length of the route is visible before the pan is hot.

## Automated results

- Unit tests: **196/196 passed**, including 21 new (`CookingJourneyTests` and
  `CookingProgressIntegrationTests`).
- UI tests: **14/14 passed**.

### Route and monotonicity

`CookingJourneyTests` covers the pure model: the strip route with the fat cap, the
contiguous six-step routes without it, fat cap as the only difference between
them, TAKE OUT as the final step, the exact label for every step of every route,
`00 / total` before the start, and no counter at all for resting and serving.

`CookingProgressIntegrationTests` drives real sessions through the controller and
asserts the *observed* sequence with repeats collapsed:

```
Strip   [1, 2, 3, 4, 5, 6, 7]
Ribeye  [1, 2, 3, 4, 5, 6]
```

plus that the observed sequence is always sorted (never walks back) on both the
thermometer and no-thermometer paths, that the counter starts only when the pan is
ready, that it disappears once the steak is resting, and that a relaunch reloads
the milestone without changing what is displayed.

Writing those tests found two real bugs rather than test bugs:

- **ADD BUTTER and CHECK TEMP were skipped in practice.** A prompt has no sticky
  fact, and observing only at confirmed-action boundaries hid those steps. The
  prompt is now evidence in its own right, which is also what makes the route read
  1…7 rather than jumping.
- **TAKE OUT was unreachable.** The milestone only advanced on `pulledAt`, but
  pulling also enters FINISHING, which hides the counter — so the last step of the
  route could never be displayed. The take-out prompt now advances it, so
  `07 / 07` shows while the app is asking for the steak to come out.

The visible counter was then confirmed against the running app:

| Stage | Displayed | Route position |
| --- | --- | --- |
| SEAR · SIDE ONE | `01 / 06` | 1, ribeye |
| BUTTER · BASTE (butter prompt) | `03 / 06` | 3, ribeye |
| CHECK (probe prompt) | `05 / 06` | 5, ribeye |
| FINISHING | hidden | — |

`docs/verification/screenshots/cooking-journey/` holds those three crops. The old
label showed `04 / 07` for the butter prompt — the wrong index *and* the wrong
total for the cut.

The session UI walk additionally asserts the on-screen counter end-to-end: every
sample matches `NN / 07` on a strip route, the sequence never decreases, the
maximum reaches 7, and FINISHING carries no counter.

## Constraints honoured

`CookingEngine` is untouched, including the boundary priority
(`estimatedPull` > `lateStage` > `flip`). No fake temperature, thermometer
priority, phase transition, `nextAction`/`nextActionAt` pairing or session
identity was changed. No cooking tuning parameter was touched. This is a change to
how progress is *described*, not to how the cook proceeds.
