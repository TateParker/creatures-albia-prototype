# Godot Two-Norn Social Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two independently simulated Norns that approach and learn from nearby events they actively observe.

**Architecture:** Add a small `NornProfile` holder for each actor's independent cognition, biochemistry, language, guidance, and feedback state. `AlbiaWorld` will step both profiles against shared habitat objects; `NornActor` gains generic peer navigation and line-of-sight sensing. The HUD focuses one profile for player actions, and save version 4 stores both profiles with migrations from versions 1–3.

**Tech Stack:** Godot 4.7.2, GDScript, `SceneTree` verification scripts, rendered Godot recording/AVI capture.

**Spec:** `docs/superpowers/specs/2026-10-29-godot-two-norn-social-slice-design.md`

## File Map

- `godot/scripts/norn_profile.gd`: identity and independent per-Norn runtime state.
- `godot/scripts/norn_actor.gd`: distinct appearance, target navigation, peer visibility, and action completion.
- `godot/scripts/norn_cognition.gd`: social-attention scoring and the existing observe learning rules.
- `godot/scripts/albia_world.gd`: two-profile spawning, ticking, focused actions, observed events, and save migration.
- `godot/scripts/habitat_ui.gd`: focus controls and selected-Norn display.
- `godot/tools/verify_social_slice.gd`: headless behavior, isolation, observation, and save assertions.
- `godot/tools/record_preview.gd`: rendered player-facing verification walkthrough.
- `godot/tools/run_habitat_scenario.gd` and `godot/README.md`: regression scenario and operating instructions.

## Global Constraints

- Keep two Norns as the fixed population for this slice; do not add population management UI.
- Reuse the existing deterministic cognition, chemistry, and language modules.
- Keep shared object availability and respawn behavior. If both Norns target one object, the first valid arrival consumes it and the other re-decides.
- Record observation only when the observer is attending and can see the peer's successful food/play event or player feedback.
- Save version 4 and migrate versions 1, 2, and 3 without losing Mallow's saved state.
- Keep the simulation local; use no remote services, generated dialogue, or machine-learning inference.
- Run gameplay recording in rendered, non-headless mode; inspect the captured clip and keep at most 10 completed clips.

## Review Focus

- **Legacy and malformed saves:** versions 1–3 preserve Mallow, initialize a reproducible Moss, and malformed version-4 data follows the safe-reset path. Test in Task 4.
- **Focused-action isolation:** guidance, teaching, Praise, and Scold affect only the focused profile while both continue simulating. Test in Task 3.
- **Observation eligibility:** distance, line of sight, and active attention each gate peer learning. Test in Task 2.
- **Shared-object race:** two actors targeting one fruit or spinner cannot consume it twice; the second actor re-decides. Test in Task 2.
- **Rendered visibility and retention:** both Norns and a witnessed event remain visible in the walkthrough, and completion leaves at most 10 clips. Verify in Task 5.

---

### Task 1: Add per-Norn state and peer navigation

**Files:**
- Create: `godot/scripts/norn_profile.gd`
- Create: `godot/tools/verify_social_slice.gd`
- Modify: `godot/scripts/norn_actor.gd`
- Modify: `godot/scripts/albia_world.gd` (preserve the existing single-Norn event wiring)

`verify_social_slice.gd` extends `SceneTree` so the same verifier can run headlessly and instantiate the habitat for integration checks.

**Interfaces:**
- `NornProfile.initialize(actor_id: String, display_name: String, actor: NornActor, cognition: Dictionary, biochemistry: Dictionary, language: Dictionary) -> void`
- `NornActor.configure_identity(actor_id: String, display_name: String, body_color: Color) -> void`
- `NornActor.set_action_target(target_node: Node3D, action_id: String, reason: String, target_id: String = "") -> void`; an omitted target ID is derived from an `Interactable` for the existing single-Norn caller, while peer callers pass the stable ID explicitly.
- `NornActor.can_see_peer(peer: NornActor) -> bool`
- `NornActor.action_completed(actor_id: String, action_id: String, target_id: String)`

- [x] **Step 1: Add failing profile and peer-navigation checks**

