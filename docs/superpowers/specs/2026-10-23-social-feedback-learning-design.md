# Social Feedback Learning Design

## Intent

Let a nearby Norn learn from watching another Norn receive the player's Praise or Scold, extending the existing social-learning loop beyond successful actions.

## Goals and non-goals

- Consider only other Norns within 330 world units of the Norn receiving feedback.
- Use the observer's sociability as the chance to notice each eligible feedback event, with one random roll per observer per feedback event.
- On noticed Praise, increase the observer's learned association for the action's object by 0.12; on noticed Scold, decrease it by 0.12. Clamp to [0, 1].
- Record the observation as a journal event and memory linked to the source feedback event.
- Preserve the existing actor feedback amount, eligibility window, one-response rule, and direct feedback messages.
- Do not add save fields, change decision formulas, or connect to external services.

## Behavior

After an eligible Praise or Scold changes the actor's association, record its feedback event, then offer that event to each other Norn within 330 units. Each eligible observer makes one `state.rng()` roll and notices when the result is below its validated sociability. A noticed observer applies the signed 0.12 adjustment to the same object's association, updates its action/reason, and records a memory-bearing observation event whose `relatedEventId` points to the feedback event. At the association limit, the observer still records noticing the feedback and that the association could not change further.

Actor feedback remains ±0.2 and can still be used once within 12 in-game seconds after the most recent success. An ineligible or duplicate player response produces no social event. The new random rolls intentionally change subsequent deterministic outcomes after observed feedback, and the existing RNG state save continues to preserve the current sequence.

## Constraints

- Keep the standalone static HTML build and local simulation.
- Reuse validated sociability, event/memory storage, and existing persistence fields.
- No automated tests may be added or run under the standing session instruction; use source inspection, JavaScript syntax validation, diff checks, review, and deployment verification.
