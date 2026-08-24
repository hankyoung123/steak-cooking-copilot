# Latest Prototype Visual and Motion Design

## Visual target

The source of truth is `/Users/hankyoung/.codex/attachments/60d0fe74-cfa5-415e-9259-c5f684e681b3/image-1.png`.

The target has two modes:

- Warm editorial preparation and result screens: lightly textured ivory paper, high-contrast serif display type, hairline borders, restrained warm-gold accents, and food photography as the focal point.
- Cinematic active cooking screens: near-black textured canvas, edge-to-edge pan photography, very large serif timers, one imperative instruction, a thin gold progress rail, and only truthful temperature telemetry.

## Approaches considered

1. Token-only restyle: fastest, but it would preserve the current card/HUD proportions and miss the prototype's hierarchy.
2. Faithful presentation refactor on the existing state machine: selected. It changes layout, assets, and transitions while preserving cooking calculations, timers, persistence, stage progression, exit, and skip.
3. New parallel flow: rejected because it would duplicate state and risk diverging from the tested engine.

## Layout decisions

- Home becomes a single-screen editorial composition: large cut image, subtle neighboring-cut navigation, centered display title, a compact three-metric summary, and one dark primary action.
- Settings remains one large sheet but adopts the prototype's quiet row hierarchy, circular doneness assets, chip thickness choices, outlined starting-temperature control, and bottom-anchored action.
- Prep, Heat, Sear, Baste, Check, and Rest share one dark session shell. The top bar carries back, phase/side, and step count; the timer, food scene, instruction, progress rail, and target/current telemetry form a single vertical rhythm.
- Cook confirmations are attached to the visible imperative instruction instead of adding a competing bottom CTA. Prep and Heat retain explicit actions because those states need a clear confirmation.
- Result and Cook Log use the same editorial system, with Cook Log switching to the dark card treatment shown in the prototype.

## Motion decisions

- Carousel selection uses view-aligned native scrolling, scale/opacity/rotation depth, content transitions, and selection haptics.
- Stage changes use a restrained dissolve with a small camera push on food imagery, animated numeric timers, and a spring-driven gold progress marker.
- Imperative instruction actions use a short press-scale response and existing event haptics. Flip cues retain the existing event-driven motion director.
- Result content reveals in a short staggered entrance. All nonessential movement is suppressed when Reduce Motion is enabled.

## Verification

- Capture Home, Settings, Sear, Baste/Check, Rest, Result, and Cook Log on iPhone 17.
- Put the latest prototype and implementation captures into the same normalized comparison canvas.
- Fix all actionable P0/P1/P2 design differences and update `design-qa.md` to `final result: passed`.
- Run the full unit/UI test suite and a Release simulator build.
