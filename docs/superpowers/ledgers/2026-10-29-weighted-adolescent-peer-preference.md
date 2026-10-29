# Weighted adolescent peer preference verification ledger

- Date: 2026-10-29
- Project: `C:\Users\Quad\Documents\GitHub\creatures-albia-prototype`
- Plan: `docs/superpowers/plans/2026-10-29-weighted-adolescent-peer-preference.md`

## Behavior delivered

- Peer scoring only runs after normal cognition chooses `observe_peer` for an adolescent.
- Score = normalized proximity (`clamp(1 - distance / 10, 0, 1)`) + `0.25` for a non-parent + remembered social valence bounded to `[-0.35, +0.35]`.
- Memory uses matching `observe` and `observe-feedback` episodes, recorded valence and salience, a 180-simulated-second half-life, and familiarity saturation after three recency-weighted units.
- Ties resolve by shortest distance, then stable actor ID. Existing child, baby, adult, and elder rules and guidance/action priorities remain in place.
- No new persisted fields were added. Save version remains 5.

## Verification

Headless checks, all exit code 0:

- `verify_social_slice.gd` → `SOCIAL_SLICE_CHECKS_OK`
- `verify_family_system.gd` → `FAMILY_SYSTEM_CHECKS_OK`
- `run_habitat_scenario.gd` → `HABITAT_SCENARIO_OK`

Rendered, non-headless recording:

- `record_preview.gd` → `ADOLESCENT_INDEPENDENCE_CAPTURE_OK`, `ADOLESCENT_MEMORY_OVERRIDE_CAPTURE_OK`, `FAMILY_LIFESPAN_CAPTURE_OK`, and `VIDEO_CAPTURE_OK`.
- Clip: `user://recordings/habitat-20261029-111422.avi` (`C:\Users\Quad\AppData\Roaming\Godot\app_userdata\New Albia — Godot 3D Slice\recordings\habitat-20261029-111422.avi`).
- `inspect_recording.gd` → `AVI_INSPECTION_OK`; 965 of 965 JPEG frames decoded at 1280×720 and every AVI index entry validated.
- Visually inspected frame `0933` (Sprout selects Clover at 180.3 seconds, reason: “Observing peer Clover beyond the family”), frame `0939` (Sprout's reason changes to “Remembering positive experiences with Mallow” and the recent Mallow episodes are visible), frame `0942` (the memory-based choice remains visible), and frame `0945` (Mallow's old-age entry appears in the family archive).
- The capture verified Mallow at 3.00 units and Clover at 4.20 units for the neutral-memory choice, and reported Mallow's memory contribution as `+0.35` for the override.
- The walkthrough restored the prior local save. The recordings folder contained 10 completed clips after capture; its existing oldest-clip retention rule kept the folder at or below the limit.

## Capture-fixture correction

The first rendered attempt showed both adolescent choices but failed a later save assertion. Investigation found the fixture had put the peer actor ID in `targetId`, while saved episode targets are restricted to known object IDs. The fixture now identifies the peer through `actorId` and leaves `targetId` unset; the full rerun passed, including the family save/archive checks.
