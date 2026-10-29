# Godot Family and Lifespan System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add persistent family creation, egg incubation, inheritance, visible Norn life stages, and old-age death to the native Godot habitat.

**Architecture:** Keep `NornProfile` as the persistent identity and learning record, with a new scene-independent lifecycle model for deterministic age, stage, and death rules. Make `AlbiaWorld` own the dynamic living roster, eggs, population limit, focus, and version-5 save validation; let `NornEgg`, `NornActor`, and `HabitatUi` render the world state. Keep deceased profiles in the saved family archive while excluding them from simulation and the population count.

**Tech Stack:** Godot 4.7.2 Standard, typed GDScript, `SceneTree` verification scripts, local JSON saves, and the existing rendered AVI capture flow.

**Spec:** `docs/superpowers/specs/2026-10-29-godot-family-system-design.md`

## File Map

- `godot/scripts/norn_lifecycle.gd` — deterministic life stages, age progression, lifespan variation, death transitions, and lifecycle-state validation.
- `godot/scripts/norn_profile.gd` — stable identity, ancestry, appearance, lifecycle state, actor reference, and existing independent learning state.
- `godot/scripts/norn_egg.gd` — pending child identity/inheritance data, incubation timer, and visible egg/name/progress.
- `godot/scripts/norn_actor.gd` — stage-specific visual scale and age-stage name label; collision, sensing, navigation, and interaction radii stay constant.
- `godot/scripts/albia_world.gd` — dynamic profile creation, living-roster iteration, pairing, inheritance, incubation/hatching, aging/death, focus transitions, population accounting, and version-5 saves.
- `godot/scripts/habitat_ui.gd` — roster-driven focus, focused age/stage, pairing and egg status, deceased archive, and extinction presentation.
- `godot/tools/verify_family_system.gd` — focused lifecycle, family, persistence, malformed-state, and extinction checks.
- `godot/tools/run_habitat_scenario.gd` — existing social/biochemistry regression flow plus version-5 profile/egg round-trips and versions-1–4 migrations.
- `godot/tools/record_preview.gd` — rendered walkthrough of pairing, incubation, hatch, growth, old-age death, and the retained archive; it continues to back up and restore the user's save.
- `godot/tools/inspect_recording.gd` — AVI header/index validation, full JPEG decode, and extraction of representative gameplay frames.
- `godot/README.md` — controls, age pacing, family behavior, save shape, and verification commands.
- `docs/superpowers/ledgers/2026-10-29-godot-family-lifespan.md` — verification outcomes and final clip path.

## Global Constraints

- Keep all state and computation local and deterministic.
- Limit living Norns and incubating eggs combined to four; deceased records do not occupy population slots.
- Incubation lasts 45 in-game seconds, pauses with the simulation, and follows 0.5×, 1×, and 2× speed.
- Life-stage targets are baby until 60 seconds, child until 180, adolescent until 420, adult until 3,000, and elder until deterministic old-age death at 3,600 ± 300 seconds.
- Mallow and Moss start as generation-zero adults aged 600 seconds; children start as newborns at age zero.
- Adult and elder Norns may parent. Death in this slice is from old age only; do not add illness, injury, or starvation mortality.
- Persist dynamic Norns, ages, death records, and eggs in save version 5; migrate versions 1–4 without losing saved learning.
- Preserve deceased profiles and ancestry in the local archive; pending eggs may hatch after their parents die.
- Keep the family controls understandable at the current 1280×720 window size.
- Run rendered verification with Godot viewport frames and inspect the resulting clip or extracted frames. Keep at most 10 completed clips in `user://recordings/`.
- Implement in the current main checkout, using the native self-implementation workflow; do not delegate to subagents.

## Review Focus

