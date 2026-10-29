# Godot Developmental Behavior Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make baby Norns follow living parents and make child Norns learn more from behavior they actually observe.

**Architecture:** Derive behavior from existing `NornProfile.life_stage` and `parent_ids` in `AlbiaWorld`; add no new save fields or cognition actions. Keep the current `observe_peer` movement and attention checks. Apply a bounded 1.5 multiplier only to a child observer's witnessed-event learning in `NornCognition.record_outcome`.

**Tech Stack:** Godot 4.7.2 Mono, typed GDScript, `SceneTree` verification scripts, local AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-godot-developmental-behavior-design.md`

## Global Constraints

- The world chooses a baby's living parent with the shortest actor distance; `parent_ids` order breaks ties.
- Parent following is considered only when there is no active player guidance and cognition did not choose `fruit`, `spinner`, or `rest`.
- A child that chooses `observe_peer` selects the nearest visible living parent if one is among sensed peers; otherwise it keeps the current nearest-visible-peer behavior.
- A child receives 1.5 times the normal learning change from witnessed food, play, Praise, and Scold events. The existing attention, range, line-of-sight, and association clamps remain authoritative.
- Adult, adolescent, and elder behavior remains unchanged. Stage is derived from existing age state, so no save version or new persistent field is needed.
- Keep at most 10 completed gameplay clips in the Godot `user://recordings/` folder. After a new recording is finalized, remove the oldest timestamped clips until 10 or fewer remain. Do not remove a clip that is still being recorded.
- Run the video capture in rendered, non-headless mode so Godot produces viewport frames. Headless checks can supplement the recording but cannot verify viewport capture.
- When changing Godot gameplay, UI, rendering, or simulation behavior, verify the relevant behavior with the in-game video recording feature. Record a representative run and inspect the resulting clip or its extracted frames; report the recording path and what was verified.

## Review Focus

- A baby whose saved parents are both dead must use normal cognition and must not target a stale actor.
- Guidance and an existing fruit, spinner, or rest decision must keep priority while a baby has a living parent.
- A child with a visible parent must prefer that parent even when a non-parent is closer; with no visible parent, it must keep nearest-peer selection.
- Child learning must still require settled attention, observation range, and line of sight; the multiplier must not admit an event that adults could not observe.
- Learning near the 0 or 1 association clamp must stay within bounds, including negative Scold feedback.

---

### Task 1: Baby parent following

**Files:**
- Modify: `godot/tools/verify_social_slice.gd`
- Modify: `godot/scripts/albia_world.gd`

**Interfaces:**
- Consumes: `NornProfile.life_stage`, `NornProfile.parent_ids`, `AlbiaWorld.profile_for(actor_id)`, `NornActor.set_action_target(...)`, and the existing `NornActor.OBSERVATION_STOP_DISTANCE`.
- Produces: `AlbiaWorld._nearest_living_parent(profile: NornProfile) -> NornProfile` for the baby-follow policy and later parent-selection behavior. A baby uses the current `observe_peer` action to target its parent and exposes a reason naming that parent.

- [x] **Step 1: Write the failing baby-follow tests.** In `verify_social_slice.gd`, add fixtures that create a child profile at the baby and child ages, with living/deceased parent profiles, and add tests for nearest living parent selection, settlement at the existing peer stop distance, resumed following after separation, guidance/object/rest priority, and orphan fallback.
- [x] **Step 2: Run the verifier and confirm the intended failures.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: `SOCIAL_SLICE_CHECK_FAILED` for missing baby parent following and priority assertions; no parse or fixture errors.

- [x] **Step 3: Implement the baby-follow policy.** Add `_nearest_living_parent(profile)` to choose from saved parent IDs by actor distance, preserving ID order for ties. In `_run_decision`, preserve active guidance first, then preserve cognition's `fruit`, `spinner`, and `rest` decisions. If the profile is a baby with a living parent and neither priority applies, keep `observe_peer`, target that parent while farther than `OBSERVATION_STOP_DISTANCE`, and set a reason that names the parent. Do not persist a follow state.
- [x] **Step 4: Re-run the focused verifier.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: `SOCIAL_SLICE_CHECKS_OK`; the new baby-follow tests pass and the existing social checks remain green.

