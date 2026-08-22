# Motion Quality Gate

| Motion | Trigger | Purpose | Owner | Duration | Interruptible | Reduce Motion fallback | Performance risk |
|---|---|---|---|---:|---|---|---|
| Setup steak morph | Cut/thickness/doneness changes | Make configuration feel attached to the food | Setup view | 220–380 ms | Yes | Opacity transition | Low: shape and gradient only |
| Prep dry/salt | User completes a prep step | Confirm a physical action | Prep view | <800 ms, once | Yes | Opacity only | Low: fixed particle count |
| Heat ambience | Heat stage is active | Build expectation without claiming temperature | Heat view | Continuous, subtle | Yes | Static warm pan | Low: three translucent shapes |
| Flip attention | Engine emits `flipApproaching` | Shift from waiting to action | MotionDirector | T−5 to T−0 | Yes | Text scale ≤1.02 | Low: localized text changes |
| Hero flip | First `flipNow` event | Make the required flip unmistakable | MotionDirector | 550 ms | Re-triggerable | Crossfade + FLIP NOW | Low: transform-only keyframes |
| Compact flip | Later `flipNow` event | Reinforce action without fatigue | MotionDirector | 380 ms | Re-triggerable | Label + haptic | Low: rotation/scale only |
| Butter | Engine enters butter event | Show the ingredient and warmer cooking state | MotionDirector | 700 ms | Yes | Opacity | Low: fixed gradients/bubbles |
| Baste | Engine enters baste event | Demonstrate pan tilt, flow, spoon arc | MotionDirector | 2 cycles maximum | Yes | Static arc | Low: three simple shapes |
| Take out | Engine emits `pullNow`; session changes to resting from user action | Communicate urgency and end active cooking | Domain state + MotionDirector styling | 550–950 ms | Yes | Fade to cream | Low: transition transforms |
| Rest breathing | Resting phase is active | Show carryover heat is still active | Finish view | 4 s cycle | Yes | Removed | Low: one scale transform |
| Ready | Engine completes resting | Deliver a distinct completion moment | Domain state + MotionDirector styling | 950 ms | Yes | Opacity + scale ≤1.02 | Low: transform/crossfade only |

No animation completion mutates `CookingSession`, `CookingPhase`, remaining time, target temperature, or next action.
