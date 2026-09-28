# The strip's Chinese name is 西冷牛排

Verified on 2026-09-25 with Xcode 26.2 / Swift 6.2, iOS 26.2, one iPhone 17
simulator running the app in Simplified Chinese.

## What changed

One localized value, plus the comments that described it:

| Key | Before | After |
| --- | --- | --- |
| `New York Strip` (zh-Hans) | 纽约客牛排 | **西冷牛排** |

The English source string is unchanged — New York Strip is the cut's English
name, and `SteakCut.title` is the single place it is spelled, so the whole app
follows from this one entry (home carousel, the cut settings sheet, the cook log).

Two comments used the old name as their example of the longest copy the home
skeleton has to lay out:

- `HomeLayoutMetrics`' doc comment, and the note explaining
  `navigationLabelWidth: 92`;
- `CookingHomeView`' doc comment.

The width constant itself did **not** need to change. It was sized for the
longest neighbour name in *either* language, and that is still `NEW YORK STRIP`
on the English side; 西冷牛排 is one CJK character shorter than 纽约客牛排, so the
Chinese side only got easier. The comments now say so instead of naming a string
that no longer exists.

`docs/verification/2026-09-11-home-layout-polish.md` still quotes 纽约客牛排. It
is a dated record of what was verified that day, so it was left as it was.

## Verification

A translated string needs the tests that read that string, not the whole suite:

- `-only-testing:SteakCopilotTests/LocalizationTests` — the `zh-Hans` bundle
  resolves, and the built app contains `"New York Strip" => "西冷牛排"`;
- `-only-testing:SteakCopilotUITests/.../testSimplifiedChineseFollowsSystemLanguage`
  — the assertion above plus the screenshot, run on one device.

Both pass. The catalog itself was checked semantically rather than by diff size:
parsing the committed and the working `zh-Hans` maps gives **0 entries added, 0
removed, 1 changed** — the one value below. Xcode re-serializes `.xcstrings` on
build (key order, empty-object formatting), which is why the file diff is larger
than one line; the parsed comparison is what proves nothing else moved.

### Not green elsewhere, and not because of this

The full UI suite was also run, out of habit, and reported **21/22 twice**:
`testCaseBStripUsesFatCapAndTakesOut` fails intermittently, at a different
assertion each time, and passes on its own. That walk has nothing to do with this
change — it drives a 4cm strip at the `-visualCook` scale, where the rest is
~20s, and it races the TAKE OUT → FINISHING → ending-page hand-over. An attempt
to harden it was **reverted out of this commit** rather than mixed into a
translation change; it should be fixed on its own, with the failure captured
rather than guessed at.

## Screenshot

`docs/verification/screenshots/strip-chinese-name/home-zh-Hans-strip.png` — the
Chinese home screen with the strip selected: eyebrow 今日牛排, title **西冷牛排**,
neighbours 肉眼牛排 / 菲力, and the fixed skeleton unchanged by the rename.
Captured by the UI test.
