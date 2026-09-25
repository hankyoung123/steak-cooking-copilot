# One ending page instead of three

Verified on 2026-09-25 with Xcode 26.2 / Swift 6.2, iOS 26.2, one iPhone 17
simulator.

## The defect

TAKE OUT handed over to a three-page epilogue, and two of the pages were the same
screen:

| Page | Eyebrow / title | Primary button | Identifier |
| --- | --- | --- | --- |
| READY | WELL DONE / "Enjoy!" | "Enjoy" | `ready.continue` |
| EAT | WELL DONE / "Enjoy!" | "Log this cook" | `eat.feedback` |
| FEEDBACK | COOK COMPLETE / "How was it?" | "Save & Cook Again" | `feedback.save` |

The hero, the summary card and the two secondary buttons were identical on all
three; only the primary label changed. So ending a cook cost three taps through
two identical pages before the feedback form — the only thing the app actually
needs from the user — finally appeared.

## The result

```
TAKE OUT → FINISHING (rest, auto-advances) → result page → setup
                                                    ↑ one tap
```

The feedback form is now part of the result page and its primary action logs the
cook and returns to setup:

- the middle band, which `SessionLayoutMetrics.Result` already reserved for the
  *taller* of {note, form}, simply holds the form from the start, so there is no
  longer an "appearance" that could push the hero, the summary or the CTA;
- the result note ("Perfect Medium Rare / Juicy and tender. Great job!") is gone:
  it stated the same thing the form asks about, and the form is the reason the
  page exists;
- `primaryTitle` is now one string and `primaryIdentifier` one identifier
  (`feedback.save`), whichever ending phase a session is in;
- skipping the ending page leaves without logging in **one** tap
  (`skipCurrentStage` for `.ready`, `.eat`, `.feedback` → `startOver`) instead of
  walking the old chain three times.

## What deliberately did not change

- **The feedback still feeds the calibration loop.** `submitFeedback` is
  unchanged: it records the feedback, updates the learned adjustment for
  (cut × bucket × doneness), saves the setup preferences and starts a fresh
  session. Merging pages removed taps, not learning.
- **The phase machine is intact.** `.eat` and `.feedback` still exist and still
  render the same page, because that is what a session *persisted by an older
  build* restores into; such a session exits through the same single action. No
  stored session can fail to decode, and nothing was migrated.
- **FINISHING is still its own screen.** The rest is a timed wait with the
  carryover estimate and the "finishing heat" bar; it advances on its own when
  the estimate elapses.
- The Live Activity / notification end state, the journey counter (which reports
  nothing after TAKE OUT), and the result layout metrics are untouched.

## Automated results

- Unit: **278/278 passed**.
  `testSkippingEveryActiveStageAdvancesAndReturnsToFreshSetup` now asserts the
  ending page is reached in `.ready` and that one more skip lands on a fresh
  setup — the chain it used to walk is gone.
  `testResultSkeletonFitsEverySupportedPhoneAtDefaultTextSize` keeps asserting
  the reserved middle band, now described as the form's band.
- UI: **22/22 passed**. `finishReadyFeedbackFlow`, which three tests share, lost
  two taps:

  ```swift
  // before: ready.continue → eat.feedback → feedback.save
  // after:  feedback.save
  ```

  `testResultSkeletonSlotsDoNotMoveBetweenReadyEatFeedback` became
  `testResultPageKeepsTheFormAndTheCallToActionOnScreen`: with the form always
  present there is no longer a transition to sample across, so it asserts what
  still matters — the form is on the page (the failing case it guarded), the CTA
  is hittable without scrolling, and the eyebrow is the ending page's own. The
  `Makefile`'s layout-test list was updated with the rename.

## Screenshot

`docs/verification/screenshots/single-result-page/result-page.png` — the ending
page as shipped: WELL DONE / "Enjoy!", the sliced-steak hero, TARGET TEMP 55°C and
TIME 00:06, the HOW WAS IT? form, `View Cook Log` / `Cook Again`, and one
`Save & Cook Again`. Captured by the UI test, not assembled by hand.
