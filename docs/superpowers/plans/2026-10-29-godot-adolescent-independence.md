# Godot Adolescent Independence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make adolescent Norns prefer observing visible non-parent peers, completing the current age-stage social progression.

**Architecture:** Keep the existing `observe_peer` cognition action and sorted, visible peer list. Add an adolescent-only target-selection rule in `AlbiaWorld`; retain the nearest-peer fallback and keep all other stages unchanged. Demonstrate the rule with a real sibling in the rendered family walkthrough.

**Tech Stack:** Godot 4.7.2 Mono, typed GDScript, `SceneTree` verification scripts, local AVI recorder.

Run commands from the repository root using the local Godot 4.7.2 Mono executable: C:\Users\Quad\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe

**Spec:** `docs/superpowers/specs/2026-10-29-godot-adolescent-independence-design.md`

## Global Constraints

- Adolescent independence applies only when the existing decision chooses `observe_peer`.
- Select the nearest visible, living non-parent by the sorted sensed-peer list; if none qualifies, preserve nearest-visible-peer fallback.
- Preserve player guidance and the existing fruit, spinner, and rest priorities.
- Keep baby following, child parent preference and learning, adult and elder behavior, save fields, save version 5, and browser code unchanged.
- Use the in-game recorder in rendered non-headless mode and inspect the finished AVI or extracted frames.
- Keep at most 10 completed gameplay clips in `user://recordings/`; do not remove an active recording.

## Review Focus

- A closer visible parent must not displace a farther visible non-parent for an adolescent; test the selected peer ID.
- Among multiple visible non-parents, the nearest is selected; test with two sensed peers.
- With no eligible non-parent visible, nearest-visible-peer fallback remains; test after moving non-parents out of range.
- Guidance and urgent fruit, spinner, and rest decisions must bypass adolescent peer selection; test target/action priority.
- Child parent preference and other life stages must remain unchanged; keep their existing verifier checks green and do not add persisted state.

---

### Task 1: Adolescent peer selection

**Files:**
- Modify: `godot/scripts/albia_world.gd`
- Modify: `godot/tools/verify_social_slice.gd`

**Interfaces:**
- Consumes: `_sense_peers(profile: NornProfile) -> Array[Dictionary]`, `profile_for(actor_id: String) -> NornProfile`, and existing `NornProfile.parent_ids` / `life_stage`.
- Produces: `_nearest_visible_non_parent(profile: NornProfile, nearby_norns: Array[Dictionary]) -> NornProfile`, returning the nearest eligible non-parent from the sorted sensed list or `null`.

- [x] **Step 1: Write failing adolescent selection checks.** Add `test_adolescent_observer_prefers_nearest_visible_non_parent_and_falls_back`. Use an adolescent with Mallow as its parent, put Mallow within 3 units, and put two non-parent peers farther away but inside the sense radius. Force its settled cognition to choose `observe_peer`; assert it targets the nearer non-parent and its reason names that peer. Move both non-parents outside sensing range and assert it falls back to Mallow. Add `test_adolescent_peer_preference_only_applies_to_observe_peer` to assert guidance and cognition-selected fruit, spinner, and rest actions keep priority.
- [x] **Step 2: Run the social verifier and confirm the intended failure.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: the new adolescent peer-selection assertion fails because the current code selects the nearest peer; no parse or fixture errors.

- [x] **Step 3: Implement nearest non-parent selection.** Add `_nearest_visible_non_parent(profile, nearby_norns)` in `albia_world.gd`, returning the first living, valid non-parent in the already distance-sorted visible list. In the `observe_peer` branch, use it only when `life_stage == "adolescent"`; keep child parent preference and all other-stage selection as written. When a non-parent is selected, set the action reason to `"Observing peer %s beyond the family" % peer.display_name`.
- [x] **Step 4: Run the focused verifier.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Expected: `SOCIAL_SLICE_CHECKS_OK`, including nearest-non-parent selection, fallback, adolescent priority cases, existing child preference, guidance, and need-priority checks.

---

### Task 2: Rendered walkthrough, documentation, and full verification

**Files:**
- Modify: `godot/tools/record_preview.gd`
- Modify: `godot/README.md`
- Create: `docs/superpowers/ledgers/2026-10-29-godot-adolescent-independence.md`

**Interfaces:**
- Consumes: Task 1's `_nearest_visible_non_parent` selection and the existing family, lifecycle, and recorder APIs.
- Produces: a rendered scene showing an adolescent choose a non-parent sibling while a parent is closer, with the action reason visible in the HUD.

- [x] **Step 1: Extend the family walkthrough with an adolescent sibling observation.** After the first child-observation segment, create a second egg from Mallow and Moss through the family controls and let normal incubation hatch it, keeping the living-plus-egg count within four. Set the first child just before the 180-second adolescent boundary and let the normal lifecycle tick cross it. Freeze and place the parent at 3 units and the sibling between 3 and 5 units from the adolescent; move the other parent outside sensing range. Settle needs and arrange the existing cognition state to choose `observe_peer`. Assert the adolescent targets the sibling, identifies them in its action reason, and displays that reason in the focused HUD. Continue the existing lifespan/archive walkthrough and preserve save restoration.
- [x] **Step 2: Run the native regression checks.**

Run: `& $godot --headless --path .\godot --script res://tools/verify_social_slice.gd`

Run: `& $godot --headless --path .\godot --script res://tools/verify_family_system.gd`

Run: `& $godot --headless --fixed-fps 60 --path .\godot --script res://tools/run_habitat_scenario.gd`

Expected: `SOCIAL_SLICE_CHECKS_OK`, `FAMILY_SYSTEM_CHECKS_OK`, and `HABITAT_SCENARIO_OK`.

- [x] **Step 3: Record and inspect the rendered walkthrough.** Run `record_preview.gd` without `--headless`; require an adolescent-independence capture marker and retain the printed AVI path. Run `inspect_recording.gd` on that AVI, verify every frame and the index, and inspect samples showing the adolescent, nearer parent, selected sibling, visible reason, and later archive UI. Confirm 10 or fewer completed clips remain.

Expected: `VIDEO_CAPTURE_OK`, `ADOLESCENT_INDEPENDENCE_CAPTURE_OK`, and `AVI_INSPECTION_OK` for the saved rendered clip.

- [x] **Step 4: Update README and ledger.** Document the adolescent peer preference and record the clip path, decoded frame count, inspected frames, regression outputs, and completed-clip count. Do not change the save schema or version.
