# Expanded Habitat Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Close the saved-position, guidance, exploration-reward, verification-suite, and recording-retention gaps found in the expanded-habitat review.

**Architecture:** Extend world-save version 7 to version 8 with validated live-Norn positions and per-Norn exploration-target IDs; migrate older saves with safe starter positions and empty discovery histories. Keep guidance until its target completes or becomes invalid. Bound echo-bloom and route-marker rewards once per Norn while leaving each landmark available to peers. Make the recorder enforce one recursive ten-clip cap across `user://recordings/`, then update verification scripts to current runtime behavior.

**Tech Stack:** Godot 4.7.2 Mono, GDScript, the existing script-based verification harness, and the in-game AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-godot-expanded-habitat-design.md`; recording retention: repository `AGENTS.md`.

## Global Constraints

- Keep the simulation local and deterministic.
- Preserve existing profile learning, chemistry, language, drawing, family, and save migrations.
- Validate restored Norn positions against `NornActor.WORLD_MIN_X`, `WORLD_MAX_X`, `WORLD_MIN_Z`, and `WORLD_MAX_Z`; legacy saves use existing spawn positions.
- Each exploration landmark rewards a Norn once; each Norn's discovery history persists through loading, while peers can still explore the shared landmark.
- Keep at most 10 completed AVI clips recursively under `user://recordings/`; never remove an active recording.
- Gameplay/rendering changes require a rendered, non-headless recording and inspection; headless checks supplement it.
- Work in the current main checkout; do not commit or push without a new request.

## Review Focus

- Version-8 saves with malformed, out-of-bounds, missing, or valid live-Norn positions must reject or restore safely.
- Version-1 through version-7 saves must migrate without losing previous learning and use their normal spawn positions.
- Guidance must survive a long trip, clear when fulfilled or invalid, and be replaced by a newer command.
- A Norn's completed landmark must not reward that Norn again before or after save/load, and must remain available to other Norns.
- Nested clip folders and an active AVI must be handled without exceeding the cap or deleting the active file.

---

### Task 1: Version-8 world save state

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Test: `godot/tools/verify_family_system.gd`, `godot/tools/verify_social_slice.gd`

**Interfaces:** Version-8 records add `position: [x, y, z]` and `exploredLandmarks: [String]` to each Norn profile. Restore candidates expose each profile `position` as `Vector3` (legacy records as `null`) and a validated string array of that profile's discoveries.

- [x] Add failing save/restore checks for position round-trip, invalid positions, consumed landmark round-trip, and version-7 migration defaults.
- [x] Run the focused Godot checks and confirm they fail on the missing version-8 behavior.
- [x] Add version 8 serialization, validation, restore, and migration while preserving version-1 through version-7 readers.
- [x] Run the focused checks and confirm valid round-trips pass, malformed records reject, and old fixtures retain their previous learning.

### Task 2: Persistent, per-Norn exploration novelty

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Test: `godot/tools/verify_social_slice.gd`, `godot/tools/run_habitat_scenario.gd`

**Interfaces:** Each `NornProfile` tracks `explored_landmarks: Dictionary`; successful exploration records the target once for that profile and does not globally consume the shared landmark or schedule it for respawn.

- [x] Add failing checks that one Norn cannot repeat a landmark reward, another Norn can explore that same landmark, and both discovery histories survive loading.
- [x] Run the focused checks and confirm shared availability and per-Norn persistence fail them.
- [x] Apply per-profile discovery state and keep shared landmarks available to other Norns.
- [x] Run focused tests and the habitat scenario, checking one-time-per-Norn discovery and save/load behavior.

**Ruling:** The initial draft used one global consumed-marker set. The habitat scenario showed this lets Moss consume the only nearby transition cue before Mallow can use it, stranding Mallow in Sunmeadow. Per-Norn novelty keeps rewards bounded and preserves access for peers; the tradeoff is that the same landmark can create one outcome per living Norn.

### Task 3: Long-distance guidance

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Test: `godot/tools/run_habitat_scenario.gd`, `godot/tools/verify_social_slice.gd`

- [x] Add a failing one-command cross-region guidance check and checks for replacement and invalid-target clearing.
- [x] Run the focused check and confirm seven-second expiry causes the expected failure.
- [x] Remove the fixed timeout; clear guidance only after completion or when the target becomes invalid/unavailable.
- [x] Run the habitat scenario at normal simulation speed and confirm one command reaches the distant target.

### Task 4: Global recording retention

**Files:**
- Modify: `godot/scripts/local_video_recorder.gd`, `godot/tools/record_expanded_habitat_preview.gd`
- Test: `godot/tools/verify_recording_retention.gd`

- [x] Add failing nested-directory and active-recording retention cases.
- [x] Run the retention verification and confirm nested clips currently evade pruning.
- [x] Recursively prune the oldest completed AVI clips under the shared recordings root after finalization; remove the per-subfolder refusal.
- [x] Run the retention verification and confirm no more than 10 completed clips remain and the active clip is preserved.

### Task 5: Verification suite and rendered walkthrough

**Files:**
- Modify stale assertions in `godot/tools/verify_*.gd`, `godot/tools/record_*.gd`, and `godot/README.md` where they still assert old save versions, chemistry shapes, action sets, or procedural face nodes.
- Test: all applicable `godot/tools/verify_*.gd` checks and `godot/tools/run_habitat_scenario.gd`.

- [x] Correct current-runtime expectations and ensure any GDScript runtime error makes the verification process exit nonzero.
- [x] Run each verification script and the habitat scenario; record exact pass/fail results.
- [x] Run the expanded-habitat walkthrough in rendered Godot, inspect representative frames, and report the path and verified behavior.
- [x] Verify the shared recursive clip count is at most 10 and the final git diff contains only the intended stabilization changes.
