# Unified Deterministic Action Utility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Norns select among fruit, spinner, rest, peer observation, and idle using one deterministic utility ranking with urgent-need safeguards.

**Architecture:** Keep scoring and decision explanations in `NornCognition`; use the existing world layer for sensing, player guidance, and developmental overrides. Add a focused cognition verifier, then extend the rendered recording so the urgency-over-commitment result is visible in the HUD.

**Tech Stack:** Godot 4.7.2, GDScript, SceneTree verification scripts, the existing local Motion JPEG AVI recorder.

**Spec:** `docs/superpowers/specs/2026-10-29-unified-action-utility-design.md`

## Global Constraints

- Keep the system local and deterministic; do not add randomness or external/cloud inference.
- Keep decisions suitable for the existing 5 Hz decision cadence.
- Preserve the existing five actions and the outer game save version (`5`) and field set. Cognition state version `2` uses centered action associations; restore version `1` states by mapping their former zero-based associations into the neutral-to-positive range.
- Fruit urgency begins at hunger `90` or glucose `10` and below; rest urgency begins at fatigue `95`.
- Preserve fixed tie order: fruit, spinner, rest, observe_peer, idle.
- Keep at most 10 completed gameplay clips in `user://recordings/`; never remove a clip still being recorded.
- Verify gameplay changes with a rendered, non-headless recording and inspect the resulting clip or extracted frames.
- Local command substitution: this workspace provides Godot 4.7.2 Mono under `C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\`; use the `_console.exe` variant for headless commands and the windowed `.exe` for rendered recording.

## Review Focus

- Hunger, glucose, and fatigue immediately below and at their safety thresholds must not trigger an early safety override or miss the threshold; pin both sides of every boundary in Task 2.
- Simultaneous urgent food and rest needs must select the higher normalized severity and use the fixed order on an exact tie; pin both winner directions and the tie in Task 2.
- A fruit/spinner target that disappears during the 1.2-second commitment must not be restored, and `observe_peer` must not win without a sensed peer; pin these in Task 2.
- A strong learned preference may redirect a close, non-critical choice but must not suppress a safety action; cover both behaviors in Tasks 1 and 2.
- Repeated equivalent observations and restored legacy decisions must remain deterministic and valid without a save-version change; pin determinism and state round-trip in Tasks 1 and 3.

---

### Task 1: Unified utility scores and decision explanation

**Files:**
- Create: `godot/tools/verify_action_utility.gd`
- Modify: `godot/scripts/norn_cognition.gd`

**Interfaces:**
- Consumes: existing `Cognition.create_state`, `Cognition.preview`, `Cognition.decide`, `Cognition.record_outcome`, and the five `ACTION_IDS`.
- Produces: `_score_decision(state: Dictionary, observation: Dictionary) -> Dictionary` continues to return `actionId`, `actionScores`, `reason`, `recalledEpisodeIds`, and the legacy `components`; it also exposes `eligibleActions`, per-action `scoreBreakdown`, and `safetyOverride` for the live decision. `Cognition.decide` strips only those three diagnostic fields before persisting `lastDecision`, preserving the existing serialized fields.

- [x] **Step 1: Write failing ordinary-choice and explanation checks** in `verify_action_utility.gd`.

  Assert that settled needs with no nearby peers select idle; a fresh neutral action association does not suppress curiosity-driven spinner seeking; a strong learned non-critical action preference can beat idle; version-1 zero-based associations restore into the centered range; all five actions receive finite utilities in `[0, 100]`; each score equals its `scoreBreakdown` final utility; identical state/observation pairs return identical action IDs and score breakdowns; and `decide` returns diagnostics while serialized/restored `lastDecision` retains only the existing fields.

- [x] **Step 2: Run the focused verifier and confirm the unified-ranking assertions fail.**

  Run from the repository root: `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_action_utility.gd`

  Expected before implementation: `ACTION_UTILITY_CHECKS_FAILED` for the new utility-ranking and score-breakdown assertions.

- [x] **Step 3: Implement the shared bounded utility ranking** in `_score_decision`.

  Normalize the existing need drives to `[0, 100]`; default untrained action associations to the neutral value `0.5` and center them there; clamp combined action, context, episodic, and recurrent preference influence to `[-20, 20]`; use idle utility `24` before preference influence; and clamp final action utility to `[0, 100]`. Cognition version `2` marks the centered association baseline and migrates version `1` zero-based associations; keep outer game save version `5` and its field set unchanged. Keep exact ties in the action order listed in Global Constraints. Keep the existing legacy component keys so current decision validation and debug consumers continue to work. Return the new explanation fields to the caller, then strip `eligibleActions`, `scoreBreakdown`, and `safetyOverride` from the stored `lastDecision` so the save shape stays unchanged.

- [x] **Step 4: Run the focused verifier and confirm ordinary decisions pass.**

  Run: `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_action_utility.gd`

  Expected: `ACTION_UTILITY_CHECKS_OK` with all ordinary-choice, score-bound, breakdown, and determinism assertions passing.

### Task 2: Urgent-need safeguards, candidate eligibility, and commitment

**Files:**
- Modify: `godot/scripts/norn_cognition.gd`
- Modify: `godot/tools/verify_action_utility.gd`

**Interfaces:**
- Consumes: Task 1's `eligibleActions`, utility scores, and breakdown.
- Produces: a safety-selected `actionId` plus a transient `safetyOverride` action ID (`"fruit"`, `"rest"`, or empty); `_apply_commitment` may retain fruit/spinner only when still eligible and must not replace a safety override.

- [x] **Step 1: Add failing safety and eligibility tests.**

  Cover hunger `89` versus `90`, glucose `11` versus `10`, fatigue `94` versus `95`; fruit overriding a live spinner commitment; rest overriding a live fruit commitment; simultaneous urgent actions won by the greater normalized severity with fruit winning an exact tie; unavailable fruit/spinner and absent peers omitted from eligible actions; and a previously committed but now ineligible target not being restored. Also check that an urgent action with no eligible target falls back deterministically among eligible actions.

- [x] **Step 2: Run the focused verifier and confirm the new safety/eligibility assertions fail.**

  Run: `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_action_utility.gd`

  Expected before implementation: `ACTION_UTILITY_CHECKS_FAILED` for the newly added boundary, override, or eligibility cases.

- [x] **Step 3: Implement urgency selection and eligibility-aware commitment.**

  Use the spec's exact severity formulas for simultaneous urgency. Build candidates from current observations: fruit/spinner only when the matching sensed object exists, `observe_peer` only with a sensed peer, and rest/idle always. If an urgent candidate is eligible, safety selection wins before ordinary utility ranking; if both urgent actions are eligible, compare severity and use the fixed tie order. Let `_apply_commitment` retain a previous target only when it remains eligible and no safety override is active.

- [x] **Step 4: Run the focused verifier and confirm all safety/eligibility cases pass.**

  Run: `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_action_utility.gd`

  Expected: `ACTION_UTILITY_CHECKS_OK` including all threshold, simultaneous urgency, missing-target, absent-peer, and commitment assertions.

### Task 3: World regression, rendered proof, and documentation

**Files:**
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/README.md`

