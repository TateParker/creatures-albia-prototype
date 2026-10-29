# Single-Point Reach Evaluation Implementation Plan

> **For agentic workers:** Use `superpowers:executing-plans` to execute this plan. The recommended route is native inline work in the current checkout because the cognition input, task runner, and rendered preview share interfaces. Do not add a learning rule in this phase.

**Goal:** Add an isolated, deterministic target-reach evaluator that measures the current no-update drawing motor's endpoint accuracy before any motor-learning rule is introduced.

**Architecture:** Append a target-relative cue to the cognition input while preserving target-free seeded behavior and existing save data. Define target scheduling and scoring in a pure task model. Run the baseline against a fresh `DrawingSurface` and cognition state per trial. Present one trial in a standalone rendered preview scene using a temporary surface, without loading or changing the shared habitat.

**Tech Stack:** Godot 4.7.2 GDScript, existing `NornCognition`, `DrawingSurface`, `LocalVideoRecorder`, Godot `SceneTree` verifiers and rendered capture tools. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-10-29-single-point-reach-design.md`

## Global Constraints

- Start each trial at UV `(0.5, 0.5)` on a blank 256×256 evaluation surface. Persist the initial center cursor through `DrawingSurface.append_point()` before the first motor decision.
- `DrawingSurface` stores cursor UVs on a 255-interval grid, so the nominal center persists as `(128/255, 128/255)`. Recompute target deltas from that quantized value and state this start quantization in the verifier and README.
- Place eight targets at radius `0.24` UV, numbered clockwise in screen UV coordinates from right/east: 0 right, 1 down-right, 2 down, 3 down-left, 4 left, 5 up-left, 6 up, 7 up-right. Cardinal directions are 0, 2, 4, and 6; held-out diagonals are 1, 3, 5, and 7.
- Give cognition target-relative `dx` and `dy`, normalized by `0.25` UV and clamped to `[-1, 1]`, in inputs 276 and 277. Keep mark pixels in inputs 20–275. Append zero target cues unless both the drawing surface and charcoal tool are visible and the cue is a finite `Vector2`; clamp accepted cue components to `[-1, 1]` before appending.
- Run exactly six motor decisions at a recorded interval of `0.2` simulated seconds. Recompute the cue from the current quantized cursor before each decision. Clamp the next UV to the surface bounds and apply the motor command through `DrawingSurface.append_point()`; never move the cursor directly or substitute an oracle command.
- Grade the final persisted/quantized cursor after decision six, including when the motor command is pen-up. Endpoint error is `distance(final_uv, target_uv) × 255`; a hit is at most 8 pixels, inclusive.
- Run 32 balanced trials per seed (four per direction) for seeds 9901–9905, with no action learning, outcome feedback, or motor-weight update. Reset recurrent hidden state, decision count, surface marks, and cursor for every trial while regenerating the same seeded motor policy.
- Hold traits and chemistry constant during each six-step reach. The evaluator isolates cursor control and does not advance the life-chemistry simulation.
- Report each seed's median endpoint error and hit rate, then the median of those seed-level metrics. Do not run the later cardinal-training/diagonal-evaluation study in this phase.
- Upgrade cognition state from version 3 to 4; migrate cognition states 1–3 without losing associations, episodes, chemistry, or recurrent state. Keep outer world saves at version 6. Do not add learned motor parameters.
- Keep ordinary drawing eligibility, safety priorities, mark sensing, and target-free seeded commands unchanged. Do not add claims about learning, mood, symbols, copying, communication, or intent.
- Render the preview in its own scene with a temporary surface and a clip directory outside `user://recordings/`. Back up and restore the local world save during capture, verify the existing user recording count is unchanged and at most 10, and inspect the resulting AVI and sample frames.

## File Map

