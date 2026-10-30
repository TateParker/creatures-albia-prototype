# Norn Foot Planting Design

## Intent

Reduce visible foot sliding while Norns walk by keeping each foot fixed against the habitat floor during its stance phase and moving it in a short lifted arc during swing. Keep root travel under `CharacterBody3D` so navigation, collision, and action timing remain authoritative.

## Current behavior

`NornActor` moves at `WALK_SPEED` and selects the imported `walk` clip. The clip is a 31-frame loop with small alternating upper-leg rotations; lower legs and feet have no authored gait motion. Animation playback speed is independent of actor speed, so the visible cycle does not match distance traveled. The admitted rig provides `leg_upper.L/R`, `leg_lower.L/R`, and `foot.L/R` chains.

## Approaches

1. **Reauthor the Blender walk clip and admit a new package.** This gives the most direct art control, but requires a new asset build, validation, package version, and project admission.
2. **Use Godot runtime two-bone IK with stance-locked foot targets (selected).** Godot 4.7's `SkeletonModifier3D` runs after animation playback, and `TwoBoneIK3D` can solve the existing upper-leg/lower-leg/foot chains. This keeps the admitted package intact and lets target motion follow actual actor speed. The solver requires pole targets to control knee bend.
3. **Only retime the existing walk clip.** This is low risk but cannot lock a foot in place and the current leg motion is too small to hide sliding reliably.

## Design

- Attach one `TwoBoneIK3D` modifier per leg under the imported `Skeleton3D`, with hip/lower-leg/foot bone names and a stable knee pole target.
- Add per-foot target nodes in the actor's rig space. During stance, keep a foot target anchored in world space. During swing, interpolate it forward to the next plant point and raise it slightly above the floor, with smooth lift and landing transitions.
- Derive gait phase from walking distance and scale walk animation playback so one cycle corresponds to a bounded stride distance. This keeps authored upper-body motion and foot targets in phase when speed changes.
- Turn the modifiers off while stationary or during one-shot praise/scold clips. Resume them only when locomotion resumes. If the required skeleton or bones are absent, retain the current static/procedural fallback behavior without errors.
- Keep the existing model package and license unchanged. The habitat is currently flat; grounding uses the actor's floor height. Uneven terrain adaptation and new authored clips are out of scope.

## Goals and limits

- Reduce stance-phase foot motion relative to the world and avoid visible snapping at the stance/swing boundary.
- Keep left and right steps alternating, preserve the current body animation, and avoid changing movement speed, destination logic, or collision.
- Validate solver setup, phase transitions, playback-rate selection, stop/resume behavior, and absent-rig fallback in a Godot verification script; inspect a rendered walking clip.
- Do not add a terrain-following system, regenerate the GLB, or change the vendor package.

## References

- [Godot 4.7 SkeletonModifier3D](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html) documents post-AnimationMixer processing.
- [Godot 4.7 TwoBoneIK3D](https://docs.godotengine.org/en/4.7/classes/class_twoboneik3d.html) documents the two-bone solver and pole target requirement.