**Interfaces:**
- Consumes: Task 2's decision result and the existing `_run_decision`, HUD, recorder, AVI inspector, and regression scripts.
- Produces: an `ACTION_UTILITY_CAPTURE_OK` marker in the rendered walkthrough after it demonstrates an urgent hunger choice overriding a spinner commitment; a README verification entry with the AVI path and inspected-frame findings.

- [x] **Step 1: Add the rendered walkthrough assertion and capture segment.**

  Add a scripted scenario while the relevant Norns and fruit target are available. Create an active spinner commitment, apply the approved urgent hunger/glucose state, invoke the actual world decision path, and assert the effective fruit decision, safety reason, HUD text, and restored temporary actor/profile state. Keep the prior local save backup/restore behavior.

- [x] **Step 2: Run the recorder and inspect the resulting video.**

  Run without `--headless`: `Godot_v4.7.2-stable_win64.exe --path .\godot --script res://tools/record_preview.gd`

  Expected: `ACTION_UTILITY_CAPTURE_OK` and `VIDEO_CAPTURE_OK` with the output clip path. Then run `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/inspect_recording.gd -- <clip-path> <frame-output-folder>`. Confirm every AVI frame decodes and inspect the extracted frame showing the urgency reason/action in the HUD. Verify the completed clip count is 10 or fewer.

- [x] **Step 3: Run the existing world and performance regressions.**

  Run:

  - `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_social_slice.gd`
  - `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/verify_family_system.gd`
  - `Godot_v4.7.2-stable_win64.exe --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`
  - `Godot_v4.7.2-stable_win64.exe --headless --path .\godot --script res://tools/profile_cognition.gd`

  Expected: social, family, and habitat checks report their existing `*_OK` markers; cognition decision p95 remains below 1,000 μs per decision. The performance target leaves a small fraction of the 200 ms decision interval for scoring.

- [x] **Step 4: Record the verified outcome** in `godot/README.md` with the actual clip path, decoded frame count, inspected frames that show the prior choice and safety override, regression markers, measured decision p95, and final recording count.
