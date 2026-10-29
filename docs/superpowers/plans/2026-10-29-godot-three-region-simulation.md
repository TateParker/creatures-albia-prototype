# Godot Three-Region Simulation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expand the Godot slice into a connected three-region world with grounded foraging, drinking, and exploration behavior while preserving existing Norn state and interactions.

**Architecture:** Keep `AlbiaWorld` as the scene adapter and keep cognition/chemistry independent of rendering and input. Extend the existing deterministic action model with source-specific actions and bounded thirst chemistry; build the larger one-scene world with local explore targets and a focused-Norn camera mode.

**Tech Stack:** Godot 4.7.2 Standard, typed GDScript, local JSON persistence.

**Spec:** `docs/superpowers/specs/2026-10-29-godot-expanded-habitat-design.md`

## Global Constraints

- Target Godot 4.7.2-stable Standard and keep the GL Compatibility renderer.
- Keep the built game self-contained and offline at runtime.
- Use one continuous 3D scene with Sunmeadow, Softwood Grove, and Glassfall Hollow.
- Keep 10-unit object sensing and line-of-sight checks; Norns may autonomously select only sensed resources and landmarks.
- Append `forage`, `drink`, and `explore` after existing action IDs; preserve the 20 existing cognition input positions and append four new inputs after the existing 256 mark values and 2 drawing-target cues.
- Use bounded 0–100 chemistry signals and preserve cognition versions 1–4, biochemistry version 1, and world saves 1–6.
- Keep current Norn bodies procedural until the user separately approves replacement.
- The project `AGENTS.md` requires a rendered, non-headless gameplay recording and inspection. Keep at most ten completed clips in `user://recordings/`.
- The game-development workflow requires a separate exact user authorization before launching Godot for the recording; prepare the command and request that authorization after code and docs are reviewable.
- Preserve existing save files and unrelated working-tree data.

## Review Focus

1. **Thirst boundaries and old biochemistry records:** thirst stays within 0–100, drink reduces thirst and restores water, and version-1 records receive a safe default.
2. **Resource range and occlusion:** berry, spring, and explore actions are eligible only with a matching available object inside 10 units and visible by line of sight.
3. **Shared resource behavior:** when two Norns reach one berry or spring, only one consumes it; the other safely reconsiders after cooldown.
4. **Existing saves and memories:** versions 1–6 preserve learned associations, episodes, language, family/eggs, drawing marks, and positions after migration.
5. **Camera focus and world bounds:** switching focused Norns, manual pan/zoom, and returning to follow work at both map ends without clamping actors into the old world.

---

### Task 1: Extend bounded thirst chemistry and cognition state compatibly

**Files:**
- Modify: `godot/scripts/norn_biochemistry.gd`
- Modify: `godot/scripts/norn_cognition.gd`

**Interfaces:**
- `NornBiochemistry.create_state(initial_signals: Dictionary = {}) -> Dictionary` returns the existing compounds plus bounded `thirst`.
- `NornBiochemistry.apply_event(state: Dictionary, event_id: String, strength: float = 1.0) -> Dictionary` accepts `drink`, decreases thirst, and replenishes the existing `water` compound.
- `NornCognition.ACTION_IDS` appends `forage`, `drink`, and `explore`; `NornCognition.VERSION` becomes 5.
- The cognition input vector retains the legacy 278 indices and appends `thirst`, `nearForage`, `nearDrink`, and `nearExplore`, for 282 total values.

- [x] **Step 1: Implement biochemistry version 2.** Append `thirst` to cognition signals and compound IDs, add its safe default and bounded drift/event behavior, and migrate version-1 serialized chemistry by filling the new compound without changing prior compound values.
- [x] **Step 2: Implement cognition version 5.** Keep the legacy 20 named-input order, mark values, target cues, and first six action outputs unchanged. Rebuild the old seeded policy with the version-4 layout, copy its 278 input weights and six action heads into the expanded state, and seed only the four new cue inputs and three new action heads from independent deterministic streams.
- [x] **Step 3: Review schema migration and legacy mapping in code.** Add bounded thirst to old episode chemistry during migration so new version-5 saves remain loadable.

---

### Task 2: Add source-aware forage, drink, and explore decisions

**Files:**
- Modify: `godot/scripts/norn_cognition.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/interactable.gd`
- Modify: `godot/scripts/norn_profile.gd` only if the chosen per-profile cooldown state cannot be derived safely from bounded episodes.

