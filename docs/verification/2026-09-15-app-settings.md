# App-wide settings (option B)

Verified on 2026-09-15 with Xcode 26.2 / Swift 6.2 and an iPhone 17 simulator
running iOS 26.2. Deployment target remains iOS 18.0.

This completes the settings screen started in
`2026-09-15-cut-visibility-settings.md`. The gear now holds the four app-wide
groups that were agreed, and **not** units — that one stays out until the domain
can express it.

| Section | What it does | Before |
| --- | --- | --- |
| Cuts on home | show/hide cuts | added previously |
| Reminders | notification switch | launch argument only |
| Sound & haptics | two independent switches | one launch argument for both |
| Learned adjustments | see and reset what feedback taught | **invisible and unresettable** |
| About | version, and what an estimated temperature is | nothing |

## The real gap: learned adjustments

Every feedback answer writes a `CookingCalibration` — a cooking-time adjustment
and a sear bias, keyed by cut, thickness bucket and doneness — and it silently
changes the timing of every later cook with that configuration. There was no way
to see it and no way to undo it.

It is now listed, most influential first, with neutral entries filtered out: the
list answers "what has this app changed about my cooking", and an entry that
changes nothing does not answer that. Each row shows the two deltas
(`−24s TIME`), and `Reset adjustments` clears them behind a confirmation.

**The reset is deliberately narrow**, and a test proves it: the saved
doneness/thickness, the cook history and the app-wide preferences are different
stores and survive untouched.

## Switches that were frozen at launch

Sound, haptics and notifications were fixed in `SteakCopilotApp.init` from
`-quietFeedback` / `-disableNotifications`. They are now persisted preferences the
services read **live**, using the same provider pattern as `TuningProviding`:

- `MotionDirector` checks the preference on every event, so a switch flipped in
  Settings is felt on the very next cue. A test flips it *between* two cues and
  asserts the second one is already affected.
- `NotificationService` checks on every use, so turning reminders off stops them
  immediately.
- The launch arguments still win as a kill switch, so UI runs stay silent and
  prompt-free. That is asserted too.

Sound and haptics are genuinely independent: turning one off does not silence the
other, and the visual cue is not a preference at all — it is how the app
communicates, so it is still delivered with both off.

Permission is requested when the reminder switch is turned **on**, not at launch,
so the system prompt arrives at a moment the user just asked for it.

## Storage

`AppPreferences` changed from a bare set of hidden cuts to an object with the
switches. The decoder reads the previous shape first, so an install that predates
the switches keeps its hidden cuts and picks up the defaults for everything else —
same storage key, no migration step, no second source of truth.

## Findings worth recording

Two problems surfaced while testing, both real:

1. **UI runs were inheriting learned adjustments.** Calibrations outlive a
   session by design, so a stale entry from an earlier run appeared in a
   screenshot as a `+9s` row the test never created, and the assertions were
   reading whatever the previous run had taught the app. A `-resetCalibrations`
   launch argument now exists for test isolation.
2. **The prototype visual walk had a latent race.** The cook can reach the rest
   between the loop's phase check and its five-second wait for the confirm
   button, which made the walk fail on a button that had legitimately gone away.
   It now breaks on the finishing phase instead of asserting.

A third, self-inflicted one is worth noting because it cost time: XCUI reports a
row sitting **under the sticky Save bar** as hittable, and tapping it presses the
bar — which dismisses the sheet. The test now asserts the row is clear of the bar
before tapping rather than trusting `isHittable`. The bar itself is correctly
pinned (measured at maxY 828 of 874); the trap is purely in XCUI's hittability.

## Automated results

- Unit tests: **254/254 passed**, 19 new across `FeedbackPreferenceTests`,
  `LearnedAdjustmentTests`, `ReminderPreferenceTests` and the extended
  `AppPreferencesTests`.
- UI tests: **20/20 passed**, 3 new.
- Generator: `--self-test` 19/19, `--check` clean. No tuning value changed.

New coverage includes: the two cue switches independently silencing one channel
and not the other; a switch flip being felt on the next cue; the reminder switch
suppressing the permission request; adjustments listed strongest-first with
neutral entries hidden and the reset leaving the other stores alone; a real
overshoot producing a negative cooking-time adjustment; every settings section
rendering; a switch surviving a relaunch; and an adjustment being shown and then
reset end to end.

## Screenshots

`docs/verification/screenshots/app-settings/`:

- `settings-overview` — every group on one screen;
- `settings-learned-adjustments` — the learned row (`Ribeye · Standard · Medium
  Rare`, `−24s TIME` from a two-step overshoot), the reset action, and About.

## Deliberately not done

Units (°C/°F, cm/inch) still need the domain and every string to express them, so
they stay out. Live Activity remains launch-argument only: it is core to the cook
screen rather than a preference, and the reminders switch already covers the
"don't interrupt me" intent for notifications.
