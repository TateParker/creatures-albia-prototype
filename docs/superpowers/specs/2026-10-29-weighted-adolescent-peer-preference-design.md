# Weighted Adolescent Peer Preference — Design

**Status:** Approved for implementation by the user on 2026-10-29. The user selected a deterministic peer utility with remembered interactions.

## Intent

Let adolescent Norns favor non-parent peers while allowing distance and remembered social experiences to outweigh that developmental preference. The current cognition system chooses an action first, then `AlbiaWorld` selects a peer. This change makes only the peer target weighted; it does not replace the existing action decision.

## Goals

- Score each sensed, living peer using distance, an adolescent non-parent preference, and that Norn's existing memories about the peer.
- Allow strong positive or negative social memory to overcome the age-stage preference.
- Keep decisions deterministic and explain the selected target in the existing action reason.
- Use existing episodic state, with no new persisted fields or save version change.
- Verify both the ordinary adolescent preference and a memory-driven exception in a rendered recording.

## Non-goals

- Change the action scores for fruit, spinner, rest, observation, or idle.
- Change baby following or child parent preference.
- Add stochastic target selection, new actions, relationship UI, or a general-purpose social simulation.
- Change the Norn character model in this behavior change; the face/model work will be designed separately.
- Implement all other emergent-behavior ideas listed in the conversation.

## Approaches considered

1. **Distance plus age-stage bias.** Small and easy to explain, but spatial position is the only way the preference can be outweighed.
2. **Deterministic peer utility with remembered interactions — selected.** Combine proximity, a bounded adolescent non-parent bonus, and bounded recency-weighted peer memory. This supports predictable tests while letting individual experiences change whom a Norn chooses.
3. **Weighted random choice.** Sample from candidate weights for greater variation. This adds randomness, makes the same situation less predictable, and is harder to verify in a short gameplay clip.

## Behavior and proposed scoring

The existing cognition decision remains authoritative. Only when an adolescent's chosen action is `observe_peer` does the world rank sensed peers. Existing parent and child rules stay unchanged.

For each candidate peer, compute:

```text
score = proximity + adolescent_non_parent_bonus + social_memory
```

- `proximity` is `1 - distance / 10`, clamped to `[0, 1]`, using the existing 10-unit peer sensor radius.
- `adolescent_non_parent_bonus` is `+0.25` for non-parents and `0` for parents.
- Social memory is bounded to `[-0.35, +0.35]`. Derive it from existing `observe` and `observe-feedback` episodes whose `actorId` matches the candidate. Use recorded valence and salience, with recency weights that halve every 180 simulated seconds. Multiply the weighted mean valence by a familiarity factor that reaches 1 after three weighted memory units. No qualifying memories produce a zero memory score.
- Choose the highest-scoring candidate. Resolve equal scores by shortest distance and then stable actor ID, so repeated equivalent inputs produce the same target.

The bonus and memory caps are proposed starting values. They make proximity and development matter while allowing several strong remembered positive or negative experiences to change the target. The actor's reason should name the selected peer and identify the strongest contributing factor when one is clear. Peer scores remain transient decision data and are not saved.

## Memory interpretation

Observed `observe` episodes represent a peer performing an event the Norn valued; `observe-feedback` episodes preserve praise or scold valence. The scorer treats repeated positive memories as attraction and negative memories as avoidance. This is an explainable first approximation from the current episode format, not a separate friendship or trust model.

## Constraints and compatibility

- Reuse the sorted, visible peer list and the existing observation attention, range, and line-of-sight gates.
- Keep guidance and urgent fruit, spinner, and rest decisions higher priority because scoring runs only after `observe_peer` has already won.
- Preserve fallback behavior when there are no eligible peers.
- Do not change the save schema, cognition serialization, lifecycle thresholds, family lineage, direct learning, or browser prototype.
- Use rendered in-game recording and inspect the AVI and extracted frames; keep the recordings folder at ten or fewer completed clips.

## Verification

- With no peer memory, an adolescent still chooses a visible non-parent over a slightly closer parent when the age bonus is enough to win.
- Strong positive memories for the parent can overcome the adolescent bonus; strong negative memories for the sibling can make the parent win.
- Older memories decay, no-memory candidates remain neutral, and ties resolve deterministically.
- Guidance, fruit, spinner, and rest priorities remain unchanged; child parent preference remains unchanged.
- Rendered walkthrough shows the normal sibling choice and a memory-driven exception, with the chosen peer and reason visible in the HUD.
- Social, family, and habitat regression checks pass. The rendered AVI is fully decoded and its index inspected.

## Builder decisions

- The user selected approach 2. The score formula, caps, decay half-life, and familiarity threshold above are implementation proposals for review.
- After this behavior is approved and completed, design the procedural face improvement as a separate workstream. Current source positions place eye whites at `z = -0.58`, pupils at `z = -0.65`, and the head center at `z = -0.02` with a `z` scale of `0.66`; the user identified the floating eyes as the visual priority.