In `verify_social_slice.gd`, add `test_profiles_keep_independent_state()` to assert two profiles keep distinct cognition, chemistry, and language dictionaries, and `test_actor_approaches_peer_without_consuming_object()` to assert an actor accepts and reaches a `Node3D` peer target, retains its action and actor/target IDs, emits no object-completion signal for peer arrival, and emits exactly one correctly identified completion for an `Interactable`.

- [x] **Step 2: Run the focused verifier and confirm the expected failures**

Run: `& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_social_slice.gd`

Expected: FAIL because `NornProfile` and generic peer-target behavior do not exist yet.

- [x] **Step 3: Implement the profile holder and generic actor target**

Store actor ID/name, actor node, cognition, biochemistry, language, guidance, current decision, recalled episodes, and per-Norn feedback fields in `NornProfile`. Generalize actor navigation from `Interactable` to `Node3D`, preserve an explicit target ID, and only emit object completion for an interactable target. Give Moss a separately configured body color and label. Configure Mallow through the same actor identity API and update the existing world callback to accept the actor ID, keeping the one-Norn habitat functional until Task 2.

- [x] **Step 4: Rerun the focused verifier**

Run the Task 1 verifier and the existing habitat scenario:

```powershell
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_social_slice.gd
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/run_habitat_scenario.gd
```

Expected: profile isolation, peer navigation, and actor-ID event dispatch pass; the existing single-Norn food, spinner, language, feedback, save, and migration scenario remains green.

- [x] **Step 5: Commit the profile/navigation layer**

After the focused verifier passes, run:

```powershell
git add godot/scripts/norn_profile.gd godot/scripts/norn_actor.gd godot/scripts/albia_world.gd godot/tools/verify_social_slice.gd docs/superpowers/specs/2026-10-29-godot-two-norn-social-slice-design.md docs/superpowers/plans/2026-10-29-godot-two-norn-social-slice.md
git commit -m "Add Norn profiles and peer navigation"
```

---

