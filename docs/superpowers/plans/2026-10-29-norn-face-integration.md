# Norn Face Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Norn's eyes and nose read as part of the head while keeping its current stylized silhouette and procedural low-poly construction.

**Architecture:** Keep the model in `NornActor._build_body()`. Calculate facial feature positions from the head ellipsoid's front surface, add shallow socket and upper-lid forms in the existing palette, and keep every new piece under `LifeStageVisuals`. Verify geometry with a small SceneTree script, then record a close-up that restores the ordinary habitat camera before the existing walkthrough continues.

**Tech Stack:** Godot 4.7.2 Mono, GDScript, SceneTree verifier, rendered Motion-JPEG AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-norn-face-integration-design.md`

## Global Constraints

- Preserve the head, ears, body proportions, body-color variation, age-stage scaling, collision, and actor behavior.
- Keep the procedural model in `godot/scripts/norn_actor.gd`; add no external asset, texture, dependency, skeleton, or animation system.
- Do not change cognition, life stages, movement, camera controls, save data, or browser visuals.
- `SphereMesh.radius` is `0.5`; the head's scale `(0.78, 0.72, 0.66)` gives radii `(0.39, 0.36, 0.33)`.
- Use the already selected native execution method in the current main checkout.
- For the model change, make a rendered recording and inspect its frames; keep at most 10 completed clips.

## Review Focus

- **Head scale versus ellipsoid surface:** derive the front surface from the actual `SphereMesh.radius * scale`; `test_face_features_follow_head_surface` must fail against current eye/nose positions and pass after the change.
- **Eye whites still visible after recessing:** keep each eye center within `0.08` local units of the front surface; `test_face_features_follow_head_surface` checks both sides.
- **Pupils look attached to their whites:** keep pupils forward of their whites by at most `0.07` and inside their horizontal bounds; `test_eye_pairs_are_symmetric_and_aligned` checks both eyes.
- **Nose or socket forms still project as separate beads:** keep the nose center within `0.10` local units of the head surface and require both socket and lid nodes; `test_face_features_follow_head_surface` covers these parts.
- **New parts detach under age scaling or body color:** verify all face parts live under `LifeStageVisuals` and retain the current stage scaling; `test_face_parts_follow_life_stage_visual_root` checks the hierarchy and child-stage scale, and `test_face_materials_follow_body_color` checks the socket tint with a distinct Norn color.

---

### Task 1: Surface-anchored procedural face

**Files:**
- Modify: `godot/scripts/norn_actor.gd`
- Create: `godot/tools/verify_face_geometry.gd`

**Interfaces:**
- Consumes: the current `NornActor._build_body()` and `SphereMesh` primitives.
- Produces: a procedural face with `LeftEyeSocket`, `RightEyeSocket`, `LeftEyelid`, and `RightEyelid` nodes; eye whites, pupils, and nose positioned from the head ellipsoid surface; and a headless geometry verifier.

- [x] **Step 1: Add failing geometry checks.** Create `verify_face_geometry.gd` with `test_face_features_follow_head_surface`, `test_eye_pairs_are_symmetric_and_aligned`, `test_face_parts_follow_life_stage_visual_root`, and `test_face_materials_follow_body_color`. Instantiate a `NornActor`, locate its `Head` and face meshes, compute the front surface from `Head.mesh.radius * Head.scale`, and assert the review-focus bounds, mirrored eye positions, expected socket/lid nodes, pupil-to-eye alignment, common visual-root parent, stage scaling, and body-derived socket tint.

- [x] **Step 2: Run the verifier to confirm the intended failures.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_face_geometry.gd`

Expected: `FACE_GEOMETRY_CHECKS_FAILED` for the missing socket/lid parts and the current eye/nose surface offsets; no parse errors.

- [x] **Step 3: Implement the surface anchor and integrated face.** In `norn_actor.gd`, define the head center/size once and add `_front_surface_point(x: float, y: float, outward_offset: float = 0.0) -> Vector3`. Compute front z using radii `SphereMesh.radius * head_size`, clamp the square-root input at zero, and treat a positive outward offset as toward negative z. Place both eye sockets and whites at the surface, pupils slightly forward and centered within the whites, upper lids just above the eyes and anchored to the surface, and the nose close to the surface. Keep all meshes under `_visual_root`; set socket contrast from `body_color.darkened(0.18)`.

- [x] **Step 4: Run the verifier and confirm every geometry assertion passes.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_face_geometry.gd`

Expected: `FACE_GEOMETRY_CHECKS_OK`.

### Task 2: Rendered face review and documentation

**Files:**
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/README.md`
- Create: `docs/superpowers/ledgers/2026-10-29-norn-face-integration.md`

**Interfaces:**
- Consumes: the named face meshes and existing `NornActor` / `AlbiaWorld` camera properties from Task 1.
- Produces: a brief face-forward Mallow close-up at the start of the rendered walkthrough, followed by the restored camera and unmodified habitat verification flow.

- [x] **Step 1: Add the close-up capture segment.** In `record_preview.gd`, save Mallow's rotation and physics state plus `_camera_target` and `_camera_offset`; set Mallow's yaw to `0` so its local negative-z face points toward a camera placed at negative z, center the view on the head at a close distance, and hold for 48 rendered frames. Assert the head is in front of the camera and projects into the clear center of the viewport, print `FACE_CLOSEUP_CAPTURE_OK`, then restore the saved actor and camera state before continuing the existing recording sequence.

- [x] **Step 2: Run the face verifier and record the full rendered walkthrough.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_face_geometry.gd`

Run without `--headless`: `Godot_v4.7.2-stable_mono_win64_console.exe --path .\godot --script res://tools/record_preview.gd`

Expected: `FACE_GEOMETRY_CHECKS_OK`, `FACE_CLOSEUP_CAPTURE_OK`, and `VIDEO_CAPTURE_OK`; all existing walkthrough markers still pass and the prior local save is restored.

- [x] **Step 3: Inspect the rendered clip.** Run `inspect_recording.gd` on the new AVI, validate the index and decode every frame, then visually inspect the face-forward frame and a normal habitat frame. Confirm the 10-clip retention limit.

Expected: `AVI_INSPECTION_OK` for all frames at 1280×720, with clearly attached eyes, visible pupils, an integrated nose, and a restored normal habitat view.

- [x] **Step 4: Update the README and verification ledger.** Record the face geometry approach, verifier output, AVI path and inspected frame numbers, completed-clip count, and unchanged save version 5.
