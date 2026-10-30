# Norn Blender Rig and Animation Verification Ledger

- Date: 2026-10-29
- Project: `C:\Users\Quad\Documents\GitHub\creatures-albia-prototype`
- Godot: 4.7.2.stable.mono.official
- Blender: 5.2.2 LTS
- Plan: `docs/superpowers/plans/2026-10-29-norn-blender-rig-animation.md`
- Design: `docs/superpowers/specs/2026-10-29-norn-blender-rig-animation-design.md`

## Task 1: Structural asset check

- Added `godot/tools/verify_norn_animation.gd` and included it in `godot/tools/run_verification_suite.ps1`.
- RED: `Godot --headless --path .\godot --script res://tools/verify_norn_animation.gd -- res://assets/generated/norns/albia-norn/model.glb` failed as expected, reporting no `Skeleton3D` and no `AnimationPlayer` in the current static model.
- PowerShell parser check: `RUNNER_PARSE_OK`.
- The rigged candidate does not exist yet, so this check remains intentionally red until Task 2 exports it.

## Plan ruling

- Ruling: Add an exact `validation.json` output after local `game-dev asset validate` — the approved design requires validation metadata beside the exported candidate, and making the path explicit prevents omission — cost if wrong: one extra local report file to maintain.

## Task 2: Blender rig builder prepared

- Created `tools/art/build_norn_rig.py`; Blender syntax check: `BLENDER_SCRIPT_SYNTAX_OK`.
- Blender dry-run passed with the exact source and four output paths; source SHA-256 is `f3a1403c7f70f1d536d825d44378867d14d6145cf7191fa62702c803439ae6e8`; all output destinations were absent and the script reported `overwrites: []`.
- In-memory rig check passed against the source mesh: 7,539 weighted vertices, 25 bones, maximum four influences per vertex, and five non-empty Blender actions with Action Slots (`idle`, `walk`, `curious`, `praised`, `scolded`). No asset files were written.
- At this point in the run, Blender export was pending explicit approval of the exact source/output invocation required by the game-asset production workflow.

## Task 2: Local Blender rig export

- User approved the exact Blender invocation and all output paths.
- Export completed in Blender 5.2.2; output GLB contains one skin referencing `Mesh_0`, five exact animation names, one material, and three textures/images.
- `game-dev asset inspect`: 7,539 vertices, 10,532 triangles, UVs/normals/tangents present, base-color/metallic-roughness/normal textures present, five animations, and skin present; no warnings.
- `game-dev asset validate --json`: passed, 0 errors, 0 warnings, 11 checks; result saved as `godot/assets/generated/norns/albia-norn-rigged-candidate/validation.json`.
- Godot structural check: `NORN_RIG_CHECKS_OK` for all five clips.
- Godot editor import returned exit 0 but emitted `.NET Sdk not found (10.0.0)` from the C# editor plugin. The import phase completed; runtime impact remains to be checked.
- Blender emitted a material-node warning during export; the GLB inspector confirms all three expected PBR channels remain bound. Rendered review is still required.

## Task 3: Godot animation state integration

- RED: `verify_norn_animation.gd` failed before integration because `NornActor` mounted no `AnimationPlayer`.
- RED: fallback assertion failed before `_load_norn_model_scene` was added.
- GREEN: `NORN_RIG_CHECKS_OK`; actor selects idle/walk/curious, praise and scold play one-shot clips and return to curiosity, and a missing candidate resolves to the approved static GLB.
- Full suite: `GODOT_VERIFICATION_SUITE_OK count=13`; all 13 checks passed, including the habitat scenario.

## Task 4: Rendered review and documentation