- **Legacy or malformed save:** v1–v4 must preserve prior learning and receive adult founder defaults; invalid v5 records must not partially replace the live world. Test in Task 2.
- **Age boundary, pause, speed, or large frame delta:** each stage and terminal death must transition once, without advancing while paused or skipping deterministic lifecycle rules. Test in Task 4.
- **Old-age death while focused:** remove the actor from simulation, persist the record, free one slot, and move focus deterministically to another living Norn or the family view. Test in Task 4.
- **Egg whose parent dies, deterministic inheritance, or full population:** preserve ancestry, keep the egg's realized traits stable, and reject a fifth living-Norn/egg slot. Test in Task 3.
- **No living Norns or an eggs-only world:** keep the archive visible, allow eggs to finish, focus the first hatch, and show extinction only when no eggs remain. Test in Tasks 4–5 and inspect in Task 6.

---

### Task 1: Implement deterministic Norn lifecycle rules

**Files:**
- Create: `godot/scripts/norn_lifecycle.gd`
- Create: `godot/tools/verify_family_system.gd`

**Interfaces:**
- `NornLifecycle.create_state(seed: int, age_seconds: float = 0.0) -> Dictionary`
- `NornLifecycle.stage_for_age(age_seconds: float) -> String`
- `NornLifecycle.advance(state: Dictionary, delta_seconds: float, simulation_time: float) -> Dictionary`
- `NornLifecycle.serialize_state(state: Dictionary) -> Dictionary`
- `NornLifecycle.restore_state(value: Variant) -> Dictionary`
- State keys: `ageSeconds`, `lifespanSeconds`, `alive`, and `death`; `death` is empty while alive and otherwise stores `cause`, `ageSeconds`, and `simulationTime`.
- `advance` returns `ok`, `stageChanged`, `previousStage`, `stage`, and `died`; it clamps the terminal age to `lifespanSeconds` and records death exactly once.
- Derive lifespan deterministically as `3600 + posmod(seed, 601) - 300` seconds. Stage boundaries are 60, 180, 420, and 3,000 seconds.

- [x] **Step 1: Add failing pure lifecycle assertions**

In `verify_family_system.gd`, extend `SceneTree` and add `test_stage_thresholds`, `test_lifespan_is_seeded_and_bounded`, `test_age_advances_and_reports_stage_change`, `test_death_is_recorded_once`, and `test_lifecycle_restore_rejects_malformed_state`. Assert exact stage values on both sides of every boundary, lifespan in `[3300, 3900]`, equal lifespan for the same seed, no death before the limit, one old-age death at the limit, and rejection of negative/non-finite age, lifespan, or timestamps.

- [x] **Step 2: Run the focused verifier and confirm the expected failures**

Run:

```powershell
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_family_system.gd
```

Expected: lifecycle checks fail because `NornLifecycle` does not exist.

- [x] **Step 3: Implement the lifecycle state and pure transitions**

Add the five declared static methods. Reject non-finite values, negative ages, and invalid state without mutation; `create_state` also rejects a starting age at or beyond its lifespan limit. `stage_for_age` returns `baby`, `child`, `adolescent`, `adult`, or `elder`; age at or beyond the lifespan limit transitions an existing living state to deceased with cause `old-age` and the provided simulation timestamp.

- [x] **Step 4: Run the focused verifier**

Run the Task 1 Godot command. Expected: `FAMILY_SYSTEM_CHECKS_OK`, with all stage, lifespan, validation, and one-shot death assertions passing.

- [x] **Step 5: Commit the lifecycle model**

```powershell
git add godot/scripts/norn_lifecycle.gd godot/tools/verify_family_system.gd
git commit -m "Add deterministic Norn lifecycle model"
```

---

### Task 2: Extend profiles and add version-5 family persistence

**Files:**
- Modify: `godot/scripts/norn_profile.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_family_system.gd`
- Modify: `godot/tools/run_habitat_scenario.gd`

**Interfaces:**
- `NornProfile` keeps its existing `initialize(...)` call and gains `generation: int`, `parent_ids: Array[String]`, `body_color: Color`, and `life_state: Dictionary`.
- `AlbiaWorld.SAVE_VERSION` becomes `5`; version-5 top-level records retain `seed`, `simulationTime`, and `focusedNornId`, and contain `nextNornNumber`, `norns` keyed by stable actor ID, and an `eggs` array.
- `AlbiaWorld.ordered_profile_ids() -> Array[String]` returns `mallow`, `moss`, then `norn-N` IDs in numeric order; `norn_profiles` keeps every living and deceased profile.
- `_serialize_profile(profile: NornProfile) -> Dictionary` serializes `actorId`, `displayName`, generation, parent IDs, color, lifecycle state, and the existing learning fields.
- `_restore_profile(value: Variant, actor_id: String, saved_simulation_time: float) -> Dictionary` validates one candidate record without mutating the live profile.
- Version-5 focus identifies a living profile whenever one exists; it is empty when no Norn is alive. Eggs and deceased profiles remain valid without an active focus.