| File | Responsibility |
|---|---|
| `godot/scripts/norn_cognition.gd` | Append target cues, expose one target-conditioned motor step, create independently seeded target weights, and migrate cognition state versions 1–3 to 4. |
| `godot/scripts/drawing_reach_task.gd` | Define target locations, deterministic balanced trial order, normalized target deltas, and endpoint scoring. |
| `godot/tools/verify_drawing_reach.gd` | Assert cognition cue behavior, geometry, scoring, reset rules, deterministic replay, and the no-update boundary. |
| `godot/tools/verify_drawing_system.gd` | Update existing cognition input-width and mark-offset assertions; retain all current drawing and world regression checks. |
| `godot/scripts/drawing_reach_evaluator.gd` | Own trial creation and one-step advancement so headless evaluation and rendered preview use the same motor/surface path. |
| `godot/tools/evaluate_drawing_reach.gd` | Run the five-seed, 32-trial-per-seed no-update baseline and print per-seed and across-seed results. |
| `godot/tools/drawing_reach_preview.tscn` | Provide a standalone rendered board, reticle, cursor, and score display. |
| `godot/tools/record_drawing_reach_preview.gd` | Run one six-step trial on a temporary surface, record the rendered preview, and restore the local save. |
| `godot/README.md` | Document the task protocol, measured baseline, and limits of the metric. |

## Review Focus

- **Target bounds and scoring:** Reject invalid directions and UVs. Test all eight target points remain on-surface, and that the 8-pixel hit boundary is inclusive.
- **Cue isolation:** Target deltas occupy only inputs 276–277 when both task objects are visible; mark pixels remain inputs 20–275. Missing, malformed, non-finite, or hidden-target cues append zeros.
- **Policy compatibility:** Compare target-free motor command fixtures captured from cognition v3. Confirm cognition versions 1–3 restore through version 4 without losing associations, episodes, chemistry, or recurrent state.
- **Trial reset and determinism:** Each trial starts with a blank surface, saved center cursor, zero hidden state, and exactly six decisions. Equal seeds and orders reproduce endpoints and scores.
- **No-update boundary:** Assert action associations, episodes, policy motor weights, and motor biases do not change during the evaluator.
- **Scoring the saved cursor:** Measure `DrawingSurface.get_last_uv()` after the sixth append, including pen-up steps; do not grade a raw floating-point motor command.

---

### Task 1: Add target-relative cognition inputs

**Files:**
- Modify: `godot/scripts/norn_cognition.gd`
- Modify: `godot/tools/verify_drawing_system.gd`
- Create: `godot/tools/verify_drawing_reach.gd`

**Interfaces:**
- Consumes: existing `NornCognition.draw_motor_command(state)`, `surfaceMarks`, `nearbyObjects`, and an optional normalized `drawTargetDelta: Vector2` observation field.
- Produces: `NornCognition.draw_motor_step(state: Dictionary, observation: Dictionary) -> Dictionary`, which advances recurrence exactly once and returns the existing bounded motor command; `_get_input_vector()` returns 278 values.

- [x] **Step 1: Capture the version-3 compatibility fixtures.** Run the current drawing verifier and capture six target-free motor commands for seeds 903 and 9901 using a blank visible surface and charcoal. Add those exact values to the new verifier as compatibility fixtures before changing `norn_cognition.gd`.
- [x] **Step 2: Write the failing cognition assertions.** In `verify_drawing_reach.gd`, assert 278 inputs, unchanged mark positions 20–275, normalized target cue positions 276–277, zero defaults for omitted/malformed/non-finite/hidden cues, one recurrence advance per `draw_motor_step()`, target-free fixture equality, and version 1–3 state restoration to version 4. Update `verify_drawing_system.gd`'s existing 276-width expectation and add an assertion that the mark grid still starts at input 20 and ends at 275.
- [x] **Step 3: Run both focused verifiers and confirm the new target-cue/version assertions fail** while existing drawing checks still pass apart from the intentionally changed width assertion.
- [x] **Step 4: Implement cognition version 4.** Append the two cues after the mark grid; accept only finite vectors when the surface and charcoal IDs are both in `nearbyObjects`; otherwise append zeros. Preserve the existing named, mark, action, recurrent, and motor random streams. Generate only the new target columns from an independent seed stream. Implement `draw_motor_step()` by advancing recurrence once and reusing `draw_motor_command()`.
- [x] **Step 5: Run the focused verifiers** with `& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path .\godot --script res://tools/verify_drawing_reach.gd` and the same command with `res://tools/verify_drawing_system.gd`. Confirm `DRAWING_REACH_CHECKS_OK`, `DRAWING_SYSTEM_CHECKS_OK`, and unchanged v3 command fixtures.

