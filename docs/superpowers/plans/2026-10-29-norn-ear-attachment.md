# Norn Ear Attachment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make both Norn ear roots visibly connect to the head while retaining the current procedural style and ear-tip height.

**Architecture:** Keep the ear geometry in `NornActor._build_body()`. Move and resize the existing outer ellipsoids so a defined root point lies inside both each ear and the head, then reposition the cream inner pads so they overlap the outer-ear surface. Extend the geometry verifier and use two rendered close-up angles plus the restored habitat view for visual review.

**Tech Stack:** Godot 4.7.2 Mono, GDScript, SceneTree verifier, rendered Motion-JPEG AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-norn-ear-attachment-design.md`

## Global Constraints

- Keep the model procedural in `godot/scripts/norn_actor.gd`.
- Do not add external assets, textures, dependencies, skeletons, or new animation systems.
- Do not change the eyes, nose, body, collision, cognition, life stages, movement, save format, or browser prototype.
- Keep at most 10 completed gameplay clips in the Godot `user://recordings/` folder.
- Run rendered in-game recording and inspect its frames; headless checks supplement the recording.
- Use the user's approved native execution method in the current main checkout.

## Review Focus

- **Root overlap on both sides:** use `test_ear_roots_overlap_head` to check a point inside the head ellipsoid and both outer ear ellipsoids.
- **Inner-pad attachment:** use `test_inner_ear_pads_overlap_outer_ears` to check an overlap point on each side.
- **Bilateral alignment and preserved tip height:** use `test_ear_pairs_are_mirrored` to compare left/right positions and scales, and `test_ear_tip_height_preserved` to keep both tips at `y = 2.46`.
- **Life-stage scaling:** include all outer and inner ear meshes in `test_face_parts_follow_life_stage_visual_root`.
- **Rendered restoration:** require the recorder to show front and three-quarter views, restore actor/camera state, and pass the existing AVI inspection and clip-retention checks.

---

### Task 1: Tuck outer ear roots into the head

**Files:**
- Modify: `godot/tools/verify_face_geometry.gd`
- Modify: `godot/scripts/norn_actor.gd`

**Interfaces:**
- Consumes: the existing `Head`, `LeftEar`, `RightEar`, `LeftEarInner`, `RightEarInner` meshes and the `LifeStageVisuals` root.
- Produces: geometry checks for root and inner-pad overlap, symmetry, and shared stage scaling; updated ear mesh transforms.

- [x] **Step 1: Add failing ear geometry checks.** Add `_ellipsoid_contains(mesh: MeshInstance3D, point: Vector3) -> bool` using `SphereMesh.radius * mesh.scale` and `LifeStageVisuals`-local coordinates. Add `test_ear_roots_overlap_head` asserting that `(±0.31, 1.90, 0.02)` is inside the matching outer ear and `Head`; add `test_inner_ear_pads_overlap_outer_ears` asserting `(±0.42, 2.19, -0.08)` is inside each inner and outer ear; add `test_ear_pairs_are_mirrored` for positions and scales; and add `test_ear_tip_height_preserved` for both tips at `y = 2.46`. Include the four ear meshes in the existing visual-root parenting and child-scale checks.

- [x] **Step 2: Run the verifier and confirm the intended failures.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_face_geometry.gd`

Expected: `FACE_GEOMETRY_CHECKS_FAILED` for ear-root and inner-pad overlap, with no parse errors.

- [x] **Step 3: Adjust the existing ear transforms.** Set outer-ear positions to `(±0.42, 2.13, 0.02)` and scales to `(0.38, 0.66, 0.25)`. This keeps the upper tip at `y = 2.46` and encloses the specified root-overlap point. Set inner-pad positions to `(±0.42, 2.19, -0.10)` and retain their current scales `(0.15, 0.36, 0.08)` so the cream pads sit partially within the outer ears. Keep all four meshes under `_visual_root` and preserve their existing materials.

- [x] **Step 4: Run the verifier and confirm all geometry checks pass.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_face_geometry.gd`

Expected: `FACE_GEOMETRY_CHECKS_OK`.

### Task 2: Rendered ear review and documentation

**Files:**
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/README.md`
- Modify: `docs/superpowers/ledgers/2026-10-29-norn-face-integration.md`

**Interfaces:**
- Consumes: the ear geometry from Task 1 and the existing face-close-up camera/actor restoration flow.
- Produces: a rendered ear review that shows frontal and three-quarter views, followed by the existing walkthrough with its original camera and actor state restored.

- [x] **Step 1: Capture two close-up angles.** Update `_run_face_closeup_demo()` to hold the current frontal view for 24 rendered frames, rotate Mallow by `0.32` radians for a three-quarter ear-root view for 24 frames, and check that each root is in front of the camera and projects into the clear viewport bounds `x=400..880`, `y=100..620`. Then restore her original rotation, physics-processing state, and camera fields. Print `EAR_ATTACHMENT_CAPTURE_OK` only after both views and restoration pass.

- [x] **Step 2: Record the rendered walkthrough.** Run without `--headless`:

`Godot_v4.7.2-stable_mono_win64_console.exe --path .\godot --script res://tools/record_preview.gd`

Expected: `EAR_ATTACHMENT_CAPTURE_OK`, all existing walkthrough markers, and `VIDEO_CAPTURE_OK`; the prior local save is restored.

- [x] **Step 3: Inspect the AVI and verify retention.** Run `inspect_recording.gd` against the new AVI, validate the index and decode every frame, then visually inspect the frontal close-up, three-quarter close-up, and restored habitat view. Confirm no more than 10 completed clips remain.

- [x] **Step 4: Update documentation.** Record the ear transform and geometry checks in the existing face ledger and README, including the AVI path, inspected frames, clip count, and unchanged save version.