- [x] **Step 1: Add failing version-5 and migration checks**

In `verify_family_system.gd` and `run_habitat_scenario.gd`, assert that v5 saves Mallow and Moss with stable IDs/names, generation zero, established body colors, age 600 seconds, deterministic lifespan, no parents, and unchanged cognition/biochemistry/language. Add fixtures for v1, v2, v3, and v4: preserve every field previously supported by that version, create adult founders with no ancestry/eggs, and initialize `nextNornNumber` to 1. Add malformed tests for duplicate IDs, missing parent references, negative age, lifespan below the minimum, an alive record with death data, a dead record without an old-age death, an invalid focus, a non-monotonic `nextNornNumber`, and a population above four; each malformed candidate must leave the current live state unchanged before safe fallback.

- [x] **Step 2: Run the focused verifier and habitat scenario against the current save code**

Run:

```powershell
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path godot --script res://tools/verify_family_system.gd
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --fixed-fps 60 --path godot --script res://tools/run_habitat_scenario.gd
```

Expected: the v5 format and new metadata assertions fail while the existing v1–v4 behavior remains observable.

- [x] **Step 3: Add profile metadata and atomic version-5 restore**

Extend `NornProfile` with the new profile fields. Set founders to generation zero, no parents, established starter colors, age 600, and lifecycle lifespan from their cognition seeds. Replace fixed `PROFILE_IDS` loading/iteration with stable numeric child ordering and a shared profile factory. Serialize stable IDs/names, the complete `norns` map, `nextNornNumber`, and an empty `eggs` array initially; on v5 load, instantiate actors only for living profiles and retain deceased records without actors. Implement v1–v4 migration defaults while preserving each version's current learning migration; validate every profile and focus before replacing live state. Do not require offspring cognition seeds to equal the world seed; they use the deterministic child seed stored on the profile/egg. Retain the existing safe-reset behavior for malformed saves.

- [x] **Step 4: Run both persistence verifiers**

Run the two Task 2 commands. Expected: `FAMILY_SYSTEM_CHECKS_OK` and `HABITAT_SCENARIO_OK`; all supported old learning fields survive migration and malformed v5 state cannot partially replace the world.

- [x] **Step 5: Commit the profile/save migration**

```powershell
git add godot/scripts/norn_profile.gd godot/scripts/albia_world.gd godot/tools/verify_family_system.gd godot/tools/run_habitat_scenario.gd
git commit -m "Add family metadata and version-5 saves"
```

---

### Task 3: Add deterministic pairing, eggs, inheritance, and hatching

**Files:**
- Create: `godot/scripts/norn_egg.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_family_system.gd`
- Modify: `godot/tools/run_habitat_scenario.gd` for egg save/load round-trips.

**Interfaces:**
- `AlbiaWorld.living_profiles() -> Array[NornProfile]` returns profiles in stable roster order.
- `AlbiaWorld.population_count() -> int` returns living profiles plus pending eggs; deceased profiles are excluded.
- `AlbiaWorld.start_egg(second_parent_id: String) -> bool` pairs the focused profile with the requested distinct adult/elder profile and reports success.
- `NornEgg.configure(record: Dictionary) -> void`, `NornEgg.advance(delta_seconds: float) -> bool`, and `NornEgg.serialize_state() -> Dictionary`; `advance` returns `true` once when incubation reaches zero.
- Egg records retain egg/child IDs, name, parent IDs, generation, realized traits, blended color, child cognition seed, and remaining incubation seconds.
- Child IDs use monotonic `norn-N`; egg IDs use `egg-N`; no generation cap is imposed. The first four child names follow `Sprout`, `Clover`, `Acorn`, `Pip`, adding the child number when a living Norn already has that name.

