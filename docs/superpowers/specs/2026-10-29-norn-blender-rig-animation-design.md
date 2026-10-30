# Norn Blender Rig and Animation Design

**Status:** Draft for approval
**Date:** 2026-10-29

## Goal

Give the current Norn model a locally authored skeleton and a small set of reusable animations that Godot can select in response to movement and Norn actions. Blender is the authoring tool; Godot remains responsible for gameplay movement and animation-state selection.

## Current asset

The approved source is `assets/generated/meshy_output/review-candidates/norn/20261029_170840_norn-review-candidate-20261029_01a1897e/model.glb`. Its packaged, tangent-ready copy is `godot/assets/generated/norns/albia-norn/model.glb`. Inspection reports one mesh primitive, 7,539 vertices, 10,532 triangles, three 2K PBR textures, no skin, and no animations. The model has a seated foxlike pose. Blender 5.2.2 is installed locally. The asset package records `LicenseRef-Meshy-Private`; the new output must retain this project-use license and provenance.

## Chosen approach

Author a lightweight custom creature rig in Blender against the existing geometry. Keep both source GLBs unchanged. Do not use paid provider rigging or generate a replacement character. Export the work as a separate rigged candidate so it can be reviewed and tested before it replaces the runtime model.

The rig should have a stable root and torso chain, a head/neck chain, paired ear controls, deform bones for the visible limbs, and a short tail chain if the mesh geometry supports useful deformation. Bone names should be stable and readable for Godot. Skin weights should be inspected and corrected around the head, shoulders, hips, ears, and tail rather than relying on unattended automatic weights.

## Animation and runtime scope

Create a compact first set of clips suited to the existing seated silhouette: `idle`, `walk`, `curious`, `praised`, and `scolded`. `idle` should add restrained breathing and occasional head/ear/tail motion. `walk` should make the visible limbs and body read as moving while the existing `CharacterBody3D` continues to control world translation and turning. The response clips should be brief, distinct head/ear/body gestures. Do not add facial morph targets in this first pass because the current asset exposes only one mesh primitive and no authored facial controls.

Import the separate GLB candidate in Godot and drive the animation through the actor's existing action and movement state. If a deformation or gait does not survive import cleanly, adjust the rig or clip in Blender before enabling it in gameplay.

## Candidate outputs

- Editable Blender source: `assets/source_art/norn/albia-norn-rig.blend`
- Exported review candidate: `godot/assets/generated/norns/albia-norn-rigged-candidate/model.glb`
- Candidate provenance metadata: `godot/assets/generated/norns/albia-norn-rigged-candidate/provenance.json`
- Candidate validation report: `godot/assets/generated/norns/albia-norn-rigged-candidate/validation.json`

These paths are new and must not overwrite the approved source package. The candidate becomes the runtime asset only after the rig, clips, import, and in-game recording have been reviewed.

## Verification

1. Inspect the exported GLB and confirm it contains a skin, the expected clips, and the original PBR material data.
2. Import it in Godot and check each clip can be selected and played.
3. Run targeted actor checks for idle, movement, praise, and scold transitions.
4. Record a rendered, non-headless gameplay clip using the game's recorder, inspect the resulting video or extracted frames, and keep the recording folder within the 10-clip retention rule.

## Risks and limits

- The seated source pose limits how natural a full locomotion cycle can look. If the walk clip cannot read clearly without changing the silhouette, keep movement root-driven and narrow the first animation set to expressive reactions.
- Automatic skinning may distort the single connected mesh at the face, shoulders, or hips; refine weights and inspect deformations in Blender.
- The model has no independent eye, mouth, or facial morph controls, so first-pass expressions use head, ear, and body motion.
- The package is marked private-use. Preserve its attribution/provenance and do not represent the derivative as an unrestricted asset.

## Deferred

- Facial blend shapes, phoneme lip-sync, age-specific body meshes, broad animation libraries, replacement topology, paid Meshy/Tripo rigging, and committing or pushing changes.

## Approval boundary

This design authorizes no Blender export, package build, or Godot runtime asset replacement by itself. Before running the asset-writing command, present its exact source, destination, output workspace, and overwrite behavior and obtain approval for that invocation.
