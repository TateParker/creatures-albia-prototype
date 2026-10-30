# Norn Blender Rig and Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rig the existing Norn locally in Blender, export a separate animated GLB candidate, and connect its clips to Godot action and movement state.

**Architecture:** A reproducible Blender Python script imports the immutable provider model, authors a custom deform rig and five clips, then writes an editable `.blend` and GLB candidate to new paths. Godot loads the candidate when present, falls back to the admitted static model, and selects clips through the existing `NornActor` action/movement state.

**Tech Stack:** Blender 5.2.2 Python API, glTF 2.0 export, Godot 4 GDScript, existing local `game-dev` CLI asset inspection, in-game video recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-norn-blender-rig-animation-design.md`

## Global Constraints

- Keep the provider model at `assets/generated/meshy_output/review-candidates/norn/20261029_170840_norn-review-candidate-20261029_01a1897e/model.glb` unchanged.
- Keep the admitted static package at `godot/assets/generated/norns/albia-norn/model.glb` unchanged as a fallback.
- Write the Blender source to `assets/source_art/norn/albia-norn-rig.blend` and the candidate GLB to `godot/assets/generated/norns/albia-norn-rigged-candidate/model.glb`.
- Keep the source license `LicenseRef-Meshy-Private` and record the source hash, Blender version, rig/animation details, and transformations.
- Write the local `game-dev asset validate --json` result to `godot/assets/generated/norns/albia-norn-rigged-candidate/validation.json` after export.
- Use local Blender only; do not call a paid provider or install dependencies.
- Do not run the asset-writing Blender invocation until its exact source, destination, output workspace, and overwrite behavior have been presented and explicitly approved.
- Retain the static GLB fallback and do not switch runtime to the candidate until the candidate passes structural and rendered review.
- For Godot gameplay/rendering changes, record and inspect a rendered, non-headless gameplay clip; retain no more than 10 completed recordings.
- Do not commit or push as part of this plan.

## Review Focus

- **Deformation around ears and eye area:** verify head/ear motions do not pull the face apart; the asset has no facial morph targets.
- **Shoulder, hip, and tail weights:** inspect endpoint and mid-range poses in Blender and Godot; no vertex should detach or spike visibly.
- **Animation names on GLB import:** assert exact names `idle`, `walk`, `curious`, `praised`, and `scolded` after Godot imports the candidate.
- **Action-state changes while stationary or moving:** test idle-to-walk, walk-to-idle, praise, and scold transitions and confirm they return to the correct loop.
- **Candidate missing or rejected:** confirm Godot continues to load the existing static package without errors when the candidate is unavailable.

---

### Task 1: Add asset and actor verification coverage

**Files:**
- Create: `godot/tools/verify_norn_animation.gd`
- Modify: `godot/tools/run_verification_suite.ps1`

**Interfaces:**
- Consumes: `NornActor`, the admitted static GLB, and (after Task 2) the rigged candidate path.
- Produces: A targeted Godot check that confirms required skeleton and clip content and is included in the existing verification suite.

- [x] **Step 1: Write the failing structural check** that loads the rigged candidate and asserts a `Skeleton3D` plus exact clips `idle`, `walk`, `curious`, `praised`, and `scolded` exist. Include a failure message naming missing content.
- [x] **Step 2: Run it against the current static source** and confirm the expected failure reports no skin/animation content.
- [x] **Step 3: Add the check to the Godot verification suite** without changing existing test order or behavior.
- [x] **Step 4: Parse and run the targeted check**; it should still fail only on the not-yet-generated candidate.

### Task 2: Author the Blender rig and clips

**Files:**
- Create: `tools/art/build_norn_rig.py`
- Create by Blender: `assets/source_art/norn/albia-norn-rig.blend`
- Create by Blender: `godot/assets/generated/norns/albia-norn-rigged-candidate/model.glb`
- Create: `godot/assets/generated/norns/albia-norn-rigged-candidate/provenance.json`
- Create after validation: `godot/assets/generated/norns/albia-norn-rigged-candidate/validation.json`

**Interfaces:**
- Consumes: The provider GLB in Global Constraints and the exact output paths above.
- Produces: A skinned GLB with a named `Skeleton3D` and five clips: `idle`, `walk`, `curious`, `praised`, and `scolded`.

- [x] **Step 1: Write the Blender script** to import the source GLB, preserve its mesh/materials/texture bindings, add the custom root/torso/head/limb/ear/tail deform rig, create and refine vertex groups, and author the five named actions.
- [x] **Step 2: Add script guards** that fail if the source is absent, if either destination already exists, or if required meshes/materials are not found; never overwrite an existing source or candidate.
- [x] **Step 3: Present the exact Blender invocation** with source, output paths, output workspace, and collision behavior; wait for explicit authorization before running it.
- [x] **Step 4: Run the approved invocation** to save the `.blend`, export the separate GLB, and write provenance with SHA-256 source hash, license, Blender version, clip list, and transformation summary.
- [x] **Step 5: Inspect and validate the GLB locally** with `game-dev asset inspect` and `game-dev asset validate model.glb --json`; confirm it has a skin and five clips while retaining UVs, normals, tangents, and the PBR material/texture bindings, then save the validation result to `validation.json`.
- [x] **Step 6: Run the structural Godot check** from Task 1 and fix export/import issues before gameplay integration.

### Task 3: Drive the clips from NornActor

**Files:**
- Modify: `godot/scripts/norn_actor.gd`
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_norn_animation.gd`

