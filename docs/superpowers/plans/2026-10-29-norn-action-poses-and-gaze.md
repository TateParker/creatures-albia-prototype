# Norn Action Poses and Gaze Implementation Plan

**Goal:** Give existing Norns short readable interaction gestures and target-directed head gaze without changing action decisions or the admitted model package.

**Architecture:** Add a custom additive `SkeletonModifier3D` for time-limited upper-body poses and a bounded `LookAtModifier3D` for gaze, both under the rigged skeleton and after its `AnimationPlayer`. Keep a scene-local gaze target on `NornActor`; start gestures when `AlbiaWorld` reports an interaction completion. Preserve fallback behavior if the rig or named bones are absent.

**Tech Stack:** Godot 4.7.2-stable Mono, GDScript, `SkeletonModifier3D`, `LookAtModifier3D`, and the existing rendered AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-norn-action-poses-and-gaze-design.md`

## Global constraints

- Keep `CharacterBody3D`, cognition, interaction timing, and biochemistry unchanged.
- Do not modify the admitted rigged GLB, the Blender source, package manifests, vendor lock, license, or static fallback.
- Use only existing named skeleton bones. Keep gestures local and deterministic.
- Record and inspect rendered gameplay video; retain no more than 10 completed clips.
- Preserve pre-existing working-tree changes. No commit is part of this task.

## Review Focus

- A missing or renamed head/arm bone must leave the rigged/static/procedural fallback usable without modifier errors; test with a malformed candidate.
- A stale or freed gaze target must return to neutral instead of generating a node-path error; test target clearing and invalidation.
- A Norn observing a peer must keep looking at that peer after it stops moving; assert peer gaze target persistence at the observation stop distance.
- Praise/Scold must override an interaction gesture without losing the authored response clip or leaving pose influence active; assert supersession and fade.
- Runtime gesture modifiers must not change root movement, foot IK, interaction outcomes, biochemistry, or action choice; retain locomotion/foot regression checks and assert outcome data is identical.

## Task 1: Add failing rig and interaction-visual assertions

**Files:** Modify `godot/tools/verify_norn_animation.gd`.

- [x] **Step 1: Add gaze, target persistence, action-pose, response-priority, and fallback assertions** in `verify_norn_animation.gd`.
- [x] **Step 2: Run the targeted rig check before implementation** and require feature-missing assertions with no parse/setup errors. Observed RED: exactly five feature-missing assertions, exit code 1.

## Task 2: Add runtime gaze and additive action poses

**Files:** Create `godot/scripts/norn_action_pose_modifier.gd`; modify `godot/scripts/norn_actor.gd` and `godot/scripts/albia_world.gd`.

- [x] **Step 1: Implement the additive action-pose modifier** with bounded time-based rotations for fruit/eat, forage, drink, and spinner/play, fading its influence to zero.
- [x] **Step 2: Add actor-local gaze tracking** with a bounded, eased `LookAtModifier3D` on the head; preserve a peer look target at observation distance and return to neutral when focus clears.
- [x] **Step 3: Add `play_interaction_animation(action_id, target_position)`** that maps fruit to eat and spinner to play, stores the completed item's position, and resets cleanly on Praise/Scold.
- [x] **Step 4: Call the method from `AlbiaWorld._on_action_completed`** before applying the outcome; keep Praise/Scold one-shots higher priority.
- [x] **Step 5: Run the targeted rig assertions to green** and re-run foot planting assertions to catch modifier-order regressions.

## Task 3: Verify rendered behavior and document it

**Files:** Modify `godot/tools/record_preview.gd`, `godot/README.md`, and `godot/ASSET_INVENTORY.md`; create a verification ledger.

- [x] **Step 1: Extend the deterministic rendered walkthrough** to show fruit, forage, drink, spinner, and peer attention; require an explicit gesture/gaze success marker.
- [x] **Step 2: Run all 13 Godot verification checks** and require the suite success marker and exit code 0.
- [x] **Step 3: Record non-headless gameplay, decode every AVI frame, and inspect samples** for readable poses, target attention, smooth transitions, and no mesh tearing or conflict with Praise/Scold and foot planting.
- [x] **Step 4: Confirm no more than 10 completed clips remain** and update README, asset inventory, and verification ledger with the clip path and findings.
- [x] **Step 5: Run `git diff --check` and review the feature diff**, confirming the approved GLB, static fallback, vendor lock, and unrelated working-tree changes remain untouched.
