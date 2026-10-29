# Norn face integration verification ledger

- Date: 2026-10-29
- Project: `C:\Users\Quad\Documents\GitHub\creatures-albia-prototype`
- Plan: `docs/superpowers/plans/2026-10-29-norn-face-integration.md`
- Design: `docs/superpowers/specs/2026-10-29-norn-face-integration-design.md`

## Face changes

- The head uses a `SphereMesh` radius of `0.5` and scale `(0.78, 0.72, 0.66)`, giving actual radii `(0.39, 0.36, 0.33)`.
- `_front_surface_point()` now calculates the negative-z surface from the head ellipsoid. Eye whites and sockets, pupils, lids, and nose use this anchor rather than independent forward offsets.
- Added body-color-derived shallow eye sockets and upper lids. All face meshes remain beneath `LifeStageVisuals`, so stage scaling applies to the complete model.
- Save version and actor behavior did not change.

## Geometry test

- RED: before production changes, `verify_face_geometry.gd` exited 1 with `FACE_GEOMETRY_CHECKS_FAILED`. The existing eye centers were `0.331` local units in front of the head surface, the nose was `0.354` units forward, socket/lid nodes were missing, and pupil placement was not mirrored. No parse errors occurred.
- GREEN: `Godot_v4.7.2-stable_mono_win64_console.exe --headless --path .\godot --script res://tools/verify_face_geometry.gd` → `FACE_GEOMETRY_CHECKS_OK` (exit 0).

## Rendered verification

- `record_preview.gd` exited 0 with `FACE_CLOSEUP_CAPTURE_OK`, all existing teaching, behavior, family, and lifespan markers, and `VIDEO_CAPTURE_OK`.
- The camera framed Mallow's head at viewport `(640.0, 367.7)`, then restored the actor rotation and normal habitat camera before the existing walkthrough.
- Clip: `user://recordings/habitat-20261029-112804.avi` (`C:\Users\Quad\AppData\Roaming\Godot\app_userdata\New Albia — Godot 3D Slice\recordings\habitat-20261029-112804.avi`).
- `inspect_recording.gd` → `AVI_INSPECTION_OK`; 980 of 980 JPEG frames decoded at 1280×720 and every AVI index entry validated.
- Visually inspected frame `0000` for the face-forward close-up, frame `0196` for the restored habitat view, and frame `0979` for the family archive/death notice.
- The prior local save was restored and remains version 5 with Mallow focused and the same three saved profiles. The recordings folder contained 10 completed clips after capture.

## Ear attachment pass — 2026-10-29

- Outer ears moved from `(±0.57, 2.18, 0.02)` / `(0.27, 0.56, 0.25)` to `(±0.42, 2.13, 0.02)` / `(0.38, 0.66, 0.25)`. Their upper tip remains at `y = 2.46`; a root point on both sides is within the head and outer-ear ellipsoids.
- Inner cream pads moved from `(±0.57, 2.19, -0.19)` to `(±0.42, 2.19, -0.10)` and overlap the outer-ear volume while remaining visibly inset.
- The verifier now checks each ear-root overlap with the head, inner-pad overlap, bilateral mirror alignment, preserved tip height, and life-stage visual-root parenting.
- RED: before changing the ear meshes, `verify_face_geometry.gd` exited 1 with the expected left/right root-overlap and inner-pad overlap failures. The head-volume, mirror, and existing tip-height checks passed; there were no parse errors.
- GREEN: `Godot_v4.7.2-stable_mono_win64_console.exe --headless --path .\godot --script res://tools/verify_face_geometry.gd` → `FACE_GEOMETRY_CHECKS_OK` (exit 0).
- The recorder now holds 24 rendered frames at the frontal angle, then 24 at yaw `0.32`, checks both ear centers against the clear viewport bounds, restores Mallow's rotation and physics state, restores the camera fields, and emits `EAR_ATTACHMENT_CAPTURE_OK` after restoration.
- Rendered run: `VIDEO_CAPTURE_OK frames=980` at `user://recordings/habitat-20261029-114254.avi`. `inspect_recording.gd` → `AVI_INSPECTION_OK frames=980 decoded=980 dimensions=1280x720 sampled=16`; all AVI index entries validated.
- The recorder captures at 15 FPS while the verification script advances at the render rate. I first inspected frames 24 and 47, which are already in the walkthrough; after tracing the capture cadence, I extracted and inspected frames 0 through 12. Frame 0000 shows the frontal connection, frame 0011 shows the three-quarter connection, and frame 0196 shows the restored normal habitat view. This was a sampling-timing investigation; no code change was needed.
- The regression checks all exited 0: `FACE_GEOMETRY_CHECKS_OK`, `SOCIAL_SLICE_CHECKS_OK`, `FAMILY_SYSTEM_CHECKS_OK`, `HABITAT_SCENARIO_OK`, and `BIOCHEMISTRY_CHECKS_OK`.
- After capture, the recordings folder contained 10 completed clips. The local save remained version 5.

## Final review

- Self-review covered the surface-anchor calculation, face mesh placement, close-up capture state restoration, geometry verifier, and rendered samples. No subagents were requested or used.
- `git diff --check` exited 0; output contained only Git's configured LF-to-CRLF notices.
- The review-package helper could not create a package because the supplied base and current HEAD were both `6ff78fd`; the implementation remains uncommitted in the user-approved main checkout. The verifier, full rendered capture, decoded AVI, visual frame inspection, direct source review, and diff check are the review evidence.
- The close-up confirms that eyes and nose now read as part of the head. The outer ear pads still appear separated; their geometry was explicitly preserved by the approved scope, so this is a minor follow-up rather than a blocker for eye integration.
