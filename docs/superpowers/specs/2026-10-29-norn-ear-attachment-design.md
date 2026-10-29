# Norn ear attachment design

**Status:** Approved by the user on 2026-10-29. The user selected the focused ear-root integration approach.

## Intent

Attach the existing outer ear pads to the Norn head so the roots do not look like separate floating parts. Keep the current procedural low-poly style and recognizable ear tips.

## Current state

`godot/scripts/norn_actor.gd::_build_body()` creates the head as a `SphereMesh` centered at `(0.0, 1.7, -0.02)`, with scale `(0.78, 0.72, 0.66)` and actual radii `(0.39, 0.36, 0.33)`. The outer ears are separate ellipsoids centered at `x = ±0.57`, `y = 2.18`; their lower roots barely meet the head. Their cream inner pads are also separate ellipsoids. The prior face pass anchored the eyes and nose to the head surface but preserved the ear geometry.

## Approaches

1. **Tuck the existing ear roots into the head — selected.** Adjust the existing outer ear ellipsoids so their lower roots overlap the head while keeping their upper tips near their current height. Reposition the inner pads to stay centered and inset within the outer ears. This directly fixes the visible gap and keeps the existing mesh-only model.
2. **Add a separate tapered connector.** Keep the ear ellipsoids in place and add a third mesh at each root. This gives more control over a gradual transition but adds pieces and can look like another attached patch.
3. **Reshape the head and ears together.** Change both forms to create a broader sculpted connection. This offers more organic contours but changes more of the established silhouette than the user requested.

## Goals

- Make each outer ear root visibly intersect the head from front and three-quarter views.
- Keep the ears mirrored, with cream inner pads nested within the outer pads.
- Preserve the current high ear tips and overall Norn identity.
- Keep all ear parts beneath `LifeStageVisuals`, preserve body-derived outer-ear color, and leave the cream inner-ear color intact.
- Verify the connection in a rendered close-up and normal habitat view.

## Non-goals and constraints

- Do not add external assets, textures, dependencies, skeletons, or new animation systems.
- Do not change the eyes, nose, body, collision, cognition, life stages, movement, save format, or browser prototype.
- Keep the model procedural in `godot/scripts/norn_actor.gd`.
- Run rendered in-game recording and inspect its frames; retain at most 10 completed clips.

## Implementation calls

- Adjust the existing outer ear position and proportions to create a measurable shared volume with the side of the head, using the actual `SphereMesh.radius * scale` dimensions.
- Move the cream inner pads with the outer pads and preserve their inset relationship.
- Add geometry checks for bilateral symmetry, stage-root parenting, and an overlap point contained by both the head and each ear root.
- Use the existing recorder's face close-up and inspect an angle that shows the roots, plus a restored normal habitat view.

## Approval scope

This is a focused geometry change only. The broader emergent-behavior ideas remain the next workstream, after the ear pass, and will be planned in sequence as the user requested.