### Task 2: Simulate two Norns and record attentive observations

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/norn_actor.gd` to expose line-of-sight checks for shared objects.
- Modify: `godot/scripts/norn_cognition.gd`
- Modify: `godot/tools/verify_social_slice.gd`
- Modify: `godot/tools/run_habitat_scenario.gd` to account for peer-driven chemistry during the existing catch-up check.

**Interfaces:**
- `AlbiaWorld.norn_profiles: Dictionary`, keyed by stable IDs `"mallow"` and `"moss"`
- `AlbiaWorld.profile_for(actor_id: String) -> NornProfile`
- `AlbiaWorld._run_decision(profile: NornProfile) -> void`
- `AlbiaWorld._offer_observation(source: NornProfile, outcome: Dictionary) -> void`
- Sense radius `10.0`, observation radius `3.0`, approach stop distance `2.1` world units.
- `NornCognition.decide` receives visible peers in `observation["nearbyNorns"]`. When a peer is visible, observe need is `8.0 + max(0.0, 50.0 - socialComfort) * 0.12 + sociability * 20.0`; otherwise it is zero. This makes Moss's higher existing sociability trait produce a visible observation tendency without overriding urgent food/rest priorities.

- [x] **Step 1: Add failing two-Norn and event-gating assertions**

Add these named assertions to `verify_social_slice.gd`: `test_world_spawns_two_independent_norns`, `test_peer_perception_filters_distance_and_occlusion`, `test_shared_object_sensing_filters_distance_and_occlusion`, `test_peer_comfort_rises_and_decays`, `test_social_attention_selects_observation_when_needs_are_settled`, `test_observation_requires_range_visibility_and_attention`, `test_observed_success_and_feedback_teach_matching_action`, and `test_contested_object_completes_once`. The tests must also confirm urgent food/rest still wins over observation.

- [x] **Step 2: Run the social verifier and confirm the expected failures**

Run the Task 1 Godot command. Expected: the two-Norn, peer perception, and observation checks fail against the single-Norn world.

- [x] **Step 3: Create and advance both independent profiles in `AlbiaWorld`**

Create Mallow with seed `4181996`, curiosity `0.65`, sociability `0.55`; create Moss with seed `4181997`, curiosity `0.50`, sociability `0.85`. Start Moss at `(6.2, 0.0, 1.6)`. Give each profile its own cognition, biochemistry, language, decision, and feedback state; advance both chemistry states at 10 Hz and both decisions at 5 Hz against shared objects.

- [x] **Step 4: Implement peer perception, attention, and approach**

Build each profile's visible peer list and available-object list independently, filtering both by the 10-unit sense radius and line of sight. Target the nearest visible peer for `observe_peer`; stop within `2.1` units. Keep current fruit/play and rest priority. Use the `3.0`-unit observation radius and require settled `observe_peer` action plus line of sight for attention.

- [x] **Step 5: Route witnessed events through existing cognition and chemistry**

After a profile completes food/play or receives eligible Praise/Scold, offer the event to the other profile only if it meets the attention gate. Record `observe` or `observe-feedback` with source actor, action/target, feedback, time, peer count, and the observer's sociability; apply the existing `social` biochemical event to the observer and synchronize its chemistry.

- [x] **Step 6: Run the social verifier**

Run: `& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_social_slice.gd`

Also run the existing habitat scenario to verify autonomous fruit/spinner behavior, chemistry integration, and save compatibility.

Expected: independent decisions, peer comfort, observation gating, learning, and one-time object completion pass.

- [ ] **Step 7: Commit the two-Norn simulation layer**

After the social verifier passes, run:

```powershell
git add godot/scripts/albia_world.gd godot/scripts/norn_actor.gd godot/scripts/norn_cognition.gd godot/tools/verify_social_slice.gd godot/tools/run_habitat_scenario.gd docs/superpowers/plans/2026-10-29-godot-two-norn-social-slice.md
git commit -m "Simulate two Norns with social observation"
```

---

### Task 3: Focus one Norn in the HUD

**Files:**
- Modify: `godot/scripts/habitat_ui.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_social_slice.gd`
- Modify: `godot/tools/run_habitat_scenario.gd`

**Interfaces:**
- `AlbiaWorld.select_norn(actor_id: String) -> void`
- `AlbiaWorld.focused_profile() -> NornProfile`
- `HabitatUi.update_view(view: Dictionary) -> void`, passing the focused Norn's identity, state, and language plus global pause/recording/status fields.

- [x] **Step 1: Add failing focus-isolation checks**

Add `test_focus_routes_actions_only_to_selected_norn`, `test_invalid_focus_id_is_ignored`, and `test_unfocused_norn_keeps_simulating`. Assert selecting Moss changes the focused display; guidance, teaching, Praise, and Scold change only Moss; an invalid ID does not change focus; and Mallow continues moving and advancing chemistry.

- [x] **Step 2: Run the verifier and confirm the focus assertions fail**

Run the Task 2 Godot command. Expected: the HUD/world still route actions through the single profile.

- [x] **Step 3: Add compact focus controls and selected-profile display**

Add Mallow/Moss buttons to the existing habitat panel, mark the active button, and pass only that profile's chemistry, memory, language, and decision data to the focused HUD fields.

- [x] **Step 4: Route direct player actions through `focused_profile()`**

Route guidance, teaching, Praise, Scold, and feedback eligibility through the focused profile. Keep both profiles simulating and keep pause, speed, shared objects, and recording global.

- [x] **Step 5: Run the social verifier and existing habitat scenario**

Run the Task 2 Godot command and:
`& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/run_habitat_scenario.gd`

Expected: focus isolation passes and the food, spinner, language, chemistry, and feedback scenario still passes.

- [x] **Step 6: Commit focused Norn controls**

After the verifier and habitat scenario pass, run:

```powershell
git add godot/scripts/habitat_ui.gd godot/scripts/albia_world.gd godot/tools/verify_social_slice.gd godot/tools/run_habitat_scenario.gd
git commit -m "Add focused Norn controls"
```

---

### Task 4: Save and migrate both profiles

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_social_slice.gd`
- Modify: `godot/tools/run_habitat_scenario.gd`
- Modify: `godot/tools/record_preview.gd`

**Interfaces:**
- Save version `4`; top-level record has `version`, `seed`, `simulationTime`, `focusedNornId`, and `norns`.
- `norns` is keyed by `mallow` and `moss`; each profile stores serialized cognition, biochemistry, language, and feedback (`available`, `action`, `target`, `time`).
- `load_game()` accepts versions 1–4. Versions 1–3 preserve Mallow through existing migrations and create Moss from its deterministic seed/traits.

