# Godot Biochemistry Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Give the Godot Norn a deterministic, inspectable biochemical model that feeds its existing cognition, survives legacy saves, and stays responsive for 12 local Norns.

**Architecture:** Add a scene-independent NornBiochemistry model with 18 named compounds, data-authored events and reaction rules, bounded deterministic stepping, and versioned state. AlbiaWorld owns the fixed-step scheduler and events, synchronizes the existing ten cognition signals, and stores version-3 saves. HabitatUi adds an expandable read-only compound view; focused verification scripts and a rendered video walkthrough cover behavior and performance.

**Tech Stack:** Godot 4.7.2 Standard, GDScript, existing local AVI recorder, PowerShell launch commands.

**Spec:** docs/superpowers/specs/2026-10-28-godot-biochemistry-design.md

## Global Constraints

- Simulation stays local, deterministic, and independent of SceneTree, renderer, input, physics, UI, saving APIs, and random-number sources.
- Use exactly the 18 named compounds from the spec, stable string IDs, and concentrations bounded to [0, 100]; do not allocate unused chemical slots.
- Keep chemistry at 10 Hz with the existing 0.1-second fixed step and a maximum of five catch-up steps per frame; keep cognition decisions at 5 Hz.
- Preserve the existing ten cognition keys, action IDs, bounded learning rules, memories, and fixed-seed cognition reference behavior.
- Write save schema version 3; load versions 1 and 2 by migrating the ten saved signals and preserving applicable learned state.
- Profile 1, 4, and 12 states at 10 Hz on the current development machine before expanding the active network.
- Do not add genome mutation, organs, life stages, fertility, pregnancy, immune populations, diffusion, genetic editing, speech, cloud services, remote models, or runtime network access in this milestone.
- Do not add a general automated test suite; use focused chemistry checks, existing bounded headless scenarios, profiling, and the required rendered recording walkthrough.
- Record gameplay in rendered, non-headless mode, inspect the resulting clip or extracted frames, verify its AVI frames/index, and keep no more than 10 completed clips.
- Run Godot CLI commands from the repository root and pass --path .\godot; project-relative res:// paths then resolve against the native Godot project.

## Review Focus

- Invalid or non-finite timestep, event strength, and stimulus values must not corrupt state; pin this in verify_biochemistry.gd.
- Depleted substrates, excessive reaction rates, and already-saturated products must remain finite and bounded without creating substrate; pin this in verify_biochemistry.gd.
- Reversing reaction-table order must not change a fixed step, and replaying the same inputs must be deterministic; pin this in verify_biochemistry.gd.
- Large rendered-frame deltas, pause, and speed changes must respect the five-step catch-up bound and fixed 10 Hz chemistry cadence; pin this in run_habitat_scenario.gd and the rendered recording walkthrough.
- Invalid version-3 biochemical records and valid version-1/version-2 saves must respectively use safe fallback and preserve their legacy learning/language state; pin this in the save walkthrough.

---

### Task 1: Build the standalone biochemical model

**Files:**
- Create: godot/scripts/norn_biochemistry.gd
- Create: godot/tools/verify_biochemistry.gd

**Interfaces:**
- Produces create_state(initial_signals: Dictionary = {}) -> Dictionary, advance(state: Dictionary, stimuli: Dictionary = {}, dt: float = 0.1) -> Dictionary, apply_event(state: Dictionary, event_id: String, strength: float = 1.0) -> Dictionary, read_signals(state: Dictionary) -> Dictionary, read_compounds(state: Dictionary) -> Dictionary, read_fluxes(state: Dictionary) -> Dictionary, serialize_state(state: Dictionary) -> Dictionary, restore_state(record: Variant) -> Dictionary, and migrate_from_legacy_signals(signals: Dictionary) -> Dictionary.
- A valid state has version, compounds, and lastFluxes fields. Compounds has exactly these 18 keys: glucose, hunger, curiosity, fatigue, reward, punishment, stress, socialComfort, arousal, satiety, starch, glycogen, pyruvate, ATP, ADP, oxygen, carbonDioxide, and water.
- advance and apply_event mutate the supplied state and return fresh compounds, signals, and fluxes snapshots. apply_event also returns ok and eventId; invalid input returns an empty result without changing state.
- _advance_reactions(compounds: Dictionary, stimuli: Dictionary, dt: float, reaction_rules: Array[Dictionary]) -> Dictionary is an internal pure helper used to check table-order independence.
- Each reaction definition has id, reactants, products, and rate fields plus an optional stimulus gate. Compute potential flux from the minimum normalized availability of its reactants and dt; cap consumption at available reactants, accumulate all deltas from one start-of-step snapshot, then clamp all products and sinks together. A decay rule has one reactant and an empty products map.
- Seed added compounds at starch 0, glycogen 25, pyruvate 0, ATP 55, ADP 20, oxygen 100, carbonDioxide 0, and water 50. Event impulses live in this module: food adds 34 starch and 8 reward; toy subtracts 45 curiosity and 12 arousal and adds 8 reward; Praise adds 12 reward and subtracts 6 stress; Scold adds 12 punishment and 8 stress; teach-word and social each add 1.5 socialComfort. All event deltas are clamped to [0, 100].