- [x] **Step 1: Add failing pairing, capacity, inheritance, and hatch assertions**

Add `test_pairing_requires_distinct_living_adults`, `test_population_cap_includes_eggs_but_not_deceased`, `test_inheritance_is_reproducible`, `test_generation_continues_past_three`, `test_family_events_record_neutral_memories`, `test_child_ids_are_monotonic`, and `test_hatch_creates_fresh_independent_profile`. Cover a fifth combined living-Norn/egg slot, a child name collision, an egg's full 45-second duration, unchanged focus after a hatch when living Norns remain, parent references, inherited curiosity/sociability in bounds, deterministic color/seed/traits after restore, neutral parent memories without feedback deltas, and empty child vocabulary/action associations at hatch.

- [x] **Step 2: Run the family verifier and confirm expected failures**

Run the Task 1 verifier command. Expected: pairing and egg checks fail because dynamic family creation and `NornEgg` do not exist.

- [x] **Step 3: Implement the egg state and visible nest item**

Create a `Node3D` `NornEgg` that owns the realized child record, renders a compact egg with a readable name/progress label, advances only by supplied in-game delta, and exposes its record for save/load. Build the static nest in `AlbiaWorld._build_habitat()`. Serialize realized inheritance on egg creation so loads never reroll it.

- [x] **Step 4: Implement parent validation, inheritance, and dynamic hatching**

Add stable living-roster and population-count helpers. Require two distinct living adults/elders and available capacity before allocating an ID or incrementing `nextNornNumber`. Compute traits as parent average plus deterministic uniform variation in `[-0.06, 0.06]`, clamped to `[0.05, 0.95]`; blend parent colors; derive the cognition seed from the world seed and child number. Record neutral family-memory episodes for both parents at egg/hatch and a birth episode with parent IDs for the child, without changing food/play associations. Tick eggs in world simulation time; save on egg creation and after hatch; on completion, replace exactly one egg with a fresh generation `max(parent generation) + 1` Norn and wire its actor the same way as the founders.

- [x] **Step 5: Persist eggs and run focused family checks**

Serialize every egg in version 5 and validate egg IDs, reserved child IDs, lineage, traits, colors, and remaining timers before applying a loaded world. Run `verify_family_system.gd` and `run_habitat_scenario.gd`. Expected: `FAMILY_SYSTEM_CHECKS_OK` and `HABITAT_SCENARIO_OK`; capacity never exceeds four, inheritance repeats exactly, hatch creates one independent profile, and egg state round-trips without rerolling.

- [x] **Step 6: Commit the family loop**

```powershell
git add godot/scripts/norn_egg.gd godot/scripts/albia_world.gd godot/tools/verify_family_system.gd godot/tools/run_habitat_scenario.gd
git commit -m "Add Norn pairing and egg hatching"
```

---

