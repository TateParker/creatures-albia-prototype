# Norn Action Poses and Gaze Design

## Intent

Make the 3D Norns' chosen interactions and attention visible through small, readable body gestures and soft head gaze. These are visual responses to decisions the simulation already made; they must not choose or reward behavior.

## Approaches

1. **Runtime skeleton modifiers (selected):** use Godot's built-in `LookAtModifier3D` for bounded target gaze and a small custom `SkeletonModifier3D` for time-based additive action poses. This leaves the admitted GLB, license receipt, vendor lock, and Blender source unchanged. Godot applies skeleton modifiers after the `AnimationPlayer`, which lets the gaze and pose layer sit over the existing loops.
2. **Add authored Blender clips and re-admit the model:** gives an animator direct control over each gesture, but changes the existing private-use model package and requires rebuilding, validating, packaging, and admitting a new asset version.
3. **Set bone rotations in the actor's `_process`:** little setup, but competes with the current `AnimationPlayer` and modifier order, making transitions brittle. Do not use.

## Behavior

- Gaze follows the actor's current object or peer target, with a limited, eased head turn. A peer remains the gaze target after the Norn reaches observation distance. Without a target, the head returns toward a neutral forward point.
- Completion of `fruit`, `forage`, `drink`, or `spinner` starts a short additive pose: paw-to-mouth/head dip, nose dip, drink lean, or paw tap respectively. The pose eases in and out and then yields to the normal idle/curious loop.
- Existing walking, foot IK, action selection, biochemistry, interaction timing, and praise/scold behavior remain authoritative. Praise and Scold one-shots take visual priority over an interaction pose.
- Only the admitted rig's existing named `head`, `neck`, `arm_upper`, `arm_lower`, and `paw` bones are used. Missing rig bones or a static/procedural fallback must remain safe and continue to render.

## Constraints and non-goals

- Keep all gesture and gaze processing local, deterministic, and independent for each Norn.
- Do not edit, regenerate, package, or re-admit the GLB; do not change save data or network access.
- Do not add facial morphs, eye-bone tracking (the rig has no eye bones), audio, or new interaction rules.
- Use the existing recording workflow to show fruit, forage, drink, spinner, and peer attention in rendered Godot.

## Verification

The targeted rig check will cover modifier/bone setup, gaze target updates and neutral return, each supported action pose and its fade, response-animation priority, and safe fallback. The full Godot suite will run. A rendered clip will show the four interaction gestures and peer observation; its frames will be decoded and inspected.
