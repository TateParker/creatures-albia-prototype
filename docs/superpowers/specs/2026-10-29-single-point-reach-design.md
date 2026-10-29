# Single-Point Reach Task Design

## Intent

Define a small, repeatable target task that can measure whether a Norn's surface cursor reaches a known point. The current drawing motor is a seed-driven prior with bounded `dx`/`dy` steps; it receives no target, and the current baseline has no task-level accuracy measure. This task provides an objective baseline before any motor-learning update is designed.

## Selected approach

The two considered tasks were single-point reach and short line tracing. The user selected single-point reach because its endpoint error and hit rate measure cursor control with fewer variables. Line tracing is deferred because it adds path-overlap scoring before endpoint control is established.

## Task

- Reset the evaluation cursor to UV `(0.5, 0.5)` at the start of every trial; clear only the evaluation surface between trials.
- Present one visible target reticle at radius `0.24` UV in one of eight evenly spaced directions from the start. Keep cardinal directions for training and diagonal directions held out for evaluation.
- Give the cognition input the current target-relative `dx` and `dy`, each normalized by `0.25` UV and clamped to `[-1, 1]`. Keep these two task cues separate from the existing 16×16 mark-perception grid so the target is not treated as existing ink.
- Run exactly six motor decisions at the existing `0.2` simulated-second interval. The evaluator records the cursor after the sixth decision and does not move the cursor or substitute an oracle motor command.
- Use a deterministic seed and balanced target order. Reset recurrent hidden state at trial start while retaining whichever motor parameters belong to that condition.

## Measures and gates

Primary measures are endpoint error in surface pixels, `distance(final_uv, target_uv) × 255`, and hit rate, the share of trials ending within 8 pixels of the target. Report per-seed values and the median across seeds. A trial is an attempt even when the motor emits pen-up; this task measures cursor reach, not stroke continuity or line quality.

For a later learning comparison, collect 32 pre-training trials (four per target), train on 64 cardinal-target trials (16 per direction), then evaluate on 32 diagonal-target trials (eight per direction). Compare with a matched no-update control using the same policy seed and target order. A candidate learning update should advance only if held-out median endpoint error improves by at least 20% and held-out hit rate improves by at least 10 percentage points over the matched control across five deterministic seeds. Treat this as a proposed engineering gate, not a claim about biological learning.

The first implementation phase should add the isolated task/evaluator and record current no-update performance. It should not add a motor-learning rule. A separate approved phase can select and bound the learning update using the baseline results. Any trainable motor state must use a versioned cognition save migration and preserve the existing seeded motor prior for older saves.

## Goals and non-goals

Goals: provide an explicit target cue, a repeatable start and horizon, an unambiguous endpoint score, and a matched control suitable for a later motor-learning comparison.

Non-goals: shape or symbol recognition, mark beauty, mood inference, social copying, communication, intrinsic drawing reward, or claims that this task measures an animal-like intention.

## Constraints and failure checks

- Keep target cues distinct from marks, authorship, and outcome labels in perception.
- Keep the existing urgent hunger/rest behavior and ordinary drawing eligibility unchanged outside evaluation mode.
- Test targets at the surface bounds, cursor rounding, episode reset, deterministic replay, held-out leakage, and save migration for any new trainable state.
- The score must use the final persisted/quantized surface cursor so evaluation matches what a saved task state would retain.

## Implementation choices left for the plan

The implementation plan should identify an isolated evaluation harness that does not modify the player's shared habitat during baseline trials, define the exact cognition-state serialization change for any trainable motor parameters, and stage a rendered target-task capture without changing the user's ten-clip recording set.