### Task 2: Define target geometry, schedule, and endpoint scoring

**Files:**
- Create: `godot/scripts/drawing_reach_task.gd`
- Modify: `godot/tools/verify_drawing_reach.gd`

**Interfaces:**
- Produces: `target_uv_for_direction(direction_index: int) -> Variant`, `build_balanced_trial_order(direction_indices: Array[int], repetitions_per_direction: int, seed: int) -> Array[Dictionary]`, `normalized_target_delta(cursor_uv: Vector2, target_uv: Vector2) -> Variant` using `(target_uv - cursor_uv) / 0.25` with component-wise clamping, and `score_endpoint(final_uv: Vector2, target_uv: Vector2) -> Dictionary`.
- A valid trial-order entry contains `directionIndex`, `repeatIndex`, and `targetUv`. Invalid direction lists, duplicate directions, invalid counts, and invalid UVs are rejected (the typed trial-order builder returns an empty array for invalid arguments) rather than silently scored.

- [x] **Step 1: Write failing task assertions** for the eight expected clockwise locations, in-bounds targets, invalid directions, invalid UV rejection, balanced requested subsets, deterministic shuffle for equal seeds, normalized/clamped target deltas, the 255-pixel scale, and the inclusive 8-pixel hit boundary.
- [x] **Step 2: Run `verify_drawing_reach.gd` and confirm the task-model assertions fail.**
- [x] **Step 3: Implement the pure task model.** Use a local `RandomNumberGenerator` seeded only by the supplied seed to shuffle balanced trial entries. Return `null` for invalid target/delta inputs and an empty score dictionary for invalid endpoint scores; valid score dictionaries contain `errorPixels` and `hit`.
- [x] **Step 4: Rerun `verify_drawing_reach.gd`** and confirm geometry, validation, order balance, determinism, and scoring pass.

### Task 3: Build and verify the no-update baseline evaluator

**Files:**
- Create: `godot/scripts/drawing_reach_evaluator.gd`
- Create: `godot/tools/evaluate_drawing_reach.gd`
- Modify: `godot/tools/verify_drawing_reach.gd`

**Interfaces:**
- Consumes: `NornCognition.draw_motor_step()`, `DrawingSurface.append_point()`, `DrawingSurface.get_last_uv()`, `DrawingSurface.sample_mark_grid()`, and `DrawingReachTask`.
- Produces: one record per seed with trial count, per-seed median endpoint error, and hit rate, followed by medians of those seed-level values across the five seeds. The runner also returns ordered trial endpoints and scores for replay assertions.
- `DrawingReachEvaluator.create_trial(seed, direction_index)` creates one clean trial; `DrawingReachEvaluator.advance_trial(trial)` applies exactly one cognition step and returns whether the trial is complete; `DrawingReachEvaluator.run_seed(seed)` loops through that seed's balanced schedule.

- [x] **Step 1: Add failing evaluator assertions** that each fixed seed runs exactly 32 trials (four per direction), initializes a blank surface and persisted center cursor, resets hidden state and decision count, performs exactly six decisions at 0.2 simulated seconds, and leaves associations, episodes, motor weights, and biases unchanged.
- [x] **Step 2: Run `verify_drawing_reach.gd` and confirm these evaluator assertions fail.**
- [x] **Step 3: Implement `DrawingReachEvaluator`.** `create_trial()` makes a fresh `DrawingSurface`, persists the center cursor, and creates cognition state with zero hidden state and decision count. `advance_trial()` samples marks at the quantized cursor, provides visible surface and charcoal objects plus the normalized current target delta, gets one motor command, clamps the proposed UV to `[0, 1]`, and applies it with `append_point()`. `run_seed()` loops through six calls per scheduled trial and scores the saved cursor.
- [x] **Step 4: Add deterministic replay assertions** that running seed 9901 twice produces the same target order, quantized endpoints, errors, and hit flags. Assert every final score comes from the stored cursor and every trial records six decisions.
- [x] **Step 5: Run the verifier and evaluator** with the Godot command above and `res://tools/evaluate_drawing_reach.gd`. Confirm five seeds 9901–9905 each have 32 trials, and record all seed rows plus the across-seed medians in the README.

