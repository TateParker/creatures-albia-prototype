# Godot Adolescent Independence — Design

**Status:** Proposed for review; the user approved pursuing adolescent independence, with this specific design awaiting review.

## Intent

Give adolescent Norns a clear social step toward independence. Babies follow living parents, and children prefer observing parents and learn more from witnessed events. Adolescents should begin choosing other peers when they decide to observe.

## Goals

- When an adolescent chooses `observe_peer`, prefer the nearest visible living peer who is not one of its parents.
- If no non-parent peer is visible, retain the existing nearest-visible-peer fallback.
- Preserve player guidance and the current higher-priority need decisions.
- Keep the behavior deterministic and derived from the existing life stage and parent IDs.
- Demonstrate and verify the behavior in a rendered game recording.

## Non-goals

- Add a new cognition action or change cognition policy weights.
- Change child, adult, or elder peer selection.
- Change observation attention, range, or line-of-sight rules.
- Change save data, lifespan thresholds, reproduction, learning amounts, or the HUD layout.

## Approaches considered

1. **Peer preference within the existing observe decision — recommended and selected.** When an adolescent's existing decision is `observe_peer`, select the nearest sensed non-parent peer; fall back to the current nearest peer when none qualify. This uses existing sensors, movement, and attention checks. It adds no cognition action and is deterministic.
2. **Add an explicit explore action.** This could make independence visible even when the Norn does not decide to observe, but it would expand the cognition action contract and require new movement targets, scoring, and learning behavior.
3. **Fade parent preference gradually with age.** This would model a smoother transition, but introduces a probability or age curve that is harder to explain and test than a clear stage boundary.

## Behavior

Life stage is derived from the existing lifecycle state. For adolescents, when the normal decision selects `observe_peer`, choose the nearest visible, living Norn whose stable ID is not in the adolescent's `parent_ids`. If there is no such sensed peer, preserve the current nearest-visible-peer behavior.

The existing guidance and action-priority order remains authoritative. The normal observe range, attention settling, and visibility gates remain unchanged. Children continue to prefer a visible parent; babies continue their living-parent following behavior; other stages keep current rules.

## Files and implementation boundaries

- `godot/scripts/albia_world.gd`: select a non-parent peer for adolescent observation, using the existing sorted sensed-peer list.
- `godot/tools/verify_social_slice.gd`: cover preference when a parent is closer, fallback when no non-parent is visible, and unchanged guidance / urgent-need priority.
- `godot/tools/record_preview.gd`: show an adolescent observing a non-parent in a rendered walkthrough and assert the HUD reason names that peer.
- `godot/README.md` and a verification ledger: document the behavior and capture evidence.

No persisted fields, schema version, new action IDs, or browser code are required.

## Verification and acceptance

- A deterministic verifier confirms the adolescent selects a visible non-parent even when a parent is closer.
- With no visible non-parent, the adolescent uses the existing nearest visible peer.
- Guidance and current fruit, spinner, or rest priority remain unchanged.
- Child parent preference and child observation learning tests remain green.
- Rendered video shows the adolescent's selected peer and visible action reason; the saved clip is inspected with the project's AVI frame inspector.
- Family and habitat scenario checks pass; the recording folder remains within the existing ten-completed-clip cap.

## Main tradeoff

This makes independence noticeable through social choice, but only when an adolescent naturally chooses to observe someone. It does not make adolescents roam independently or add a new exploration goal.