- [x] Step 1: Add focused verifier assertions for the 18 compound IDs, legacy signal seeding, bounded deterministic stepping, event responses, invalid inputs, depletion/saturation, and reversed rule order. The verifier must exercise food over subsequent steps, activity, rest, toy, Praise, Scold, and teaching/social input.
- [x] Step 2: Run Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_biochemistry.gd and confirm the expected failure while the model is absent.
- [x] Step 3: Implement the state registry, initialization defaults, normalized stimuli, event definitions, reaction definitions, snapshot/delta evaluator, clamps, migration, serialization, and validation in norn_biochemistry.gd. Seed the existing ten signals from the supplied dictionary; use the added-compound defaults and event impulse amounts listed above; cap accepted dt at 0.5 seconds and event strength at 1.0. Add basal drift/decay and nutrient-mediated metabolism as authored reaction rules, keeping the older cognition-only path unchanged.
- [x] Step 4: Run Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_biochemistry.gd and require a single BIOCHEMISTRY_CHECKS_OK result. Confirm no concentration becomes non-finite or leaves [0, 100], and event IDs outside the authored map leave the state unchanged.

### Task 2: Preserve cognition behavior while accepting biochemical snapshots

**Files:**
- Modify: godot/scripts/norn_cognition.gd
- Modify: godot/tools/verify_biochemistry.gd
- Reference: godot/scenarios/browser_reference.json
- Reference: godot/tools/print_cognition_reference.gd

**Interfaces:**
- Consumes the NornBiochemistry ten-key signals dictionary.
- Produces sync_chemistry(state: Dictionary, signals: Dictionary) -> bool and extends record_outcome(state: Dictionary, outcome: Dictionary = {}, external_chemistry: Dictionary = {}) -> Dictionary.
- external_chemistry is either empty, preserving the existing direct outcome-chemistry behavior, or has before and after dictionaries. With before/after supplied, record_outcome stores those snapshots in the episode, sets state chemistry to after, and does not apply the legacy direct chemistry edit a second time.

- [x] Step 1: Extend verify_biochemistry.gd with checks that sync_chemistry accepts exactly the existing ten valid signals and that external snapshots appear in episode chemicalsBefore/chemicalsAfter without duplicate outcome edits.
- [x] Step 2: Run the focused verifier and confirm the new cognition assertions fail before implementation.
- [x] Step 3: Add sync_chemistry and the optional external-chemistry branch to record_outcome. Keep the existing two-argument call path byte-for-byte behaviorally equivalent for fixture consumers, including action IDs, bounded learning, episode numbering, and default food/Praise/Scold chemistry.
- [x] Step 4: Run the focused verifier with Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_biochemistry.gd, then run Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/print_cognition_reference.gd. Confirm the new focused checks pass and compare every fixed-seed decision, outcome, and final cognition value with the fixture.

### Task 3: Route world simulation and events through biochemistry

**Files:**
- Modify: godot/scripts/albia_world.gd
- Modify: godot/tools/run_habitat_scenario.gd
- Reference: godot/scripts/norn_actor.gd

**Interfaces:**
- AlbiaWorld owns biochemistry_state: Dictionary and initializes it from the new NornCognition state signals.
- The world calls advance once per 0.1-second step with active, resting, and nearbyPeer stimuli, then synchronizes read_signals into cognition before the 0.2-second decision loop.
- A world helper _apply_biochemistry_event(event_id: String, outcome: Dictionary) -> Dictionary captures pre-event signals, applies the event, synchronizes cognition, and records the outcome with before/after snapshots.

- [x] Step 1: Extend run_habitat_scenario.gd with assertions for food-to-nutrient changes, activity energy use and fatigue, rest recovery, toy satisfaction, Praise, Scold, and teaching/social comfort; assert each event changes cognition only through the synchronized biochemical snapshot.
- [x] Step 2: Run the scenario and confirm the new assertions fail against the cognition-only world.
- [x] Step 3: Add the biochemistry model to AlbiaWorld initialization and fixed-step updates. Preserve the current scheduler bounds, update cognition readouts before decisions, and keep all world event amounts inside the model's event table.
- [x] Step 4: Route completed fruit/spinner actions, feedback, and word teaching through _apply_biochemistry_event. Preserve each existing episode text, action/target links, word metadata, feedback window, and learning update.
- [x] Step 5: Run Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd. Require the existing scenario and new biochemical integration assertions to pass; verify a paused interval changes neither simulation time nor concentrations.

