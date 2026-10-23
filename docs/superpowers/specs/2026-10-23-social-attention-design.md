# Trait-Weighted Social Attention — Design

## Intent

Make the already displayed sociability trait affect whether a nearby Norn notices another Norn's success. Today only values below `0.45` are probabilistic; values at or above that threshold always observe. Both starting Norns are above it, so their sociability does not currently affect whether they notice one another.

## Goals

- Use sociability as the chance of observing each nearby success, with its validated range of `0` to `1` mapping directly to a probability from 0% to 100%.
- Apply one attention roll to both grounded word learning and behavior imitation for the same observation.
- Preserve the existing self and 330-pixel distance filters, learning amounts, cooldown, memories, and event explanations.
- Keep the save shape unchanged and keep the behavior inspectable through the existing Sociability trait and observation memories.

## Non-goals

- Add persistent attention or relationship values.
- Separate speech-hearing odds from behavior-observation odds.
- Add a language model, new vocabulary, new UI, or more social-event types.

## Approaches

1. **Use sociability directly as the observation chance (selected).** One random gate precedes both existing learning paths. This corrects the dead zone with no new tuning values and leaves the trait easy to interpret.
2. **Use separate chances for words and behavior.** This offers finer tuning, but splits the meaning of sociability and adds balance values unsupported by this prototype.
3. **Keep observation guaranteed and scale only learning strength.** This avoids random attention but does not make sociability affect whether the Norn notices, which is the current gap.

The user authorized continued small improvements; direct probability is the implementation call because it gives the visible 0–1 trait one clear meaning and uses the existing local seeded random stream.

## Constraints and implementation notes

- `shareObservation(actor, object, actionEvent, spokenWord)` in `index.html` owns nearby observation and already has one common point before word and behavior learning.
- Saved and newly created traits are validated in the inclusive 0–1 range. Sociability values of 0 mean no observation, values of 1 mean every eligible success is observed, and intermediate values use that chance.
- The attention roll is after excluding the actor and observers beyond 330 pixels. A failed roll skips both word and behavior learning for that event.
- Existing learning amounts, imitation cooldown, event records, and memory copy stay unchanged.
- The autosaved state already contains the seeded RNG state. This change adds no persisted field or migration. Probabilistic observation can consume a random draw for traits that previously observed every time, changing later random outcomes in that saved run.
- Update README's social-observation description to explain how sociability affects attention.
- Automated tests are not to be added or run for this continuation. Use static source checks and scoped review.
