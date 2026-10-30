# Norn Foot Planting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce visible foot sliding by locking Norn feet during stance and lifting them during swing, while keeping `CharacterBody3D` movement authoritative.

**Architecture:** Add two `TwoBoneIK3D` modifiers to the imported Norn skeleton, one for each existing upper-leg/lower-leg/foot chain. Actor-local gait phase follows distance moved; world-space targets remain still through stance and blend toward the next landing point with a small swing arc. Walk playback speed follows the measured actor speed and the selected stride distance.

**Tech Stack:** Godot 4.7.2 GDScript and SkeletonModifier3D/TwoBoneIK3D; existing rendered Godot AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-norn-foot-planting-design.md`

## Global Constraints

- Keep movement and collision controlled by `CharacterBody3D`.
- Use the already admitted 25-bone GLB without changing its bytes, package, vendor lock, or license.
- Use named chains `leg_upper.L` → `leg_lower.L` → `foot.L` and `leg_upper.R` → `leg_lower.R` → `foot.R`.
- Keep the existing static/procedural fallback path valid if rig bones or IK configuration are unavailable.
- Record and inspect a rendered non-headless Godot clip; retain no more than 10 completed clips.

## Review Focus

- Missing or renamed leg bones must leave the actor on the existing fallback without runtime errors; cover in the targeted rig check.
- Stance targets must not move as the actor advances; cover with a fixed-phase actor test.
- Swing targets must lift and land continuously; cover sampled start/mid/end target values and inspect the clip.
- Gait timing must track different movement speeds; assert the computed playback scale at two speeds.
- IK must fade out when walking ends and stay off during praise/scold one-shots; assert solver influence and response state.

---

### Task 1: Add failing foot-planting assertions

**Files:**
- Modify: `godot/tools/verify_norn_animation.gd`

**Interfaces:**
- Consumes: `NornActor`, the admitted rigged GLB, and Godot's `TwoBoneIK3D` class.
- Produces: Rig setup, stance/swing target, gait timing, stop, and response assertions.

- [x] **Step 1: Add rig setup assertions** that require two modifiers, one per expected named chain, each with a resolvable target and pole node.
- [x] **Step 2: Add a stance-lock test** that establishes a left-foot plant, moves the actor while phase remains in stance, and asserts the target's world position stays unchanged within 0.001 units.
- [x] **Step 3: Add swing assertions** at swing start, midpoint, and landing; the midpoint must be above the floor, and the landing point must be continuous with the next stance plant within 0.02 units.
- [x] **Step 4: Assert walk playback scale** equals `animation.length * speed / 1.2` for speeds 1.4 and 2.8, and equals 1.0 when idle or a response one-shot is active.
- [x] **Step 5: Run the targeted rig check** and confirm it fails because the actor has no foot modifiers/targets yet.

### Task 2: Add distance-synchronized stance/swing IK

**Files:**
- Modify: `godot/scripts/norn_actor.gd`
- Test: `godot/tools/verify_norn_animation.gd`

**Interfaces:**
- Consumes: `is_walking`, measured movement distance, imported skeleton, and the test contracts from Task 1.
- Produces: `_configure_foot_planting(skeleton: Skeleton3D) -> void`, `_update_foot_planting_targets(gait_phase: float) -> void`, and `_walk_speed_scale_for(speed: float) -> float`.

- [x] **Step 1: Configure two `TwoBoneIK3D` nodes** under the rig's skeleton with the named bone chains, per-foot target nodes, and per-knee pole nodes. Skip configuration if any required chain bone is absent.
- [x] **Step 2: Capture actor-local ankle offsets** from the imported rest pose and initialize planted target points from the current skeleton pose.
- [x] **Step 3: Implement gait target updates** with `WALK_CYCLE_DISTANCE = 1.2`, `STANCE_FRACTION = 0.48`, `SWING_LIFT = 0.14`, and alternating right-foot phase offset 0.5. Lock targets during stance; during swing, smoothstep toward the actor's next foot position and add a half-sine lift.
- [x] **Step 4: Accumulate actual post-slide horizontal displacement** during `_physics_process` and use it to derive the normalized gait phase.
- [x] **Step 5: Synchronize walk animation playback** with `_walk_speed_scale_for(speed)` using `walk_animation.length * speed / WALK_CYCLE_DISTANCE`; restore speed scale 1.0 for idle/curious and response one-shots.
- [x] **Step 6: Blend solver influence** to 1.0 while walking and 0.0 over 0.12 seconds when stationary or during one-shot responses. Reset phase/targets when walking begins or direction changes sharply.
- [x] **Step 7: Run the targeted rig check** and require `NORN_RIG_CHECKS_OK` with the new assertions included.

### Task 3: Run full regression and inspect rendered gait

**Files:**
- Modify: `godot/README.md`
- Modify: `godot/ASSET_INVENTORY.md`
- Create/update: `docs/superpowers/ledgers/2026-10-29-norn-foot-planting.md`
- Create by recorder: one rendered verification clip in `user://recordings/`.

**Interfaces:**
- Consumes: the passing rig verifier and existing verification suite.
- Produces: full test evidence, a visually reviewed walking clip, and usage/limitation notes.

- [x] **Step 1: Run the complete serial Godot verification suite** and require `GODOT_VERIFICATION_SUITE_OK count=13` with exit 0.
- [x] **Step 2: Record a rendered walkthrough** that includes an extended straight walk, a turn, stopping, a response animation, and resumed walking.
- [x] **Step 3: Decode all AVI frames and inspect close-up and gait samples** for planted stance feet, smooth swing lifts/landings, knee direction, and no visible solver snaps or mesh tearing.
- [x] **Step 4: Check completed recordings remain at 10 or fewer**, then update README, asset inventory, and the verification ledger with the capture path and findings.
- [x] **Step 5: Run `git diff --check` and confirm the admitted GLB, package lock, static fallback, and unrelated working-tree changes remain untouched.** The diff check exited 0; the admitted rigged model SHA-256 still matches the previously approved hash. The static fallback, vendor lock, and pre-existing working-tree changes were not modified by this pass.