### Task 4: Render one isolated target-reach trial

**Files:**
- Create: `godot/tools/drawing_reach_preview.tscn`
- Create: `godot/tools/record_drawing_reach_preview.gd`

- [x] **Step 1: Add the standalone preview scene** with a board image, separate target reticle, start/current cursor markers, and labels for decision count and final score. Use a temporary `DrawingSurface` and `LocalVideoRecorder`; do not instantiate `AlbiaWorld` or touch its shared drawing surface.
- [x] **Step 2: Add the capture flow** that backs up the existence and exact bytes of `user://albia_norn_save.json`, records the existing user-recording count, advances one seed-9901 trial through `DrawingReachEvaluator.advance_trial()` once per 0.2 simulated seconds, updates the preview after each step, finalizes an AVI under `C:/Users/Quad/Documents/Codex/2026-10-29/audit-review-and-verify-this-report-2/outputs/single-point-reach-preview` (outside `user://recordings/`), and restores the original save on success and failure.
- [x] **Step 3: Run the preview in rendered mode** using `& 'C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --path .\godot --scene res://tools/drawing_reach_preview.tscn`.
- [x] **Step 4: Inspect the AVI and sample frames** using `res://tools/inspect_recording.gd`; verify the quantized center start, reticle, incremental mark path, quantized endpoint, six-step count, and score are visible. Confirm a pre-existing save matches its original bytes (or remains absent if there was no save), the user recording count is unchanged and at most 10, and the preview output is outside `user://recordings/`.

### Task 5: Document the baseline and run regressions

**Files:**
- Modify: `godot/README.md`

- [x] **Step 1: Add a focused README section** describing the single-point task, cue isolation, six-step horizon, five-seed no-update results, per-seed and median metrics, and the limit that this baseline establishes neither learned motor skill nor intent.
- [x] **Step 2: Run the focused reach verifier and evaluator** and confirm the README numbers exactly match fresh output.
- [x] **Step 3: Run existing Godot regressions:** `verify_drawing_system.gd`, `verify_action_utility.gd`, `verify_social_slice.gd`, `verify_family_system.gd`, `verify_biochemistry.gd`, `verify_face_geometry.gd`, `verify_avi_writer.gd`, `verify_recording_retention.gd`, and `run_habitat_scenario.gd`. Confirm cognition versions 1–3 and outer world save versions 1–6 still migrate and restore as expected.
- [x] **Step 4: Review the final diff** for unchanged ordinary drawing priorities, target-free fixture equality, no learning updates, and absence of claims outside the approved scope.

---

## Acceptance Criteria

1. Existing target-free seeded motor commands, ordinary drawing eligibility, urgent-need priorities, and mark perception remain unchanged.
2. Cognition exposes 278 inputs with target cues only in indices 276–277 and mark perception in 20–275; cues are zero unless valid and both task objects are visible.
3. The task returns eight bounded points, a deterministic balanced schedule, six decisions per trial, quantized endpoint error, and an inclusive 8-pixel hit result.
4. Five seeds each run 32 no-update trials; replays of the same seed reproduce the trial order and scores.
5. Cognition versions 1–3 migrate to 4 without data loss; outer world saves remain version 6.
6. A rendered capture visibly verifies a trial and leaves the local save and existing user recordings unchanged.
7. No online motor learning, mood interpretation, social-copying, symbolic, communication, or intent claim is added.