### Task 4: Add version-3 persistence and legacy migration

**Files:**
- Modify: godot/scripts/albia_world.gd
- Modify: godot/tools/run_habitat_scenario.gd
- Modify: godot/tools/record_preview.gd

**Interfaces:**
- Save version 3 contains version, seed, simulationTime, cognition, language, and biochemistry. The biochemistry record is produced only by NornBiochemistry.serialize_state.
- Version 1 initializes an empty language state; version 2 restores its language state; versions 1 and 2 both migrate cognition chemistry into a valid biochemical state.
- Version 3 restores both states and then synchronizes cognition chemistry from the restored biochemical compounds. Invalid biochemistry must trigger the existing safe-save fallback before replacing any live state.

- [x] Step 1: Extend the focused save checks to cover version-3 round-trip of all 18 compounds and ten cognition readouts, version-2 migration with vocabulary retained, version-1 migration with empty vocabulary, and invalid version-3 fallback.
- [x] Step 2: Run the save scenario and confirm the new version-3 and migration assertions fail before persistence changes.
- [x] Step 3: Set SAVE_VERSION to 3, serialize biochemistry in save_game, accept versions 1, 2, and 3 in load_game, migrate legacy chemistry, validate version-3 records, and assign restored state only after every record validates.
- [x] Step 4: Run Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd. Require exact compound round-trip, preserved v1/v2 learning and vocabulary, and safe fallback from invalid version-3 data.

### Task 5: Add the expandable in-game compound inspector and record it

**Files:**
- Modify: godot/scripts/habitat_ui.gd
- Modify: godot/scripts/albia_world.gd
- Modify: godot/tools/record_preview.gd

**Interfaces:**
- HabitatUi.update_view receives the existing ten-key summary plus the full compound dictionary and latest reaction fluxes.
- The compact Needs/Body summary remains visible. A Biochemistry toggle opens a read-only, scrollable view of all 18 named compounds and recent non-zero reaction fluxes.
- The rendered walkthrough visibly demonstrates the inspector and a food/activity/rest/feedback sequence while retaining the current language-teaching walkthrough and recorder validation.
- Place the initially hidden inspector in a right-docked 340-by-600-pixel panel so opening it does not resize the existing HUD; list every compound in stable registry order and show at most the six largest non-zero fluxes from the latest step.

- [x] Step 1: Add rendered-walkthrough checks for the Biochemistry toggle, visibility of every compound label, reaction-flux display, and HUD fit at 1280×720.
- [x] Step 2: Run the rendered walkthrough and confirm those checks fail before the UI is implemented.
- [x] Step 3: Add the expandable inspector to HabitatUi, pass read-only biochemical snapshots from AlbiaWorld, and preserve the compact summary and existing controls.
- [x] Step 4: Extend record_preview.gd to guide Mallow to fruit and the spinner for eating/activity, apply Praise or Scold, set a bounded high-fatigue fixture so the Norn visibly rests, open the inspector, check the expected concentrations/fluxes, and exercise save/load migration while recording.
- [x] Step 5: Run the rendered recording walkthrough using Godot_v4.7.2-stable_win64.exe --path .\godot --script res://tools/record_preview.gd. Inspect the resulting clip or extracted frames for the HUD, event sequence, and inspector; then run Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_avi_writer.gd to verify AVI frame count/index and retain no more than 10 completed clips.

### Task 6: Profile the 12-state model and update the Godot guide

**Files:**
- Create: godot/tools/profile_biochemistry.gd
- Modify: godot/README.md

**Interfaces:**
- The profile uses fixed initial states and identical 0.1-second stimuli, measures 1, 4, and 12 independent states for 1,000 chemistry steps, and prints median, p95, and maximum microseconds per population.
- The local real-time budget is a p95 below 1 millisecond for one 10 Hz update across 12 states on the current development machine.

- [x] Step 1: Add profile assertions that each population is independent and receives identical inputs, then collect 1,000 measured update samples per population.
- [x] Step 2: Run Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/profile_biochemistry.gd and record the baseline output.
- [x] Step 3: If the 12-state p95 exceeds 1 millisecond, inspect active-rule iteration and allocations, reduce avoidable work without changing results, then rerun the profile.
- [x] Step 4: Update godot/README.md with the compound model, fixed-step behavior, inspector controls, save version and migration, focused verification commands, recording workflow, and measured 1/4/12-state profile.
- [x] Step 5: Run the focused chemistry verifier, cognition reference comparison, headless habitat scenario, rendered recording walkthrough, AVI verification, and 1/4/12-state profile once more using the commands above. Report the clip path and inspected behavior, profile measurements, and any remaining limitation.
