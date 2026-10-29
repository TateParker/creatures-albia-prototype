# Unified deterministic action utility — design

**Status:** Approved by the user on 2026-10-29. The user selected a shared deterministic utility score with urgent-need safety bounds on 2026-10-29.

## Intent

Let a Norn's current needs, learned action preferences, context associations, memories, and deterministic policy compete on one explainable scale. The result should allow experience to redirect ordinary choices while keeping player guidance and critical hunger or fatigue decisions dependable.

## Current state

`NornCognition._score_decision()` already calculates values for fruit, spinner, rest, peer observation, and idle. Those values combine chemical needs, action associations, context associations, recalled episodic bias, and a bounded recurrent-policy signal. The values currently use different ranges, and selection then applies separate priority bands: fruit/spinner scores of at least 11/14 are considered first, rest wins above 18, peer observation competes with idle, and idle is the fallback. A 1.2 simulated-second commitment can keep a fruit or spinner target unless the replacement score exceeds the previous score by 18. `AlbiaWorld._run_decision()` applies valid player guidance after cognition; it also supplies baby parent-follow behavior and chooses peer targets after `observe_peer` is selected.

The local cognition profile measured about 306 μs p95 per 5 Hz decision in one workstation session. The action scorer uses a fixed five-action list, bounded recurrent state, and at most three recalled episodes.

## Approaches

1. **Tune the existing priority bands.** Adjust thresholds and bonuses while retaining the layered selector. This changes less and is easy to compare, but learned preferences remain unable to compete across the hard-coded bands.
2. **Unified deterministic utility with urgent-need safety bounds — selected.** Give every eligible action a comparable score, then choose the highest score with stable tie-breaking. Add explicit urgent hunger/low-glucose and extreme-fatigue safeguards that bypass target commitment. Keep valid player guidance above the cognition result. This provides a clear route for learned preferences to redirect non-critical choices while protecting critical needs.
3. **Move directly to a goal planner.** Add goals and multi-step plans now. This could support routines earlier, but it would replace more of the compact cognition model at once and make this first behavior improvement harder to isolate and verify.

## Goals

- Rank all eligible actions—fruit, spinner, rest, `observe_peer`, and idle—through one deterministic utility selection.
- Put current need pressure, learned action association, contextual association, recalled experience, and the existing deterministic recurrent signal on a bounded, comparable scale.
- Make hunger with very low glucose and extreme fatigue safety conditions that a learned non-critical preference or target commitment cannot suppress.
- Keep unavailable fruit/spinner targets and absent peers out of the eligible action set; keep rest and idle eligible.
- Preserve player guidance, baby parent following, child parent preference, adolescent peer scoring, actor movement, and the current save format.
- Keep the selected action's score components and a human-readable reason in the decision result.
- Keep the work local, deterministic, and suitable for the existing 5 Hz decision cadence.

## Proposed scoring and safety rules

- Normalize each need-pressure component to `[0, 100]` before combining actions. Preserve the current drive relationships: hunger and low glucose raise fruit utility; curiosity raises spinner utility; fatigue and low glucose raise rest utility; low social comfort and sociability raise peer-observation utility when a peer is sensed.
- Center learned action association around its neutral value `0.5`; cap total non-drive influence from action association, context association, recalled episodic bias, and recurrent policy so ordinary experience can redirect close decisions without outweighing a critical need.
- Give idle a settled-state baseline and keep it as a real candidate. It does not win merely because the other action branches were skipped.
- Use fixed tie-breaking so identical state and observation produce the same action. In the first implementation pass, preserve the existing action order for exact ties, with idle last.
- Proposed initial safety bands: fruit urgency when hunger is at least `90` or glucose is at most `10`; rest urgency when fatigue is at least `95`. For simultaneous safety actions, calculate fruit severity as `max(clamp((hunger - 90) / 10, 0, 1), clamp((10 - glucose) / 10, 0, 1))` and rest severity as `clamp((fatigue - 95) / 5, 0, 1)`; choose the greater severity, then use the fixed tie order. Treat these values as initial tunable constants and exercise both sides of each boundary in tests.
- Mark safety-selected decisions as transient overrides so `_apply_commitment()` cannot retain a conflicting fruit or spinner target. Player guidance continues to override cognition in the world layer.
- Candidate eligibility depends on the current observation. If an urgent action's target is unavailable, it is omitted and the scorer selects the highest utility among the remaining eligible actions.
- Target commitment may retain a prior fruit or spinner choice only while that action remains eligible in the current observation; a disappeared, unavailable, or no-longer-sensed target must never be reselected by commitment.
- These eligibility and safety rules govern cognition's candidates and target commitment. The existing world layer remains authoritative afterward: active player guidance and developmental behavior (including baby parent-follow and child parent preference) keep their current precedence and are not utility candidates.

The score weights and caps above are proposed implementation values for review. The chosen design requires every contribution and override reason to remain inspectable in `current_decision`; eligibility, score-breakdown, and safety-override diagnostics are returned for the live decision and stripped from persisted `lastDecision` so save serialization retains its existing fields.

## Non-goals and constraints

- Do not add randomness or external/cloud inference.
- Do not add traits, relationships, affordance learning, spatial habits, routines, new actions, or UI panels in this workstream. Those remain later behavior projects.
- Do not change life-stage cutoffs, family rules, peer-target scoring, language, biochemistry equations, movement, or save serialization.
- Keep scoring in `godot/scripts/norn_cognition.gd`; keep guidance, target resolution, and life-stage overrides in `godot/scripts/albia_world.gd`.
- Verify with deterministic headless decision cases, the relevant social/world regression checks, a cognition performance measurement, and the rendered in-game recording. Keep the recordings folder at 10 or fewer completed clips.

## Success criteria

- A critical hunger/low-glucose case selects fruit when a fruit target is eligible, even during an existing spinner commitment; extreme fatigue similarly selects rest despite a prior fruit/spinner commitment.
- When needs are non-critical, learned action/context experience can make an action win against a competing drive or idle baseline, with bounded scores and a reason matching the strongest contribution.
- The cognition scorer never selects unavailable/unsensed fruit or spinner targets or `observe_peer` without a sensed peer; target commitment cannot restore them. The existing world-layer guidance and developmental overrides remain intact.
- Guidance still resolves to its instructed object, baby/child developmental rules remain intact, and adolescent peer-memory target scoring still runs only after peer observation wins.
- Repeated equivalent inputs yield the same action and score breakdown. Existing save version and serialized fields remain unchanged.
- The 5 Hz decision path remains comfortably real-time under the existing local performance target.

## Implementation calls left to the builder

- Choose the exact per-action drive normalization and preference caps while preserving the relationships and safety bands above.
- Keep score breakdown keys stable enough for the existing debug/recording checks, adding only fields needed to explain the unified winner and any safety override.
- Extend tests before tuning production weights; use the existing deterministic preview/decision entry points and real world observation construction.