**Interfaces:**
- Consumes: Candidate GLB and verified animation names from Task 2; existing `current_action` and `is_walking` state.
- Produces: A model `AnimationPlayer` reference, internal loop selection, and `NornActor.play_response_animation(feedback: String) -> void` for one-shot feedback clips without affecting root locomotion, collision, drawing effector, or fallback geometry.

- [x] **Step 1: Add/extend the actor verification** so stationary actors expect `idle`, moving actors expect `walk`, and `observe_peer`/`explore` expect `curious`; verify feedback responses play `praised`/`scolded` once and then resume the current loop.
- [x] **Step 2: Run the actor check** and confirm it fails because `NornActor` does not yet bind imported animation playback.
- [x] **Step 3: Load the rigged candidate when it exists**, keep the current admitted static model as a fallback, and recursively locate the imported `AnimationPlayer`.
- [x] **Step 4: Add an animation selection method** that maps movement and curiosity to exact loop clip names, avoids restarting the current loop every frame, and falls back to `idle` if a clip is absent.
- [x] **Step 5: Add `play_response_animation(feedback: String) -> void`** to play `praised` or `scolded` once; on completion resume the loop chosen from the actor's current movement/action state.
- [x] **Step 6: Call `play_response_animation` from `AlbiaWorld.give_feedback` only after valid praise/scold feedback is applied.** Keep biochemistry and language-learning calculations unchanged.
- [x] **Step 7: Call loop selection from the actor update path** even when the drawing effector is absent; leave CharacterBody3D movement and collision unchanged.
- [x] **Step 8: Run the targeted actor check and the full verification suite** and confirm both pass.

### Task 4: Review the in-game result and document the candidate

**Files:**
- Modify: `godot/README.md`
- Modify: `godot/ASSET_INVENTORY.md`
- Create by recorder: one rendered Norn animation review clip in `user://recordings/`.

**Interfaces:**
- Consumes: Candidate GLB, Godot state mapping, and test results from Tasks 2–3.
- Produces: A reviewed in-game candidate with a video artifact and accurate source/license/animation notes.

- [x] **Step 1: Run the game in rendered, non-headless mode** and trigger idle, walking, curiosity, praise, and scold so each authored clip is visibly exercised.
- [x] **Step 2: Record the representative run** using the built-in video recorder; inspect the resulting video or extracted frames for mesh deformation, animation selection, clipping, and fallback behavior. The gameplay video and close-up frames were visually reviewed; the targeted actor assertions verified exact clip selection and static fallback behavior.
- [x] **Step 3: Keep the recordings folder at 10 or fewer completed clips** using its timestamp order after recording is finished.
- [x] **Step 4: Update the README and asset inventory** with the rigged candidate location, Blender-authored clip list, private-use license, and any known limitations.
- [x] **Step 5: Re-run the verification suite and inspect final Git status** to confirm the old source package is unchanged and no unrelated user work was overwritten.

### Task 5: Promote the reviewed rig to an admitted runtime package

After the user approved the rendered rig, the candidate was built into canonical package `albia_norn_rigged`, verified, and admitted to `godot/assets/generated/norns/albia-norn-rigged/` after explicit approval of the dry run and exact admission command. The original static package remains unchanged as fallback. Runtime and structural-check paths use the admitted package; the `-rigged-candidate` directory remains the reproducible export and review source.