**Interfaces:**
- Cognition decisions use the 282-value input vector from Task 1 and return existing fields plus scores for `forage`, `drink`, and `explore`.
- `AlbiaWorld._sense_objects(profile: NornProfile) -> Array[Dictionary]` continues returning `id`, `kind`, `label`, `distance`, and `affordances` for local visible objects.
- `Interactable.object_id` remains the stable source/episode target ID; `affordances` includes the matching `forage`, `drink`, or `explore` capability.
- Cognition episode validation accepts `berry_bush`, `spring`, `echo_bloom`, and the bounded route-marker ID family while keeping existing target IDs valid.

- [x] **Step 1: Implement bounded scoring and eligibility.** Drive `forage` from hunger, `drink` from thirst, and `explore` from curiosity; retain urgent fruit/rest safety overrides and the existing action order. Select only an available sensed target whose affordances match the decision.
- [x] **Step 2: Implement world outcomes.** Add source-specific forage, drink, and explore events, chemistry updates, target cooldown/availability, memories, association learning, peer observation, and Praise/Scold feedback eligibility. Trail markers are single-use; the echo bloom has a short cooldown.
- [x] **Step 3: Preserve shared-resource and fallback behavior.** Completion callbacks check availability before applying an event; an unavailable target is discarded by the actor and reconsidered on the next decision.

---

### Task 3: Build the connected three-region world and focused camera

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/norn_actor.gd` only if actor boundary clamping is owned there.

**Interfaces:**
- Region bounds use one continuous map spanning approximately x = -12 through x = 60, retaining the current 18-unit depth.
- `AlbiaWorld._update_camera()` follows the focused living Norn only while follow mode is enabled; manual movement disables follow, and selection/guidance re-enables it.
- Exploration landmarks are regular `Interactable` instances using the shared explore model family and `explore` affordance.

- [x] **Step 1: Implement the 72×18 blockout.** Add three connected, clearly colored regions; retain an unobstructed travel corridor because movement is direct and has no pathfinding. Move the spinner into Glassfall Hollow, place berry/spring/curiosity targets in the intended regions, and add visible region labels.
- [x] **Step 2: Implement local exploration landmarks and camera follow.** Use visible markers spaced so a Norn can sense a next target from its previous marker. Manual WASD/arrow movement suspends follow; selecting a Norn or guiding it resumes follow. Keep scroll zoom and the existing 6–24 unit camera offset bounds.
- [ ] **Step 3: Check map bounds, focus switching, pan, and zoom during the rendered walkthrough in Task 5.**

---

### Task 4: Wire guidance, vocabulary, save migration, and HUD needs

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/norn_language.gd`
- Modify: `godot/scripts/habitat_ui.gd`

**Interfaces:**
- New teachable target IDs are `berry_bush`, `spring`, and `echo_bloom`; route markers may use unique IDs but share the `explore` affordance.
- Existing `select_hud_target(target_id: String, input_word: String = "") -> void` handles new object targets while keeping Praise/Scold behavior unchanged.
- World save schema becomes version 7 and cognition records restore through the version-5 migration.

- [x] **Step 1: Implement target registration and HUD controls.** Add guide/teach controls for berries, spring, and echo bloom in the existing scrollable control grid; include thirst in the focused-Norn needs line; preserve accessible labels and current Praise/Scold controls.
- [x] **Step 2: Implement world save version 7 migration.** Allow version-1 through version-6 world saves to load into version 7, using the cognition and biochemistry migration paths while retaining previous serialized fields.
- [ ] **Step 3: Review legacy save fields and new guidance targets in code; demonstrate the HUD and region movement in the rendered walkthrough in Task 5.**

---

### Task 5: Document and capture the integrated simulation

**Files:**
- Modify: `godot/README.md`
- Modify: `godot/tools/record_preview.gd` or create `godot/tools/record_expanded_habitat_preview.gd` if a focused walkthrough is clearer.
- Modify: `godot/tools/inspect_recording.gd` only if the new output needs a named-frame roster.

- [x] **Step 1: Update Godot help text.** Document all three regions, the new needs/actions, guidance and teaching targets, follow-camera controls, and the distinction between local simulation behavior and any claim about general intelligence.
- [ ] **Step 2: Record a rendered non-headless walkthrough.** Show Norns travelling across region boundaries, forage, drink, explore, the HUD chemistry/reason, and return to the focused Norn. Preserve and restore the user's local save; respect the ten-clip retention limit.
- [ ] **Step 3: Inspect representative frames and report the exact AVI path.** Use `res://tools/inspect_recording.gd` on the finalized clip and inspect the resulting frames for all regions and interactions.

Run: `Godot_v4.7.2-stable_win64.exe --path .\godot --script res://tools/record_expanded_habitat_preview.gd`

Expected: a decodable 1280×720 rendered clip and inspected frames showing the three regions and each new interaction.

- [x] **Step 4: Leave changes uncommitted for user review.** Keep generated asset-tool metadata and unrelated user files separate from the implementation changes.
