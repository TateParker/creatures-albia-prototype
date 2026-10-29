# Godot Albia Vertical Slice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a local Godot 4.7.2 3D vertical slice in which one Norn uses the portable cognition model in a walkable habitat with fruit, a toy, player guidance, feedback, and local save/load.

**Architecture:** Keep cognition in a deterministic, scene-independent GDScript class. A Godot scene adapter supplies fixed-step chemistry/decision updates and structured physics observations, then applies the chosen action to a `CharacterBody3D` Norn. Use simple procedural meshes and a small HUD; retain the browser as the behavior reference.

**Tech Stack:** Godot 4.7.2-stable Standard (non-.NET), typed GDScript, built-in 3D primitives, `JSON`, local `user://` storage.

**Spec:** `docs/superpowers/specs/2026-10-28-godot-albia-vertical-slice-design.md`

## Global Constraints

- No runtime cloud, remote model, speech service, or runtime network dependency.
- Keep the browser app playable and its cognition code/browser adapter unchanged during the Godot port.
- Preserve action IDs `fruit`, `spinner`, `rest`, `observe_peer`, and `idle`, 10 Hz chemistry, 5 Hz decisions, 128 recurrent units, and the 512-episode cap.
- Keep cognition independent of Godot scene, physics, renderer, UI, and file APIs.
- Keep the Godot slice to one Norn. The browser's ordinary gameplay limit remains four; 12 remains a benchmark stress profile.
- Use procedural original meshes; add no third-party asset dependency.
- Do not implement speech input/output in Godot in this phase.
- Do not add or run automated test suites; use source checks, Godot project import/run, and manual browser/Godot scenarios.

## Review Focus

- Fixed-step scheduling after a long frame or paused state: keep chemistry bounded and action decisions responsive.
- Deterministic seed initialization: keep policy generation independent of world RNG and compare equivalent browser/Godot initial states.
- Invalid or incomplete save JSON: reject safely and start a clean seeded Norn without crashing.
- Physics observation across object distance and occlusion: provide valid affordances only for locally sensed interactables.
- Repeated Praise/Scold: apply learning to the Norn's active/recent action without unbounded association changes.

---

### Task 1: Install portable tool and scaffold the Godot project

**Files:**
- Create: `godot/project.godot`
- Create: `godot/scenes/main.tscn`
- Create: `godot/README.md`
- Modify: `README.md`

**Interfaces:**
- Project entry scene: `res://scenes/main.tscn`.
- Target engine: Godot 4.7.2-stable Standard from the official Godot archive.

- [x] Download the official Windows Standard archive to a temporary tool directory outside the repository and verify it reports version 4.7.2-stable.
- [x] Create a Godot project configured for a desktop 3D viewport and point its main scene to `main.tscn`.
- [x] Add Godot launch/run instructions to `godot/README.md` and link the Godot project from the repository README.
- [x] Import the project with `godot --headless --editor --path godot --quit`.

### Task 2: Port the deterministic cognition core

**Files:**
- Create: `godot/scripts/norn_cognition.gd`
- Create: `godot/scenarios/browser_reference.json`

**Interfaces:**
- `NornCognition.create_state(seed: int, traits: Dictionary = {}, initial: Dictionary = {}) -> Dictionary`.
- `NornCognition.advance_chemistry(state: Dictionary, stimuli: Dictionary = {}, dt: float = 0.1) -> Dictionary`.
- `NornCognition.decide(state: Dictionary, observation: Dictionary) -> Dictionary` and `preview(...) -> Dictionary`.
- `NornCognition.record_outcome(state: Dictionary, outcome: Dictionary) -> Dictionary`.
- `NornCognition.serialize_state(state: Dictionary) -> Dictionary` and `restore_state(record: Dictionary) -> Dictionary`.
- State keys preserve the browser schema: chemistry, action/context associations, eligibility, episodes, recurrent hidden vector, decision count, commitment window, and last decision.

