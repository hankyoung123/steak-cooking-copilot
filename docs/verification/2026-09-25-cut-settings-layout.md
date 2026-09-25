# The cut settings sheet no longer clips its thickness row

Verified on 2026-09-25 with Xcode 26.2 / Swift 6.2, iOS 26.2 and one iPhone 17
simulator (1206 × 2622).

## The defect

The thickness choices were a single `HStack` of six equal chips:

```swift
HStack(spacing: 7) {
    ForEach([2.0, 2.5, 3.0, 3.5, 4.0, 5.0], id: \.self) { thickness in
        Button(String(format: "%.1f", thickness)) { … }
            .frame(maxWidth: .infinity, minHeight: 34)
    }
}
```

`maxWidth: .infinity` lets a chip grow but never shrink below the width its text
needs, so the row has a hard minimum. Two things push past it:

1. **A narrower content area.** The sheet is not always 402pt wide — iOS presents
   it inset (with side margins) on some devices and presentations, which is what
   the reported screenshot shows: the `5.0` chip sits half outside the sheet.
2. **Dynamic Type.** These labels are `.font(.system(size: 10))`, and that fixed
   size *does* scale: at the `accessibility-extra-large` content size the section
   headings in the sheet grow from 40pt to roughly 56pt, so the chip text grows
   with them and the row needs more width than it has.

Both were reproduced before the fix: the chips fit on a full-width 402pt sheet at
the default text size, and the row overflows as soon as the content area shrinks
or the text grows.

## The fix

The row is now an **adaptive grid** instead of a fixed row:

```swift
LazyVGrid(
    columns: [GridItem(.adaptive(minimum: 84), spacing: 7)],
    spacing: 7
) { … }
```

An adaptive `GridItem` resolves its column count from the width it is actually
given, so a chip can never be laid out beyond the content edge — the property
holds by construction rather than by picking numbers that happen to fit one
device. Three per row at every phone width (2 + 3 + … at the top, then the rest),
two only in a container narrower than roughly 250pt.

Alongside it:

- chips are **44pt tall** (`minHeight: 34` before), the HIG minimum tap target,
  which the grid's second row makes affordable;
- each chip carries `minimumScaleFactor(0.8)` as a second line of defence, and the
  label size went 10 → 11pt now that there is room;
- each chip has an identifier (`setup.thickness.4.0`) and an `isSelected` trait,
  so the choices are addressable and their state is observable;
- the two information rows (`Target Temperature`, `Estimated Time`) had no
  vertical padding, so they sat cramped against each other while every other
  section breathed at 15pt. They now have 14pt each;
- the footnote's top padding went 52 → 36pt, which the taller grid absorbs, so
  the sheet does not end in a wide empty band before the button.

The slider stays exactly as it was: it is the only way to reach `4.5`, which the
chip set does not offer. (Consolidating the two controls is a product decision,
not a layout fix, so it was left alone.)

## Automated results

New UI test `testEveryThicknessChoiceIsInsideTheSheet` walks the sheet and asserts
for **every** choice that it exists, is hittable, and that its frame lies inside
the window — then taps the one that used to be clipped (`5.0`) and asserts it
became the selected chip. It runs as part of the full suite, and was run twice
more by hand:

- at the default text size, and
- with `xcrun simctl ui <device> content_size accessibility-extra-large` — the
  case that a fixed row cannot survive; see
  `screenshots/cut-settings-layout/after-accessibility-text.png`.

Full runs: **unit 278/278** and **UI 22/22** (the new test included).

## Screenshots

`docs/verification/screenshots/cut-settings-layout/`:

- `after-default-text.png` — the 2 × 3 grid at the default text size, `3.5 cm`
  selected, every chip inside the sheet;
- `after-accessibility-text.png` — the same sheet at `accessibility-extra-large`;
  the headings and chart labels grow, and the grid keeps all six chips inside.

Both are attached by the UI tests rather than assembled by hand.

## Constraints honoured

No tuning, engine or session-layout code was touched, and no layout constant moved
into `Config/production.yaml`: `84` is a view constant in the sheet, where the
other presentation constants live. The doneness row, the value rows, the slider
identifier (`setup.thickness`, which the cook walk drives) and the
`settings.save` / `setup.doneness.*` identifiers are unchanged.
