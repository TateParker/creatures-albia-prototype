# Norn face integration design

## Intent

Keep the current stylized Norn silhouette while making the eyes and nose read as part of the head instead of separate pieces sitting in front of it. The user selected the focused face-integration approach because the detached-looking eyes are the clearest visual issue.

## Current state

`godot/scripts/norn_actor.gd::_build_body()` creates the Norn from low-poly ellipsoids. The head is centered at `(0, 1.7, -0.02)` and uses a `SphereMesh` with base radius `0.5` scaled by `(0.78, 0.72, 0.66)`, so its actual radii are `(0.39, 0.36, 0.33)`. Eye whites, pupils, and nose are additional spheres at fixed coordinates; there are no eye sockets or eyelid forms to visually join them to the head. At the current eye positions, the head's front surface is around `z = -0.25`, while eye centers sit at `z = -0.58`, roughly `0.33` units forward of the head.

## Approaches

1. **Integrate the current face — selected.** Anchor the eye features to the head ellipsoid, recess the whites, place pupils just forward enough to remain readable, add shallow socket/lid forms using the existing material palette, and tuck the nose closer to the face. This addresses the floating appearance while preserving the recognizable silhouette and procedural low-poly workflow.
2. **Broader primitive sculpt.** Reshape the head and add cheeks, muzzle, and stronger brow forms. This could create more expression but changes the Norn's identity and expands the review scope beyond the reported issue.
3. **Authored mesh replacement.** Replace the face or head with a Blender-authored mesh. This offers more organic shapes but adds asset, rigging, and maintenance work to a primitive-only slice.

## Goals

- Make the eye whites visibly intersect the head's surface, with pupils aligned to each eye rather than projecting forward as separate beads.
- Add enough socket and eyelid contour to visually anchor the eyes without hiding them or making the face look stern.
- Bring the nose into the same facial plane while retaining its existing dark color and small shape.
- Preserve the head, ears, body proportions, body-color variation, age-stage scaling, collision, and actor behavior.
- Review the result in a rendered close-up and the normal habitat camera.

## Non-goals and constraints

- Do not add external assets, textures, dependencies, skeletons, or new animation systems.
- Do not change cognition, life stages, movement, camera controls, save data, or browser-prototype visuals.
- Keep the geometry procedural and local to `norn_actor.gd` so generated child colors and life-stage visuals continue to work.

## Implementation calls

- Derive local feature depth from the head ellipsoid instead of relying on independent hard-coded front offsets.
- Use shallow ellipsoid primitives for sockets and lids, with restrained contrast from the existing warm-brown and cream materials.
- Capture a close-up of an adult Norn in the in-game recording and inspect it alongside the normal habitat view before accepting the face pass.