- [x] Port seed initialization, 10 chemistry channels, reaction/coupling table, bounded `dt`, and deterministic per-Norn policy initialization.
- [x] Port the 128-unit recurrent update and the exact five action IDs/input-vector contract.
- [x] Port context selection, episode retrieval (three maximum), score breakdown/reason strings, and commitment behavior.
- [x] Port food/toy/praise/scold outcome chemistry, bounded associations, eligibility traces, and the 512-episode cap.
- [x] Port allowlisted serialization/restore and produce browser-authored comparison fixtures for one initial decision, one food outcome, and one feedback outcome.
- [x] Run the same fixed-seed authored scenarios in the browser and Godot, compare action IDs, scores within 0.02 tolerance, chemistry, recall IDs/counts, and restored associations.

### Task 3: Build the 3D habitat and Norn adapter

**Files:**
- Create: `godot/scripts/albia_world.gd`
- Create: `godot/scripts/norn_actor.gd`
- Create: `godot/scripts/interactable.gd`
- Modify: `godot/scenes/main.tscn`

**Interfaces:**
- `Interactable` exposes `object_id: String`, `kind: String`, and `affordances: Array[String]`.
- `NornActor` exposes `set_action_target(target: Node3D, action_id: String, reason: String)`, `current_action: String`, and a completion signal.
- World observation contains `time`, chemistry, nearby objects with IDs/distance/affordances, nearby Norns (empty in this slice), optional guidance, and language signals.

- [x] Add a bounded walkable floor, simple habitat silhouettes, honey fruit, spinner toy, lighting, and observer camera using built-in meshes and materials.
- [x] Add a `CharacterBody3D` Norn with a readable original low-poly face/body assembled from primitive meshes and collision shapes.
- [x] Use a short sensor Area3D plus direct-space ray query for local object presence/visibility; translate results into the plain observation contract.
- [x] Advance chemistry at 10 Hz and decisions at 5 Hz with capped catch-up work; use the same `NornCognition` API as the scenario fixture.
- [x] Move the Norn toward the selected interactable, apply food/toy outcomes on arrival, and choose a new action from updated chemistry.
- [x] Manually verify autonomous and guided fruit-seeking/eating and spinner-seeking/use with the fixed seed.

### Task 4: Add player interaction, feedback UI, and local saves

**Files:**
- Create: `godot/scripts/habitat_ui.gd`
- Modify: `godot/scenes/main.tscn`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/README.md`

**Interfaces:**
- HUD actions: guide to fruit, guide to spinner, Praise, Scold, Pause, Save, Load, and Reset.
- Save path: `user://albia_norn_save.json`; file contents are `NornCognition.serialize_state` plus the world simulation time and seed.

- [x] Add a readable HUD for hunger, glucose, curiosity, fatigue, current action/reason, and up to three recalled moments.
- [x] Add guidance buttons that set the structured guidance observation and visibly direct the Norn to the selected object.
- [x] Add Praise/Scold controls that record learning against the recent action and show the resulting association change.
- [x] Save and load local JSON safely; reject invalid data and retain the clean seeded starting state.
- [x] Manually verify guidance, feedback, pause/resume, save/reload persistence, and malformed-save fallback without network access.

### Task 5: Compare, profile, and hand off the vertical slice

**Files:**
- Modify: `godot/README.md`
- Modify: `README.md`
- Modify: `docs/superpowers/plans/2026-10-28-portable-norn-cognition.md`

- [x] Run `godot --headless --editor --path godot --quit` and a short native runtime smoke launch; resolve GDScript parse/load errors.
- [x] Repeat the authored fixed-seed scenarios in browser and Godot; the four choices, reasons, recalls, outcomes, chemistry and associations match within floating-point noise (maximum score delta < 5e-14).
- [x] Profile the one-Norn 3D scene and fixed-step cognition separately; document the machine/session and app-frame limits in `godot/README.md`.
- [x] Update repository instructions with the Godot launch path, controls, local-save path, and known deferrals.
- [x] Keep the browser benchmark and ordinary four-Norn cap unchanged; leave the Godot project ready for interactive review.