### Task 4: Advance ages, apply old-age death, and preserve lineage

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/scripts/norn_profile.gd`
- Modify: `godot/tools/verify_family_system.gd`
- Modify: `godot/tools/run_habitat_scenario.gd`

**Interfaces:**
- `AlbiaWorld._step_lifecycle(profile: NornProfile, delta_seconds: float) -> void` advances only living profiles with simulation time after the current world tick.
- `AlbiaWorld._handle_norn_death(profile: NornProfile, death: Dictionary) -> void` clears actor actions, removes the actor node, keeps the profile/death record, chooses the next stable living focus or empty focus, reports the event, and saves.
- Age advances with the existing `step_delta = min(delta * simulation_speed, 0.5)`; eggs use the same in-game delta. Pause advances neither.
- A life-stage boundary updates the profile/actor and saves once. Ordinary per-frame age advancement does not save.

- [x] **Step 1: Add failing world age and death assertions**

Add `test_world_age_obeys_speed_and_pause`, `test_stage_transition_saves_once`, `test_old_age_death_frees_population_slot_once`, `test_focus_moves_after_death`, `test_dead_parent_egg_hatches`, and `test_extinction_keeps_archive`. Assert living profiles alone receive chemistry/cognition steps, paused age and egg timers hold, 0.5×/1×/2× rates are honored, a large frame delta respects the existing 0.5-second world-step cap, death is emitted once, old records remain in the family map, death releases one slot, eggs continue after parent death, and no-living/egg states produce the specified focus behavior.

- [x] **Step 2: Run the focused verifier and confirm expected failures**

Run `verify_family_system.gd`. Expected: world age, death, focus, and parent-death hatch assertions fail before lifecycle integration.

- [x] **Step 3: Integrate age and death into the world tick**

Advance lifecycle state once per living profile per in-game frame delta, separately from the fixed-rate chemistry/decision accumulators. On stage changes, update the actor and save; on terminal death, record `old-age`, remove the actor from simulation and the living roster, preserve the profile, release the slot, move focus deterministically, and save. Continue ticking eggs when no living Norn remains. Do not add illness, injury, or starvation mortality.

- [x] **Step 4: Run family and habitat scenarios**

Run `verify_family_system.gd` and `run_habitat_scenario.gd`. Expected: both print their `*_OK` markers; pause, speed, one-shot death, focus transitions, parent death during incubation, and old-age save/load checks pass.

- [x] **Step 5: Commit age/death integration**

```powershell
git add godot/scripts/albia_world.gd godot/scripts/norn_profile.gd godot/tools/verify_family_system.gd godot/tools/run_habitat_scenario.gd
git commit -m "Integrate Norn aging and old-age death"
```

---

### Task 5: Show life stages, family controls, and deceased archives in the HUD

**Files:**
- Modify: `godot/scripts/norn_actor.gd`
- Modify: `godot/scripts/habitat_ui.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_family_system.gd`
- Modify: `godot/tools/record_preview.gd` to require the new visible controls before it records.

**Interfaces:**
- `NornActor.set_life_stage(stage: String) -> void` updates body scale and the overhead stage label without scaling collision, sensing, or navigation.
- `HabitatUi.update_view(view: Dictionary) -> void` receives a stable ordered `roster`, focused `ageSeconds`/`lifeStage`, `eggRecords`, `archivedNorns`, `populationCount`, and `extinct` state.
- Family UI invokes `AlbiaWorld.start_egg(second_parent_id)`; roster focus invokes the existing `select_norn(actor_id)` only for living profiles.
- Stable UI control names for verification: `NornRoster`, `FamilyPanel`, `SecondParentSelector`, `StartEggButton`, `FamilyArchive`, `ExtinctionPanel`, `StartNewRunButton`, and `FocusNameLabel`.

- [x] **Step 1: Add failing HUD/actor state assertions before implementation**

Add `test_actor_stage_changes_visuals_only` and `test_hud_shows_family_and_archive_states` to `verify_family_system.gd`. Assert the body visual scale is 0.55 baby, 0.70 child, 0.85 adolescent, 1.00 adult, and 0.95 elder while collision/sensor scales remain unchanged; verify the living roster excludes dead IDs, the archive includes them read-only, the second-parent selector excludes self and all stages below adult, and the extinction panel plus start-new-run action appear only with zero living Norns and zero eggs. Add preflight assertions to `record_preview.gd` for the roster, family panel, parent selector, start button, archive, extinction panel, and age/stage display before that script starts a recording.

- [x] **Step 2: Run the focused verifier and confirm expected failures**

Run `verify_family_system.gd`. Expected: actor-stage and family/archive HUD assertions fail because stage rendering and family UI are absent.

- [x] **Step 3: Implement stage visuals and compact family HUD**

Group actor body meshes under a visual-only node and apply the planned stage scale. Update the name label with the current stage. Replace fixed Mallow/Moss focus buttons with the dynamic living roster; add current age/stage, collapsible family pairing and egg progress, a read-only deceased archive, and an eggs-only/extinction presentation with an explicit start-new-run action. Keep the archive until the player chooses that action; do not clear it as a side effect of death. Preserve teaching, needs, recording, biochemistry, and the existing 1280×720 layout. Keep the HUD usable if `focused_profile()` is null.

- [x] **Step 4: Run the focused and habitat checks**

Run `verify_family_system.gd` and `run_habitat_scenario.gd`. Expected: `FAMILY_SYSTEM_CHECKS_OK` and `HABITAT_SCENARIO_OK`; active profile controls remain isolated and all family/empty-world states are visible to the verifier.

- [x] **Step 5: Commit the HUD and stage rendering**

```powershell
git add godot/scripts/norn_actor.gd godot/scripts/habitat_ui.gd godot/scripts/albia_world.gd godot/tools/verify_family_system.gd
git commit -m "Show Norn life stages and family archive"
```

---

### Task 6: Verify the full life cycle in a rendered recording and document it

**Files:**
- Modify: `godot/scripts/albia_world.gd` to keep the death notice visible after its automatic save.
- Modify: `godot/scripts/habitat_ui.gd` to name the status label for rendered verification.
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/tools/run_habitat_scenario.gd`
- Create: `godot/tools/inspect_recording.gd`
- Modify: `godot/README.md`
- Create: `docs/superpowers/ledgers/2026-10-29-godot-family-lifespan.md`

