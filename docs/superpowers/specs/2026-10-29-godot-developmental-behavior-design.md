# Godot Developmental Behavior — Design

**Status:** Approved direction; the user asked to continue with the accepted milestone of making family life stages matter behaviorally.

## Intent

Make age visible in how young Norns behave. Babies should stay near a living parent, and children should learn more from behavior they actually witness. Mature Norns keep their current autonomous behavior.

## Current state

`NornLifecycle` derives baby, child, adolescent, adult, and elder stages from saved age. `NornActor` changes body scale and its stage label, while `AlbiaWorld._run_decision` gives all stages the same cognition and targets the nearest peer for `observe_peer`. `_offer_observation` already requires a settled observer within 3 units and line of sight. `NornCognition.record_outcome` applies sociability-weighted learning at the same rate for every age.

## Goals

- A baby follows its nearest living parent, selected from its saved parent IDs, until it is within the existing 2.1-unit peer stopping distance.
- Parent following yields to active player guidance and to the baby's existing fruit, spinner, or rest decision.
- If neither parent is alive, a baby falls back to its normal cognition behavior.
- A child that chooses to observe a peer prefers a visible living parent; if no parent is visible, it keeps the current nearest-visible-peer behavior.
- A child receives 1.5 times the normal learning change from witnessed food, play, Praise, and Scold events. The existing attention, range, line-of-sight, and association clamps remain authoritative.
- Adult, adolescent, and elder behavior remains unchanged. Stage is derived from existing age state, so no save version or new persistent field is needed.
- A rendered walkthrough visibly demonstrates parent following and child learning.

## Non-goals

- New feeding, carrying, protection, discipline, or other caregiving actions.
- Changing needs, biochemical rates, the life-stage thresholds, general cognition scores, or direct player feedback.
- Learning from events a Norn did not attend or could not see.
- New save data, new network services, or generated dialogue.

## Approaches

1. **Use the existing peer action for parent following, plus a child observation multiplier (selected).** Reuse `observe_peer`, its existing 2.1-unit stop distance, and the event-gated observation path. Add only stage checks in the world decision layer and a bounded learning multiplier for observation outcomes. This keeps the change local and avoids new save fields.
2. **Add an explicit caregiving and dependency model.** Parents would feed, protect, or respond to young Norns and could gain family relationships. This needs new actions, needs, UI, and persistent state, which goes well beyond making the existing life stages meaningful.
3. **Increase learning for children only.** This is the smallest code change, but leaves babies visually small and behaviorally identical to adults, so it misses the requested family distinction.

The accepted scope is approach 1. Player guidance and the Norn's established object/rest decisions keep priority over following. A child learns more from both positive and negative observed feedback; only the magnitude of the existing observation association update changes.

## Behavior details

The world chooses a baby's living parent with the shortest actor distance; `parent_ids` order breaks ties. When the parent is farther than `NornActor.OBSERVATION_STOP_DISTANCE`, the baby uses the existing `observe_peer` movement target and a reason that names the parent. Once in range, it remains settled with no movement target, so existing attention checks can register events the baby witnesses. If the parent moves away, the normal decision tick starts following again.

Following is considered only after active guidance is resolved and only when cognition did not choose `fruit`, `spinner`, or `rest`. Babies with no living parent use the normal cognition result. Children retain cognition's existing choice of when to observe; when they choose `observe_peer`, the world selects the nearest visible living parent if one is among sensed peers, otherwise the nearest sensed peer as today. For a child observer, the world passes a `learningMultiplier` of `1.5` with the existing observed outcome. `NornCognition.record_outcome` applies that multiplier only to `observe` and `observe-feedback`, clamps the result using its existing learning bounds, and uses the unchanged sociability formula as the base. Other stages default to `1.0`.

## Verification

- A baby with a living parent targets that parent while separated, settles inside the current stopping distance, and resumes following after separation.
- Parent following yields to guidance and to fruit, spinner, or rest decisions; no living parent leaves normal cognition in control.
- A child chooses a visible parent over a nearer non-parent when observing, and falls back to the nearest visible peer when no parent is sensed.
- A child observer's recorded learning delta is 1.5 times an adult observer's delta for the same witnessed event, including negative Scold learning; other event types and direct learning remain unchanged.
- Existing social, family/lifespan, and habitat walkthroughs continue to pass, and the new behavior is shown in an inspected rendered AVI recording. Keep no more than 10 completed clips.