---

### Task 2: Parent-focused child observation and learning

**Files:**
- Modify: `godot/tools/verify_social_slice.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/norn_cognition.gd`

**Interfaces:**
- Consumes: Task 1's `_nearest_living_parent(profile)` and the existing sorted `nearby_norns` observations.
- Produces: `_nearest_visible_parent(profile, nearby_norns) -> NornProfile` (or equivalent private helper); `record_outcome` reads optional `learningMultiplier`, clamps it to `[0.0, 2.0]`, and applies it only to `observe` and `observe-feedback` learning deltas. `AlbiaWorld._offer_observation` supplies `1.5` for a child observer and `1.0` otherwise.

- [x] **Step 1: Write the failing parent-target and learning tests.** Assert that a child who chooses `observe_peer` targets the nearest visible living parent ahead of a closer non-parent, falls back to the nearest visible peer when no parent is sensed, and receives exact 1.5× positive and negative observation deltas compared with an otherwise identical adult observer. Assert a non-observation event ignores `learningMultiplier` and all associations stay within `[0, 1]`.
- [x] **Step 2: Run the verifier and confirm the intended failures.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: `SOCIAL_SLICE_CHECK_FAILED` only for child parent preference and learning multiplier; no parse or fixture errors.

- [x] **Step 3: Implement parent preference and stage-scaled observation learning.** When a child selects `observe_peer`, use the closest sensed parent when available and retain the current nearest peer fallback. Pass `learningMultiplier` in the observation outcome from `_offer_observation`. In `NornCognition.record_outcome`, default and clamp the multiplier, then scale only the computed `observe` and `observe-feedback` deltas before the existing association/context updates. Keep all attention and visibility gates unchanged.
- [x] **Step 4: Re-run the focused verifier.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: `SOCIAL_SLICE_CHECKS_OK`; parent focus, positive and negative child learning, clamp bounds, and existing adult learning all pass.

---

### Task 3: Rendered demonstration, documentation, and full verification

**Files:**
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/README.md`
- Create: `docs/superpowers/ledgers/2026-10-29-godot-developmental-behavior.md`

**Interfaces:**
- Consumes: Task 1 baby-follow behavior and Task 2 child-parent selection/learning multiplier.
- Produces: A rendered capture walkthrough that shows a hatched baby approaching a living parent, then shows the child stage observing a parent's event and confirms the 1.5× association change; README verification instructions and a verification ledger.

- [x] **Step 1: Extend the rendered walkthrough.** After hatching, assert that the newborn is a baby and targets a living parent, wait for it to settle within 2.1 units, then advance it through the existing child-stage threshold. Settle the child's needs, let its normal decision choose a visible parent for `observe_peer`, and trigger a visible parent food event while it attends. Record the event's exact learning delta and compare it with the adult baseline in a deterministic fixture. Preserve the preview's save backup/restore behavior and the rest of the family/death walkthrough.
- [x] **Step 2: Run all native headless checks.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Run: `& $godot --headless --path .\godot --script res://tools/verify_family_system.gd`

Run: `& $godot --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`

Expected: `SOCIAL_SLICE_CHECKS_OK`, `FAMILY_SYSTEM_CHECKS_OK`, and `HABITAT_SCENARIO_OK`.

- [x] **Step 3: Capture and inspect the rendered demonstration.** Run `& $godot --path .\godot --script res://tools/record_preview.gd` without `--headless`, retain the printed AVI path, then run the recording inspector against that clip. Inspect the extracted frames for the baby following/settling by a parent, the child observing a parent, and the existing family/death UI. Confirm at most 10 completed clips remain.

Expected: `VIDEO_CAPTURE_OK` plus the developmental behavior marker; AVI integrity and every JPEG frame validate; sample frames visibly demonstrate both new behaviors.

- [x] **Step 4: Update documentation and ledger.** Document age-dependent following/learning and the verifier commands in `godot/README.md`. Add capture path, frame validation, observed behaviors, test output, and clip-retention count to the ledger. Do not change save version or persisted state.

---