**Interfaces:**
- Keep the recorder's existing save-backup/restore behavior and AVI path reporting.
- The rendered preview uses 2× speed for the actual 45-second hatch, then sets a saved-age test fixture near a real stage threshold and near one founder's actual lifespan limit; the normal `_process` path must produce those transitions.
- The recorded AVI must be finalized by the recorder, decoded/inspected through its frames, and leave no more than 10 completed clips in `user://recordings/`.

- [x] **Step 1: Add the family and lifespan sequence to the rendered walkthrough**

Extend `record_preview.gd` to select the two founders, start an egg through the HUD, set 2× speed, and wait for the full 45 in-game-second incubation. After hatch, place the child fixture just before a stage boundary and wait for the ordinary world tick to advance it; place a founder just before its saved lifespan limit and wait for the ordinary world tick to produce old-age death. Assert focus fallback, archived lineage, clip finalization, and restoration of the prior local save on every success/failure exit.

- [x] **Step 2: Run the rendered preview and inspect its clip**

Run in rendered, non-headless mode:

```powershell
& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path godot --script res://tools/record_preview.gd
```

Inspect the AVI itself or extracted frames for the named parents, visible egg progress, child identity/age, death notification, and archived lineage. Confirm the recorder finalized a playable clip and at most 10 completed recordings remain; record the clip path in the ledger.

- [x] **Step 3: Run supporting checks**

Run `verify_family_system.gd`, `run_habitat_scenario.gd`, `verify_biochemistry.gd`, `verify_avi_writer.gd`, `verify_recording_retention.gd`, and a rendered scene-startup check. Expected: each emits its documented `*_OK` marker or exits successfully, with no regressions in existing social, chemistry, recording, or save behavior.

- [x] **Step 4: Update the README and execution ledger**

Document adult/elder pairing, the five life stages, approximate lifespan, old-age-only mortality, family archive/extinction behavior, version-5 saves, and the new verification commands in `godot/README.md`. In the ledger, list every command, its pass/fail marker, the captured AVI path, and inspected frames; do not claim any check that lacks fresh output.

- [x] **Step 5: Commit and push the verified feature**

After all checks and frame inspection pass, run:

```powershell
git add godot/scripts/norn_lifecycle.gd godot/scripts/norn_profile.gd godot/scripts/norn_egg.gd godot/scripts/norn_actor.gd godot/scripts/albia_world.gd godot/scripts/habitat_ui.gd godot/tools/verify_family_system.gd godot/tools/run_habitat_scenario.gd godot/tools/record_preview.gd godot/README.md docs/superpowers/specs/2026-10-29-godot-family-system-design.md docs/superpowers/plans/2026-10-29-godot-family-lifespan.md docs/superpowers/ledgers/2026-10-29-godot-family-lifespan.md
git commit -m "Add Godot Norn family and lifespan"
git push
```

Expected: the pushed commit contains the approved family/lifespan behavior, completed migration and verification records, and a rendered clip that has been inspected.
