# Grounded Norn Intent Speech — Design

## Intent

Norns can currently say a learned object word after succeeding with that object. That communicates an outcome, but not what they want to do next. Use the existing vocabulary and target choice to let them express a newly selected goal.

## Goals

- When a Norn selects a different non-null target that is still outside its arrival range, let it say the matching known word if its confidence is at least the existing `0.6` speaking threshold and no speech bubble is active.
- Describe this utterance as looking for the selected object in the speech event and memory.
- Let nearby Norns learn the spoken word through the existing sociability probability; an intent utterance does not teach behavior because no success has occurred yet.
- Preserve successful-action speech and its single shared sociability gate for both word hearing and behavior imitation.
- Add no words, traits, save fields, or network/LLM behavior.

## Non-goals

- Add free-form conversation or ungrounded language.
- Speak again on every decision refresh while the target is unchanged.
- Change decision scores, target selection, learning amounts, imitation cooldown, or success-event speech.
- Add a separate speech cooldown field or persistence migration.

## Approaches

1. **Speak on target transitions when a known word is available (selected).** This expresses intent at a meaningful state change, reuses existing vocabulary and bubble duration, and avoids speech on every re-evaluation.
2. **Speak on every target-selection refresh.** This is easy to add but the 0.9–1.45 second decision cadence would make repeated words noisy.
3. **Speak only after success.** This preserves current behavior but does not add intent expression.

The user authorized continued prototype improvements; target-transition speech is the implementation call because it adds grounded expression without altering the underlying choice or adding saved state.

## Constraints and implementation notes

- `updateNorn` selects targets on its existing think timer. Compare the prior and newly chosen target; speak only for a changed non-null target that is still beyond its existing arrival distance (52 world units for fruit, 48 for the spinner). Player guidance should wake this same selection path without preassigning `targetId`, so guided switches retain the previous target for comparison.
- Reuse the existing 0.6 confidence threshold, `norn.speech` bubble expiry, `recordEvent`, and `sociability` probability.
- `speakKnownWord` should default to the existing successful-use event wording, while accepting a seeking context for intent speech.
- Extract the common word-hearing update/event into one helper. Successful events retain one per-observer attention gate shared with imitation. A standalone seeking utterance gets one sociability gate for word hearing and no imitation.
- Existing speech state is already persisted. No schema change or migration is needed.
- Sociability rolls for new intent utterances consume the existing saved RNG stream and may change later random outcomes in a saved run; they add no persisted fields.
- Update README to mention known words may express a newly chosen goal.
- Do not add or run automated tests. Use static whitespace/JavaScript syntax checks and scoped review.