- [x] **Step 1: Add failing save/load and migration assertions**

Add `test_version4_round_trip_preserves_both_profiles`, `test_v1_migration_preserves_mallow_and_seeds_moss`, `test_v2_migration_preserves_mallow_and_seeds_moss`, `test_v3_migration_preserves_mallow_and_seeds_moss`, and `test_malformed_v4_save_uses_safe_reset`. Assert a version-4 round trip preserves both profiles' episodes, compounds, vocabularies, focus, and independent feedback windows; each legacy version preserves Mallow and adds reproducible Moss; invalid profile IDs, chemistry, feedback, or missing data safely reset.

- [x] **Step 2: Run the verifier and confirm persistence assertions fail**

Run the Task 2 Godot command. Expected: current version-3 single-Norn records cannot round-trip the new profile map.

- [x] **Step 3: Implement version-4 serialization, validation, and migrations**

Serialize and validate both profiles before applying restored data. Preserve Mallow with the existing migrations for versions 1–3, create a clean deterministic Moss for those records, and clear transient movement targets on load.

- [x] **Step 4: Run version-4 and legacy save checks**

Run: `& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_social_slice.gd`

Expected: round-trip, v1/v2/v3 migration, and malformed-save reset checks pass.

- [ ] **Step 5: Commit version-4 saves**

After the migration checks pass, run:

```powershell
git add godot/scripts/albia_world.gd godot/tools/verify_social_slice.gd godot/tools/run_habitat_scenario.gd godot/tools/record_preview.gd docs/superpowers/plans/2026-10-29-godot-two-norn-social-slice.md
git commit -m "Persist both Norn profiles"
```

---

### Task 5: Record, inspect, and document the social walkthrough

**Files:**
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/tools/run_habitat_scenario.gd`
- Modify: `godot/README.md`
- Modify: `docs/superpowers/plans/2026-10-29-godot-two-norn-social-slice.md`
- Create: `docs/superpowers/ledgers/2026-10-29-godot-two-norn-social-slice.md`

- [ ] **Step 1: Extend the rendered walkthrough assertions**

Drive the actual focus controls and actions for both Norns, assert status/memory/chemistry evidence for observation, and preserve/restore the user's local save around the run.

- [ ] **Step 2: Run targeted headless checks and scene startup**

Run each command and confirm it exits successfully with no parser/runtime errors:

```powershell
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_social_slice.gd
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/run_habitat_scenario.gd
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_biochemistry.gd
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_avi_writer.gd
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_recording_retention.gd
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --quit-after 2
```

- [ ] **Step 3: Capture a rendered walkthrough**

Run: `& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path godot --script res://tools/record_preview.gd`

Expected: the clip visibly shows both Norns, one approaching to observe the other's successful event, the observer's learning evidence, focused feedback, and restored save data.

- [ ] **Step 4: Inspect the AVI and retention result**

Check the AVI header/index and decodable 1280×720 JPEG frames; inspect frames showing both actors and observation; confirm `user://recordings/` has no more than 10 completed clips; report the recording path.

- [ ] **Step 5: Update documentation and review the final change set**

Document controls, two-Norn behavior, observation, version-4 migration, and verification results in `godot/README.md` and the ledger. Mark completed steps, run `git diff --check`, and exclude generated Godot data from the change set.

- [ ] **Step 6: Commit the completed feature**

```powershell
git add godot/scripts/norn_profile.gd godot/scripts/norn_actor.gd godot/scripts/norn_cognition.gd godot/scripts/norn_biochemistry.gd godot/scripts/norn_language.gd godot/scripts/albia_world.gd godot/scripts/habitat_ui.gd godot/tools/verify_social_slice.gd godot/tools/run_habitat_scenario.gd godot/tools/record_preview.gd godot/README.md docs/superpowers/specs/2026-10-29-godot-two-norn-social-slice-design.md docs/superpowers/plans/2026-10-29-godot-two-norn-social-slice.md docs/superpowers/ledgers/2026-10-29-godot-two-norn-social-slice.md
git commit -m "Add two-Norn social simulation"
```

- [ ] **Step 7: Push and verify the branch**

Run `git push origin main`, fetch `origin`, then confirm `git status --short --branch` is clean and `git rev-list --left-right --count origin/main...main` returns `0 0`.
