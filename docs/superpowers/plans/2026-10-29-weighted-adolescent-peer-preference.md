# Weighted Adolescent Peer Preference Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an adolescent's remembered positive and negative experiences influence peer observation target selection, so the non-parent preference can be outweighed by individual experience.

**Architecture:** Keep `NornCognition.decide` authoritative for choosing the action. Add a pure, deterministic peer-selection scorer in `norn_cognition.gd` and call it only for adolescent `observe_peer` decisions. Derive peer memory from existing social episodes, retain the child parent rule and all other-stage behavior, then demonstrate both the usual non-parent preference and a memory-driven exception in the rendered recorder.

**Tech Stack:** Godot 4.7.2 Mono, typed GDScript, existing episode/save model, `SceneTree` verification scripts, rendered Motion-JPEG AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-weighted-adolescent-peer-preference-design.md`

## Global Constraints

- Use `distanceScore = clamp(1 - distance / 10, 0, 1)`, adolescent non-parent bonus `+0.25`, and peer-memory score bounded to `[-0.35, +0.35]`.
- Peer memory comes from `observe` and `observe-feedback` episodes whose `actorId` matches the candidate, with recorded valence and salience and a 180 simulated-second half-life.
- Familiarity reaches 1.0 after three recency-weighted memory units; no matching memory contributes 0.
- Keep target scoring deterministic; ties resolve by shortest distance, then stable actor ID.
- Only change the peer target after existing cognition selects `observe_peer`; preserve guidance and higher-priority needs, baby behavior, child parent preference, and adult/elder behavior.
- Do not add persisted fields, change save version 5, add dependencies, change browser code, or change character visuals in this workstream.
- Run the rendered in-game recorder for gameplay changes, inspect the AVI, and retain no more than 10 completed clips.

## Review Focus

- A slightly nearer parent must lose to the adolescent's non-parent bias when peer memory is neutral; test parent at 3.0 and non-parent at 4.2 units.
- Strong recent positive memory for a parent must be able to overcome the non-parent bias; assert the selected peer ID and score components.
- Strong recent negative memory for a non-parent must lower that candidate's score; assert the selected target and reason.
- Stale memories must decay enough that they no longer dominate the stage preference; test at four half-lives.
- Missing, invalid, or tied candidate data must not make selection nondeterministic or crash; test fallback, filtering, and tie resolution.

---

### Task 1: Pure peer utility and world integration

**Files:**
- Modify: `godot/scripts/norn_cognition.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_social_slice.gd`

**Interfaces:**
- Consumes: the existing sensed-peer dictionaries (`id`, `name`, `distance`), parent IDs, life stage, simulation time, and cognition `episodes`.
- Produces: `NornCognition.select_observation_peer(state: Dictionary, candidates: Array[Dictionary], parent_ids: Array[String], life_stage: String, now: float) -> Dictionary` returning `peerId`, `reasonKey`, and a deterministic per-peer score breakdown.
- The world uses the result only when an adolescent's cognition action is `observe_peer`; child parent-first selection and other-stage nearest-peer behavior remain as implemented.

- [x] **Step 1: Add failing utility and integration checks.** Add verifier cases that assert: a neutral-history adolescent selects the 4.2-unit non-parent over a 3.0-unit parent; several recent positive memories about the parent make the parent win; recent negative memories lower a peer's score enough to change the target; memories at four half-lives no longer outweigh the non-parent bonus; ties use distance then stable ID; invalid candidates are ignored; empty input preserves the existing world fallback. Keep existing child, guidance, fruit, spinner, and rest priority assertions.

- [x] **Step 2: Run the social verifier to confirm the intended failures.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: the new scoring and memory-override assertions fail before implementation, with no parse or fixture errors.

- [x] **Step 3: Implement deterministic observation-peer scoring.** In `norn_cognition.gd`, compute normalized proximity, the adolescent non-parent bonus, and bounded familiarity-scaled valence from matching `observe` / `observe-feedback` episodes. Use recency weights with a 180-second half-life; return a stable score breakdown and reason key. In `albia_world.gd`, use the selected profile for adolescent `observe_peer` actions and format a HUD reason that names the peer and the dominant selection factor. Remove or replace the earlier nearest-non-parent-only helper if no longer used.

- [x] **Step 4: Run the social verifier and confirm all checks pass.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: `SOCIAL_SLICE_CHECKS_OK`, including the stage preference, positive/negative memory overrides, decay, deterministic ties, unchanged child behavior, and unchanged action priorities.

### Task 2: Rendered behavior demonstration, documentation, and regression checks

**Files:**
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/README.md`
- Create: `docs/superpowers/ledgers/2026-10-29-weighted-adolescent-peer-preference.md`

**Interfaces:**
- Consumes: Task 1's `NornCognition.select_observation_peer` result and the existing family, lifecycle, HUD, and video recorder APIs.
- Produces: a rendered walkthrough showing an adolescent first choose a non-parent from a neutral-memory scenario, then choose a remembered positively valued parent despite the non-parent age bonus. The HUD reason names the target and explains the memory-driven choice.

- [x] **Step 1: Extend the rendered adolescent scenario.** Use the normal family walkthrough, with Mallow at 3.0 units and sibling Clover at 4.2 units. Assert and show Sprout choosing Clover with neutral peer memory. Then add bounded, recent positive `observe` / `observe-feedback` episodes about Mallow, rerun the normal decision, and assert Sprout chooses Mallow with a memory-based HUD reason. Keep the family and archive sequence and restore the user's prior save.

- [x] **Step 2: Run social, family, and habitat checks.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Run: `& $godot --headless --path .\godot --script res://tools/verify_family_system.gd`

Run: `& $godot --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`

Expected: `SOCIAL_SLICE_CHECKS_OK`, `FAMILY_SYSTEM_CHECKS_OK`, and `HABITAT_SCENARIO_OK`.

- [x] **Step 3: Record and inspect the rendered walkthrough.** Run `record_preview.gd` without `--headless`; require both adolescent choice markers and `VIDEO_CAPTURE_OK`. Run `inspect_recording.gd` on the resulting AVI, decode every frame, validate the index, and visually inspect frames showing both peer choices and the existing archive UI. Confirm the recordings folder remains at 10 or fewer completed clips.

Expected: `ADOLESCENT_INDEPENDENCE_CAPTURE_OK`, `ADOLESCENT_MEMORY_OVERRIDE_CAPTURE_OK`, `VIDEO_CAPTURE_OK`, and `AVI_INSPECTION_OK` for the saved rendered clip.

- [x] **Step 4: Update documentation and verification ledger.** Document the weighted rule, the memory decay and limits, the inspected clip path and frame numbers, regression outputs, completed-clip count, and unchanged save version 5.
