# Cuts on the home screen, and a real settings screen

Verified on 2026-09-15 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2. Deployment target remains iOS 18.0.

## The problem this closes

The gear in the top-right corner and the bottom "Fine-tune settings" button
opened the **same sheet**. Worse, that sheet is entirely about *this cook* —
doneness, thickness, and the target temperature and estimated time derived from
them — so the one control that conventionally means "app-wide settings" was
showing per-cook content.

There was also genuine app-wide content with nowhere to live. This adds the first
piece of it and gives the gear a screen of its own:

| Entry point | Opens | Scope |
| --- | --- | --- |
| Gear (top right) | `SettingsView` | app-wide |
| Fine-tune settings (bottom) | `AdvancedSettingsSheet` | this cook |

## Hiding cuts is a display filter

The setting decides which cuts the home screen shows. Hiding one is explicitly
**not** deleting it:

- its doneness and thickness survive;
- the adjustments it has learned survive;
- its cook history survives;
- showing it again restores all of it untouched, and this is asserted by a test
  that writes a preference, a setup and a calibration through **both** stores and
  checks the other store is undisturbed.

The screen says so in as many words, because "隐藏" reads as "delete" otherwise.

### Stored as the hidden set, not the visible one

`AppPreferences` persists `hiddenCuts`. Two consequences, both deliberate:

- an empty set means "everything visible", so a fresh install and every existing
  user get exactly today's behaviour with **no migration**;
- a cut added in a later release is **visible by default** rather than invisible
  to everyone who ever opened this screen.

The value is encoded as a bare set of raw values, and decoding sanitises it, so a
hand-edited or corrupted store cannot leave the home screen empty.

### The screen can never be empty

The last visible cut cannot be hidden. The toggle is disabled *and* the reason is
printed — a control that silently does nothing is worse than one that explains
itself. The model refuses the change as well, so the guard does not depend on the
UI.

### Where the selection lands

Hiding the cut you are looking at moves the selection to the nearest one you
still have: the first visible cut at or after it in the canonical order,
otherwise the nearest one before it. It never wraps to the far end, and it is
deterministic — "whichever the set happened to yield" would put the screen
somewhere different on each launch.

`AppPreferences.selection(startingFrom:)` is a pure function, so a session
restored from storage resolves to the same cut every time.

### The empty navigation row keeps its height

With one cut there is nothing to page through, so the arrows and dots are hidden
rather than shown inert. The row's **height is still reserved**, so turning a cut
off does not shift the title, the parameters, the summary or the call to action.
The UI test captures the title frame with three cuts, hides two, and asserts the
frame is unchanged.

## What is deliberately not configurable

**Adding a cut is not a setting.** Every cut needs a hero photograph, a tuned
parameter set in `Config/production.yaml`, a localized name and a domain case, so
a user-facing "add" would either be a lie (only re-showing hidden cuts) or would
produce a cut with no artwork and no tuning. The screen is therefore named
**Cuts on Home** and only shows and hides what exists. A new cut remains a content
release.

The full cut list stays the domain truth: `SteakCut.allCases` is **not** filtered,
because tuning validation, the Tuning Lab coverage test and the generator's
`CUT_NAMES` must all keep seeing every cut. Only the setup screen reads
`visibleCuts`.

## Automated results

- Unit tests: **235/235 passed**, including 18 new across `AppPreferencesTests`
  and `AppPreferencesStoreTests`.
- UI tests: **17/17 passed**, including 3 new.
- Generator: `--self-test` 19/19, `--check` clean (no tuning value changed).

New UI coverage:

- the gear opens app settings and **not** the per-cook sheet, and the bottom
  button still opens the per-cook sheet and not app settings;
- hiding a cut removes it from the carousel entirely (its `setup.cut.*` element
  is absent), the neighbour stays reachable, and re-showing restores it;
- the last visible cut's toggle is disabled, the reason is shown, the arrows are
  gone, and the title does not move.

UI tests pass `-resetPreferences` alongside the existing reset arguments, because
preferences persist by design and a leftover value would otherwise make the
layout walk non-deterministic.

## Screenshots

`docs/verification/screenshots/cut-visibility/`:

- `settings-cuts` — the settings screen with one cut hidden;
- `settings-last-cut-guard` — the last cut locked, with the reason and the
  non-destructive note;
- `home-single-cut` — the home screen with one cut: no arrows or dots, and the
  title, parameters, summary and CTA in their usual places.

## Where the next app-wide settings go

`AppPreferencesStore` is deliberately separate from `CookingStore`: clearing a
session or a calibration must not disturb app settings, and vice versa (asserted).
Sound, haptics and notification switches are currently launch-argument-only and
belong in this screen and this store next — followed by the learned adjustments,
which are still invisible to the user and cannot be reset.
