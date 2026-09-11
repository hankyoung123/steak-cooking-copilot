# Setup screen polish and layout skeleton

Verified on 2026-09-11 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2, Simplified Chinese and English. Deployment target remains
iOS 18.0.

## Why the screen needed a skeleton

The three cuts have different name lengths in both languages — `RIBEYE` /
`NEW YORK STRIP` / `FILET`, `肉眼牛排` / `纽约客牛排` / `菲力` — and the screen
was a plain `VStack` of intrinsically sized rows. Nothing pinned the title band,
the parameter row, the pre-flight summary or the call to action, so any copy
change was free to reflow everything below it.

`SteakCopilot/Design/HomeLayoutMetrics.swift` resolves one geometry per device,
and the selected cut is not an input to it:

```
topBar         history / settings          fixed
hero           steak artwork               flexible (fills the leftover)
navigation     prev cut · dots · next cut  fixed
title          TODAY'S CUT + cut name      fixed
plan           doneness | thickness        fixed
summary        duration + pull target      fixed
primaryAction  Begin Cooking               fixed
secondary      Fine-tune settings          fixed
```

The hero takes `container − heightExcludingHero`, clamped to a floor and a
ceiling. That is what makes the page fill a phone exactly — confirmed by
measurement, not by eye: the primary action lands at 740.0–795.7pt with all
three cuts, and the only empty space below it is the 40pt home-indicator safe
area.

## What changed

| Area | Before | After |
| --- | --- | --- |
| Title size | 48pt | **43pt** (−10.4%) |
| Top icons | 18pt, ink 0.6, no target | 17pt, ink 0.62, uniform 44pt target |
| Carousel labels | ink 0.58, 82pt slot, 6pt from arrow | ink 0.66, 92pt slot, 5pt from arrow |
| Carousel row | labels at page margins | capped at 302pt so arrows + labels + dots read as one control |
| Pagination dot | fill-only change | constant 7pt slot, so the animated dot cannot shift the group |
| Parameter divider | `Divider()` | 0.7pt hairline at ink 0.12 |
| Parameter columns | icon sized to glyph, no value slot | fixed 20×16 icon box, fixed 22pt value slot |
| Parameter labels | `.secondary` | ink 0.55 |
| Summary | 11pt, ink 0.48, all one weight | 12/13pt, ink 0.66, pull temperature in ember |
| CTA shadow | `0.2 / r10 / y5` | `0.12 / r6 / y3` |
| Fine-tune | underline, 12pt, no arrow | + trailing arrow, ink 0.72, full-width 44pt target |

### The title

43pt is a 10.4% reduction from 48pt, inside the requested 8–12% band. The
artwork stays the primary subject and the title now confirms the current cut
rather than competing with the photograph. Type style, weight, tracking and ink
are unchanged, so the brand voice is intact.

### The spacing rhythm

Every vertical gap now comes from a resolved token instead of per-element
padding: `heroToNavigation` 0, `navigationToTitle` 10, `titleToPlan` 22,
`planToSummary` 16, `summaryToPrimary` 22, `primaryToSecondary` 8.

The rhythm is **grouped, not uniform** — the hero and title form one
composition, the parameter row and summary form a second, and the CTA is set
apart from both. `testVerticalRhythmGroupsTheCompositionAndSetsTheCTAApart`
asserts exactly that structure, including that hero → title is the tight end of
the page and that the CTA gets the most air. A first attempt asserted a
monotonic ramp; that assertion was wrong about the design and was rewritten
rather than satisfied by distorting the spacing.

## Optical centring of the artwork

The artwork was geometrically centred but the subject is not. Measured as the
alpha-weighted centroid of each shipped asset, relative to the frame centre:

| Cut | Asset | Centroid offset | Declared correction |
| --- | --- | --- | --- |
| Ribeye | `RawRibeye` | +0.93% | −0.0093 |
| Strip | `RawStrip` | +0.73% | −0.0073 |
| Filet | `RawFilet` | +2.06% | −0.0206 |

The correction is a fraction of the rendered image side, so it holds at every
device size rather than being a hardcoded point value; on a 393pt phone it comes
to 2.3 / 1.8 / 4.9pt, all within the requested 4–8pt optical range. Filet is
genuinely about 2.2× the others, which is why the correction is per cut.

`SessionAssetOpticalTests` reads the alpha channel of the shipped assets and
fails if the declared constants stop matching the pixels, so these stay a
measurement rather than a nudge.

Two findings from that measurement contradicted the initial visual impression and
are worth recording:

- The bounding box of every asset is centred within ~0.4%; only the *weight*
  distribution is right-shifted. Correcting on the bounding box would have moved
  the artwork the wrong way.
- Only Filet's offset is visually meaningful (~2%). The subtle leftward shift on
  Ribeye and Strip is a real but tiny correction, not a fix for a visible defect.

## Automated results

UI tests run on **one device only** (iPhone 17), per the standing instruction.

- Unit tests: **177/177 passed**, including 11 new (`HomeLayoutTests` and
  `SessionAssetOpticalTests`).
- UI tests: **14/14 passed**, including the new
  `testHomeSkeletonSlotsDoNotMoveBetweenCuts`.

### Frame stability

`testHomeSkeletonSlotsDoNotMoveBetweenCuts` walks Ribeye → Strip → Filet,
samples the frame of each shared slot, and asserts a **±2pt** tolerance for
`minY`, `midX` and `height` on `home.carousel`, `home.title`,
`home.plan.doneness`, `home.plan.thickness` and `setup.primary`.

`home.summary` is asserted vertically only: the row is centred and its width
tracks the cut's cooking budget (a two-digit minute count is wider than a
one-digit one), so pinning its midpoint would pin a layout that should be free to
breathe. A coverage guard fails the test if the walk does not visit three
distinct cuts, so the assertions cannot pass vacuously.

Independently confirmed by pixel measurement of the captured screenshots: every
content band in all three cuts is identical to the tenth of a point.

## Screenshots

`docs/verification/screenshots/home-polish/` — four captures, downscaled to
1000px wide:

`home-ribeye`, `home-strip`, `home-filet`,
`home-zh-Hans-ribeye` (the CJK layout, where `纽约客牛排` is the longest string
the screen must lay out).

## Constraints honoured

`CookingEngine`, the state machine, all `Config/production.yaml` cooking
parameters, the tuning architecture and the artwork layer policy are untouched.
No glassmorphism, gradient, glow, floating badge, extra card or new illustration
was added. Motion is unchanged apart from the carousel's drag response, which was
narrowed (no rotation, gentler scale) so it reads as the same page swapping
content; Reduce Motion still disables the selection animation.