- Ran the in-game recording feature in rendered, non-headless Godot on the AMD Radeon RX 6750 XT. The final post-review-fix capture is `user://recordings/habitat-20261029-202647.avi`, 1,227 frames at 1280×720. The earlier `201144` capture preceded the fallback hardening.
- `inspect_recording.gd` decoded all 1,227 JPEG frames and validated the final AVI index. Inspected the close-up samples (frames 0, 12, 24, 36, 47) and gameplay samples (frames 90, 150, 210, 270); the eye sockets and ears remain attached through frontal/three-quarter views and no obvious skin tearing appeared in the sampled poses. Targeted assertions cover the exact animation states and fallback path; the recording itself shows the rigged model during the interaction walkthrough.
- At review time, the sharp cheek silhouette was noted as part of the source sculpt; the rig has no facial morph targets. The rigged output was later admitted after the user reviewed and approved it; the original static package remains intact as fallback.
- The root recordings directory contained eight completed clips at final check, below the project limit of 10.
- Updated `godot/README.md` and `godot/ASSET_INVENTORY.md` to distinguish the admitted static model from the rigged runtime candidate, document its five clips, 25-bone weights, private license, provenance/validation, and current limitations.
- Independent review found that a loadable but invalid rig scene could bypass the static fallback. Replaced the scene-only loader with a validated instance path that requires a 25-bone skeleton and all five clips; invalid candidate instances are freed and the admitted static scene is instantiated. Added regressions for both a missing file and a loadable malformed scene; the targeted check passed after being red before the implementation.
- Tightened the Blender export validator to require exactly one skin referencing one node, exactly 25 joints, exactly the five expected animation names, all required mesh/skin vertex attributes, the source vertex attributes, unchanged material/texture/image counts, and matching PBR texture-channel bindings. The bundled Blender Python syntax check and direct validation of the existing candidate passed.
- Final full suite rerun after the fallback change: `GODOT_VERIFICATION_SUITE_OK count=13`, exit code 0. The post-fix rendered capture completed and all 1,227 frames decoded. Provider source SHA-256 still matches the approved value, and Git reports no changes to either the provider source GLB or admitted static fallback.
- The same independent reviewer rechecked the fallback and export-validation fixes and reported no remaining findings; assessment: ready.

## Task 5: Package admission and runtime promotion

- User approved building canonical package `pkg_9ce82befbb3a2ca19f1cf0af` from the reviewed rigged model (`SHA-256 299155fbe431c2e6191b3dbf40700de2c5ea2706b07e35785e88dd5324518b53`) and then approved the exact vendor-admission operation after its dry run reported no blockers.
- Package verification passed before and after admission. The admitted model and manifest hashes match the canonical package; the package records `LicenseRef-Meshy-Private`.
- Godot runtime and structural-check paths use `res://assets/generated/norns/albia-norn-rigged/model.glb`. The original admitted static model at `res://assets/generated/norns/albia-norn/model.glb` remains unchanged as fallback; the `-rigged-candidate` folder is retained as the source build and review output.
- Vendor lock and receipt record package ID, destination, hashes, and license. `game-dev package verify` passed on the admitted destination with hashes verified and 0 validation errors/warnings.
- Godot import completed for the new model; the known editor-plugin `.NET Sdk not found (10.0.0)` warning occurred during editor import, but the GLB import completed. The targeted animation check passed against the admitted path, and the full serial suite passed `GODOT_VERIFICATION_SUITE_OK count=13` with exit 0.
- Rendered, non-headless verification on the AMD Radeon RX 6750 XT completed as `user://recordings/habitat-20261029-203819.avi`: 1,226 frames at 1280×720. The inspector decoded all frames and validated the AVI index. Inspected frames 0, 245, 490, 613, 858, 1127, and 1225; frame 0 shows the face and ears attached in close-up, while gameplay frames show the rigged model across the habitat, family, and aging walkthrough. Recorder assertions covered action utility, social observation, baby-follow, child learning, adolescent independence, egg incubation/hatching, and old-age death/archive. The completed recordings folder contains nine clips, within the ten-clip limit.
- `git diff --check` passed (Git reported only the repository's existing LF-to-CRLF working-copy normalization notices). The admitted model hash matches the retained build candidate and vendor lock: `299155fbe431c2e6191b3dbf40700de2c5ea2706b07e35785e88dd5324518b53`. The original static model has no working-tree changes. The completed recordings folder contains nine clips.
